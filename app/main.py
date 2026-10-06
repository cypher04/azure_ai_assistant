"""AI assistant API: answers questions from the documents in Azure AI Search (RAG).

Flow per question:
  1. embed the question with the embedding deployment
  2. hybrid (keyword + vector) search over the "documents" index
  3. send the question plus the retrieved passages to the chat deployment
  4. return the answer and the sources it was based on

Auth is Entra ID only (DefaultAzureCredential): the web app's managed identity in
Azure, your `az login` session locally. The search service has local auth
disabled, so API keys would not work anyway.
"""

import logging
import os
from functools import lru_cache
from pathlib import Path

from azure.core.exceptions import HttpResponseError
from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from azure.search.documents import SearchClient
from azure.search.documents.models import VectorizedQuery
from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from openai import APIError, AzureOpenAI
from pydantic import BaseModel, Field

# ---------------------------------------------------------------- settings
# Required: the app fails at startup if these are missing.
OPENAI_ENDPOINT = os.environ["AZURE_OPENAI_ENDPOINT"]
SEARCH_ENDPOINT = os.environ["AZURE_SEARCH_ENDPOINT"]

# Defaults match modules/compute and search/indexes/documents.json.
CHAT_DEPLOYMENT = os.getenv("AZURE_OPENAI_CHAT_DEPLOYMENT", "gpt-4o")
EMBEDDING_DEPLOYMENT = os.getenv("AZURE_OPENAI_EMBEDDING_DEPLOYMENT", "embedding")
OPENAI_API_VERSION = os.getenv("AZURE_OPENAI_API_VERSION", "2024-10-21")
SEARCH_INDEX = os.getenv("AZURE_SEARCH_INDEX", "documents")
TOP_K = int(os.getenv("SEARCH_TOP_K", "5"))
MAX_CHARS_PER_SOURCE = 4000

SYSTEM_PROMPT = """You are an assistant that answers questions using only the sources provided.
- Cite the sources you use with their number in square brackets, e.g. [1] or [2][3].
- If the sources do not contain the answer, say you don't know. Do not guess.
- Be concise."""

logger = logging.getLogger("ai-assistant")
app = FastAPI(title="AI Assistant")
STATIC_DIR = Path(__file__).parent / "static"


# ---------------------------------------------------------------- clients
# Created once per worker on first use, then reused.
@lru_cache
def credential() -> DefaultAzureCredential:
    return DefaultAzureCredential()


@lru_cache
def openai_client() -> AzureOpenAI:
    token_provider = get_bearer_token_provider(
        credential(), "https://cognitiveservices.azure.com/.default"
    )
    return AzureOpenAI(
        azure_endpoint=OPENAI_ENDPOINT,
        azure_ad_token_provider=token_provider,
        api_version=OPENAI_API_VERSION,
    )


@lru_cache
def search_client() -> SearchClient:
    return SearchClient(SEARCH_ENDPOINT, SEARCH_INDEX, credential())


# ---------------------------------------------------------------- models
class ChatRequest(BaseModel):
    question: str = Field(min_length=1, max_length=2000)


class Source(BaseModel):
    id: str
    title: str | None = None


class ChatResponse(BaseModel):
    answer: str
    sources: list[Source]


# ---------------------------------------------------------------- RAG
def retrieve(question: str) -> list[dict]:
    """Hybrid search: keyword match on content/title plus vector similarity."""
    embedding = (
        openai_client()
        .embeddings.create(model=EMBEDDING_DEPLOYMENT, input=question)
        .data[0]
        .embedding
    )
    results = search_client().search(
        search_text=question,
        vector_queries=[
            VectorizedQuery(vector=embedding, k_nearest_neighbors=TOP_K, fields="embedding")
        ],
        select=["id", "title", "content"],
        top=TOP_K,
    )
    return [
        {"id": r["id"], "title": r.get("title"), "content": r.get("content") or ""}
        for r in results
    ]


def answer(question: str, docs: list[dict]) -> str:
    sources = "\n\n".join(
        f"[{i}] {d['title'] or d['id']}\n{d['content'][:MAX_CHARS_PER_SOURCE]}"
        for i, d in enumerate(docs, start=1)
    )
    completion = openai_client().chat.completions.create(
        model=CHAT_DEPLOYMENT,
        temperature=0.2,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": f"Sources:\n{sources or '(none found)'}\n\nQuestion: {question}"},
        ],
    )
    return completion.choices[0].message.content or ""


# ---------------------------------------------------------------- routes
@app.get("/", include_in_schema=False)
def index() -> FileResponse:
    return FileResponse(STATIC_DIR / "index.html")


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.post("/api/chat", response_model=ChatResponse)
def chat(req: ChatRequest) -> ChatResponse:
    try:
        docs = retrieve(req.question)
        if not docs:
            return ChatResponse(answer="I couldn't find anything relevant in the documents.", sources=[])
        return ChatResponse(
            answer=answer(req.question, docs),
            sources=[Source(id=d["id"], title=d["title"]) for d in docs],
        )
    except (HttpResponseError, APIError) as exc:
        # Most common cause: the managed identity is missing a role assignment.
        logger.exception("Upstream Azure call failed")
        raise HTTPException(status_code=502, detail=f"Upstream service error: {exc}") from exc

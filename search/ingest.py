"""Load files from the "documents" blob container into the "documents" search index.

For each blob:
  1. download it and extract the text (.pdf, .docx, .txt, .md)
  2. split the text into overlapping chunks
  3. embed each chunk with the embedding deployment
  4. upload the chunks to the index, then delete any chunks left over from an
     older version of the same file

Re-running is safe: chunk ids are derived from the blob name, so a re-run
overwrites instead of duplicating. The index itself is created/updated from
indexes/documents.json on every run.

Auth is Entra ID (DefaultAzureCredential), the same as the app. The identity
running this needs:
  - Storage Blob Data Reader          on the storage account
  - Search Service Contributor        on the search service (creates the index)
  - Search Index Data Contributor     on the search service (writes documents)
  - Cognitive Services OpenAI User    on the AI Services account

Usage:
  python ingest.py                 # every blob in the container
  python ingest.py --blob a.pdf    # just one (repeatable)
"""

import argparse
import hashlib
import io
import json
import logging
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from azure.search.documents import SearchClient
from azure.storage.blob import ContainerClient
from docx import Document as DocxDocument
from openai import AzureOpenAI
from pypdf import PdfReader

# ---------------------------------------------------------------- settings
STORAGE_ACCOUNT_URL = os.environ["AZURE_STORAGE_ACCOUNT_URL"]  # https://aistorageXXXX.blob.core.windows.net
SEARCH_ENDPOINT = os.environ["AZURE_SEARCH_ENDPOINT"]
OPENAI_ENDPOINT = os.environ["AZURE_OPENAI_ENDPOINT"]

CONTAINER = os.getenv("AZURE_STORAGE_CONTAINER", "documents")
EMBEDDING_DEPLOYMENT = os.getenv("AZURE_OPENAI_EMBEDDING_DEPLOYMENT", "embedding")
OPENAI_API_VERSION = os.getenv("AZURE_OPENAI_API_VERSION", "2024-10-21")
SEARCH_API_VERSION = "2024-07-01"
INDEX_FILE = Path(__file__).parent / "indexes" / "documents.json"

CHUNK_CHARS = 2000      # ~500 tokens
CHUNK_OVERLAP = 200     # so a sentence cut at a boundary still appears whole in one chunk
EMBED_BATCH = 16        # chunks per embeddings call
UPLOAD_BATCH = 100      # documents per index upload

log = logging.getLogger("ingest")


# ---------------------------------------------------------------- index
def ensure_index(credential: DefaultAzureCredential) -> str:
    """PUT the index definition from indexes/documents.json (create or update)."""
    definition = json.loads(INDEX_FILE.read_text())
    name = definition["name"]
    token = credential.get_token("https://search.azure.com/.default").token
    req = urllib.request.Request(
        f"{SEARCH_ENDPOINT.rstrip('/')}/indexes/{name}?api-version={SEARCH_API_VERSION}",
        data=json.dumps(definition).encode(),
        method="PUT",
        headers={"Content-Type": "application/json", "Authorization": f"Bearer {token}"},
    )
    try:
        with urllib.request.urlopen(req) as resp:
            log.info("Index '%s' ready (HTTP %s)", name, resp.status)
    except urllib.error.HTTPError as exc:
        # e.g. 400 if a field's type changed: Search can't alter existing fields,
        # so the index has to be deleted and rebuilt.
        sys.exit(f"Failed to create/update index '{name}': {exc.code} {exc.read().decode()}")
    return name


# ---------------------------------------------------------------- text
def extract_text(name: str, data: bytes) -> str | None:
    ext = Path(name).suffix.lower()
    if ext == ".pdf":
        return "\n\n".join(page.extract_text() or "" for page in PdfReader(io.BytesIO(data)).pages)
    if ext == ".docx":
        return "\n\n".join(p.text for p in DocxDocument(io.BytesIO(data)).paragraphs)
    if ext in (".txt", ".md"):
        return data.decode("utf-8", errors="replace")
    return None


def chunk(text: str) -> list[str]:
    """Fixed-size chunks with overlap, cut at the nearest paragraph/sentence/word break."""
    text = text.strip()
    chunks, start = [], 0
    while start < len(text):
        end = min(start + CHUNK_CHARS, len(text))
        if end < len(text):
            window = text[start:end]
            for sep in ("\n\n", ". ", " "):
                cut = window.rfind(sep)
                if cut > CHUNK_CHARS // 2:
                    end = start + cut + len(sep)
                    break
        piece = text[start:end].strip()
        if piece:
            chunks.append(piece)
        if end >= len(text):
            break
        start = max(end - CHUNK_OVERLAP, start + 1)
    return chunks


# ---------------------------------------------------------------- ingest
def chunk_id(source: str, i: int) -> str:
    # Keys may only contain letters, digits, '_', '-', '='; blob names can contain anything.
    return f"{hashlib.sha1(source.encode()).hexdigest()[:16]}-{i}"


def existing_ids(search: SearchClient, source: str) -> set[str]:
    escaped = source.replace("'", "''")
    return {d["id"] for d in search.search(search_text="*", filter=f"source eq '{escaped}'", select=["id"])}


def ingest_blob(name: str, data: bytes, openai: AzureOpenAI, search: SearchClient) -> int:
    text = extract_text(name, data)
    if text is None:
        log.warning("Skipping %s: unsupported file type", name)
        return 0
    pieces = chunk(text)
    if not pieces:
        log.warning("Skipping %s: no text extracted (scanned PDF?)", name)
        return 0

    docs = []
    for b in range(0, len(pieces), EMBED_BATCH):
        batch = pieces[b : b + EMBED_BATCH]
        vectors = openai.embeddings.create(model=EMBEDDING_DEPLOYMENT, input=batch).data
        for offset, (content, vec) in enumerate(zip(batch, vectors)):
            docs.append({
                "id": chunk_id(name, b + offset),
                "title": Path(name).name,
                "source": name,
                "content": content,
                "embedding": vec.embedding,
            })

    old_ids = existing_ids(search, name)
    for b in range(0, len(docs), UPLOAD_BATCH):
        results = search.upload_documents(docs[b : b + UPLOAD_BATCH])
        failed = [r.key for r in results if not r.succeeded]
        if failed:
            raise RuntimeError(f"{len(failed)} chunk(s) failed to upload: {failed[:5]}")

    # The file got shorter since last run: remove the chunks that no longer exist.
    stale = old_ids - {d["id"] for d in docs}
    if stale:
        search.delete_documents([{"id": i} for i in stale])

    log.info("%s: %d chunk(s) indexed, %d stale removed", name, len(docs), len(stale))
    return len(docs)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--blob", action="append", help="only ingest this blob (repeatable)")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    logging.getLogger("azure").setLevel(logging.WARNING)

    credential = DefaultAzureCredential()
    index_name = ensure_index(credential)

    container = ContainerClient(STORAGE_ACCOUNT_URL, CONTAINER, credential=credential)
    search = SearchClient(SEARCH_ENDPOINT, index_name, credential)
    openai = AzureOpenAI(
        azure_endpoint=OPENAI_ENDPOINT,
        azure_ad_token_provider=get_bearer_token_provider(credential, "https://cognitiveservices.azure.com/.default"),
        api_version=OPENAI_API_VERSION,
        max_retries=10,  # the embedding deployment has low TPM; the client backs off on 429s
    )

    names = args.blob or [b.name for b in container.list_blobs()]
    total, failures = 0, []
    for name in names:
        try:
            data = container.download_blob(name).readall()
            total += ingest_blob(name, data, openai, search)
        except Exception:
            log.exception("Failed: %s", name)
            failures.append(name)

    log.info("Done: %d blob(s), %d chunk(s) indexed, %d failed", len(names), total, len(failures))
    if failures:
        sys.exit(1)


if __name__ == "__main__":
    main()

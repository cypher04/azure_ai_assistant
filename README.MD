# Enterprise AI Assistant on Azure

A retrieval-augmented (RAG) assistant that answers questions from your own
documents, built with Terraform and deployed by a GitLab CI/CD pipeline that
authenticates with **workload identity federation**. No Azure credentials are
stored in GitLab or in this repository, and the app holds no API keys: every
service-to-service call uses Entra ID.

The repo holds three Terraform stacks with separate state, a Python web app,
and an ingestion script that loads documents into the search index.

## How it works

```
User → Web App (FastAPI, App Service)
          ├─→ Azure OpenAI   embeds the question, then answers it   (gpt-4o, text-embedding-3-small)
          └─→ AI Search      hybrid keyword + vector search          ("documents" index)

search/ingest.py:  Blob Storage ("documents" container) → extract text → chunk → embed → AI Search
```

1. Upload files (`.pdf`, `.docx`, `.txt`, `.md`) to the `documents` blob container.
2. The `ingest` job splits them into overlapping chunks, embeds each chunk and
   writes it to the `documents` index.
3. For each question, the app retrieves the most relevant chunks and asks the
   chat model to answer **only** from them, citing sources as `[1]`, `[2]`. If
   the documents don't contain the answer, it says so instead of guessing.

## Stacks and apply order

Order matters: each stack depends on the one above it existing.

| # | Path | Creates | State | Applied by |
|---|------|---------|-------|------------|
| 1 | `backend/` | Resource group, storage account and `tfstate` container that hold remote state | Local file | Human, once |
| 2 | `gitlab/` | Two Entra ID app registrations and service principals (one for Terraform, one for app deploy and ingestion), federated credentials, RBAC role assignments, GitLab environment, branch protection, CI/CD variables | `gitlab-ai-terraform.tfstate` | Human, on identity changes |
| 3 | `env/dev/` | The workload: networking, AI services, search, storage, web app, and the ingestion identity's data roles | `ai-terraform.tfstate` | The pipeline |

`backend/` keeps its state in a local file on purpose: it *creates* the remote
backend, so it cannot use one. Back that file up. It is gitignored and is the
only record of the state infrastructure.

The `gitlab/` stack is deliberately never applied by CI. It owns the identities
that grant the pipeline its access, so letting the pipeline rewrite it would be
circular. **A change to `gitlab/*.tf` only takes effect when a human applies it.**

## Prerequisites

- **Terraform**: CI runs `1.9.8`; use 1.9 or newer locally
- **Azure CLI**: for the initial sign-in; providers pinned to `azurerm ~> 4.80`
- **Python 3.12+**: only to run the app or ingestion locally. On macOS with the
  python.org installer, run `Install Certificates.command` once, or HTTPS calls
  fail with `CERTIFICATE_VERIFY_FAILED`
- **Azure permissions**: ability to create Entra ID app registrations and assign
  RBAC roles at subscription scope
- **Azure quota**: App Service quota in the region set by `app_location`
- **A GitLab project**: `gitlab.tf` reads it with a `data` source; it does not
  create it
- **A GitLab personal access token** with `api` scope, for the bootstrap stack

## First-time setup

```bash
# 1. sign in and select the subscription
az login --tenant <tenant-id>
az account set --subscription <subscription-id>

# 2. create the remote state backend
terraform -chdir=backend init
terraform -chdir=backend apply

# 3. create the pipeline identities and GitLab configuration
export TF_VAR_gitlab_token='<gitlab-pat>'
terraform -chdir=gitlab init
terraform -chdir=gitlab apply

# 4. point the ingestion roles at the app service principal's OBJECT ID
az ad sp show --id <app-client-id> --query id -o tsv
#    → set ingest_principal_id in env/dev/dev.auto.tfvars
```

`ingest_principal_id` must be the service principal's **object ID**, not its
client (application) ID. The client ID fails with `PrincipalNotFound`.

Secrets are passed through the environment, never through a committed file.
`*.tfvars` is gitignored, with one deliberate exception: `env/*/*.auto.tfvars`,
which carries non-secret values (regions, CIDRs, the ingestion principal's
object ID) that CI needs.

## Day-to-day

A change ships through the pipeline, defined in `.gitlab-ci.yml`:

| Stage | Runs on | Trigger | What it does |
|-------|---------|---------|--------------|
| `validate` | any branch, any MR | automatic | `fmt -check`, `init -backend=false`, `validate`; no Azure access needed |
| `plan` | default branch | automatic | authenticates via OIDC, plans against real state, saves `tfplan` as an artifact |
| `apply` | default branch | **manual** | applies the exact plan artifact from `plan` |
| `app-deploy` | default branch | **manual** | zips `app/` and deploys it to the web app (looked up by name, since it has a random suffix) |
| `ingest` | default branch | **manual** | looks up the storage, search and OpenAI endpoints, then runs `search/ingest.py` |
| `destroy` | default branch | **manual** | tears the environment down |

1. Branch, edit, run `terraform fmt -recursive`, open a merge request.
2. `validate` runs on the MR.
3. On merge, `plan` runs and prints the full plan into the job log. **Read it.**
4. Release `apply` by hand if the plan is what you intended.
5. Release `app-deploy` after app code changes, and `ingest` after uploading documents.

`apply` and `destroy` share a `resource_group` mutex so two runs can never touch
the state file at once.

After `apply`, the site address is printed under `Outputs:`, or at any time with:

```bash
terraform -chdir=env/dev output -raw web_app_url
```

## Loading documents

Upload files to the `documents` container, then release the `ingest` job. Re-running
is safe: chunk IDs are derived from the file name, so a re-run overwrites instead
of duplicating, and chunks left over from a shortened file are removed.

To run ingestion from a laptop instead, your own account needs the same four
roles as the pipeline identity (see [Authentication](#authentication)):

```bash
cd search
python3 -m pip install -r requirements.txt
export AZURE_STORAGE_ACCOUNT_URL=https://<storage-account>.blob.core.windows.net
export AZURE_SEARCH_ENDPOINT=https://<search-service>.search.windows.net
export AZURE_OPENAI_ENDPOINT=https://<ai-account>.cognitiveservices.azure.com/
python3 ingest.py                 # every file in the container
python3 ingest.py --blob a.pdf    # just one
```

The embedding deployment runs at low capacity, so large document sets ingest
slowly. The client backs off and retries rather than failing.

## Repository layout

```
backend/        remote state bootstrap (local state)
gitlab/         pipeline identities, RBAC, GitLab project config
env/dev/        the deployed dev environment, plus the ingestion identity's roles
env/stage/      scaffold: files exist but are empty
env/prod/       scaffold: files exist but are empty
modules/
  networking/   hub and two spoke VNets with peering, route tables, NSGs,
                delegated App Service subnet, private endpoints and DNS for OpenAI and storage
  compute/      AI Services account and project, gpt-4o and embedding deployments,
                content-filter policy, AI Search (Entra-only auth), shared private link to storage
  database/     storage account with documents and processed containers
  app/          App Service plan, Linux web app (Python 3.12), managed identity and its roles
  security/     not yet implemented
app/            FastAPI web app: chat API and single-page UI
search/
  indexes/      index schema (documents.json)
  ingest.py     blob → chunk → embed → index loader
```

## Authentication

GitLab mints a short-lived OIDC token for each job. Entra ID exchanges it for an
access token only if the token's `sub` claim matches a federated credential
exactly, and the resulting service principal holds only the RBAC it was granted.

There are three identities, each with only what it needs:

| Identity | Used by | Roles |
|----------|---------|-------|
| Terraform service principal | `plan`, `apply`, `destroy` | Contributor and RBAC Administrator on the subscription; Blob Data Contributor on the state account |
| App service principal | `app-deploy`, `ingest` | Website Contributor and Reader on the subscription; Search Service Contributor, Search Index Data Contributor, Storage Blob Data Contributor and Cognitive Services OpenAI User on the workload |
| Web app managed identity | the running app | Cognitive Services OpenAI User; Search Index Data Reader |

Points worth knowing:

- **Management and data roles are separate.** Owner or Contributor can create
  resources but cannot read blobs, write index documents or call the model. Those
  need the data roles above. AI Search adds one more split: creating an index needs
  **Search Service Contributor**, and writing documents needs **Search Index Data Contributor**.
- New role assignments can take a minute or two to apply. A 403 straight after
  an apply is usually that delay.
- The credentials' subject is pinned to the default branch, so only pipelines on
  that branch can authenticate. `validate` works anywhere because it runs with
  `-backend=false` and needs no Azure access.
- CI/CD variables are **protected**, so they are injected only on protected
  branches and tags. On any other ref they arrive as empty strings, which
  surfaces as a confusing authentication error rather than a missing-value one.

## State

Remote state lives in the storage account created by `backend/`, with blob
versioning and a 30-day soft-delete window. If a run is cancelled mid-operation
the lease can be left held:

```bash
terraform -chdir=env/dev force-unlock <LOCK_ID>
```

Confirm no pipeline job is still running first.

## Status

`env/dev` is the only environment built out. `env/stage` and `env/prod` contain
empty placeholder files, and the `security` module is likewise unimplemented.
Treat them as not yet available.

## Tear down

Release the manual `destroy` job on the default branch. It removes everything in
`env/dev`, including the uploaded documents and the search index. Re-ingest after
the next `apply`.

`backend/` and `gitlab/` are not touched by `destroy`. Remove them by hand, in
reverse order, only when retiring the project. The state storage account has
`prevent_destroy = true`, so delete that `lifecycle` block in `backend/main.tf`
first, or the second command refuses to run:

```bash
terraform -chdir=gitlab destroy
terraform -chdir=backend destroy
```

Azure AI Services accounts are soft-deleted for 48 hours and keep their name
reserved. To free it immediately:

```bash
az cognitiveservices account list-deleted -o table
az cognitiveservices account purge --name <ai-account> --resource-group compute-rg --location <region>
```

## License

Proprietary. All rights reserved.

# ShopPulse

## Architecture

ShopPulse is a lightweight e-commerce analytics platform built around three services: **api** (Python/FastAPI) receives sales events from the frontend, persists them to PostgreSQL, and publishes each event to an Azure Service Bus queue; **worker** (Python) consumes that queue, recomputes a 24-hour dashboard summary, and caches it in Redis; **frontend** (React/Vite) provides a form for submitting events and a live dashboard that polls the API every 10 seconds. All services run as Docker containers and are intended for deployment on Azure Kubernetes Service.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (includes Docker Compose v2)

## Quickstart

```bash
git clone <this-repo>
cd shoppulse
docker compose up --build
```

Services start at:
- Frontend: http://localhost:3000
- API: http://localhost:8000
- Service Bus emulator UI: http://localhost:8080

## Submit a test event

```bash
curl -s -X POST http://localhost:8000/api/events \
  -H "Content-Type: application/json" \
  -d '{
    "store_id": "store-42",
    "product_id": "SKU-9981",
    "product_name": "Widget Pro",
    "event_type": "sale",
    "quantity": 2,
    "unit_price": 49.99
  }' | jq .
```

## Dashboard

Open http://localhost:3000/dashboard. It polls every 10 seconds. A **LIVE (cache)** badge means the worker has processed at least one event and the Redis cache is warm; **FALLBACK (db)** means it is querying PostgreSQL directly.

## Azure (Terraform + AKS)

One Terraform root under [infra/terraform/](infra/terraform/README.md): shared modules, root files per service (`redis.tf`, `aks.tf`, …).

- **Full stack** (default): network + AKS + Service Bus + private data plane  
- **Data layer only**: `enable_aks=false` (same modules, no AKS)

Kubernetes manifests: [infra/terraform/k8s/README.md](infra/terraform/k8s/README.md).

```powershell
kubectl get svc frontend -n shoppulse
```

## Observability

One Log Analytics workspace per environment collects everything:

- **Platform** — a diagnostic setting on AKS, PostgreSQL, Key Vault, ACR, Service Bus, Redis and the blob service ships `allLogs` and `AllMetrics`.
- **Containers** — the Container Insights addon, authenticated with managed identity rather than a workspace key.
- **Application** — Application Insights, fed by `azure-monitor-opentelemetry` in the API and the worker. No connection string in the environment means the app runs uninstrumented, which is what docker-compose and CI want.

Alerts go through one action group (`alert_email` to add a receiver): node CPU and memory, PostgreSQL CPU and storage, pods restarting more than three times in 30 minutes, and more than 20 error log lines in 15 minutes. Dev caps ingestion at 1 GB/day, because on a student subscription a log storm is a billing incident; prod removes the cap and samples telemetry instead.

Queries for the usual questions are in [`docs/runbooks/incident-response.md`](docs/runbooks/incident-response.md).

## Report snapshots

The worker writes the dashboard summary to a private blob container after each recompute, at most once every 15 minutes, keyed by day (`2026-09-21/summary-160509.json`). `GET /api/reports` lists them. The worker identity holds Storage Blob Data Contributor, the API identity only Reader, and the account has shared key access disabled — so there is no key to leak and the read path cannot corrupt the archive. A lifecycle policy tiers snapshots to cool, then archive, then deletes them, with short steps in dev so the policy can be watched working.

A failed upload is logged and dropped: storage is a side channel and must never cost us a queue message.

## Decisions and runbooks

- [`docs/adr/`](docs/adr/README.md) — why the Terraform root is single, why the data plane is private, why Workload Identity, why Azure Monitor.
- [`docs/runbooks/incident-response.md`](docs/runbooks/incident-response.md) — severity levels, the first five minutes, KQL queries, rollback, database restore.

## CI/CD (GitHub Actions)

[`ci.yml`](.github/workflows/ci.yml) runs on every pull request and push to `main`. Jobs are selected by which paths changed, so a README edit does not rebuild images:

| Job | Checks |
|-----|--------|
| Terraform | `fmt -check`, `validate` without a backend, `tflint` (advisory) |
| Manifests | `yamllint`, `kubeconform` against the Kubernetes schemas |
| Python | `ruff check` over `api/` and `worker/` |
| Tests | `pytest`: API endpoints through `TestClient` with fake dependencies, plus the worker's DSN parsing. No database, Redis or Service Bus required |
| Frontend | `tsc --noEmit`, the only type gate since `vite build` skips types |
| Dockerfiles | `hadolint` |
| Security | `gitleaks` over the full history, `checkov` on Terraform (advisory) |
| Build | Docker build per changed service, Trivy report, blocking on fixable CRITICAL |

`CI OK` aggregates them into one status check — that is the one to require in branch protection.

The other workflows:

- [`terraform-plan.yml`](.github/workflows/terraform-plan.yml) plans against real Azure state and posts the output as a pull request comment.
- [`drift.yml`](.github/workflows/drift.yml) re-plans nightly and opens an issue when Azure no longer matches the code.
- [`deploy.yml`](.github/workflows/deploy.yml) is manual, authenticates with OIDC, pushes images tagged `sha-<commit>`, rolls them out, smoke tests the public URL and rolls back if anything fails.
- [`pr-title.yml`](.github/workflows/pr-title.yml) enforces Conventional Commits on pull request titles.
- [`release.yml`](.github/workflows/release.yml) publishes a GitHub release when a `v*` tag is pushed, and images tagged with that version once ACR exists.

Dependencies and pinned action SHAs are kept current by [`dependabot.yml`](.github/dependabot.yml). Environments differ only by input file and state key: [`envs/dev.tfvars`](infra/terraform/envs/dev.tfvars) and [`envs/prod.tfvars`](infra/terraform/envs/prod.tfvars).

All three Azure workflows skip themselves until the repository variables described in their header comments exist, so the pipeline stays green before any cloud setup.

Manifests use the `IMAGE_TAG` placeholder, so both the workflow and [`scripts/deploy.ps1`](scripts/deploy.ps1) deploy exactly the tag they just built.

## Environment variable reference

### API (`api/`)

| Variable | Description | Default |
|---|---|---|
| `DATABASE_URL` | PostgreSQL DSN (`postgresql+asyncpg://…`) | — |
| `REDIS_URL` | Redis connection string | `redis://localhost:6379/0` |
| `SERVICE_BUS_CONNECTION_STRING` | Azure Service Bus namespace connection string | — |
| `SERVICE_BUS_QUEUE_NAME` | Queue name | `sales-events` |
| `CORS_ORIGINS` | Comma-separated allowed origins | `*` |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | Enables tracing when set | `""` (uninstrumented) |
| `REPORTS_STORAGE_ACCOUNT_URL` | Blob endpoint for snapshots. Empty disables `/api/reports` | `""` |
| `REPORTS_CONTAINER` | Container holding snapshots | `reports` |

### Worker (`worker/`)

| Variable | Description | Default |
|---|---|---|
| `DATABASE_URL` | PostgreSQL DSN | — |
| `REDIS_URL` | Redis connection string | `redis://localhost:6379/0` |
| `SERVICE_BUS_CONNECTION_STRING` | Azure Service Bus namespace connection string | — |
| `SERVICE_BUS_QUEUE_NAME` | Queue name | `sales-events` |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | Enables tracing when set | `""` (uninstrumented) |
| `REPORTS_STORAGE_ACCOUNT_URL` | Blob endpoint for snapshots. Empty disables snapshot writes | `""` |
| `REPORTS_CONTAINER` | Container holding snapshots | `reports` |
| `REPORTS_MIN_INTERVAL_SECONDS` | Minimum gap between snapshot writes | `900` |

### Frontend (`frontend/`)

| Variable | Description | Default |
|---|---|---|
| `VITE_API_BASE_URL` | Base URL for the API | `""` (same origin via nginx proxy) |

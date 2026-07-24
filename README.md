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

Kubernetes manifests: [infra/k8s/README.md](infra/k8s/README.md).

```powershell
kubectl get svc frontend -n shoppulse
```
## Environment variable reference

### API (`api/`)

| Variable | Description | Default |
|---|---|---|
| `DATABASE_URL` | PostgreSQL DSN (`postgresql+asyncpg://…`) | — |
| `REDIS_URL` | Redis connection string | `redis://localhost:6379/0` |
| `SERVICE_BUS_CONNECTION_STRING` | Azure Service Bus namespace connection string | — |
| `SERVICE_BUS_QUEUE_NAME` | Queue name | `sales-events` |
| `CORS_ORIGINS` | Comma-separated allowed origins | `*` |

### Worker (`worker/`)

| Variable | Description | Default |
|---|---|---|
| `DATABASE_URL` | PostgreSQL DSN | — |
| `REDIS_URL` | Redis connection string | `redis://localhost:6379/0` |
| `SERVICE_BUS_CONNECTION_STRING` | Azure Service Bus namespace connection string | — |
| `SERVICE_BUS_QUEUE_NAME` | Queue name | `sales-events` |

### Frontend (`frontend/`)

| Variable | Description | Default |
|---|---|---|
| `VITE_API_BASE_URL` | Base URL for the API | `""` (same origin via nginx proxy) |

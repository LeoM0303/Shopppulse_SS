# ShopPulse — Kubernetes deployment

Manifests for deploying api, worker, frontend to AKS.

## Prerequisites

- `terraform apply` completed (AKS, ACR, Key Vault)
- `az login`, `docker`
- **One-time kubectl setup** (fixes `kubelogin not found` in new terminals):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup-kubectl.ps1
```

## One-command deploy

```powershell
.\scripts\deploy.ps1
```

Options:

```powershell
.\scripts\deploy.ps1 -SkipTerraform   # ACR already provisioned
.\scripts\deploy.ps1 -SkipBuild       # images already in ACR
.\scripts\deploy.ps1 -ImageTag v1.0.0  # custom tag
```

## What it does

1. Applies ACR via Terraform (unless `-SkipTerraform`)
2. Builds & pushes `shoppulse-api`, `shoppulse-worker`, `shoppulse-frontend` to ACR
3. Syncs secrets from Key Vault → Kubernetes Secret `shoppulse-secrets`
4. Applies manifests from `infra/k8s/`
5. Prints frontend LoadBalancer URL

## Access in browser

After deploy (or `az aks start`), open:

- **Frontend:** http://134.112.0.53
- **Dashboard:** http://134.112.0.53/dashboard

IP can change when the cluster is stopped and started. Current address:

```powershell
kubectl get svc frontend -n shoppulse -o jsonpath='http://{.status.loadBalancer.ingress[0].ip}{"\n"}'
```

## Architecture in cluster

```
Internet → frontend (LoadBalancer:80)
              └─ nginx /api/* → api:8000
worker ← KEDA ScaledObject ← Service Bus queue sales-events
api/worker → PostgreSQL, Redis, Service Bus (secrets from Key Vault)
```

## Useful commands

```powershell
kubectl get pods -n shoppulse
kubectl logs -n shoppulse deployment/api -f
kubectl get svc frontend -n shoppulse
kubectl get scaledobject -n shoppulse
```

## Stop AKS to save credits

```powershell
az aks stop --resource-group shoppulse-dev-rg --name shoppulse-dev-aks
```

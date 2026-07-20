# ShopPulse — Terraform data layer (private networking)

Provisions four Azure data-plane resources inside an **existing** resource group and VNet
(referenced via Terraform `data` sources — this stack does **not** create the network).

| Resource | Implementation |
|----------|----------------|
| **ACR** | Premium, admin disabled, public access disabled, private endpoint + `privatelink.azurecr.io` |
| **Key Vault** | Standard, soft-delete + purge protection, RBAC, public access disabled, private endpoint + `privatelink.vaultcore.azure.net` |
| **Redis** | Azure Managed Redis (`Balanced_B0`), public access disabled, private endpoint + `privatelink.redis.azure.net` |
| **PostgreSQL** | Flexible Server v16, `GP_Standard_D2s_v3`, 32 GB, VNet integration (delegated subnet), `privatelink.postgres.database.azure.com`, database `shoppulse`, backup 7 days, geo-redundant backup off |

Secrets (via `random_password`, never hardcoded):

- `postgres-password` — also used as PostgreSQL admin password
- `redis-password`
- `servicebus-connection-string`

## Redis: assignment vs Azure reality

The assignment text specifies **Azure Cache for Redis Premium P1** (`family = P`, `capacity = 1`) and DNS `privatelink.redis.cache.windows.net`.

Azure now **blocks creating** new Azure Cache for Redis instances:

> *Azure Cache for Redis is retiring, create Azure Managed Redis instance instead.*  
> See [retirement schedule](https://aka.ms/AzureCacheForRedisRetirement).

This stack therefore uses **Azure Managed Redis** with the same security goals:

- no public network access
- private endpoint (`subresource_names = ["redisEnterprise"]`)
- private DNS zone `privatelink.redis.azure.net` ([Private Link DNS values](https://learn.microsoft.com/azure/private-link/private-endpoint-dns))

Connectivity was verified from a jumpbox in the VNet: `AUTH` → `OK`, `PING` → `PONG` (host resolved to private IP `10.0.17.7`).

## Prerequisites

- Terraform >= 1.5
- Azure CLI (`az login`)
- Existing RG + VNet with subnets:
  - `private-endpoints` — for ACR / Key Vault / Redis private endpoints
  - `postgres` — delegated to `Microsoft.DBforPostgreSQL/flexibleServers`

If the network does not exist yet, use the optional bootstrap once (see below).

## No hardcoded IDs / secrets

| Value | Source |
|-------|--------|
| Subscription | `$env:ARM_SUBSCRIPTION_ID` ← `az account show` |
| RG / VNet names | `{project}-{environment}-rg` / `-vnet` (defaults: `shoppulse-dev-*`) |
| Location | Existing RG (`data.azurerm_resource_group`) |
| Passwords | `random_password` → Key Vault |
| Deployer IP (temporary KV open) | `data.http` → api.ipify.org |

## Quick start

### 0) Subscription in every new shell

```powershell
az login
$env:ARM_SUBSCRIPTION_ID = (az account show --query id -o tsv)
```

### 1) Bootstrap network (optional)

```powershell
cd infra/terraform-data/bootstrap-network
terraform init
terraform apply
```

Creates `shoppulse-dev-rg`, `shoppulse-dev-vnet`, subnets `postgres` + `private-endpoints`.

### 2) Data layer — first apply (from a laptop)

Key Vault starts with public access **temporarily** enabled so Terraform can write secrets.
Your public IP is auto-allowed.

```powershell
cd infra/terraform-data
terraform init
terraform apply -auto-approve -var="key_vault_public_network_access_enabled=true"
```

### 3) Lock Key Vault (task requirement: no public access)

If your IP changed and you see `403 ForbiddenByFirewall`, refresh the allowlist first, then lock
with `-refresh=false` so Terraform does not re-read secrets over the public endpoint:

```powershell
terraform apply -auto-approve -var="key_vault_public_network_access_enabled=true"
terraform apply -auto-approve -refresh=false -var="key_vault_public_network_access_enabled=false"
```

## Verify (control plane)

```powershell
az acr show -n shoppulsedevacr --query "{sku:sku.name,admin:adminUserEnabled,public:publicNetworkAccess}" -o json
az keyvault show -n shoppulsedevkv5886 --query "{public:properties.publicNetworkAccess,purge:properties.enablePurgeProtection,rbac:properties.enableRbacAuthorization}" -o json
az resource show -g shoppulse-dev-rg -n shoppulsedevredis --resource-type Microsoft.Cache/redisEnterprise --query "{state:properties.resourceState,public:properties.publicNetworkAccess}" -o json
az postgres flexible-server show -g shoppulse-dev-rg -n shoppulse-dev-psql --query "{version:version,sku:sku.name,public:network.publicNetworkAccess}" -o json
az network private-endpoint list -g shoppulse-dev-rg -o table
```

Listing Key Vault secrets from the public internet will fail after step 3 — that is expected.

## Optional: test Redis from inside the VNet

Public Redis access is disabled. Use a short-lived jumpbox in `private-endpoints`:

```powershell
# Prefer Standard_D2s_v4 in polandcentral (B-series often SkuNotAvailable)
az vm create -g shoppulse-dev-rg -n jumpbox --image Ubuntu2204 --size Standard_D2s_v4 `
  --vnet-name shoppulse-dev-vnet --subnet private-endpoints --public-ip-sku Standard `
  --admin-username azureuser --generate-ssh-keys

az redisenterprise database list-keys --cluster-name shoppulsedevredis -g shoppulse-dev-rg --query primaryKey -o tsv
ssh azureuser@<publicIp>
```

On the jumpbox:

```bash
sudo apt-get update && sudo apt-get install -y redis-tools
getent hosts shoppulsedevredis.polandcentral.redis.azure.net   # expect 10.x.x.x
redis-cli -h shoppulsedevredis.polandcentral.redis.azure.net -p 10000 --tls
# AUTH default <primaryKey>
# PING   → PONG
```

Cleanup:

```powershell
az vm delete -g shoppulse-dev-rg -n jumpbox --yes --force-deletion true
```

## Destroy

```powershell
cd infra/terraform-data
$env:ARM_SUBSCRIPTION_ID = (az account show --query id -o tsv)

# If KV is locked, open briefly or use -refresh=false / destroy from a host in the VNet
terraform destroy -auto-approve -var="key_vault_public_network_access_enabled=true"

cd bootstrap-network
terraform destroy -auto-approve
```

## Layout

```
terraform-data/
├── main.tf                 # data sources, random passwords, secrets, modules
├── variables.tf
├── outputs.tf
├── providers.tf
├── bootstrap-network/      # optional RG / VNet / subnets
└── modules/
    ├── acr/
    ├── keyvault/
    ├── redis/              # azurerm_managed_redis + PE
    └── postgresql/
```

## Cost

Managed Redis, Premium ACR, and GP PostgreSQL are billable while running. Destroy when not needed.
Jumpbox (`Standard_D2s_v4`) should be deleted immediately after connectivity tests.

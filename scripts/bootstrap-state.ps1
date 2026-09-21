#Requires -Version 5.1
<#
.SYNOPSIS
    Creates the Azure Storage account that holds Terraform remote state, and writes backend.hcl.

.DESCRIPTION
    Terraform cannot create its own backend, so this runs once with the Azure CLI before the
    first `terraform init`. The account is locked down: no public blob access, TLS 1.2 minimum,
    blob versioning and soft delete on, so a corrupted or deleted state file can be recovered.

    Access uses Entra ID rather than storage account keys, which is why the script assigns
    "Storage Blob Data Contributor" to the caller instead of handing out a key.

.EXAMPLE
    .\scripts\bootstrap-state.ps1
    .\scripts\bootstrap-state.ps1 -StorageAccount shoppulsetfstate42 -StateKey shoppulse/prod.tfstate
#>
param(
    [string]$ResourceGroup = "shoppulse-tfstate-rg",
    [string]$Location = "polandcentral",
    [string]$StorageAccount = "",
    [string]$Container = "tfstate",
    [string]$StateKey = "shoppulse/dev.tfstate"
)

$ErrorActionPreference = "Stop"

$TfDir = Join-Path (Split-Path $PSScriptRoot -Parent) "infra/terraform"

if (-not $StorageAccount) {
    # Storage account names are globally unique, lowercase, max 24 characters.
    $suffix = -join ((48..57) + (97..122) | Get-Random -Count 6 | ForEach-Object { [char]$_ })
    $StorageAccount = "shoppulsetfstate$suffix"
}

$subscriptionId = az account show --query id -o tsv
if (-not $subscriptionId) { throw "Not logged in. Run 'az login' first." }
Write-Host "==> Subscription: $subscriptionId" -ForegroundColor Cyan

Write-Host "==> Resource group $ResourceGroup" -ForegroundColor Yellow
az group create --name $ResourceGroup --location $Location --output none

Write-Host "==> Storage account $StorageAccount" -ForegroundColor Yellow
az storage account create `
    --name $StorageAccount `
    --resource-group $ResourceGroup `
    --location $Location `
    --sku Standard_LRS `
    --kind StorageV2 `
    --min-tls-version TLS1_2 `
    --allow-blob-public-access false `
    --allow-shared-key-access false `
    --output none

Write-Host "==> Enabling versioning and soft delete" -ForegroundColor Yellow
az storage account blob-service-properties update `
    --account-name $StorageAccount `
    --resource-group $ResourceGroup `
    --enable-versioning true `
    --enable-delete-retention true `
    --delete-retention-days 30 `
    --output none

$accountId = az storage account show --name $StorageAccount --resource-group $ResourceGroup --query id -o tsv
$callerId = az ad signed-in-user show --query id -o tsv

Write-Host "==> Granting Storage Blob Data Contributor to the current user" -ForegroundColor Yellow
az role assignment create `
    --assignee-object-id $callerId `
    --assignee-principal-type User `
    --role "Storage Blob Data Contributor" `
    --scope $accountId `
    --output none 2>$null

# Role assignments are eventually consistent; container creation right after tends to 403.
Write-Host "==> Waiting 30s for the role assignment to propagate" -ForegroundColor Yellow
Start-Sleep -Seconds 30

Write-Host "==> Container $Container" -ForegroundColor Yellow
az storage container create `
    --name $Container `
    --account-name $StorageAccount `
    --auth-mode login `
    --output none

$backendPath = Join-Path $TfDir "backend.hcl"
@"
resource_group_name  = "$ResourceGroup"
storage_account_name = "$StorageAccount"
container_name       = "$Container"
key                  = "$StateKey"
"@ | Set-Content -Path $backendPath -Encoding UTF8

Write-Host ""
Write-Host "Wrote $backendPath" -ForegroundColor Green
Write-Host ""
Write-Host "Next:" -ForegroundColor Cyan
Write-Host "  cd infra/terraform"
Write-Host "  terraform init -backend-config=backend.hcl -migrate-state"
Write-Host ""
Write-Host "For CI, set these repository variables:" -ForegroundColor Cyan
Write-Host "  TFSTATE_RESOURCE_GROUP  = $ResourceGroup"
Write-Host "  TFSTATE_STORAGE_ACCOUNT = $StorageAccount"
Write-Host "  TFSTATE_CONTAINER       = $Container"
Write-Host "  TFSTATE_KEY             = $StateKey"

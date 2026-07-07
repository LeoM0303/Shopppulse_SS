# ShopPulse — build, push, and deploy to AKS
#
# Prerequisites: az login, docker, kubectl, terraform apply (infra + ACR)
#
# Usage:
#   .\scripts\deploy.ps1              # full pipeline
#   .\scripts\deploy.ps1 -SkipBuild     # only sync secrets + apply manifests
#   .\scripts\deploy.ps1 -SkipTerraform # skip ACR terraform apply

param(
    [string]$ImageTag = "latest",
    [switch]$SkipBuild,
    [switch]$SkipTerraform
)

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$TfDir = Join-Path $RepoRoot "infra\terraform"
$K8sDir = Join-Path $RepoRoot "infra\k8s"
$BuildDir = Join-Path $env:TEMP "shoppulse-k8s-build"

# kubelogin/kubectl from `az aks install-cli` are not always on PATH in new shells
$env:Path = "$env:USERPROFILE\.azure-kubelogin;$env:USERPROFILE\.azure-kubectl;" + $env:Path
if (-not (Get-Command kubelogin -ErrorAction SilentlyContinue)) {
    throw "kubelogin not found. Run: az aks install-cli"
}
kubelogin convert-kubeconfig -l azurecli | Out-Null

function Get-TfOutput($name) {
    Push-Location $TfDir
    try { return (terraform output -raw $name) }
    finally { Pop-Location }
}

function Get-TfOutputJson($name) {
    Push-Location $TfDir
    try { return (terraform output -json $name | ConvertFrom-Json) }
    finally { Pop-Location }
}

Write-Host "==> ShopPulse deploy (tag: $ImageTag)" -ForegroundColor Cyan

# --- Terraform: ACR (if not skipped) ---
if (-not $SkipTerraform) {
    Write-Host "==> Applying ACR via Terraform..." -ForegroundColor Yellow
    Push-Location $TfDir
    terraform apply -auto-approve -target=module.acr -target=azurerm_role_assignment.kubelet_acr_pull -target=azurerm_role_assignment.deployer_acr_push
    Pop-Location
}

$AcrServer = Get-TfOutput "acr_login_server"
$AcrName = Get-TfOutput "acr_name"
$KeyVault = Get-TfOutput "key_vault_name"
$SbNamespace = Get-TfOutput "servicebus_namespace"
$Rg = Get-TfOutput "resource_group_name"
$Aks = Get-TfOutput "aks_cluster_name"

Write-Host "ACR: $AcrServer"
Write-Host "Key Vault: $KeyVault"

# --- Build & push images ---
if (-not $SkipBuild) {
    Write-Host "==> Logging in to ACR..." -ForegroundColor Yellow
    az acr login --name $AcrName

    $images = @(
        @{ Name = "shoppulse-api"; Context = "api"; Args = @() },
        @{ Name = "shoppulse-worker"; Context = "worker"; Args = @() },
        @{ Name = "shoppulse-frontend"; Context = "frontend"; Args = @("--build-arg", "VITE_API_BASE_URL=") }
    )

    foreach ($img in $images) {
        $full = "${AcrServer}/$($img.Name):${ImageTag}"
        Write-Host "==> Building $full" -ForegroundColor Yellow
        $contextPath = Join-Path $RepoRoot $img.Context
        docker build @($img.Args) -t $full $contextPath
        docker push $full
    }
}

# --- Sync secrets from Key Vault ---
Write-Host "==> Syncing secrets from Key Vault..." -ForegroundColor Yellow
$DatabaseUrl = az keyvault secret show --vault-name $KeyVault --name database-url --query value -o tsv
$DatabaseUrl = $DatabaseUrl -replace "sslmode=require", "ssl=require"
$RedisUrl = az keyvault secret show --vault-name $KeyVault --name redis-url --query value -o tsv
$SbConn = az keyvault secret show --vault-name $KeyVault --name servicebus-connection-string --query value -o tsv

if (-not $DatabaseUrl -or -not $RedisUrl -or -not $SbConn) {
    throw "Failed to read secrets from Key Vault $KeyVault"
}

# --- Render manifests ---
if (Test-Path $BuildDir) { Remove-Item $BuildDir -Recurse -Force }
New-Item -ItemType Directory -Path $BuildDir | Out-Null

Get-ChildItem $K8sDir -Filter "*.yaml" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    $content = $content.Replace("ACR_LOGIN_SERVER", $AcrServer)
    $content = $content.Replace("SERVICEBUS_NAMESPACE", $SbNamespace)
    Set-Content -Path (Join-Path $BuildDir $_.Name) -Value $content -NoNewline
}

# Patch secret.yaml with real values
$secretPath = Join-Path $BuildDir "secret.yaml"
$secret = Get-Content $secretPath -Raw
$secret = $secret.Replace("REPLACE_ME_DATABASE", $DatabaseUrl)
# Use careful replacement for secret file
@(
    @{ Key = "DATABASE_URL"; Val = $DatabaseUrl },
    @{ Key = "REDIS_URL"; Val = $RedisUrl },
    @{ Key = "SERVICE_BUS_CONNECTION_STRING"; Val = $SbConn }
) | ForEach-Object {
    # handled below via kubectl create secret
}

# Create secret via kubectl (avoids yaml escaping issues)
kubectl create namespace shoppulse --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic shoppulse-secrets `
    --namespace shoppulse `
    --from-literal=DATABASE_URL="$DatabaseUrl" `
    --from-literal=REDIS_URL="$RedisUrl" `
    --from-literal=SERVICE_BUS_CONNECTION_STRING="$SbConn" `
    --dry-run=client -o yaml | kubectl apply -f -

kubectl rollout restart deployment/api deployment/worker -n shoppulse

# --- Apply manifests (skip secret.yaml template) ---
Write-Host "==> Applying Kubernetes manifests..." -ForegroundColor Yellow
Get-ChildItem $BuildDir -Filter "*.yaml" | Where-Object { $_.Name -ne "secret.yaml" } | ForEach-Object {
    kubectl apply -f $_.FullName
}

# --- Wait for frontend LB ---
Write-Host "==> Waiting for frontend LoadBalancer IP..." -ForegroundColor Yellow
$deadline = (Get-Date).AddMinutes(5)
$frontendIp = $null
while ((Get-Date) -lt $deadline) {
    $frontendIp = kubectl get svc frontend -n shoppulse -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
    if ($frontendIp) { break }
    Start-Sleep -Seconds 10
}

Write-Host ""
Write-Host "=== Deploy complete ===" -ForegroundColor Green
kubectl get pods -n shoppulse
kubectl get svc -n shoppulse
if ($frontendIp) {
    Write-Host "Frontend URL: http://$frontendIp" -ForegroundColor Green
} else {
    Write-Host "Frontend LB IP pending. Run: kubectl get svc frontend -n shoppulse -w"
}

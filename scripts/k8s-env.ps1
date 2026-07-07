# One-time / per-session kubectl setup for AKS (Azure AD RBAC)
# Usage: . .\scripts\k8s-env.ps1

$kubeloginDir = Join-Path $env:USERPROFILE ".azure-kubelogin"
$kubectlDir = Join-Path $env:USERPROFILE ".azure-kubectl"

foreach ($dir in @($kubeloginDir, $kubectlDir)) {
    if ((Test-Path $dir) -and ($env:Path -notlike "*$dir*")) {
        $env:Path = "$dir;$env:Path"
    }
}

if (-not (Get-Command kubelogin -ErrorAction SilentlyContinue)) {
    Write-Error "kubelogin not found. Run: az aks install-cli"
    return
}

kubelogin convert-kubeconfig -l azurecli | Out-Null
Write-Host "kubectl ready. Try: kubectl get nodes" -ForegroundColor Green

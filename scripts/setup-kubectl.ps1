# One-time kubectl/kubelogin setup for ShopPulse AKS (Windows)
# Run: powershell -ExecutionPolicy Bypass -File .\scripts\setup-kubectl.ps1

$ErrorActionPreference = "Stop"

$KubeloginDir = Join-Path $env:USERPROFILE ".azure-kubelogin"
$KubectlDir = Join-Path $env:USERPROFILE ".azure-kubectl"
$KubeloginExe = Join-Path $KubeloginDir "kubelogin.exe"
$Kubeconfig = Join-Path $env:USERPROFILE ".kube\config"

function Add-ToUserPath([string[]]$Dirs) {
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $changed = $false
    foreach ($dir in $Dirs) {
        if ((Test-Path $dir) -and ($userPath -notlike "*$dir*")) {
            $userPath = if ($userPath) { "$userPath;$dir" } else { $dir }
            $changed = $true
        }
    }
    if ($changed) {
        [Environment]::SetEnvironmentVariable("Path", $userPath, "User")
        Write-Host "Added kubelogin/kubectl to User PATH." -ForegroundColor Green
    }
    $env:Path = "$KubeloginDir;$KubectlDir;" + $env:Path
}

function Ensure-KubeTools {
    if (-not (Test-Path $KubeloginExe)) {
        Write-Host "Installing kubectl + kubelogin..." -ForegroundColor Yellow
        az aks install-cli
    }
    if (-not (Test-Path $KubeloginExe)) {
        throw "kubelogin not found at $KubeloginExe"
    }
}

function Set-KubeconfigKubeloginPath {
    if (-not (Test-Path $Kubeconfig)) {
        Write-Host "No kubeconfig — run: az aks get-credentials --resource-group shoppulse-dev-rg --name shoppulse-dev-aks" -ForegroundColor Yellow
        return
    }

    & $KubeloginExe convert-kubeconfig -l azurecli | Out-Null

    $kubeloginPath = ($KubeloginExe -replace '\\', '/')
    $content = Get-Content $Kubeconfig -Raw
    $fixed = $content -replace '(?m)^(\s+command:\s+).*$', "`${1}$kubeloginPath"

    if ($fixed -ne $content) {
        Set-Content -Path $Kubeconfig -Value $fixed -NoNewline
    }
    Write-Host "kubeconfig uses full path to kubelogin (works without PATH)." -ForegroundColor Green
}

Write-Host "==> ShopPulse kubectl setup" -ForegroundColor Cyan
Ensure-KubeTools
Add-ToUserPath @($KubeloginDir, $KubectlDir)
Set-KubeconfigKubeloginPath

Write-Host ""
kubectl get nodes
Write-Host ""
Write-Host "Done. kubectl works in any new terminal — no profile or PATH commands needed." -ForegroundColor Green

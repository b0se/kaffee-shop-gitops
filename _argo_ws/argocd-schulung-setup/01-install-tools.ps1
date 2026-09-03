# ============================================================
#  Argo CD Schulung - Tool-Installation (Windows 10/11)
#  Als Administrator in PowerShell ausfuehren.
#  Voraussetzung: winget (App Installer) ist vorhanden.
#  Datei-Encoding: UTF-8 mit BOM, Inhalt reines ASCII
# ============================================================
$ErrorActionPreference = "Stop"

Write-Host "== 1/6  Docker Desktop (WSL2-Backend) ==" -ForegroundColor Cyan
winget install -e --id Docker.DockerDesktop --accept-source-agreements --accept-package-agreements

Write-Host "== 2/6  kubectl, kind, helm, kustomize ==" -ForegroundColor Cyan
winget install -e --id Kubernetes.kubectl
winget install -e --id Kubernetes.kind
winget install -e --id Helm.Helm
winget install -e --id Kubernetes.kustomize

Write-Host "== 3/6  Git, GitHub CLI, VS Code ==" -ForegroundColor Cyan
winget install -e --id Git.Git
winget install -e --id GitHub.cli
winget install -e --id Microsoft.VisualStudioCode

Write-Host "== 4/6  Argo CD CLI (aktuelles Release von GitHub) ==" -ForegroundColor Cyan
$argoDir = "$env:LOCALAPPDATA\Programs\argocd"
New-Item -ItemType Directory -Force -Path $argoDir | Out-Null
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$latest = (Invoke-RestMethod "https://api.github.com/repos/argoproj/argo-cd/releases/latest").tag_name
Write-Host "   Version: $latest"
Invoke-WebRequest -Uri "https://github.com/argoproj/argo-cd/releases/download/$latest/argocd-windows-amd64.exe" -OutFile "$argoDir\argocd.exe"

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$argoDir*") {
  [Environment]::SetEnvironmentVariable("Path", "$userPath;$argoDir", "User")
}
$env:Path += ";$argoDir"

Write-Host "== 5/6  Autovervollstaendigung und Alias (optional) ==" -ForegroundColor Cyan
if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Force -Path $PROFILE | Out-Null }
Add-Content $PROFILE 'kubectl completion powershell | Out-String | Invoke-Expression'
Add-Content $PROFILE 'argocd completion powershell | Out-String | Invoke-Expression'
Add-Content $PROFILE 'Set-Alias -Name k -Value kubectl'

Write-Host "== 6/6  Naechste Schritte ==" -ForegroundColor Cyan
Write-Host "Terminal neu oeffnen, dann pruefen:" -ForegroundColor Yellow
Write-Host "  docker version; kubectl version --client; kind version; helm version"
Write-Host "  kustomize version; git --version; gh --version; argocd version --client"
Write-Host ""
Write-Host "WICHTIG: Docker Desktop einmal starten, WSL2-Backend bestaetigen und unter" -ForegroundColor Yellow
Write-Host "Settings > Resources mindestens 4 CPU / 8 GB RAM freigeben." -ForegroundColor Yellow

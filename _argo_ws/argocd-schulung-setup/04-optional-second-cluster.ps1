# ============================================================
#  OPTIONAL: Zweiter kind-Cluster "prod" fuer das Multi-Cluster-Modul (Tag 2)
#  Argo CD (im Cluster "schulung") erreicht den API-Server von "prod" nur ueber
#  das Docker-Netz -> interne kubeconfig verwenden, nicht 127.0.0.1.
#  Voraussetzung: argocd login wurde bereits ausgefuehrt.
#  Datei-Encoding: UTF-8 mit BOM, Inhalt reines ASCII
# ============================================================
$ErrorActionPreference = "Continue"

function Assert-Ok($Schritt) {
  if ($LASTEXITCODE -ne 0) {
    Write-Host "FEHLGESCHLAGEN: $Schritt (Exit-Code $LASTEXITCODE)" -ForegroundColor Red
    exit 1
  }
}

$clusters = @(kind get clusters 2>$null)
if ($clusters -notcontains "prod") {
  kind create cluster --name prod --wait 120s
  Assert-Ok "kind create cluster prod"
}

$kubeDir = Join-Path $env:USERPROFILE ".kube"
New-Item -ItemType Directory -Force -Path $kubeDir | Out-Null
$prodCfg = Join-Path $kubeDir "prod-internal.yaml"
kind get kubeconfig --name prod --internal | Set-Content -Encoding ascii $prodCfg
Assert-Ok "kind get kubeconfig --internal"

$env:KUBECONFIG = "$(Join-Path $kubeDir 'config');$prodCfg"
argocd cluster add kind-prod --name prod --yes
$rc = $LASTEXITCODE
$env:KUBECONFIG = ""
if ($rc -ne 0) {
  Write-Host "argocd cluster add fehlgeschlagen - ist 'argocd login' erfolgt?" -ForegroundColor Red
  exit 1
}

kubectl config use-context kind-schulung
argocd cluster list

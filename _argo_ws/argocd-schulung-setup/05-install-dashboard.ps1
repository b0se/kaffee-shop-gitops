# ============================================================
#  Headlamp - Kubernetes Web-UI fuer die Schulungsumgebung
#
#  Hintergrund: Das klassische "Kubernetes Dashboard" wurde am 21.01.2026
#  archiviert, sein Helm-Repo liefert seitdem 404. Nachfolger laut den
#  Maintainern ist Headlamp (kubernetes-sigs, SIG-UI).
#
#  Datei-Encoding: UTF-8 mit BOM, Inhalt reines ASCII
#
#  Aufruf:
#    .\05-install-dashboard.ps1                 -> NodePort 30084 (http://localhost:8084)
#    .\05-install-dashboard.ps1 -PortForward    -> ClusterIP, Zugriff per port-forward
#    .\05-install-dashboard.ps1 -SkipMetrics    -> ohne metrics-server
# ============================================================
param(
  [switch]$PortForward,
  [switch]$SkipMetrics
)
$ErrorActionPreference = "Continue"
Set-Location $PSScriptRoot

function Assert-Ok($Schritt) {
  if ($LASTEXITCODE -ne 0) {
    Write-Host "FEHLGESCHLAGEN: $Schritt (Exit-Code $LASTEXITCODE)" -ForegroundColor Red
    exit 1
  }
}

kubectl config use-context kind-schulung
Assert-Ok "kubectl config use-context kind-schulung"

# --- 0. Reste des alten Kubernetes Dashboards entfernen (falls vorhanden) ---
$oldNs = kubectl get namespace kubernetes-dashboard --ignore-not-found -o name
if (-not [string]::IsNullOrWhiteSpace($oldNs)) {
  Write-Host "== Altes kubernetes-dashboard entfernen ==" -ForegroundColor Yellow
  helm uninstall kubernetes-dashboard -n kubernetes-dashboard 2>$null | Out-Null
  kubectl delete namespace kubernetes-dashboard --ignore-not-found --wait=false | Out-Null
  kubectl delete clusterrolebinding admin-user viewer-user --ignore-not-found | Out-Null
}

# --- 1. Erreichbarkeit klaeren -------------------------------------------
$useNodePort = -not $PortForward
if ($useNodePort) {
  $mapped = docker port schulung-control-plane 2>$null | Select-String "8084"
  if (-not $mapped) {
    Write-Host "Der Cluster hat kein Portmapping fuer 8084." -ForegroundColor Yellow
    Write-Host "Entweder Cluster mit aktueller kind-config.yaml neu anlegen," -ForegroundColor Yellow
    Write-Host "oder ohne NodePort weitermachen (Zugriff per port-forward)." -ForegroundColor Yellow
    $useNodePort = $false
  }
}
$valuesFile = if ($useNodePort) { "dashboard\values.yaml" } else { "dashboard\values-portforward.yaml" }

# --- 2. metrics-server (CPU-/RAM-Anzeige in der Cluster-Uebersicht) ------
if (-not $SkipMetrics) {
  Write-Host "== metrics-server installieren ==" -ForegroundColor Cyan
  helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ --force-update
  if ($LASTEXITCODE -ne 0) {
    Write-Host "Helm-Repo metrics-server nicht erreichbar - uebersprungen (Graphen bleiben leer)." -ForegroundColor Yellow
  } else {
    helm repo update metrics-server | Out-Null
    helm upgrade --install metrics-server metrics-server/metrics-server `
      --namespace kube-system `
      --set "args={--kubelet-insecure-tls}"
    Assert-Ok "helm install metrics-server"
  }
}

# --- 3. Headlamp per Helm -----------------------------------------------
Write-Host "== Headlamp installieren ==" -ForegroundColor Cyan
helm repo add headlamp https://kubernetes-sigs.github.io/headlamp/ --force-update
Assert-Ok "helm repo add headlamp"
helm repo update headlamp | Out-Null

helm upgrade --install headlamp headlamp/headlamp `
  --create-namespace --namespace headlamp `
  --values $valuesFile
Assert-Ok "helm install headlamp"

Write-Host "== Warte auf Pod ==" -ForegroundColor Cyan
kubectl -n headlamp rollout status deployment/headlamp --timeout=300s
Assert-Ok "rollout headlamp"

# --- 4. Zugangskonten ----------------------------------------------------
Write-Host "== ServiceAccounts admin-user und viewer-user ==" -ForegroundColor Cyan
kubectl apply -f dashboard\admin-user.yaml
Assert-Ok "apply admin-user.yaml"
kubectl apply -f dashboard\viewer-user.yaml
Assert-Ok "apply viewer-user.yaml"

# --- 5. Token ausgeben ---------------------------------------------------
$token = kubectl -n headlamp create token admin-user --duration=24h
Assert-Ok "Token erzeugen"
$tokenFile = Join-Path $PSScriptRoot "dashboard-token.txt"
Set-Content -Path $tokenFile -Value $token -Encoding ascii

Write-Host ""
Write-Host "Headlamp laeuft." -ForegroundColor Green
if ($useNodePort) {
  Write-Host "  URL:   http://localhost:8084" -ForegroundColor Green
} else {
  Write-Host "  Zugriff per port-forward, in einem EIGENEN Fenster starten und offen lassen:" -ForegroundColor Green
  Write-Host "    kubectl -n headlamp port-forward svc/headlamp 8084:80"
  Write-Host "  URL:   http://localhost:8084"
}
Write-Host "  Login: Token einfuegen, Token steht in $tokenFile (Gueltigkeit 24 h)"
Write-Host ""
Write-Host "Neues Token spaeter erzeugen:  .\06-dashboard-token.ps1" -ForegroundColor Yellow

# ============================================================
#  Argo CD Schulung - Argo CD installieren und erreichbar machen
#  UI danach: http://localhost:8080  (HTTP, insecure - nur Schulung!)
#  Datei-Encoding: UTF-8 mit BOM, Inhalt reines ASCII
#
#  ErrorActionPreference bleibt auf "Continue": PowerShell 5.1 wuerde
#  sonst bei jeder stderr-Zeile von kubectl abbrechen. Wir pruefen
#  stattdessen $LASTEXITCODE nach jedem kritischen Schritt.
# ============================================================
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

Write-Host "== Namespace argocd ==" -ForegroundColor Cyan
# --ignore-not-found schreibt nichts auf stderr, wenn es den Namespace nicht gibt.
$ns = kubectl get namespace argocd --ignore-not-found -o name
if ([string]::IsNullOrWhiteSpace($ns)) {
  kubectl create namespace argocd
  Assert-Ok "kubectl create namespace argocd"
} else {
  Write-Host "Namespace existiert bereits." -ForegroundColor Yellow
}

Write-Host "== Offizielles Install-Manifest (stable) ==" -ForegroundColor Cyan
# Server-Side Apply ist hier Pflicht, nicht Geschmackssache:
# Das CRD applicationsets.argoproj.io ist groesser als das 256-KB-Limit der
# Annotation last-applied-configuration, die klassisches Client-Side-Apply schreibt.
# --force-conflicts uebernimmt die Field-Ownership bei einer Neuinstallation ueber
# eine vorhandene (client-side angelegte) Installation.
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
Assert-Ok "kubectl apply install.yaml"

# Patches als Dateien statt Inline-JSON: kein Anfuehrungszeichen-Escaping noetig.
$tmp = (New-Item -ItemType Directory -Force -Path "$env:TEMP\argocd-setup").FullName

Write-Host "== server.insecure=true (HTTP ohne Zertifikatswarnung) ==" -ForegroundColor Cyan
@'
data:
  server.insecure: "true"
'@ | Set-Content -Encoding ascii "$tmp\cmd-params.yaml"
kubectl -n argocd patch configmap argocd-cmd-params-cm --type merge --patch-file "$tmp\cmd-params.yaml"
Assert-Ok "patch argocd-cmd-params-cm"
kubectl -n argocd rollout restart deployment argocd-server

Write-Host "== Service als NodePort 30080 (kind-Portmapping -> localhost:8080) ==" -ForegroundColor Cyan
@'
spec:
  type: NodePort
  ports:
    - name: http
      port: 80
      targetPort: 8080
      nodePort: 30080
    - name: https
      port: 443
      targetPort: 8080
      nodePort: 30443
'@ | Set-Content -Encoding ascii "$tmp\svc.yaml"
kubectl -n argocd patch svc argocd-server --type merge --patch-file "$tmp\svc.yaml"
Assert-Ok "patch svc argocd-server"

Write-Host "== Warte auf Argo CD Pods (kann 2-3 Minuten dauern) ==" -ForegroundColor Cyan
kubectl -n argocd rollout status deployment/argocd-server --timeout=300s
Assert-Ok "rollout argocd-server"
kubectl -n argocd rollout status deployment/argocd-repo-server --timeout=300s
Assert-Ok "rollout argocd-repo-server"
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s
Assert-Ok "rollout argocd-application-controller"

$pw = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
Assert-Ok "Admin-Secret lesen"
$pwPlain = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($pw))

Write-Host ""
Write-Host "Argo CD laeuft." -ForegroundColor Green
Write-Host "  UI:       http://localhost:8080"
Write-Host "  User:     admin"
Write-Host "  Passwort: $pwPlain"
Write-Host ""
Write-Host "CLI-Login:" -ForegroundColor Yellow
Write-Host "  argocd login localhost:8080 --username admin --password '$pwPlain' --plaintext"

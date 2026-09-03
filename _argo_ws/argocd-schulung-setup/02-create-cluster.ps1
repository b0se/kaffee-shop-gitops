# ============================================================
#  Argo CD Schulung - kind-Cluster "schulung" anlegen
#  Datei-Encoding: UTF-8 mit BOM, Inhalt reines ASCII
#
#  Hinweis: ErrorActionPreference bleibt bewusst auf "Continue".
#  Windows PowerShell 5.1 wandelt sonst jede stderr-Ausgabe eines
#  externen Programms (kubectl, kind, docker) in einen Abbruch um -
#  auch harmlose Meldungen. Wir pruefen stattdessen $LASTEXITCODE.
# ============================================================
$ErrorActionPreference = "Continue"
Set-Location $PSScriptRoot

function Assert-Ok($Schritt) {
  if ($LASTEXITCODE -ne 0) {
    Write-Host "FEHLGESCHLAGEN: $Schritt (Exit-Code $LASTEXITCODE)" -ForegroundColor Red
    exit 1
  }
}

Write-Host "== Docker Desktop pruefen ==" -ForegroundColor Cyan
docker info 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
  Write-Host "Docker Desktop laeuft nicht. Bitte starten, Wal-Symbol abwarten, Skript erneut ausfuehren." -ForegroundColor Red
  exit 1
}

$clusters = @(kind get clusters 2>$null)
if ($clusters -contains "schulung") {
  Write-Host "Cluster 'schulung' existiert bereits - wird uebersprungen." -ForegroundColor Yellow
} else {
  Write-Host "== Cluster anlegen (dauert ca. 1 Minute) ==" -ForegroundColor Cyan
  kind create cluster --config kind-config.yaml --wait 120s
  Assert-Ok "kind create cluster"
}

kubectl config use-context kind-schulung
Assert-Ok "kubectl config use-context"

kubectl cluster-info
kubectl get nodes -o wide
Write-Host ""
Write-Host "Cluster bereit. Weiter mit: .\03-install-argocd.ps1" -ForegroundColor Green

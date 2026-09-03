# ============================================================
#  Frisches Headlamp-Token erzeugen und in die Zwischenablage legen
#  Datei-Encoding: UTF-8 mit BOM, Inhalt reines ASCII
#
#  Aufruf:  .\06-dashboard-token.ps1            -> admin-user
#           .\06-dashboard-token.ps1 -Viewer    -> viewer-user (read-only)
# ============================================================
param([switch]$Viewer)
$ErrorActionPreference = "Continue"

$sa = if ($Viewer) { "viewer-user" } else { "admin-user" }
$token = kubectl -n headlamp create token $sa --duration=24h
if ($LASTEXITCODE -ne 0) {
  Write-Host "Token konnte nicht erzeugt werden. Laeuft der Cluster, ist Headlamp installiert?" -ForegroundColor Red
  exit 1
}

$token | Set-Clipboard
Write-Host "Token fuer '$sa' erzeugt und in die Zwischenablage kopiert (gueltig 24 h)." -ForegroundColor Green
Write-Host ""
Write-Host $token

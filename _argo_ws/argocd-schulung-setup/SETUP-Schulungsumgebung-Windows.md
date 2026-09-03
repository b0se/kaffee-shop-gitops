# Argo CD Schulung (2 Tage) – Setup der Schulungsumgebung auf Windows

Stand: September 2026 · Argo CD 3.x (stable, aktuell 3.5) · Kubernetes via **kind** in Docker Desktop

Dieses Dokument ist für dich als Trainer: Es beschreibt das vollständige Setup
**GitHub + Kubernetes + Argo CD** für jeden Teilnehmer-PC sowie deine Vorbereitung
auf GitHub. Alles läuft lokal auf einem Windows-Rechner – kein Cloud-Account nötig.

---

## 0. Architektur der Schulungsumgebung

```
Teilnehmer-PC (Windows 10/11)
├── Docker Desktop (WSL2)
│   ├── kind-Cluster "schulung"  ← Argo CD + Apps (Tag 1 + 2)
│   │     Ports: 8080 → Argo CD UI · 8081 dev · 8082 prod · 8083 helm
│   └── kind-Cluster "prod"      ← optional, Multi-Cluster-Modul (Tag 2)
├── CLI: kubectl · kind · helm · kustomize · argocd · git · gh
└── VS Code (Repo-Bearbeitung)

GitHub
├── Template-Repo (du):    <dein-account>/kaffee-shop-gitops   [Template, public]
└── Teilnehmer-Repos:      <tn-account>/kaffee-shop-gitops     [aus Template, public]
```

Roter Faden der Schulung: Die fiktive Rösterei **Nordlicht Kaffee** betreibt einen
Web-Shop. Die Teilnehmer bringen ihn von "kubectl apply von Hand" bis zu einem
produktionsreifen GitOps-Setup mit Umgebungen, Projekten, RBAC, Hooks und Secrets.

---

## 1. Hardware / Voraussetzungen pro Teilnehmer-PC

| Punkt | Minimum | Empfehlung |
|---|---|---|
| RAM | 8 GB | 16 GB |
| CPU | 4 Kerne | 8 Kerne |
| Festplatte frei | 20 GB | 40 GB |
| Windows | 10 21H2 / 11 | 11 |
| Virtualisierung | im BIOS aktiviert (Hyper-V / WSL2) | – |
| Admin-Rechte | für Installation nötig | – |
| Internet | GitHub, Docker Hub, ghcr.io, raw.githubusercontent.com erreichbar | Proxy vorher klären! |

> **Firmen-Proxys / Zscaler:** Häufigste Fehlerquelle. Vorab testen:
> `docker pull nginx:1.27-alpine` und `Invoke-WebRequest https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml`.
> Bei TLS-Inspection muss das Firmen-Root-Zertifikat in Docker Desktop und WSL hinterlegt werden.

---

## 2. Tools installieren (Skript `01-install-tools.ps1`)

PowerShell **als Administrator**:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\01-install-tools.ps1
```

Installiert per winget: Docker Desktop, kubectl, kind, helm, kustomize, Git, GitHub CLI,
VS Code – und lädt die **Argo CD CLI** (`argocd.exe`) aus dem aktuellen GitHub-Release
nach `%LOCALAPPDATA%\Programs\argocd` (PATH wird gesetzt).

Danach:

1. Terminal neu öffnen.
2. **Docker Desktop starten**, WSL2-Backend akzeptieren.
3. Docker Desktop → *Settings → Resources*: **mind. 4 CPU, 8 GB RAM** (bei 16-GB-Maschine).
4. Prüfen:

```powershell
docker version; kubectl version --client; kind version; helm version
kustomize version; git --version; gh --version; argocd version --client
```

Manuelle Alternative ohne winget: Installer von docker.com, kubernetes.io, kind.sigs.k8s.io,
helm.sh, git-scm.com, cli.github.com; `argocd-windows-amd64.exe` von
https://github.com/argoproj/argo-cd/releases.

---

## 3. Kubernetes-Cluster anlegen (Skript `02-create-cluster.ps1`)

```powershell
.\02-create-cluster.ps1
```

Legt den kind-Cluster **`schulung`** mit `kind-config.yaml` an. Wichtig darin sind die
**extraPortMappings** – sie machen NodePorts als `localhost:8080…8083` erreichbar,
ohne dass ständig ein `kubectl port-forward` laufen muss (das stirbt gern im Training).

Test: `kubectl get nodes` → `schulung-control-plane Ready`.

Warum kind statt minikube? kind startet in ~40 s, braucht keinen Hypervisor außer
Docker, unterstützt mehrere Cluster nebeneinander (Multi-Cluster-Modul) und verhält
sich wie ein "echter" Cluster. minikube funktioniert ebenso, dann aber
`minikube service`/Tunnel statt Port-Mappings.

---

## 4. Argo CD installieren (Skript `03-install-argocd.ps1`)

```powershell
.\03-install-argocd.ps1
```

Das Skript:

1. legt Namespace `argocd` an,
2. wendet das offizielle **install.yaml (stable)** an – die Standard-Installation
   (nicht "core", nicht HA), passend für die Schulung, und zwar mit
   `--server-side --force-conflicts`. Das ist Pflicht: Das CRD
   `applicationsets.argoproj.io` überschreitet das 256-KB-Limit der Annotation
   `last-applied-configuration`, die klassisches Client-Side-Apply schreibt,
3. setzt `server.insecure=true` in `argocd-cmd-params-cm` → UI über **HTTP** ohne
   Zertifikatswarnung (nur Schulung! In der Schulung selbst wird das als Anti-Pattern
   für Produktion thematisiert),
4. patcht `svc/argocd-server` auf **NodePort 30080** → `http://localhost:8080`,
5. liest das Admin-Initialpasswort aus `argocd-initial-admin-secret` aus und zeigt den
   CLI-Login-Befehl.

Die beiden Patches werden bewusst als **Patch-Dateien** (`--patch-file`) angewendet und
nicht als Inline-JSON. Inline-JSON braucht in PowerShell Backslash-Escaping, das je nach
PowerShell-Version anders interpretiert wird - eine klassische Fehlerquelle im
Schulungsraum.

Login testen:

```powershell
argocd login localhost:8080 --username admin --password <PW> --plaintext
argocd account update-password      # optional: einfacheres Schulungspasswort setzen
argocd version                       # zeigt Client- und Server-Version
```

Zeitbedarf pro PC: ~10 Minuten inkl. Image-Pulls.

---

## 5. GitHub vorbereiten (deine Aufgabe, einmalig)

### 5.1 Template-Repository anlegen

1. Neues Repo `kaffee-shop-gitops` in deinem Account (oder einer Schulungs-Organisation).
2. Inhalt von `seed-repo/` committen und pushen.
3. Repo → *Settings → General → Template repository* ☑.
4. Sichtbarkeit **Public** (so brauchen die Teilnehmer zunächst keine Credentials
   in Argo CD – Private-Repos + Credentials sind ein eigener Lernschritt in Modul 6).

```powershell
cd seed-repo
git init -b main
git add . ; git commit -m "Nordlicht Kaffee – GitOps-Startpunkt"
gh repo create kaffee-shop-gitops --public --source . --push
gh repo edit --template          # als Template markieren
```

> In allen YAMLs steht `<DEIN-ACCOUNT>` als Platzhalter. Die Teilnehmer ersetzen ihn
> in Modul 4 per Suchen/Ersetzen durch ihren eigenen GitHub-Namen – das ist bewusst
> Teil der Übung (Verständnis, was `repoURL` bedeutet).

#### 5.1a Für Modul 10 (CI/CD): Actions-Berechtigung

Der Workflow `.github/workflows/promote-dev.yaml` committet ins Repo. Jeder Teilnehmer muss in
seinem Repo einmal *Settings → Actions → General → Workflow permissions → Read and write*
setzen, sonst scheitert der `git push` des Workflows mit 403. Beim Template-Repo selbst ist das
nicht nötig.

### 5.1b Für Modul 14 (Monitoring): RAM-Reserve

`argocd/optional/monitoring.yaml` installiert kube-prometheus-stack (~1,2 GB RAM zusätzlich).
Nur auf PCs mit ≥ 16 GB einsetzen; auf 8-GB-Maschinen den Abschnitt als Demo vom Trainer-PC
zeigen. Grafana ist über `kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80`
erreichbar (kein kind-Portmapping vorgesehen).

## 5.2 Was jeder Teilnehmer auf GitHub braucht

- Einen GitHub-Account (kostenlos reicht).
- Repo aus Template erzeugen: *Use this template → Create a new repository*,
  Name `kaffee-shop-gitops`, **Public**.
- Lokal klonen: `gh auth login` → `gh repo clone <tn>/kaffee-shop-gitops`.
- Für Modul 6 (private Repos): ein **Fine-grained Personal Access Token** mit
  *Contents: Read-only* auf dieses Repo (Settings → Developer settings → Personal
  access tokens → Fine-grained tokens). Alternative im Kurs: SSH-Key oder GitHub App.

### 5.3 Optional: Schulungs-Organisation

Wenn du mehrere Durchläufe machst: GitHub-Organisation `nordlicht-schulung-<monat>`
anlegen, Template dort hosten, Teilnehmer als Members einladen. Vorteil: du siehst alle
Repos, kannst Webhooks zentral zeigen. Nachteil: Einladungen kosten Zeit am Morgen.

---

## 5.4 Optional: Kubernetes Web-UI (Headlamp)

Für den Cluster-Blick neben der Argo CD-UI gibt es eine eigene Anleitung (Headlamp – das klassische Kubernetes Dashboard ist seit Januar 2026 archiviert):
`ANLEITUNG-Kubernetes-Dashboard-Windows.md` plus die Skripte `05-install-dashboard.ps1`
und `06-dashboard-token.ps1`. Beachten: Die aktuelle `kind-config.yaml` enthält dafür ein
zusätzliches Portmapping (30084 → 8084) — Cluster, die vor dieser Änderung angelegt wurden,
brauchen entweder eine Neuanlage oder den port-forward-Weg.

---

## 6. Optional: zweiter Cluster für das Multi-Cluster-Modul (`04-optional-second-cluster.ps1`)

Für Modul 6/9 (Cluster hinzufügen, ApplicationSet Cluster-Generator). Das Skript legt
kind-Cluster `prod` an und registriert ihn in Argo CD. Der Kniff: Argo CD läuft *im*
Cluster `schulung` und erreicht `prod` nur über das Docker-Netzwerk – daher wird die
**interne** kubeconfig (`kind get kubeconfig --internal`, Server
`https://prod-control-plane:6443`) statt `127.0.0.1` verwendet.

Nur ausführen, wenn der PC ≥ 16 GB RAM hat.

---

## 7. Checkliste am Morgen von Tag 1 (pro PC, 5 Minuten)

- [ ] Docker Desktop läuft (Wal-Icon grün).
- [ ] `kubectl get nodes` → Ready.
- [ ] `kubectl -n argocd get pods` → alle Running (7 Pods: server, repo-server,
      application-controller, applicationset-controller, dex, redis, notifications).
- [ ] http://localhost:8080 → Argo CD Login-Seite.
- [ ] `argocd login localhost:8080 --plaintext` funktioniert.
- [ ] Teilnehmer hat GitHub-Account, Repo aus Template erzeugt und lokal geklont.
- [ ] VS Code öffnet das Repo, YAML-Extension (redhat.vscode-yaml) empfohlen.

---

## 8. Reset zwischen Gruppen / bei kaputtem Zustand

```powershell
# Alle Apps löschen, Argo CD behalten:
argocd app delete --all --yes ; kubectl delete ns shop-dev shop-prod shop-helm shop-hooks --ignore-not-found

# Komplett neu (2 Minuten):
.\99-teardown.ps1 ; .\02-create-cluster.ps1 ; .\03-install-argocd.ps1
```

---

## 9. Bekannte Stolpersteine auf Windows

| Symptom | Ursache / Lösung |
|---|---|
| `kind create cluster` hängt bei "Starting control-plane" | Docker Desktop zu wenig RAM → Resources hochsetzen; WSL neu starten `wsl --shutdown` |
| `localhost:8080` nicht erreichbar | Port von anderem Dienst belegt (`netstat -ano \| findstr 8080`) → in `kind-config.yaml` hostPort ändern und Cluster neu anlegen |
| `argocd login` → x509-Fehler | `--plaintext` vergessen (Server läuft insecure/HTTP) |
| Repo in Argo CD "Connection failed" | Proxy/TLS-Inspection; `<DEIN-ACCOUNT>` nicht ersetzt; Repo privat ohne Credentials |
| Pods `ImagePullBackOff` | Docker Hub Rate-Limit oder Proxy → `docker login` in Docker Desktop, Images ggf. vorab pullen und `kind load docker-image` |
| `kubectl patch` mit Inline-JSON schlägt fehl | Anführungszeichen-Escaping in PowerShell → die Skripte verwenden `--patch-file` mit einer YAML-Datei |
| PowerShell meldet „Die Zeichenfolge hat kein Abschlusszeichen“, im Text steht `â€“` oder `Ã¤` | Das `.ps1` wurde als UTF-8 **ohne BOM** gespeichert; Windows PowerShell 5.1 liest es dann als ANSI und zerlegt Umlaute/Sonderstriche. Die mitgelieferten Skripte sind ASCII-only **mit BOM**. Nach eigenen Änderungen in VS Code unten rechts „UTF-8 with BOM“ wählen – oder Umlaute im Skript vermeiden |
| `kubectl apply` → „CustomResourceDefinition applicationsets.argoproj.io is invalid: metadata.annotations: Too long" | Client-Side-Apply schreibt das ganze Manifest in eine Annotation, das CRD ist dafür zu groß → `kubectl apply --server-side --force-conflicts -f ...` (Skript 03 macht das) |
| `argocd` nicht gefunden | PATH nach Installation nicht neu geladen → Terminal schließen/öffnen |
| Zeilenenden CRLF in YAML | Git `core.autocrlf=input` setzen: `git config --global core.autocrlf input` |

---

## 10. Image-Vorab-Download (bei schlechtem Internet im Schulungsraum)

```powershell
"nginx:1.27-alpine","busybox:1.36","curlimages/curl:8.10.1" | % { docker pull $_ ; kind load docker-image $_ --name schulung }
```

Argo CD-Images werden beim Install-Manifest gezogen (quay.io/argoproj/argocd, dex, redis);
bei Offline-Räumen vorab `docker pull` + `kind load` analog.

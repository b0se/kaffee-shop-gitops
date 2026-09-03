# Kubernetes Web-UI in der Schulungsumgebung: Headlamp (Windows)

Stand: September 2026 · Headlamp 0.4x · kind-Cluster `schulung` · Windows 10/11

Diese Anleitung ist eigenständig, setzt aber den Cluster aus
`SETUP-Schulungsumgebung-Windows.md` voraus (Skripte 01 und 02).

---

## 0. Warum Headlamp und nicht „das Kubernetes Dashboard"?

Das klassische **Kubernetes Dashboard** (`kubernetesui/dashboard`) wurde am **21. Januar 2026
archiviert** — keine Maintainer mehr, Repository read-only, Helm-Repo abgeschaltet
(`https://kubernetes.github.io/dashboard/` liefert 404). Die Maintainer verweisen
ausdrücklich auf **Headlamp**, das unter `kubernetes-sigs` von SIG-UI weitergeführt wird.

Für die Schulung ist das ein Gewinn:

| | Kubernetes Dashboard 7 (archiviert) | Headlamp |
|---|---|---|
| Installation | Helm, 5 Pods, zwingend Kong-Gateway | Helm oder ein YAML, 1 Pod |
| Zugriff | nur HTTPS, selbstsigniert | HTTP (TLS optional per Ingress) |
| Login | Token / Kubeconfig | Token / OIDC / Kubeconfig |
| Multi-Cluster | nein | ja (Kubeconfigs, Cluster Inventory API) |
| Erweiterbar | nein | Plugin-System (u. a. Flux-, Prometheus-, Cert-Manager-Plugins) |
| Auch als Desktop-App | nein | ja (Windows/macOS/Linux) |

Trainer-Hinweis für den Kurs: Wer noch „`kubectl apply -f recommended.yaml`" im Kopf hat,
lernt hier nebenbei, dass Plattform-Komponenten sterben können — ein Argument für
Helm-Charts aus Git statt Copy-Paste-URLs im Wiki.

---

## 1. Wozu eine Cluster-UI in einer Argo CD-Schulung?

Argo CD zeigt nur, was **Argo CD verwaltet**. Headlamp zeigt den Cluster als Ganzes:

| Frage | Argo CD UI | Headlamp |
|---|---|---|
| Entspricht der Cluster dem Git-Stand? | ja, das ist ihr Kern | nein, kennt Git nicht |
| Was läuft in `kube-system`? | nur wenn eine Application es verwaltet | alles |
| Verwaiste Objekte, handgestartete Pods | Projekt-Feature `orphanedResources` | direkt sichtbar |
| Live-Logs, Shell in den Pod | ja | ja |
| Ressourcen editieren | nur über Git (richtig so) | direkt im YAML-Editor (= Drift!) |

**Einsatz im Kurs:** In Modul 1 und 5 zeigen, dass der Cluster nichts von Git weiß. Als
Betriebswerkzeug für GitOps ist eine Cluster-UI ein Anti-Pattern: Wer dort auf „Scale" oder
„Edit" klickt, erzeugt Drift — und Self-Heal dreht es zurück.

---

## 2. Installation (Skript)

```powershell
cd C:\Users\Dozent\Desktop\argocd\argocd-schulung-setup
.\05-install-dashboard.ps1
```

Das Skript:

1. räumt Reste einer früheren Kubernetes-Dashboard-Installation weg (Namespace
   `kubernetes-dashboard`, alte ClusterRoleBindings),
2. prüft, ob der Cluster das Portmapping `8084` hat (Abschnitt 3),
3. installiert **metrics-server** mit `--kubelet-insecure-tls` (kind-Kubelets haben
   selbstsignierte Zertifikate; ohne den Schalter bleiben die CPU-/RAM-Graphen leer),
4. installiert das Headlamp-Chart aus `https://kubernetes-sigs.github.io/headlamp/` in den
   Namespace `headlamp` mit `dashboard\values.yaml`,
5. legt die ServiceAccounts `admin-user` (cluster-admin) und `viewer-user` (read-only) an,
6. erzeugt ein Token und schreibt es nach `dashboard-token.txt`.

| Aufruf | Wirkung |
|---|---|
| `.\05-install-dashboard.ps1` | NodePort 30084 → `http://localhost:8084` |
| `.\05-install-dashboard.ps1 -PortForward` | ClusterIP, Zugriff per port-forward |
| `.\05-install-dashboard.ps1 -SkipMetrics` | ohne metrics-server |

Von Hand entspricht das:

```powershell
helm repo add headlamp https://kubernetes-sigs.github.io/headlamp/
helm repo update
helm upgrade --install headlamp headlamp/headlamp `
  --create-namespace --namespace headlamp `
  --values dashboard\values.yaml
kubectl apply -f dashboard\admin-user.yaml
kubectl -n headlamp create token admin-user --duration=24h
```

Ohne Helm (reines Manifest, landet in `kube-system`, ClusterIP):

```powershell
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/headlamp/main/kubernetes-headlamp.yaml
```

---

## 3. Zugriffsweg wählen

### Variante A — NodePort über das kind-Portmapping (empfohlen)

Stabile URL, kein Prozess, der offen bleiben muss. Bedingung: Der Cluster hat beim Anlegen
das Mapping `30084 → 8084` bekommen. Die aktuelle `kind-config.yaml` enthält es; ältere
Cluster nicht. Prüfen:

```powershell
docker port schulung-control-plane     # Zeile mit 8084 vorhanden?
```

Fehlt sie: Cluster neu anlegen (Argo CD danach neu installieren):

```powershell
.\99-teardown.ps1 ; .\02-create-cluster.ps1 ; .\03-install-argocd.ps1 ; .\05-install-dashboard.ps1
```

Aufruf: **http://localhost:8084** — kein HTTPS, keine Zertifikatswarnung.

### Variante B — port-forward (ohne Neuanlage)

```powershell
kubectl -n headlamp port-forward svc/headlamp 8084:80
```

Fenster offen lassen. Bricht der Befehl ab (Standby, Pod-Neustart), ist die UI weg — im
Kurs die häufigste „geht nicht mehr"-Ursache.

---

## 4. Anmelden

1. `http://localhost:8084` öffnen → Headlamp fragt nach einem Token.
2. Token erzeugen (landet in der Zwischenablage):

```powershell
.\06-dashboard-token.ps1              # admin-user, cluster-admin
.\06-dashboard-token.ps1 -Viewer      # viewer-user, read-only
```

3. Einfügen → **Authenticate**.

> **Warum kein Passwort?** Headlamp hat keine eigene Benutzerverwaltung. Es reicht das Token
> an den Kubernetes-API-Server durch — Sie sehen genau das, was der ServiceAccount per RBAC
> darf. Die Frage ist nie „wer darf in die UI", sondern „welche Rechte hat der Account".

Zwei ServiceAccounts, die man auseinanderhalten muss:

- **`headlamp`** (vom Chart angelegt, cluster-admin per Chart-Default): der Account des
  *Pods*. Headlamp braucht ihn für interne Aufrufe; er ist nicht Ihr Login.
- **`admin-user` / `viewer-user`**: die Accounts, deren Token Sie beim Login eingeben.

Tokens laufen nach 24 h ab; dann Skript 06 erneut ausführen.

---

## 5. Rundgang durch die Oberfläche

**Kopfzeile:** Namespace-Filter (Standard: alle — anders als beim alten Dashboard),
Cluster-Umschalter (bei mehreren Kubeconfigs), globale Suche, Benutzer-Menü mit Logout.

**Startseite „Cluster":** CPU-/RAM-Auslastung (braucht metrics-server), Anzahl Pods/Nodes,
jüngste Events. Guter Ort, um zu zeigen, dass `kubectl top` und die UI dieselbe Quelle haben.

**Linke Navigation:**

| Bereich | Inhalt | Nützlich für |
|---|---|---|
| Cluster | Übersicht, Namespaces, Nodes, CRDs | Cluster-weite Sicht |
| Workloads | Deployments, ReplicaSets, StatefulSets, DaemonSets, Jobs, CronJobs, Pods — auf einer Seite | Einstieg; Status-Ampel je Workload |
| Storage | PVs, PVCs, StorageClasses | „Wo liegen die Bestelldaten?" |
| Network | Services, Endpoints, Ingresses, NetworkPolicies | „Warum ist der Shop nicht erreichbar?" |
| Security | ServiceAccounts, Roles, RoleBindings, Secrets | RBAC live nachvollziehen (Modul 8) |
| Config | ConfigMaps, HPAs, ResourceQuotas, LimitRanges | HPA-vs-Self-Heal-Flapping (Modul 10) |
| Custom Resources | alle CRDs — auch `applications.argoproj.io` | Argo CD-Objekte als reine K8s-Objekte |

**Pro Ressource** (Detailseite): YAML-Editor (Bearbeiten → Speichern schreibt direkt in den
Cluster!), Löschen, Scale bei Deployments, Restart. **Pro Pod:** Logs (Follow, Container-Wahl,
Vorgänger-Container), Terminal (Exec), Events, Ressourcenverbrauch.

**Plugins** (Zahnrad → Plugins): Headlamp kann per Plugin z. B. Flux- oder Prometheus-Sichten
ergänzen. Für Argo CD gibt es kein offizielles Plugin — Argo CD hat seine eigene UI, und
genau diese Trennung ist die didaktische Pointe.

---

## 6. Übungen für den Kurs

**Übung A — Der Cluster kennt Git nicht (Modul 1).**
Shop von Hand deployen, in Headlamp unter Workloads ansehen. Frage: Woran erkennt man
hier, ob dieser Stand dem Git-Repository entspricht? (Antwort: gar nicht.)

**Übung B — Drift erzeugen und verlieren (Modul 5).**
Bei aktivem Self-Heal in Headlamp das Deployment `kaffee-shop` auf 0 skalieren
(Detailseite → Scale). Zusehen, wie Argo CD es binnen Sekunden zurückdreht. Dann dasselbe im
YAML-Editor versuchen. Erkenntnis: Die UI darf, gewinnt aber nicht.

**Übung C — RBAC begreifen (Modul 8).**
Mit `viewer-user`-Token neu anmelden. Was fehlt? (Secrets: „forbidden"; Scale/Edit/Delete
ausgegraut oder Fehler.) Dieselbe Mechanik wie Argo CDs RBAC — nur eine Ebene tiefer.

**Übung D — Argo CD-Objekte als CRDs (Modul 2/9).**
Unter *Custom Resources* die `Application` `shop-dev` öffnen und ihr YAML lesen. Alles, was
in der Argo CD-UI geklickt wird, ist ein normales Kubernetes-Objekt.

---

## 7. Sicherheit — was hier bewusst falsch ist

- **`cluster-admin` für einen Login-Account** ist Vollzugriff. Produktiv: eigene Role je Team,
  auf Namespaces begrenzt, read-only als Standard (`viewer-user.yaml` zeigt das Muster).
- **Auch der Pod-Account `headlamp` hat cluster-admin** (Chart-Default). Produktiv auf eine
  engere ClusterRole setzen (`clusterRoleBinding.clusterRoleName`).
- **HTTP ohne TLS, NodePort.** In kind harmlos (nur localhost). Produktiv: Ingress mit
  cert-manager und **OIDC-Login** (Headlamp unterstützt das nativ) statt kopierter Tokens.
- **Langlebige Tokens.** 24 h ist schon besser als das früher übliche Secret ohne Ablauf;
  produktiv kurze Laufzeiten oder OIDC.
- Historisch: Der Tesla-Kryptomining-Vorfall 2018 lief über ein ungeschütztes Kubernetes
  Dashboard. Die UI war nicht das Problem — der exponierte Cluster-Zugang war es.

---

## 8. Deinstallation und Reset

```powershell
helm uninstall headlamp -n headlamp
kubectl delete namespace headlamp
kubectl delete clusterrolebinding headlamp-admin-user headlamp-viewer-user --ignore-not-found
# optional:
helm uninstall metrics-server -n kube-system
```

---

## 9. Troubleshooting

| Symptom | Ursache / Lösung |
|---|---|
| `helm repo add kubernetes-dashboard` → 404 | Projekt archiviert, Repo weg. Nicht reparierbar — Headlamp verwenden |
| `http://localhost:8084` lädt nicht | Cluster ohne Portmapping 8084 → `docker port schulung-control-plane`, sonst Variante B |
| Seite lädt, Login „Unauthorized" | Token abgelaufen, unvollständig kopiert oder ServiceAccount gelöscht → Skript 06 bzw. `kubectl apply -f dashboard\admin-user.yaml` |
| Alles leer / „forbidden" | viewer-user ohne Rechte im Namespace; oder Namespace-Filter |
| CPU-/RAM-Graphen leer | metrics-server fehlt oder scheitert an TLS → `kubectl -n kube-system logs deploy/metrics-server`; `--kubelet-insecure-tls` muss gesetzt sein |
| `helm upgrade` → „cannot re-use a name" | Halb entfernte Installation → `helm uninstall headlamp -n headlamp`, neu |
| Pod `ImagePullBackOff` | Image liegt auf ghcr.io (`ghcr.io/headlamp-k8s/headlamp`) → Proxy/Firewall für ghcr.io prüfen |
| port-forward bricht ab | Pod neu gestartet → Befehl neu starten; dauerhaft: Variante A |

---

## 10. Optional: Headlamp per Argo CD ausrollen (Tag 2)

`dashboard\argocd-app-headlamp.yaml` enthält eine fertige `Application`, die das Chart
direkt aus dem Chart-Repository zieht. Ins Schulungs-Repo unter `argocd/apps/` legen, dann
erzeugt die Root-Application sie mit. Ein echtes Beispiel für ein **Fremd-Chart aus einem
Helm-Repo** (Modul 7) — und dafür, dass Plattform-Werkzeuge genauso in Git gehören wie
Anwendungen.

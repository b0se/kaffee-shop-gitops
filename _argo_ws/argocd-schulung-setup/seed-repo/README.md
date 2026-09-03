# Nordlicht Kaffee – GitOps-Repository (Schulung Argo CD)

Dieses Repository ist die **Single Source of Truth** für den Web-Shop der fiktiven
Rösterei *Nordlicht Kaffee*. Es wird in der zweitägigen Argo CD-Schulung Schritt für
Schritt erweitert.

```
apps/shop/base/          Kustomize-Basis (Deployment, Service, ConfigMap)
apps/shop/overlays/dev   Overlay dev  (1 Replica, NodePort 30081)
apps/shop/overlays/prod  Overlay prod (3 Replicas, NodePort 30082)
charts/kaffee-shop/      Dieselbe App als Helm-Chart (Tag 2)
argocd/projects/         AppProject "nordlicht"
argocd/apps/             App-of-Apps-Kinder
argocd/applicationsets/  ApplicationSet-Beispiele
hooks/                   Sync-Hooks & Sync-Waves
secrets-demo/            Sealed-Secrets-Beispiel (ohne Klartext!)
.github/workflows/       promote-dev: simulierter CI-Bump (Modul 10)
scripts/                 PowerShell-Automatisierung: drift-report, sync-and-wait (Modul 13)
monitoring/              ServiceMonitors + PrometheusRule fuer Argo CD (Modul 14)
argocd/optional/         kube-prometheus-stack u.a. - nicht von der Root-App erfasst
```

Jede*r Teilnehmer*in arbeitet in einer **eigenen Kopie** dieses Repos
(GitHub → "Use this template" → eigener Account, Sichtbarkeit *Public*).

#!/usr/bin/env bash
# Download the ArgoCD CLI and log in to the locally port-forwarded ArgoCD server.
set -euo pipefail

ARGO_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)

kubectl port-forward svc/argocd-server -n argocd 8081:443 --address=0.0.0.0 \
  >/dev/null 2>&1 &
PORTFORWARD_PID=$!
sleep 10

curl -sSL -o /tmp/argocd-linux-amd64 \
  https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 /tmp/argocd-linux-amd64 /usr/local/bin/argocd
rm /tmp/argocd-linux-amd64

argocd login localhost:8081 --username admin --password "$ARGO_PASSWORD" --insecure

kill "$PORTFORWARD_PID" || true

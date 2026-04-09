#!/usr/bin/env bash
# Validate that all non-excluded ArgoCD applications reach Synced+Healthy.
# Runs app checks in parallel; exits 1 if any fail within TIMEOUT seconds.
set -euo pipefail

# Apps excluded from CI health checks due to production infrastructure dependencies.
# Reasons:
#   - iSCSI NAS storage: apps with PVs pointing to 192.168.42.42 (production NAS)
#   - VaultStaticSecret CRD: requires vault-secrets-operator to be initialized first
#   - Production secrets: Datadog API key, Tailscale auth key, etc.
#   - cert-manager CRDs: ClusterIssuer/Certificate CRDs unavailable until cert-manager is healthy
#   - Self-referential: ArgoCD managing its own Helm deployment
EXCLUDED_APPS=(
  "argocd/argocd"                          # Self-referential: ArgoCD managing itself via Helm
  "argocd/authentik"                       # Requires VaultStaticSecret CRD + production secrets
  "argocd/bazarr"                          # Requires iSCSI NAS storage (192.168.42.42)
  "argocd/cert-manager"                    # Pods remain Pending in CI environment
  "argocd/cert-manager-letsencrypt-issuer" # Requires cert-manager CRDs + ACME challenge
  "argocd/cert-manager-selfsigned-issuer"  # Requires cert-manager CRDs to be operational
  "argocd/cleanuparr"                      # Requires iSCSI NAS storage (192.168.42.42)
  "argocd/datadog"                         # Requires Datadog API key secret
  "argocd/flaresolverr"                    # Pods remain Pending in CI environment
  "argocd/homepage"                        # Requires cert-manager CRDs + Traefik IngressRoute CRDs
  "argocd/jellyfin"                        # Requires iSCSI NAS storage (192.168.42.42)
  "argocd/jellyseerr"                      # Requires iSCSI NAS storage (192.168.42.42)
  "argocd/memory-webhook"                  # Requires cert-manager CRDs for webhook TLS cert
  "argocd/pihole"                          # Liveness probe checks DNS functionality unavailable in CI
  "argocd/prowlarr"                        # Requires iSCSI NAS storage + Traefik IngressRoute CRDs
  "argocd/qbittorrent"                     # Requires VaultStaticSecret CRD + iSCSI NAS storage
  "argocd/radarr"                          # Requires iSCSI NAS storage + Traefik IngressRoute CRDs
  "argocd/sonarr"                          # Requires iSCSI NAS storage + Traefik IngressRoute CRDs
  "argocd/st0rmingbr4in.com-cert"          # Requires cert-manager CRDs
  "argocd/tailscale-operator"              # Requires Tailscale auth key secret
  "argocd/traefik"                         # Requires VaultStaticSecret CRD in manifests path
  "argocd/vault"                           # Requires manual Vault initialization
  "argocd/vault-secrets-operator"          # upgrade-crds job remains Pending in CI
)

TIMEOUT=600

is_excluded() {
  local app="$1"
  for excluded in "${EXCLUDED_APPS[@]}"; do
    [ "$app" = "$excluded" ] && return 0
  done
  return 1
}

check_app() {
  local app="$1"
  echo "Checking $app..."
  local start
  start=$(date +%s)
  local prev_sync="" prev_health=""

  while [ $(( $(date +%s) - start )) -lt "$TIMEOUT" ]; do
    local sync health
    sync=$(argocd app get "$app" -o json 2>/dev/null | jq -r '.status.sync.status // "Unknown"')
    health=$(argocd app get "$app" -o json 2>/dev/null | jq -r '.status.health.status // "Unknown"')

    if [ "$sync" = "Synced" ] && [ "$health" = "Healthy" ]; then
      echo "✓ $app: Synced and Healthy"
      return 0
    fi

    if [ "$sync" != "$prev_sync" ] || [ "$health" != "$prev_health" ]; then
      echo "  $app: Sync=$sync, Health=$health (waiting...)"
      prev_sync="$sync"
      prev_health="$health"
    fi

    sleep 5
  done

  local final_sync final_health
  final_sync=$(argocd app get "$app" -o json 2>/dev/null | jq -r '.status.sync.status // "Unknown"')
  final_health=$(argocd app get "$app" -o json 2>/dev/null | jq -r '.status.health.status // "Unknown"')
  echo "✗ $app: timed out after ${TIMEOUT}s (Sync=$final_sync, Health=$final_health)"
  echo "$app" >> /tmp/failed_apps.txt
  return 1
}

# Re-establish port-forward and re-login (previous port-forward was killed after configure step)
ARGO_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
kubectl port-forward svc/argocd-server -n argocd 8081:443 --address=0.0.0.0 \
  >/dev/null 2>&1 &
PORTFORWARD_PID=$!
sleep 10
argocd login localhost:8081 --username admin --password "$ARGO_PASSWORD" --insecure

echo "=== ArgoCD Applications ==="
argocd app list

echo ""
echo "=== Waiting for applications to sync and become healthy ==="

APPS=$(argocd app list -o name 2>/dev/null || echo "")

rm -f /tmp/failed_apps.txt
PIDS=()

if [ -n "$APPS" ]; then
  for app in $APPS; do
    if is_excluded "$app"; then
      echo "⏭ $app: Skipped (excluded — requires production infrastructure)"
      continue
    fi
    check_app "$app" &
    PIDS+=($!)
  done

  for pid in "${PIDS[@]}"; do
    wait "$pid"
  done
fi

FAILED_APPS=()
if [ -f /tmp/failed_apps.txt ]; then
  readarray -t FAILED_APPS < /tmp/failed_apps.txt
fi

echo ""
echo "=== Excluded Applications (require production infrastructure) ==="
for app in "${EXCLUDED_APPS[@]}"; do
  echo "  ⏭ $app"
done

if [ "${#FAILED_APPS[@]}" -gt 0 ]; then
  echo ""
  echo "=== Applications that failed to sync/become healthy within ${TIMEOUT}s ==="
  for app in "${FAILED_APPS[@]}"; do
    echo "  ✗ $app"
  done
  kill "$PORTFORWARD_PID" || true
  exit 1
fi

echo ""
echo "=== All testable applications successfully synced and healthy ==="
argocd app get argocd-apps || echo "argocd-apps application not found"

kill "$PORTFORWARD_PID" || true

#!/usr/bin/env bash
# Queries the Authentik API and outputs terraform import commands for existing resources.
# Run this once before the first `terraform apply` to avoid recreating existing resources.
#
# Usage:
#   export AUTHENTIK_TOKEN=<your-api-token>
#   ./import.sh | bash

set -euo pipefail

AUTHENTIK_URL="${AUTHENTIK_URL:-https://authentik.st0rmingbr4in.com}"
TOKEN="${AUTHENTIK_TOKEN:?Set AUTHENTIK_TOKEN to an Authentik API token}"

api() { curl -sf -H "Authorization: Bearer $TOKEN" "$AUTHENTIK_URL/api/v3/$1"; }

echo "# Importing existing Authentik resources into Terraform state"
echo ""

# Proxy providers (skip cleanuparr — it's new, Terraform will create it)
# Format: "key:Provider Name"
PROVIDERS=(
  "argocd:ArgoCD Provider"
  "bazarr:Bazarr Provider"
  "prowlarr:Prowlarr Provider"
  "qbittorrent:qBittorrent Provider"
  "radarr:Radarr Provider"
  "sonarr:Sonarr Provider"
)

for entry in "${PROVIDERS[@]}"; do
  key="${entry%%:*}"
  name="${entry#*:}"
  encoded=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$name")
  id=$(api "providers/proxy/?name=$encoded" | jq -r '.results[0].pk // empty')
  if [ -n "$id" ]; then
    echo "terraform import 'authentik_provider_proxy.apps[\"$key\"]' $id"
  else
    echo "# WARNING: provider '$name' not found in Authentik — will be created" >&2
  fi
done

echo ""

# Applications (skip cleanuparr — it's new)
for slug in argocd bazarr prowlarr qbittorrent radarr sonarr; do
  id=$(api "core/applications/$slug/" | jq -r '.pk // empty')
  if [ -n "$id" ]; then
    echo "terraform import 'authentik_application.apps[\"$slug\"]' $id"
  else
    echo "# WARNING: application '$slug' not found in Authentik — will be created" >&2
  fi
done

echo ""

# Embedded outpost
outpost_id=$(api "outposts/instances/?name=authentik+Embedded+Outpost" | jq -r '.results[0].pk // empty')
if [ -n "$outpost_id" ]; then
  echo "terraform import authentik_outpost.embedded $outpost_id"
else
  echo "# WARNING: embedded outpost not found — check the outpost name in Authentik UI" >&2
fi

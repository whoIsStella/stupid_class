#!/usr/bin/env bash
# import-dashboards.sh — import all dashboard JSON files via Grafana API
# Alternative to file-based provisioning — useful if you've edited dashboards
# in the UI and want to re-import from the repo versions.
set -euo pipefail

GRAFANA_URL="http://localhost:3000"
GRAFANA_CREDS="admin:${GRAFANA_ADMIN_PASSWORD:-honeypot2025}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASH_DIR="$SCRIPT_DIR/../provisioning/dashboards"

ok()   { printf '  \033[0;32m✓\033[0m %s\n' "$*"; }
fail() { printf '  \033[0;31m✗\033[0m %s\n' "$*"; }

# Wait for Grafana to be ready
echo "Waiting for Grafana..."
for i in $(seq 1 20); do
    if curl -sf "$GRAFANA_URL/api/health" > /dev/null 2>&1; then
        echo "Grafana is ready."
        break
    fi
    sleep 3
done

echo ""
echo "Importing dashboards from $DASH_DIR..."

for dash_file in "$DASH_DIR"/*.json; do
    name=$(basename "$dash_file")
    # Wrap in the format Grafana's import API expects
    payload=$(python3 -c "
import json, sys
with open('$dash_file') as f:
    dash = json.load(f)
dash['id'] = None   # let Grafana assign the internal ID
print(json.dumps({'dashboard': dash, 'overwrite': True, 'folderId': 0}))
")
    result=$(curl -sf -u "$GRAFANA_CREDS" \
        -X POST "$GRAFANA_URL/api/dashboards/db" \
        -H 'Content-Type: application/json' \
        -d "$payload" 2>/dev/null)
    status=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','unknown'))" 2>/dev/null)
    if [ "$status" = "success" ]; then
        ok "$name"
    else
        fail "$name — $result"
    fi
done

echo ""
echo "Open Grafana to verify: $GRAFANA_URL"

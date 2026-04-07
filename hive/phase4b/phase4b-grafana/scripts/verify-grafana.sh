#!/usr/bin/env bash
# verify-grafana.sh — health check Grafana services and provisioned resources
set -euo pipefail

GRAFANA_URL="http://localhost:3000"
GRAFANA_CREDS="admin:${GRAFANA_ADMIN_PASSWORD:-honeypot2025}"

ok()   { printf '  \033[0;32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[0;33m!\033[0m %s\n' "$*"; }
fail() { printf '  \033[0;31m✗\033[0m %s\n' "$*"; }

echo ""
echo "=== Grafana health ==="
HEALTH=$(curl -sf "$GRAFANA_URL/api/health" 2>/dev/null) || { fail "Grafana not reachable at :3000"; exit 1; }
echo "$HEALTH" | python3 -m json.tool 2>/dev/null || echo "$HEALTH"

DB_STATE=$(echo "$HEALTH" | python3 -c "import sys,json; print(json.load(sys.stdin).get('database','unknown'))" 2>/dev/null)
[ "$DB_STATE" = "ok" ] && ok "database: $DB_STATE" || warn "database: $DB_STATE"

echo ""
echo "=== Data sources ==="
DS=$(curl -sf -u "$GRAFANA_CREDS" "$GRAFANA_URL/api/datasources" 2>/dev/null) || { warn "Could not fetch datasources (check credentials)"; DS="[]"; }
echo "$DS" | python3 -c "
import sys, json
sources = json.load(sys.stdin)
print(f'  {len(sources)} datasource(s) provisioned:')
for s in sources:
    print(f'    [{s[\"uid\"]}] {s[\"name\"]} → {s[\"database\"]}')
" 2>/dev/null || echo "$DS"

echo ""
echo "=== Dashboards ==="
DASH=$(curl -sf -u "$GRAFANA_CREDS" "$GRAFANA_URL/api/search?type=dash-db" 2>/dev/null) || { warn "Could not fetch dashboards"; DASH="[]"; }
echo "$DASH" | python3 -c "
import sys, json
dashboards = json.load(sys.stdin)
print(f'  {len(dashboards)} dashboard(s) provisioned:')
for d in dashboards:
    print(f'    [{d[\"uid\"]}] {d[\"title\"]}')
" 2>/dev/null || echo "$DASH"

echo ""
echo "=== Provisioning status ==="
PROV=$(curl -sf -u "$GRAFANA_CREDS" "$GRAFANA_URL/api/admin/provisioning/dashboards/reload" \
  -X POST -H 'Content-Type: application/json' 2>/dev/null) || true
echo "  Dashboard provisioning reload triggered (check Grafana logs if dashboards are missing)"

echo ""
echo "Open Grafana: $GRAFANA_URL"
echo "Login: admin / ${GRAFANA_ADMIN_PASSWORD:-honeypot2025}"

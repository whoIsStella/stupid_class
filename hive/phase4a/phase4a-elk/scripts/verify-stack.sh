#!/usr/bin/env bash
# verify-stack.sh — health check Elasticsearch, Logstash, and Kibana
set -euo pipefail

ok()   { printf '  \033[0;32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[0;33m!\033[0m %s\n' "$*"; }
fail() { printf '  \033[0;31m✗\033[0m %s\n' "$*"; }

echo ""
echo "=== Elasticsearch ==="
ES_HEALTH=$(curl -sf http://localhost:9200/_cluster/health 2>/dev/null) || { fail "Elasticsearch not reachable at :9200"; ES_HEALTH=""; }
if [ -n "$ES_HEALTH" ]; then
    STATUS=$(echo "$ES_HEALTH" | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])")
    case "$STATUS" in
        green)  ok  "cluster health: $STATUS" ;;
        yellow) warn "cluster health: $STATUS (normal for single-node)" ;;
        red)    fail "cluster health: $STATUS" ;;
    esac
    curl -sf http://localhost:9200/_cluster/health | python3 -m json.tool
fi

echo ""
echo "=== Logstash ==="
LS_STATS=$(curl -sf http://localhost:9600/_node/stats 2>/dev/null) || { fail "Logstash not reachable at :9600"; LS_STATS=""; }
if [ -n "$LS_STATS" ]; then
    ok "Logstash reachable"
    echo "$LS_STATS" | python3 -c "
import sys, json
d = json.load(sys.stdin)
ev = d.get('events', {})
print(f'  in: {ev.get(\"in\",0)}  filtered: {ev.get(\"filtered\",0)}  out: {ev.get(\"out\",0)}')
"
fi

echo ""
echo "=== Kibana ==="
KB_STATUS=$(curl -sf http://localhost:5601/api/status 2>/dev/null) || { fail "Kibana not reachable at :5601"; KB_STATUS=""; }
if [ -n "$KB_STATUS" ]; then
    STATE=$(echo "$KB_STATUS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',{}).get('overall',{}).get('level','unknown'))")
    case "$STATE" in
        available) ok  "Kibana state: $STATE" ;;
        degraded)  warn "Kibana state: $STATE" ;;
        *)         warn "Kibana state: $STATE" ;;
    esac
fi

echo ""
echo "=== Index counts ==="
curl -sf "http://localhost:9200/_cat/indices/hive-*?v&h=index,docs.count,store.size" 2>/dev/null | sort || warn "No hive-* indices yet (run create-indices.sh and test-ingest.sh)"

echo ""
echo "=== Index templates ==="
curl -sf "http://localhost:9200/_index_template/hive-*" 2>/dev/null | \
  python3 -c "import sys,json; d=json.load(sys.stdin); [print(f'  {t[\"name\"]}') for t in d.get('index_templates',[])]" || warn "No hive-* templates found (run create-indices.sh)"

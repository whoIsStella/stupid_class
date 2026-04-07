#!/usr/bin/env bash
# test-enrichment.sh — smoke-test the IP enrichment pipeline
#
# Validates API keys and connectivity before running against live data.
# Uses 8.8.8.8 (Google DNS) as a known-good test IP — it has known ASN
# data and a predictable AbuseIPDB record (low score, high volume).
#
# Usage:
#   export ABUSEIPDB_API_KEY=your_key
#   export SHODAN_API_KEY=your_key
#   bash scripts/test-enrichment.sh
#
# Dev cache workaround (avoids needing /var/lib/hive/):
#   export HIVE_CACHE_DB=/home/gumby/hive-data/enrichment_cache/enrichment_cache.db

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENRICHMENT_DIR="$(dirname "$SCRIPT_DIR")"
TEST_IP="8.8.8.8"

cd "$ENRICHMENT_DIR"

fail() { echo "[FAIL] $*" >&2; exit 1; }
ok()   { echo "[ OK ] $*"; }

echo "=== Hive enrichment smoke test ==="
echo "Test IP: ${TEST_IP}"
echo ""

[[ -n "${ABUSEIPDB_API_KEY:-}" ]] || fail "ABUSEIPDB_API_KEY is not set"
ok "ABUSEIPDB_API_KEY is set (${#ABUSEIPDB_API_KEY} chars)"

[[ -n "${SHODAN_API_KEY:-}" ]] || fail "SHODAN_API_KEY is not set"
ok "SHODAN_API_KEY is set (${#SHODAN_API_KEY} chars)"

# Dev cache path if /var/lib/hive/ isn't writable
if [[ -z "${HIVE_CACHE_DB:-}" ]] && [[ ! -w /var/lib/hive/ ]]; then
    CACHE_DIR="${HOME}/hive-data/enrichment_cache"
    mkdir -p "$CACHE_DIR"
    export HIVE_CACHE_DB="${CACHE_DIR}/enrichment_cache.db"
    echo "[info] /var/lib/hive not writable; using dev cache: ${HIVE_CACHE_DB}"
fi

ES_HOST="${ES_HOST:-localhost}"
ES_PORT="${ES_PORT:-9200}"

echo ""
echo "--- Elasticsearch connectivity ---"
if curl -sf "http://${ES_HOST}:${ES_PORT}/_cluster/health" | python3 -m json.tool > /dev/null 2>&1; then
    ok "Elasticsearch reachable at ${ES_HOST}:${ES_PORT}"
else
    fail "Cannot reach Elasticsearch at ${ES_HOST}:${ES_PORT}"
fi

echo ""
echo "--- AbuseIPDB API ---"
python3 - <<EOF
import sys
sys.path.insert(0, '.')
from sources import abuseipdb
try:
    r = abuseipdb.check_ip("${TEST_IP}")
    print(f"[ OK ] score={r['abuse_confidence_score']}  reports={r['total_reports']}  isp={r.get('isp')}")
except Exception as e:
    print(f"[FAIL] {e}", file=sys.stderr)
    sys.exit(1)
EOF

echo ""
echo "--- Shodan API ---"
python3 - <<EOF
import sys
sys.path.insert(0, '.')
from sources import shodan_lookup
try:
    r = shodan_lookup.lookup_ip("${TEST_IP}")
    print(f"[ OK ] org={r.get('org')}  tags={r.get('tags')}  ports={r.get('ports')}")
except Exception as e:
    print(f"[FAIL] {e}", file=sys.stderr)
    sys.exit(1)
EOF

echo ""
echo "--- ASN lookup (ipinfo.io) ---"
python3 - <<EOF
import sys
sys.path.insert(0, '.')
from sources import asn_lookup
try:
    r = asn_lookup.lookup_asn("${TEST_IP}")
    print(f"[ OK ] asn={r.get('asn')}  org={r.get('org')}  country={r.get('country')}")
except Exception as e:
    print(f"[FAIL] {e}", file=sys.stderr)
    sys.exit(1)
EOF

echo ""
echo "=== All checks passed. Run: python3 enricher.py ==="

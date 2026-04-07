#!/usr/bin/env bash
# test-ingest.sh — inject one sample document per source directly into Elasticsearch
# Verifies index templates, field mappings, and that data can be queried.
#
# This bypasses Logstash (posts directly to ES REST API) to test indexing
# and mappings independently of the Beats pipeline.
set -euo pipefail

ES="http://localhost:9200"
TODAY="$(date -u '+%Y.%m.%d')"

echo "Injecting sample documents into Elasticsearch..."
echo ""

# ── Web honeypot ───────────────────────────────────────────────────────────────
echo "→ hive-web-${TODAY}"
curl -sf -X POST "$ES/hive-web-${TODAY}/_doc" \
  -H 'Content-Type: application/json' \
  -d '{
    "@timestamp": "'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'",
    "remote_ip": "1.2.3.4",
    "method": "GET",
    "path": "/.env",
    "query_string": "",
    "user_agent": "gobuster/3.1.0",
    "response_code": 200,
    "honeypot_surface": "web",
    "log_source": "web_honeypot"
  }' > /dev/null && echo "   ✓ web doc indexed"

# ── Cowrie ─────────────────────────────────────────────────────────────────────
echo "→ hive-cowrie-${TODAY}"
curl -sf -X POST "$ES/hive-cowrie-${TODAY}/_doc" \
  -H 'Content-Type: application/json' \
  -d '{
    "@timestamp": "'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'",
    "src_ip": "5.6.7.8",
    "cowrie_event_type": "cowrie.login.failed",
    "username": "root",
    "password": "123456",
    "session": "abc123def456",
    "honeypot_surface": "ssh",
    "log_source": "cowrie"
  }' > /dev/null && echo "   ✓ cowrie doc indexed"

# ── Suricata ───────────────────────────────────────────────────────────────────
echo "→ hive-suricata-${TODAY}"
curl -sf -X POST "$ES/hive-suricata-${TODAY}/_doc" \
  -H 'Content-Type: application/json' \
  -d '{
    "@timestamp": "'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'",
    "src_ip": "9.10.11.12",
    "dest_ip": "192.168.1.1",
    "src_port": 54321,
    "dest_port": 80,
    "proto": "TCP",
    "event_type": "alert",
    "alert": {
      "signature": "HONEYPOT DirBust Tool - gobuster",
      "severity": 3,
      "category": "Web Application Attack"
    },
    "honeypot_surface": "ids",
    "log_source": "suricata"
  }' > /dev/null && echo "   ✓ suricata doc indexed"

echo ""
sleep 2

# ── Verify ────────────────────────────────────────────────────────────────────
echo "Index counts:"
curl -sf "$ES/_cat/indices/hive-*?v&h=index,docs.count,store.size" | sort

echo ""
echo "Sample web query (path=/.env):"
curl -sf "$ES/hive-web-*/_search?q=path:.env&size=1" | \
  python3 -c "import sys,json; d=json.load(sys.stdin); h=d['hits']['hits']; print('  found:', len(d['hits']['hits']), 'doc(s)'); [print('  ', json.dumps(h[0]['_source'], indent=2)[:300]) for _ in [1]] if h else None"

echo ""
echo "Sample cowrie query (failed logins):"
curl -sf "$ES/hive-cowrie-*/_search?q=cowrie_event_type:cowrie.login.failed&size=1" | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print('  found:', len(d['hits']['hits']), 'doc(s)')"

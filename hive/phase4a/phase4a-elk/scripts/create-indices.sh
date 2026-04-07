#!/usr/bin/env bash
# create-indices.sh — create Elasticsearch index templates with correct field mappings
# Run once after the stack is healthy, before first ingest.
#
# Key mappings:
#   - IP fields as 'ip' type  → enables IP range queries and GeoIP
#   - geoip.location as 'geo_point' → required for Kibana/Grafana map panels
#   - keyword fields          → exact-match aggregations (top paths, creds, etc.)
set -euo pipefail

ES="http://localhost:9200"

wait_for_es() {
    echo "Waiting for Elasticsearch..."
    for i in $(seq 1 30); do
        if curl -sf "$ES/_cluster/health" > /dev/null 2>&1; then
            echo "Elasticsearch is ready."
            return 0
        fi
        sleep 2
    done
    echo "ERROR: Elasticsearch did not become healthy in time."
    exit 1
}

wait_for_es

# ── hive-web-* ─────────────────────────────────────────────────────────────────
echo "Creating template: hive-web"
curl -sf -X PUT "$ES/_index_template/hive-web" \
  -H 'Content-Type: application/json' \
  -d '{
    "index_patterns": ["hive-web-*"],
    "template": {
      "mappings": {
        "properties": {
          "@timestamp":      { "type": "date" },
          "remote_ip":       { "type": "ip" },
          "method":          { "type": "keyword" },
          "path":            { "type": "keyword" },
          "query_string":    { "type": "keyword" },
          "user_agent":      { "type": "text", "fields": { "keyword": { "type": "keyword" } } },
          "response_code":   { "type": "integer" },
          "honeypot_surface":{ "type": "keyword" },
          "geoip": {
            "properties": {
              "location": { "type": "geo_point" },
              "country_name": { "type": "keyword" },
              "city_name":    { "type": "keyword" },
              "as_org":       { "type": "keyword" }
            }
          }
        }
      }
    }
  }' && echo " ✓ hive-web template created"

# ── hive-cowrie-* ──────────────────────────────────────────────────────────────
echo "Creating template: hive-cowrie"
curl -sf -X PUT "$ES/_index_template/hive-cowrie" \
  -H 'Content-Type: application/json' \
  -d '{
    "index_patterns": ["hive-cowrie-*"],
    "template": {
      "mappings": {
        "properties": {
          "@timestamp":        { "type": "date" },
          "src_ip":            { "type": "ip" },
          "cowrie_event_type": { "type": "keyword" },
          "username":          { "type": "keyword" },
          "password":          { "type": "keyword" },
          "session":           { "type": "keyword" },
          "message":           { "type": "text" },
          "honeypot_surface":  { "type": "keyword" },
          "geoip": {
            "properties": {
              "location":     { "type": "geo_point" },
              "country_name": { "type": "keyword" },
              "city_name":    { "type": "keyword" },
              "as_org":       { "type": "keyword" }
            }
          }
        }
      }
    }
  }' && echo " ✓ hive-cowrie template created"

# ── hive-suricata-* ────────────────────────────────────────────────────────────
echo "Creating template: hive-suricata"
curl -sf -X PUT "$ES/_index_template/hive-suricata" \
  -H 'Content-Type: application/json' \
  -d '{
    "index_patterns": ["hive-suricata-*"],
    "template": {
      "mappings": {
        "properties": {
          "@timestamp":       { "type": "date" },
          "src_ip":           { "type": "ip" },
          "dest_ip":          { "type": "ip" },
          "src_port":         { "type": "integer" },
          "dest_port":        { "type": "integer" },
          "proto":            { "type": "keyword" },
          "event_type":       { "type": "keyword" },
          "honeypot_surface": { "type": "keyword" },
          "alert": {
            "properties": {
              "signature":    { "type": "keyword" },
              "severity":     { "type": "integer" },
              "category":     { "type": "keyword" }
            }
          },
          "geoip": {
            "properties": {
              "location":     { "type": "geo_point" },
              "country_name": { "type": "keyword" },
              "city_name":    { "type": "keyword" },
              "as_org":       { "type": "keyword" }
            }
          }
        }
      }
    }
  }' && echo " ✓ hive-suricata template created"

# ── hive-pcap-* ───────────────────────────────────────────────────────────────
echo "Creating template: hive-pcap"
curl -sf -X PUT "$ES/_index_template/hive-pcap" \
  -H 'Content-Type: application/json' \
  -d '{
    "index_patterns": ["hive-pcap-*"],
    "template": {
      "mappings": {
        "properties": {
          "@timestamp":       { "type": "date" },
          "src_ip":           { "type": "ip" },
          "dst_ip":           { "type": "ip" },
          "src_port":         { "type": "integer" },
          "dst_port":         { "type": "integer" },
          "proto":            { "type": "keyword" },
          "length":           { "type": "integer" },
          "pcap_file":        { "type": "keyword" },
          "honeypot_surface": { "type": "keyword" },
          "geoip": {
            "properties": {
              "location":     { "type": "geo_point" },
              "country_name": { "type": "keyword" }
            }
          }
        }
      }
    }
  }' && echo " ✓ hive-pcap template created"

# ── hive-enriched-* (Phase 4c) ────────────────────────────────────────────────
echo "Creating template: hive-enriched"
curl -sf -X PUT "$ES/_index_template/hive-enriched" \
  -H 'Content-Type: application/json' \
  -d '{
    "index_patterns": ["hive-enriched-*"],
    "template": {
      "mappings": {
        "properties": {
          "@timestamp": { "type": "date" },
          "ip":         { "type": "ip" },
          "abuseipdb": {
            "properties": {
              "abuse_confidence_score": { "type": "integer" },
              "total_reports":          { "type": "integer" },
              "is_tor":                 { "type": "boolean" },
              "isp":                    { "type": "keyword" },
              "usage_type":             { "type": "keyword" }
            }
          },
          "shodan": {
            "properties": {
              "open_ports": { "type": "integer" },
              "tags":       { "type": "keyword" },
              "os":         { "type": "keyword" }
            }
          },
          "asn": {
            "properties": {
              "asn":     { "type": "keyword" },
              "org":     { "type": "keyword" },
              "country": { "type": "keyword" },
              "city":    { "type": "keyword" }
            }
          }
        }
      }
    }
  }' && echo " ✓ hive-enriched template created"

echo ""
echo "All index templates created. Verify:"
echo "  curl -s http://localhost:9200/_index_template/hive-* | python3 -m json.tool | grep '\"name\"'"

# Phase 4b — Grafana Dashboards

Phase 4b provides the Grafana provisioning files and dashboard definitions for the hive. The JSON files visualize activity across the web, SSH, IDS, geographic, and enrichment surfaces.

## What lives here

- `phase4b-grafana/provisioning/dashboards/master-overview.json` — top-level cross-surface dashboard
- `phase4b-grafana/provisioning/dashboards/attack-overview.json` — high-level attack summary views
- `phase4b-grafana/provisioning/dashboards/web-hive.json` — Flask web hive activity
- `phase4b-grafana/provisioning/dashboards/ssh-cowrie.json` — Cowrie SSH/Telnet activity
- `phase4b-grafana/provisioning/dashboards/ids-alerts.json` — Suricata alert views
- `phase4b-grafana/provisioning/dashboards/geographic.json` — GeoIP-based attacker views
- `phase4b-grafana/provisioning/dashboards/ip-enrichment.json` — enriched attacker IP views from phase 4c
- `phase4b-grafana/provisioning/datasources/elasticsearch.yml` — Grafana Elasticsearch datasources using the Compose `elasticsearch` service
- `phase4b-grafana/scripts/import-dashboards.sh` — API-based dashboard import helper
- `phase4b-grafana/scripts/verify-grafana.sh` — Grafana health/provisioning checker

## Notes

- The phase4a Docker Compose stack mounts `phase4b-grafana/provisioning/` into Grafana.
- Grafana is bound to `127.0.0.1:3000` by default in Compose.
- Dashboard names and fields assume the Elasticsearch indices produced by phases 3b, 4a, and 4c.

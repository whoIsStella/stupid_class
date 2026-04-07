# Phase 4b — Grafana Dashboards

Phase 4b provides the Grafana dashboard definitions for the hive. The JSON files in this phase visualize activity across the web, SSH, IDS, geographic, and enrichment surfaces.

## What lives here

- `phase4b-grafana/provisioning/dashboards/master-overview.json` — top-level cross-surface dashboard
- `phase4b-grafana/provisioning/dashboards/attack-overview.json` — high-level attack summary views
- `phase4b-grafana/provisioning/dashboards/web-hive.json` — Flask web hive activity
- `phase4b-grafana/provisioning/dashboards/ssh-cowrie.json` — Cowrie SSH/Telnet activity
- `phase4b-grafana/provisioning/dashboards/ids-alerts.json` — Suricata alert views
- `phase4b-grafana/provisioning/dashboards/geographic.json` — GeoIP-based attacker views
- `phase4b-grafana/provisioning/dashboards/ip-enrichment.json` — enriched attacker IP views from phase 4c

## Notes

- These files are dashboard definitions only; the repo currently does not include Grafana service or import helper scripts in this directory.
- The dashboards are intended to be provisioned into Grafana or imported manually after the analysis stack is running.
- Dashboard names and fields assume the Elasticsearch indices produced by phases 3b, 4a, and 4c.
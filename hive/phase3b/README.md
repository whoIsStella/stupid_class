# Phase 3b — Log Shipping

Phase 3b provides the transport layer from the VPS to the local machine. It uses Filebeat on the VPS to ship hive JSON logs over WireGuard to Logstash, which then routes events into the correct Elasticsearch indices.

## What lives here

- `filebeat/filebeat.yml` — Filebeat inputs for `web.json`, `cowrie.json`, and `eve.json`, with `log_source` tagging
- `filebeat/install-filebeat.sh` — VPS installer for Filebeat, its config, and the systemd override
- `logstash/hive-input.conf` — analysis-side Beats input and index routing for hive events
- `systemd/filebeat-override.conf` — Filebeat drop-in that waits for `wg0` before starting

## Notes

- `hive/scripts/deploy-to-vps.sh` syncs this phase into `/opt/hive/phase3b/` on the VPS.
- The default transport path is WireGuard `10.0.0.1 -> 10.0.0.2`, with Logstash listening on port `5044` on the tunnel address.
- In this repo snapshot, phase 3b contains the JSON log shipping pieces: Filebeat config, one Logstash pipeline, and a Filebeat startup override.
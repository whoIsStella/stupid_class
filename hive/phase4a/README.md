# Phase 4a — ELK Stack Pipelines

Phase 4a provides analysis-side Logstash pipeline fragments for the hive. These configs normalize incoming events, add GeoIP data, and write each surface into its own Elasticsearch index.

## What lives here

- `phase4a-elk/logstash/pipeline/00-input.conf` — shared Beats input on port `5044`
- `phase4a-elk/logstash/pipeline/web-hive.conf` — web hive parsing, GeoIP enrichment, and output to `hive-web-*`
- `phase4a-elk/logstash/pipeline/cowrie.conf` — Cowrie parsing, field normalization, and output to `hive-cowrie-*`
- `phase4a-elk/logstash/pipeline/suricata.conf` — Suricata parsing, GeoIP enrichment, and output to `hive-suricata-*`
- `phase4a-elk/logstash/pipeline/pcap-meta.conf` — optional PCAP metadata indexing to `hive-pcap-*`

## Notes

- These pipeline files expect Elasticsearch on `localhost:9200`.
- The shared input is written for local/dev use by default; its header comment notes the host change needed for production WireGuard-only binding.
- In this repo snapshot, phase 4a contains Logstash pipeline pieces for the ELK stack rather than a full Docker or Compose setup.
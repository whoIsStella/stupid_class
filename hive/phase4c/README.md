# Phase 4c — IP Enrichment

Phase 4c enriches attacker IPs already captured by the hive. It queries unique IPs from the hive Elasticsearch indices, looks them up against AbuseIPDB, Shodan, and ipinfo ASN data, caches the results in SQLite, and writes enriched documents back into Elasticsearch.

## What lives here

- `phase4c-enrichment/enricher.py` — main enrichment job
- `phase4c-enrichment/config.py` — API key, Elasticsearch, index, cache, and rate-limit settings
- `phase4c-enrichment/cache.py` — SQLite cache for previously enriched IPs
- `phase4c-enrichment/sources/` — provider-specific lookup clients
- `phase4c-enrichment/scripts/test-enrichment.sh` — smoke test for Elasticsearch and external APIs
- `phase4c-enrichment/scripts/install-enricher-timer.sh` — installs recurring `hive-enricher.timer` on the analysis host
- `phase4c-enrichment/requirements.txt` — Python dependencies for the enrichment job

## Notes

- The job reads from `hive-web-*`, `hive-cowrie-*`, and `hive-suricata-*`, then writes to `hive-enriched-YYYY.MM.dd`.
- `ABUSEIPDB_API_KEY` and `SHODAN_API_KEY` are required; Elasticsearch defaults to `localhost:9200`.
- Cached results live at `/var/lib/hive/enrichment_cache.db` unless `HIVE_CACHE_DB` overrides the path.
- `HIVE_CACHE_TTL_HOURS` controls provider-response cache TTL; default `24`.
- `HIVE_ENRICHMENT_REFRESH_HOURS` controls how recently enriched IPs are skipped before refresh; default matches cache TTL.
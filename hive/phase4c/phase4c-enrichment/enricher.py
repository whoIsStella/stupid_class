#!/usr/bin/env python3
"""
enricher.py — query unique attacker IPs from hive-* indices and enrich them
via AbuseIPDB, Shodan, and ipinfo.io ASN lookup. Results are written to
hive-enriched-YYYY.MM.dd and cached in SQLite to preserve API quota.

Usage:
    python enricher.py

Environment:
    ABUSEIPDB_API_KEY  — required
    SHODAN_API_KEY     — required
    ES_HOST            — default: localhost
    ES_PORT            — default: 9200
    HIVE_CACHE_DB      — default: /var/lib/hive/enrichment_cache.db
"""

import sys
import time
import logging
from datetime import datetime, timezone

from elasticsearch import Elasticsearch, exceptions as es_exceptions

import config
import cache
from sources import abuseipdb, shodan_lookup, asn_lookup

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [enricher] %(levelname)s %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%SZ",
)
log = logging.getLogger(__name__)


def get_es_client() -> Elasticsearch:
    es = Elasticsearch(f"http://{config.ES_HOST}:{config.ES_PORT}")
    try:
        if not es.ping():
            raise ConnectionError(f"Elasticsearch at {config.ES_HOST}:{config.ES_PORT} did not respond")
    except es_exceptions.ConnectionError as e:
        raise ConnectionError(f"Cannot connect to Elasticsearch: {e}") from e
    return es


def collect_unique_ips(es: Elasticsearch) -> dict[str, dict]:
    """
    Gather all unique source IPs from hive-web-*, hive-cowrie-*, hive-suricata-*.
    Returns: {ip: {"total": N, "surfaces": [...], "first_seen": ..., "last_seen": ...}}
    """
    ip_data: dict[str, dict] = {}

    for index_pattern, ip_field in config.SOURCE_IP_FIELDS.items():
        surface = index_pattern.replace("hive-", "").replace("-*", "")
        log.info("Collecting IPs from %s (field: %s)", index_pattern, ip_field)

        resp = es.search(
            index=index_pattern,
            body={
                "size": 0,
                "aggs": {
                    "unique_ips": {
                        "terms": {"field": ip_field, "size": 10000},
                        "aggs": {
                            "first_seen": {"min": {"field": "@timestamp"}},
                            "last_seen":  {"max": {"field": "@timestamp"}},
                        },
                    }
                },
            },
            ignore_unavailable=True,
        )

        if "aggregations" not in resp:
            log.info("  no data in %s, skipping", index_pattern)
            continue
        buckets = resp["aggregations"]["unique_ips"]["buckets"]
        log.info("  found %d unique IPs in %s", len(buckets), index_pattern)

        for bucket in buckets:
            ip    = bucket["key"]
            count = bucket["doc_count"]
            first = bucket["first_seen"]["value_as_string"]
            last  = bucket["last_seen"]["value_as_string"]

            if ip not in ip_data:
                ip_data[ip] = {"total": 0, "surfaces": [], "first_seen": first, "last_seen": last}

            ip_data[ip]["total"]    += count
            ip_data[ip]["surfaces"] = list(set(ip_data[ip]["surfaces"] + [surface]))
            if first < ip_data[ip]["first_seen"]:
                ip_data[ip]["first_seen"] = first
            if last  > ip_data[ip]["last_seen"]:
                ip_data[ip]["last_seen"]  = last

    return ip_data


def already_enriched_ips(es: Elasticsearch) -> set[str]:
    """Return the set of IPs that already have a record in hive-enriched-*."""
    try:
        resp = es.search(
            index="hive-enriched-*",
            body={"size": 0, "aggs": {"ips": {"terms": {"field": "ip", "size": 100000}}}},
            ignore_unavailable=True,
        )
        if "aggregations" not in resp:
            return set()
        return {b["key"] for b in resp["aggregations"]["ips"]["buckets"]}
    except es_exceptions.NotFoundError:
        return set()


def enrich_ip(ip: str) -> dict:
    """
    Query all three enrichment sources for the given IP.
    Uses cache; falls back to live API calls on cache miss.
    Returns the enrichment sub-dict (abuseipdb, shodan, asn).
    """
    cached = cache.get_cached(ip)
    if cached is not None:
        return cached

    result: dict = {}

    # AbuseIPDB
    try:
        result["abuseipdb"] = abuseipdb.check_ip(ip)
        time.sleep(config.ABUSEIPDB_SLEEP)
    except EnvironmentError:
        raise
    except Exception as e:
        log.warning("AbuseIPDB query failed for %s: %s", ip, e)
        result["abuseipdb"] = {}

    # Shodan
    try:
        result["shodan"] = shodan_lookup.lookup_ip(ip)
        time.sleep(config.SHODAN_SLEEP)
    except EnvironmentError:
        raise
    except Exception as e:
        log.warning("Shodan query failed for %s: %s", ip, e)
        result["shodan"] = {}

    # ASN (ipinfo.io — no key needed, errors silently)
    result["asn"] = asn_lookup.lookup_asn(ip)

    cache.set_cached(ip, result)
    return result


def write_enriched_record(es: Elasticsearch, ip: str, enrichment: dict, hit_data: dict) -> None:
    today = datetime.now(timezone.utc).strftime("%Y.%m.%d")
    doc = {
        "@timestamp":    datetime.now(timezone.utc).isoformat(),
        "ip":            ip,
        "abuseipdb":     enrichment.get("abuseipdb", {}),
        "shodan":        enrichment.get("shodan", {}),
        "asn":           enrichment.get("asn", {}),
        "honeypot_hits": {
            "total":      hit_data["total"],
            "surfaces":   hit_data["surfaces"],
            "first_seen": hit_data["first_seen"],
            "last_seen":  hit_data["last_seen"],
        },
    }
    es.index(index=f"{config.ENRICHED_INDEX}-{today}", document=doc)


def main() -> None:
    # Validate API keys before doing any work
    if not config.ABUSEIPDB_API_KEY:
        log.error("ABUSEIPDB_API_KEY is not set — exiting")
        sys.exit(1)
    if not config.SHODAN_API_KEY:
        log.error("SHODAN_API_KEY is not set — exiting")
        sys.exit(1)

    log.info("Starting enrichment run")
    cache.init_db()

    try:
        es = get_es_client()
    except ConnectionError as e:
        log.error("%s", e)
        sys.exit(1)

    all_ips     = collect_unique_ips(es)
    enriched    = already_enriched_ips(es)
    new_ips     = {ip: data for ip, data in all_ips.items() if ip not in enriched}

    log.info(
        "Total unique IPs: %d  |  Already enriched: %d  |  To process: %d",
        len(all_ips), len(enriched), len(new_ips),
    )

    if not new_ips:
        log.info("Nothing to enrich.")
        return

    n_cached  = 0
    n_fresh   = 0
    n_failed  = 0

    for ip, hit_data in new_ips.items():
        was_cached = cache.get_cached(ip) is not None
        try:
            enrichment = enrich_ip(ip)
            write_enriched_record(es, ip, enrichment, hit_data)
            if was_cached:
                n_cached += 1
            else:
                n_fresh += 1
            log.info(
                "enriched %s  abuse=%s  shodan_tags=%s  asn=%s",
                ip,
                enrichment.get("abuseipdb", {}).get("abuse_confidence_score", "?"),
                enrichment.get("shodan", {}).get("tags", []),
                enrichment.get("asn", {}).get("asn", "?"),
            )
        except EnvironmentError as e:
            log.error("API key error: %s — aborting", e)
            sys.exit(1)
        except Exception as e:
            log.warning("Failed to enrich %s: %s — skipping", ip, e)
            n_failed += 1

    log.info(
        "Run complete. fresh=%d  from_cache=%d  failed=%d",
        n_fresh, n_cached, n_failed,
    )


if __name__ == "__main__":
    main()

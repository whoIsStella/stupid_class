# Phase 4c Sources — Provider Clients

This directory contains the provider-specific lookup modules used by the phase 4c enrichment job. Each module wraps one external source and returns a normalized Python dictionary for `enricher.py`.

## What lives here

- `abuseipdb.py` — AbuseIPDB lookups for abuse score, report count, categories, ISP, and usage type
- `shodan_lookup.py` — Shodan lookups for ports, tags, OS, hostnames, and last-seen data
- `asn_lookup.py` — ipinfo-based ASN, organization, country, and city lookup
- `__init__.py` — package marker for importing the source modules

## Notes

- The parent `config.py` file provides API keys and rate-limit settings used by callers.
- `abuseipdb.py` and `shodan_lookup.py` require their respective API keys to be present in the environment.
- `asn_lookup.py` is treated as supplementary data: lookup failures return empty fields instead of stopping the enrichment run.
import os

# API keys — set as environment variables, never hardcode
ABUSEIPDB_API_KEY = os.environ.get("ABUSEIPDB_API_KEY")
SHODAN_API_KEY    = os.environ.get("SHODAN_API_KEY")

# Elasticsearch connection
ES_HOST = os.environ.get("ES_HOST", "localhost")
ES_PORT = int(os.environ.get("ES_PORT", 9200))

# Source indices and their IP field names
SOURCE_INDICES = ["hive-web-*", "hive-cowrie-*", "hive-suricata-*"]
SOURCE_IP_FIELDS = {
    "hive-web-*":      "remote_ip",
    "hive-cowrie-*":   "src_ip",
    "hive-suricata-*": "src_ip",
}

# Output index (date suffix appended by enricher)
ENRICHED_INDEX = "hive-enriched"

# SQLite cache
CACHE_DB_PATH   = os.environ.get("HIVE_CACHE_DB", "/var/lib/hive/enrichment_cache.db")
CACHE_TTL_HOURS = 24

# Rate limiting (seconds between requests per API)
ABUSEIPDB_SLEEP = 0.1
SHODAN_SLEEP    = 1.0

"""
abuseipdb.py — AbuseIPDB API client.

Free tier: 1,000 checks/day. Caller is responsible for rate limiting.
API key must be set in the ABUSEIPDB_API_KEY environment variable.
"""

import requests
from config import ABUSEIPDB_API_KEY

BASE_URL = "https://api.abuseipdb.com/api/v2/check"


def check_ip(ip: str) -> dict:
    """
    Query AbuseIPDB for the given IP address.

    Returns a dict with abuse_confidence_score, total_reports, etc.
    Raises EnvironmentError if API key is not set.
    Raises requests.HTTPError on non-2xx responses.
    """
    if not ABUSEIPDB_API_KEY:
        raise EnvironmentError("ABUSEIPDB_API_KEY is not set")

    resp = requests.get(
        BASE_URL,
        headers={"Key": ABUSEIPDB_API_KEY, "Accept": "application/json"},
        params={"ipAddress": ip, "maxAgeInDays": 90, "verbose": True},
        timeout=10,
    )
    resp.raise_for_status()
    data = resp.json()["data"]

    # Extract categories from the most recent report if available
    reports = data.get("reports") or []
    categories = reports[0].get("categories", []) if reports else []

    return {
        "abuse_confidence_score": data["abuseConfidenceScore"],
        "total_reports":          data["totalReports"],
        "last_reported_at":       data.get("lastReportedAt"),
        "categories":             categories,
        "is_tor":                 data.get("isTor", False),
        "isp":                    data.get("isp"),
        "usage_type":             data.get("usageType"),
    }

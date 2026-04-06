"""
shodan_lookup.py — Shodan API client.

Free tier is slow and rate-limited; caller sleeps 1s between requests.
Many IPs are simply not in Shodan's index — that is normal, not an error.
API key must be set in the SHODAN_API_KEY environment variable.
"""

import shodan
from config import SHODAN_API_KEY


def lookup_ip(ip: str) -> dict:
    """
    Query Shodan for the given IP address.

    Returns a dict with open_ports, tags, os, hostnames, last_update.
    Returns an empty result (not an error) if the IP is not in Shodan's index.
    Raises EnvironmentError if API key is not set.
    """
    if not SHODAN_API_KEY:
        raise EnvironmentError("SHODAN_API_KEY is not set")

    api = shodan.Shodan(SHODAN_API_KEY)
    try:
        host = api.host(ip)
        return {
            "open_ports":  host.get("ports", []),
            "tags":        host.get("tags", []),
            "os":          host.get("os"),
            "hostnames":   host.get("hostnames", []),
            "last_update": host.get("last_update"),
        }
    except shodan.APIError:
        # IP not indexed in Shodan — return empty, not an error
        return {
            "open_ports":  [],
            "tags":        [],
            "os":          None,
            "hostnames":   [],
            "last_update": None,
        }

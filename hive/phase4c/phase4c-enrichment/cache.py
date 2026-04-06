"""
cache.py — SQLite-based cache for IP enrichment results.

Avoids re-querying APIs for IPs seen in a previous run within the TTL window.
Cache lives at CACHE_DB_PATH (default: /var/lib/hive/enrichment_cache.db).
"""

import sqlite3
import json
import os
from datetime import datetime, timedelta, timezone

from config import CACHE_DB_PATH, CACHE_TTL_HOURS


def _connect() -> sqlite3.Connection:
    os.makedirs(os.path.dirname(CACHE_DB_PATH), exist_ok=True)
    conn = sqlite3.connect(CACHE_DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    """Create the cache table if it doesn't already exist."""
    with _connect() as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS enrichment_cache (
                ip          TEXT PRIMARY KEY,
                data        TEXT NOT NULL,
                cached_at   TEXT NOT NULL
            )
        """)


def get_cached(ip: str) -> dict | None:
    """Return cached enrichment data if it's within TTL, else None."""
    with _connect() as conn:
        row = conn.execute(
            "SELECT data, cached_at FROM enrichment_cache WHERE ip = ?", (ip,)
        ).fetchone()
    if row is None:
        return None
    cached_at = datetime.fromisoformat(row["cached_at"])
    if datetime.now(timezone.utc) - cached_at > timedelta(hours=CACHE_TTL_HOURS):
        return None
    return json.loads(row["data"])


def set_cached(ip: str, data: dict) -> None:
    """Write enrichment result to cache with the current UTC timestamp."""
    now = datetime.now(timezone.utc).isoformat()
    with _connect() as conn:
        conn.execute(
            """
            INSERT INTO enrichment_cache (ip, data, cached_at)
            VALUES (?, ?, ?)
            ON CONFLICT(ip) DO UPDATE SET data = excluded.data, cached_at = excluded.cached_at
            """,
            (ip, json.dumps(data), now),
        )

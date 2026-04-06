import json
import os
from datetime import datetime, timezone

from flask import request

LOG_PATH = os.environ.get("HIVE_LOG", "/var/log/hive/web.json")


def _ensure_log_dir():
    try:
        os.makedirs(os.path.dirname(LOG_PATH), exist_ok=True)
    except OSError:
        pass


def log_hit(response_code):
    try:
        _ensure_log_dir()

        # Exclude headers that Flask injects internally and keep only the
        # ones actually sent by the client.
        skip = {"Host", "Content-Length", "Content-Type"}
        headers = {
            k: v
            for k, v in request.headers.items()
            if k not in skip
        }

        post_body = None
        if request.method in ("POST", "PUT", "PATCH"):
            raw = request.get_data(as_text=True)
            post_body = raw if raw else None

        entry = {
            "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "remote_ip": request.remote_addr,
            "method": request.method,
            "path": request.path,
            "query_string": request.query_string.decode("utf-8", errors="replace"),
            "user_agent": request.headers.get("User-Agent", ""),
            "referer": request.headers.get("Referer", ""),
            "headers": headers,
            "post_body": post_body,
            "response_code": response_code,
        }

        with open(LOG_PATH, "a", encoding="utf-8") as f:
            f.write(json.dumps(entry) + "\n")

    except Exception:
        # Never let logging crash the app.
        pass

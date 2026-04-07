#!/usr/bin/env bash
# deploy-secrets.sh — create /etc/hive/secrets.env from a filled-in template
# Usage: sudo bash hive/scripts/deploy-secrets.sh [path/to/secrets.env]
# If no argument is given, prompts for each value interactively.
set -euo pipefail

DEST="/etc/hive/secrets.env"

if [ "$(id -u)" -ne 0 ]; then
    echo "error: must run as root (sudo)" >&2
    exit 1
fi

mkdir -p /etc/hive
chmod 700 /etc/hive

if [ "${1:-}" != "" ]; then
    # Deploy from a pre-filled file
    SRC="$1"
    if [ ! -f "$SRC" ]; then
        echo "error: file not found: $SRC" >&2
        exit 1
    fi
    install -m 600 -o root "$SRC" "$DEST"
    echo "Deployed $SRC → $DEST (mode 600)"
else
    # Interactive — prompt for each value
    read -rsp "GRAFANA_ADMIN_PASSWORD: " GRAFANA_ADMIN_PASSWORD; echo
    read -rsp "ABUSEIPDB_API_KEY: "      ABUSEIPDB_API_KEY;      echo
    read -rsp "SHODAN_API_KEY: "         SHODAN_API_KEY;          echo

    install -m 600 -o root /dev/null "$DEST"
    cat > "$DEST" <<EOF
GRAFANA_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
ABUSEIPDB_API_KEY=${ABUSEIPDB_API_KEY}
SHODAN_API_KEY=${SHODAN_API_KEY}
EOF
    chmod 600 "$DEST"
    echo "Created $DEST (mode 600)"
fi

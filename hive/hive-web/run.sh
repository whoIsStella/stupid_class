#!/usr/bin/env bash
# run.sh — start hive-web Flask app
# Defaults suit local dev; systemd overrides HIVE_PORT and HIVE_LOG for production.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -d ".venv" ]; then
    echo "error: .venv not found — run ./setup.sh first" >&2
    exit 1
fi

if [ ! -d "fake_responses" ]; then
    echo "error: fake_responses/ not found — run ./setup.sh first" >&2
    exit 1
fi

export HIVE_PORT="${HIVE_PORT:-5000}"
export HIVE_LOG="${HIVE_LOG:-$SCRIPT_DIR/logs/web.json}"

mkdir -p "$(dirname "$HIVE_LOG")"

source .venv/bin/activate
exec gunicorn \
    --bind "0.0.0.0:${HIVE_PORT}" \
    --workers 2 \
    --access-logfile /dev/null \
    --error-logfile /dev/null \
    "app:app"

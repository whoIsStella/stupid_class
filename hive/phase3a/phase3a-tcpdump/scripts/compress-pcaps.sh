#!/usr/bin/env bash
# compress-pcaps.sh — compress completed PCAPs with zstd, clean up old files
# Run nightly via cron:
#   0 2 * * * /opt/hive/scripts/compress-pcaps.sh >> /var/log/hive/pcap-compress.log 2>&1
set -euo pipefail

PCAP_DIR="/var/log/hive/pcap"
LOCK="/var/run/compress-pcaps.lock"

# Prevent overlapping runs
if [ -f "$LOCK" ]; then
    echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') lock file exists — another run in progress, exiting"
    exit 0
fi
touch "$LOCK"
trap "rm -f '$LOCK'" EXIT

if [ ! -d "$PCAP_DIR" ]; then
    echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') PCAP dir $PCAP_DIR not found — nothing to compress"
    exit 0
fi

shopt -s nullglob
for pcap in "$PCAP_DIR"/*.pcap; do
    [ -f "${pcap}.done" ] || continue   # skip: not yet marked complete
    [ -f "${pcap}.zst"  ] && continue   # skip: already compressed

    if zstd -q --rm "$pcap" -o "${pcap}.zst"; then
        rm -f "${pcap}.done"
        echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') compressed: $(basename "${pcap}.zst")"
    else
        echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') FAILED: $(basename "$pcap")"
    fi
done

# Disk safety: delete compressed files older than 30 days
find "$PCAP_DIR" -name "*.pcap.zst" -mtime +30 -delete

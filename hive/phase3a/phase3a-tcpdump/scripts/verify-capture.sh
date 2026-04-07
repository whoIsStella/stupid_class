#!/usr/bin/env bash
# verify-capture.sh — confirm tcpdump is running and PCAPs are appearing
set -euo pipefail

PCAP_DIR="/var/log/hive/pcap"

echo "=== tcpdump process ==="
pgrep -a tcpdump || echo "WARNING: tcpdump not running"

echo ""
echo "=== Current capture file ==="
ls -lh "$PCAP_DIR"/*.pcap 2>/dev/null | tail -3 || echo "No .pcap files found"

echo ""
echo "=== Compressed files ==="
ls -lh "$PCAP_DIR"/*.pcap.zst 2>/dev/null | tail -5 || echo "No .pcap.zst files found"

echo ""
echo "=== Disk usage ==="
du -sh "$PCAP_DIR" 2>/dev/null || echo "$PCAP_DIR does not exist"

echo ""
echo "=== Packet count in current file ==="
CURRENT=$(ls -t "$PCAP_DIR"/*.pcap 2>/dev/null | head -1)
if [ -n "$CURRENT" ]; then
    tcpdump -r "$CURRENT" --count 2>/dev/null || echo "Could not read $CURRENT"
else
    echo "No current capture file found"
fi

#!/usr/bin/env bash
# start-capture.sh — continuous tcpdump capture for the Hive PCAP surface
#
# Runs as the ExecStart for pcap-capture.service.
# Rotates every ROTATE_MINUTES minutes, keeping MAX_FILES files.
# Writes to /var/log/hive/pcap/ — directory must exist (service prereq).
#
set -euo pipefail

IFACE="${HIVE_IFACE:-$(ip -o route show default | awk '{print $5; exit}')}"
if [ -z "$IFACE" ]; then
    echo "start-capture.sh: could not determine capture interface (set HIVE_IFACE)" >&2
    exit 1
fi
OUTDIR="/var/log/hive/pcap"
ROTATE_MINUTES="${HIVE_PCAP_ROTATE:-60}"   # rotate every N minutes
MAX_FILES="${HIVE_PCAP_MAX_FILES:-168}"    # keep 7 days at 1-hour rotation
SNAPLEN=96                                  # capture first 96 bytes (headers only, no payload)

mkdir -p "$OUTDIR"

exec tcpdump \
    -i "$IFACE" \
    -s "$SNAPLEN" \
    -n \
    -G "$(( ROTATE_MINUTES * 60 ))" \
    -W "$MAX_FILES" \
    -w "${OUTDIR}/hive-%Y%m%dT%H%M%S.pcap" \
    -z /opt/hive/scripts/on-rotate.sh \
    'not src host 10.77.0.2 and not dst host 10.77.0.2'

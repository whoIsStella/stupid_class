# Phase 3a — tcpdump PCAP Capture

Phase 3a provides packet capture for the hive. It runs a host-side `tcpdump` service, rotates compressed PCAP files under `/var/log/hive/pcap/`, and keeps raw network evidence for later analysis.

## What lives here

- `phase3a-tcpdump/scripts/start-capture.sh` — `tcpdump` wrapper with interface, rotation, retention, and capture-filter settings
- `phase3a-tcpdump/systemd/pcap-capture.service` — systemd unit that runs the capture service on the VPS

## Notes

- `hive/scripts/deploy-to-vps.sh` copies `start-capture.sh` to `/opt/hive/scripts/` and installs the service unit into `/etc/systemd/system/`.
- By default, capture runs on `eth0`, rotates hourly, keeps 168 files, and stores gzip-compressed PCAPs in `/var/log/hive/pcap/`.
- The script captures only the first 96 bytes of each packet and excludes traffic to the analysis host at `10.0.0.2`.
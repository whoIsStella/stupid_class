# Phase 2c — Suricata IDS

Phase 2c provides host-side network detection for the hive. It runs Suricata on the VPS host in passive AF_PACKET mode on `eth0`, watches the exposed hive services, and writes IDS events to `/var/log/hive/eve.json` with operational logs in `/var/log/hive/suricata.log`.

## What lives here

- `suricata/suricata.yaml` — main Suricata configuration for host monitoring, outputs, and protocol detection
- `suricata/rules/local.rules` — hive-specific detection rules for scanners, bait paths, brute force, Telnet, and port scans
- `suricata/systemd/suricata-override.conf` — systemd drop-in for startup ordering and file descriptor limits

## Notes

- This phase runs on the VPS host directly, not inside a microVM.
- Replace `YOUR_VPS_PUBLIC_IP` in `suricata.yaml` before deployment so `HOME_NET` matches the actual public IP.
- `hive/scripts/deploy-to-vps.sh` substitutes the public IP inline, syncs `local.rules`, and installs the systemd override.
- The config is passive IDS only: it inspects traffic and alerts, but does not drop packets.
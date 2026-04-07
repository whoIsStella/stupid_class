# Phase 2a — Cowrie SSH Hive

Phase 2a provides the SSH/Telnet deception layer for the hive. It runs Cowrie inside the phase 2a VM, presents a bank-themed Linux host, and records authentication attempts plus post-login activity under `/var/log/hive/`.

## What lives here

- `cowrie/cowrie.cfg` — Cowrie overrides for ports, SSH banner, log paths, and session capture
- `cowrie/userdb.txt` — fake credentials that allow attackers into the shell
- `cowrie/honeyfs/` — fake filesystem content used by the shell persona
- `cowrie/txtcmds/` — canned command output for common utilities
- `cowrie/systemd/cowrie.service` — service unit used on the VPS

## Notes

- Cowrie listens on `2222` (SSH) and `2323` (Telnet) inside the VM; the host forwards public `22/23` traffic into it.
- This directory is configuration only, not a full Cowrie source checkout.
- `hive/scripts/deploy-to-vps.sh` syncs these files into `/opt/cowrie/...`; first-time Cowrie installation still happens on the VPS before enabling `cowrie.service`.
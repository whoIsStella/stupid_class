# Hive Scripts

This directory contains small deployment helpers for the hive. They handle VPS-side file sync and secrets installation without changing the source tree itself.

## What lives here

- `deploy-to-vps.sh` — rsync-based deploy script for hive configs, service units, and supporting files
- `deploy-secrets.sh` — installs `/etc/hive/secrets.env` from a filled template or interactive prompts

## Notes

- `deploy-to-vps.sh` assumes SSH key access to the VPS and syncs files into locations such as `/opt/hive/`, `/opt/cowrie/`, `/etc/suricata/`, and `/etc/systemd/system/`.
- `deploy-secrets.sh` must run as root and writes `/etc/hive/secrets.env` with mode `600`.
- These scripts are deployment utilities only; they do not build or package the hive components themselves.
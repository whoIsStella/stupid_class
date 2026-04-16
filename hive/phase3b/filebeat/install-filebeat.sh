#!/usr/bin/env bash
# install-filebeat.sh — install and configure Filebeat on the VPS
#
# Run as root on the VPS (10.77.0.1).
# Prerequisites:
#   - WireGuard tunnel up (wg0): 10.77.0.1 → 10.77.0.2
#   - Logstash listening on 10.77.0.2:5044
#
# Usage:  sudo bash install-filebeat.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_PHASE3B="$(dirname "$SCRIPT_DIR")"   # phase3b/

echo "[install-filebeat] Installing Filebeat 8.x from Elastic APT repo..."

if ! apt-get -qq list --installed 2>/dev/null | grep -q filebeat; then
    wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch \
        | gpg --dearmor > /usr/share/keyrings/elastic-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/elastic-keyring.gpg] \
https://artifacts.elastic.co/packages/8.x/apt stable main" \
        > /etc/apt/sources.list.d/elastic-8.x.list
    apt-get update -qq
    apt-get install -y -qq filebeat
    echo "[install-filebeat] Filebeat installed."
else
    echo "[install-filebeat] Filebeat already installed, skipping apt."
fi

echo "[install-filebeat] Deploying filebeat.yml..."
cp "${SCRIPT_DIR}/filebeat.yml" /etc/filebeat/filebeat.yml
chmod 600 /etc/filebeat/filebeat.yml

echo "[install-filebeat] Deploying systemd drop-in override..."
mkdir -p /etc/systemd/system/filebeat.service.d/
cp "${REPO_PHASE3B}/systemd/filebeat-override.conf" \
    /etc/systemd/system/filebeat.service.d/override.conf

echo "[install-filebeat] Ensuring log directories exist..."
mkdir -p /var/log/hive/pcap /var/log/hive/filebeat

echo "[install-filebeat] Enabling and starting Filebeat..."
systemctl daemon-reload
systemctl enable filebeat
systemctl restart filebeat

echo "[install-filebeat] Done. Checking status..."
systemctl status filebeat --no-pager -l

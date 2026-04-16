#!/usr/bin/env bash
# deploy-to-vps.sh — push all VPS-side hive phases to the VPS via rsync over SSH
#
# Usage:
#   bash hive/scripts/deploy-to-vps.sh [--dry-run]
#
# Prerequisites:
#   - SSH key auth to VPS (root or sudo user with NOPASSWD)
#   - rsync installed locally
#
# Environment overrides:
#   VPS_USER  (default: root)
#   VPS_IP    (default: 70.34.215.229)
#   SSH_KEY   (default: ~/.ssh/id_ed25519)

set -euo pipefail

VPS_USER="${VPS_USER:-root}"
VPS_IP="${VPS_IP:-70.34.215.229}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"
HIVE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # .../hive/

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then DRY_RUN=1; fi

VPS="$VPS_USER@$VPS_IP"
SSH_OPTS=(-i "$SSH_KEY" -o StrictHostKeyChecking=accept-new -o BatchMode=yes)
RSYNC_OPTS=(-az --delete --exclude='__pycache__' --exclude='*.pyc'
            --exclude='.gitignore' --exclude='.venv' --exclude='logs'
            -e "ssh ${SSH_OPTS[*]}")
if [ "$DRY_RUN" -eq 1 ]; then RSYNC_OPTS+=(--dry-run); fi

green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
info()  { printf '  \033[0;34m→\033[0m %s\n' "$*"; }

echo ""
echo "  deploy-to-vps"
echo "  ─────────────"
info "target:  $VPS"
info "ssh key: $SSH_KEY"
[ "$DRY_RUN" -eq 1 ] && info "mode:    DRY RUN (no changes)"
echo ""

info "checking SSH..."
if ! ssh "${SSH_OPTS[@]}" "$VPS" "true" 2>/dev/null; then
    echo ""
    echo "  ERROR: cannot reach $VPS"
    echo "  Make sure your SSH key is in ~/.ssh/authorized_keys on the VPS."
    echo "  To copy it:  ssh-copy-id -i $SSH_KEY $VPS"
    exit 1
fi
green "  SSH OK"
echo ""

info "creating remote directories, user, and cowrie source tree..."
ssh "${SSH_OPTS[@]}" "$VPS" bash <<'REMOTE'
set -e
mkdir -p \
    /opt/hive/hive-web \
    /opt/hive/scripts \
    /opt/hive/phase3b \
    /var/log/hive/dl \
    /var/log/hive/tty \
    /var/log/hive/pcap \
    /etc/suricata/rules \
    /etc/systemd/system

if ! id cowrie >/dev/null 2>&1; then
    useradd --system --home-dir /opt/cowrie --shell /usr/sbin/nologin cowrie
fi

# Only config files are shipped below; the upstream source tree has to be cloned.
if [ ! -d /opt/cowrie/.git ]; then
    apt-get update -qq
    apt-get install -y -qq git python3-venv python3-dev build-essential libssl-dev libffi-dev
    git clone https://github.com/cowrie/cowrie.git /opt/cowrie
fi
chown -R cowrie:cowrie /opt/cowrie /var/log/hive/dl /var/log/hive/tty

if [ ! -x /opt/cowrie/cowrie-env/bin/cowrie ]; then
    sudo -u cowrie python3 -m venv /opt/cowrie/cowrie-env
    sudo -u cowrie /opt/cowrie/cowrie-env/bin/pip install --quiet --upgrade pip
    sudo -u cowrie /opt/cowrie/cowrie-env/bin/pip install --quiet -e /opt/cowrie
fi
REMOTE

info "phase2a: cowrie config → /opt/cowrie/..."
rsync "${RSYNC_OPTS[@]}" \
    "$HIVE/phase2a/cowrie/cowrie.cfg" \
    "$HIVE/phase2a/cowrie/userdb.txt" \
    "$VPS:/opt/cowrie/etc/"

rsync "${RSYNC_OPTS[@]}" \
    "$HIVE/phase2a/cowrie/honeyfs/" "$VPS:/opt/cowrie/honeyfs/"

rsync "${RSYNC_OPTS[@]}" \
    "$HIVE/phase2a/cowrie/txtcmds/" "$VPS:/opt/cowrie/txtcmds/"

info "phase2b: hive-web → /opt/hive/hive-web/..."
rsync "${RSYNC_OPTS[@]}" \
    "$HIVE/phase2b/hive-web/" "$VPS:/opt/hive/hive-web/"

# run.sh and setup.sh live in the top-level hive-web/ (phase2b doesn't include them)
rsync "${RSYNC_OPTS[@]}" \
    "$HIVE/hive-web/run.sh" \
    "$HIVE/hive-web/setup.sh" \
    "$VPS:/opt/hive/hive-web/"

info "phase2c: suricata config → /etc/suricata/..."
# Substitute placeholder IP inline; never touches the repo copy
ssh "${SSH_OPTS[@]}" "$VPS" "cat > /etc/suricata/suricata.yaml" < \
    <(sed "s/YOUR_VPS_PUBLIC_IP/$VPS_IP/" "$HIVE/phase2c/suricata/suricata.yaml")

rsync "${RSYNC_OPTS[@]}" \
    "$HIVE/phase2c/suricata/rules/" "$VPS:/etc/suricata/rules/"

ssh "${SSH_OPTS[@]}" "$VPS" \
    "mkdir -p /etc/systemd/system/suricata.service.d"
rsync "${RSYNC_OPTS[@]}" \
    "$HIVE/phase2c/suricata/systemd/suricata-override.conf" \
    "$VPS:/etc/systemd/system/suricata.service.d/override.conf"

info "phase3a: tcpdump capture scripts → /opt/hive/scripts/..."
rsync "${RSYNC_OPTS[@]}" \
    "$HIVE/phase3a/phase3a-tcpdump/scripts/start-capture.sh" \
    "$HIVE/phase3a/phase3a-tcpdump/scripts/compress-pcaps.sh" \
    "$HIVE/phase3a/phase3a-tcpdump/scripts/on-rotate.sh" \
    "$VPS:/opt/hive/scripts/"

info "phase3b: filebeat config → /opt/hive/phase3b/..."
rsync "${RSYNC_OPTS[@]}" \
    "$HIVE/phase3b/" "$VPS:/opt/hive/phase3b/"

info "systemd: deploying service units..."
rsync "${RSYNC_OPTS[@]}" \
    "$HIVE/phase2a/cowrie/systemd/cowrie.service" \
    "$HIVE/phase2b/hive-web/hive-web.service" \
    "$HIVE/phase3a/phase3a-tcpdump/systemd/pcap-capture.service" \
    "$VPS:/etc/systemd/system/"

info "wireguard: setup script → /opt/hive/scripts/..."
rsync "${RSYNC_OPTS[@]}" \
    "$HIVE/phase1/wireguard/setup-wg-vps.sh" \
    "$VPS:/opt/hive/scripts/"

info "fixing permissions..."
ssh "${SSH_OPTS[@]}" "$VPS" bash <<'REMOTE'
chmod +x \
    /opt/hive/hive-web/run.sh \
    /opt/hive/hive-web/setup.sh \
    /opt/hive/scripts/start-capture.sh \
    /opt/hive/scripts/compress-pcaps.sh \
    /opt/hive/scripts/on-rotate.sh \
    /opt/hive/scripts/setup-wg-vps.sh 2>/dev/null || true
chmod 600 /opt/cowrie/etc/cowrie.cfg /opt/cowrie/etc/userdb.txt 2>/dev/null || true

# 22/tcp deliberately omitted: real sshd holds it; moving it is an operator call.
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "^Status: active"; then
    ufw allow 23/tcp    >/dev/null
    ufw allow 80/tcp    >/dev/null
    ufw allow 443/tcp   >/dev/null
    ufw allow 51820/udp >/dev/null
fi

systemctl daemon-reload
REMOTE

echo ""
green "  Deploy complete."
echo ""
echo "  Next steps on the VPS (ssh $VPS):"
echo ""
echo "  1. Run hive-web setup (first time only):"
echo "       bash /opt/hive/hive-web/setup.sh"
echo ""
echo "  2. Set up WireGuard tunnel:"
echo "       bash /opt/hive/scripts/setup-wg-vps.sh"
echo "     Then follow the printed instructions."
echo ""
echo "  3. Start services:"
echo "       systemctl enable --now hive-web cowrie pcap-capture"
echo ""

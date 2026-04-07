# hive — CSC651 Hive Infrastructure

Multi-surface hive for observing real-world attack traffic.
Captures SSH credential attempts, web scanner behavior, IDS alerts,
and full PCAPs. Ships everything to an ELK + Grafana analysis stack.

## Architecture

```
Internet → VPS eth0
             ├── :22  → Cowrie SSH hive  (phase2a, microVM tap1)
             ├── :80  → Flask web hive   (phase2b, microVM tap2)
             ├── :443 → Flask web hive   (phase2b, microVM tap2)
             ├── Suricata IDS on eth0        (phase2c, host)
             └── tcpdump ports 22/80/443     (phase3a, host)
                          │
                    WireGuard tunnel
                          │
               Analysis machine (phase4a/4b/4c)
                  Elasticsearch :9200
                  Logstash       :5044
                  Kibana         :5601
                  Grafana        :3000
```

Phases 1a–1e (VPS provisioning, TAP/iptables, WireGuard, Firecracker microVMs)
are implemented on the VPS. Everything below can be run and tested locally.

---

## Phase 2a — Cowrie SSH Hive

**Location:** `phase2a/cowrie/`

```bash
# Install (VPS or local, requires root)
sudo bash phase2a/cowrie/scripts/install.sh

# Run without systemd (dev)
bash phase2a/cowrie/scripts/run.sh

# Start via systemd (production)
sudo systemctl start cowrie
sudo systemctl status cowrie

# Test — connect to the hive
ssh root@localhost -p 2222
# Try any password — it will accept credentials from userdb.txt

# Watch live sessions
tail -f /var/log/hive/cowrie.json | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        e = json.loads(line)
        print(e.get('eventid','?'), '|', e.get('src_ip',''), '|', e.get('username',''), e.get('password',''))
    except: pass
"
```

---

## Phase 2b — Flask Web Hive (Cascade Community Bank)

**Location:** `phase2b/hive-web/`

```bash
# First-time setup (creates venv, fake_responses/, log dir)
bash phase2b/hive-web/setup.sh

# Run locally on port 5000
bash phase2b/hive-web/run.sh

# Run on a specific port
HIVE_PORT=8080 bash phase2b/hive-web/run.sh

# Test — hit key routes
curl http://localhost:5000/
curl http://localhost:5000/.env
curl http://localhost:5000/wp-admin
curl http://localhost:5000/api/keys
curl http://localhost:5000/phpmyadmin
curl -X POST http://localhost:5000/login -d "username=admin&password=test"

# Test scanner detection (gobuster UA)
curl -A "gobuster/3.1.0" http://localhost:5000/.env

# Watch live logs
tail -f phase2b/hive-web/logs/web.json | python3 -m json.tool

# Start via systemd (production, binds to port 80)
sudo cp phase2b/hive-web/hive-web.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now hive-web
sudo systemctl status hive-web
```

---

## Phase 2c — Suricata IDS

**Location:** `phase2c/suricata/`

```bash
# Before installing: set HOME_NET to the VPS public IP
sed -i 's/YOUR_VPS_PUBLIC_IP/1.2.3.4/' phase2c/suricata/suricata.yaml

# Install (requires root, VPS host only)
sudo bash phase2c/suricata/scripts/install.sh

# Check running
sudo systemctl status suricata

# Validate config syntax (no live traffic needed)
sudo suricata -T -c /etc/suricata/suricata.yaml

# Trigger a test alert (gobuster UA → sid:9000001)
sudo bash phase2c/suricata/scripts/test-alert.sh

# Watch live alerts
tail -f /var/log/hive/eve.json | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        e = json.loads(line)
        if e.get('event_type') == 'alert':
            print(e['alert']['signature'], '|', e.get('src_ip'))
    except: pass
"

# Update ET Open rules (then reload — no restart)
sudo bash phase2c/suricata/scripts/update-rules.sh

# Replay a PCAP offline against the rules
sudo suricata -r /path/to/capture.pcap -c /etc/suricata/suricata.yaml -l /tmp/replay/
```

---

## Phase 3a — tcpdump PCAP Capture

**Location:** `phase3a/phase3a-tcpdump/`

```bash
# Install (requires root, VPS host only)
sudo bash phase3a/phase3a-tcpdump/install.sh

# Check running
sudo systemctl status pcap-capture
bash phase3a/phase3a-tcpdump/scripts/verify-capture.sh

# Add nightly compression cron
echo '0 2 * * * /opt/hive/scripts/compress-pcaps.sh >> /var/log/hive/pcap-compress.log 2>&1' | crontab -

# Test locally (30s rotation on loopback, requires phase2b running on :5000)
sudo tcpdump -i lo -w /tmp/test_%Y%m%d_%H%M%S.pcap -G 30 -C 10 \
  -z /tmp/on-rotate.sh -n "tcp port 5000"
# In another terminal: curl http://localhost:5000/ && curl http://localhost:5000/.env

# Compress manually
sudo bash phase3a/phase3a-tcpdump/scripts/compress-pcaps.sh
```

---

## Phase 3b — Log Shipping (Filebeat + Logstash)

**Location:** `phase3b/`

```bash
# Install Filebeat on the VPS (requires root)
sudo bash phase3b/scripts/install-filebeat.sh

# Check Filebeat is running
sudo systemctl status filebeat
sudo journalctl -u filebeat -n 30

# Deploy Logstash pipeline on the analysis machine
sudo cp phase3b/logstash/hive-input.conf /etc/logstash/conf.d/
sudo systemctl restart logstash

# Test PCAP shipping (WireGuard must be up)
# Dry run — shows what would be shipped without transferring
bash phase3b/scripts/ship-pcaps.sh --dry-run 2>/dev/null || \
  echo "Run: bash phase3b/scripts/ship-pcaps.sh"
```

---

## Phase 4a — ELK Stack

**Location:** `phase4a/phase4a-elk/`

**Prerequisites:** Docker + Docker Compose, minimum 4GB RAM free.

```bash
cd phase4a/phase4a-elk

# Start the stack
docker compose up -d

# Wait ~60s for Elasticsearch, then verify all three services
bash scripts/verify-stack.sh

# Create index templates (MUST run before first ingest)
bash scripts/create-indices.sh

# Inject sample documents to test indexing and mappings
bash scripts/test-ingest.sh

# Open Kibana
xdg-open http://localhost:5601

# View logs
docker compose logs -f elasticsearch
docker compose logs -f logstash

# Stop (preserves data volume)
docker compose down

# Stop and wipe all data
docker compose down -v
```

---

## Phase 4b — Grafana Dashboards

**Location:** `phase4b/phase4b-grafana/`

**Prerequisites:** Phase 4a stack running.

```bash
# Add Grafana to phase4a docker-compose.yml:
#   1. Copy 'grafana' service block from phase4b/phase4b-grafana/docker-compose-addition.yml
#      into phase4a/phase4a-elk/docker-compose.yml
#   2. Copy provisioning directory alongside docker-compose.yml:
cp -r phase4b/phase4b-grafana phase4a/phase4a-elk/phase4b-grafana

#   3. Add 'grafanadb:' to the volumes section, then:
cd phase4a/phase4a-elk
docker compose up -d grafana

# Verify dashboards and data sources loaded
bash ../phase4b/phase4b-grafana/scripts/verify-grafana.sh

# Open Grafana (login: admin / honeypot2025)
xdg-open http://localhost:3000

# Re-import dashboards from JSON files (if needed)
bash ../phase4b/phase4b-grafana/scripts/import-dashboards.sh
```

---

## Phase 4c — IP Enrichment

**Location:** `phase4c/phase4c-enrichment/`

**Prerequisites:** Phase 4a Elasticsearch running, API keys for AbuseIPDB and Shodan.

```bash
cd phase4c/phase4c-enrichment

# First-time setup
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Test each API source against a known safe IP (1.1.1.1)
export ABUSEIPDB_API_KEY="your_key"
export SHODAN_API_KEY="your_key"
bash scripts/test-enrichment.sh

# Run enrichment manually
export ABUSEIPDB_API_KEY="your_key"
export SHODAN_API_KEY="your_key"
python enricher.py

# Store keys for cron use
sudo mkdir -p /etc/hive
echo "your_key" | sudo tee /etc/hive/abuseipdb.key
echo "your_key" | sudo tee /etc/hive/shodan.key
sudo chmod 600 /etc/hive/*.key

# Set up cron (every 6 hours)
sudo cp -r . /opt/hive/phase4c-enrichment
sudo cp scripts/run-enrichment.sh /opt/hive/scripts/run-enrichment.sh
sudo chmod +x /opt/hive/scripts/run-enrichment.sh
echo '0 */6 * * * /opt/hive/scripts/run-enrichment.sh >> /var/log/hive/enrichment.log 2>&1' | crontab -

# Check cache
ls -lh /var/lib/hive/enrichment_cache.db

# Reset cache (forces re-query of all IPs on next run)
rm /var/lib/hive/enrichment_cache.db
```

---

## Log locations

All logs use `/var/log/hive/` on the VPS:

| File | Source | ES index |
|------|--------|----------|
| `/var/log/hive/web.json` | Flask web hive | `hive-web-*` |
| `/var/log/hive/cowrie.json` | Cowrie SSH/Telnet | `hive-cowrie-*` |
| `/var/log/hive/eve.json` | Suricata IDS | `hive-suricata-*` |
| `/var/log/hive/pcap/*.pcap.zst` | tcpdump (compressed) | shipped to `/data/pcap/` |
| `/var/log/hive/enrichment.log` | enricher.py cron | — |
| `/var/log/hive/pcap-compress.log` | compress-pcaps.sh cron | — |
| `/var/log/hive/pcap-ship.log` | ship-pcaps.sh cron | — |
| `/var/log/hive/suricata-update.log` | update-rules.sh cron | — |

---

## Port reference

| Port | Protocol | Service | Where |
|------|----------|---------|-------|
| 22 | TCP | Cowrie SSH hive | VPS (public) |
| 80 | TCP | Flask web hive | VPS (public) |
| 443 | TCP | Flask web hive | VPS (public) |
| 2222 | TCP | Cowrie SSH (direct, dev) | microVM / local |
| 2323 | TCP | Cowrie Telnet | microVM |
| 5000 | TCP | Flask (dev, non-root) | local |
| 5044 | TCP | Logstash Beats input | analysis machine |
| 9200 | TCP | Elasticsearch | analysis machine (localhost) |
| 5601 | TCP | Kibana | analysis machine (localhost) |
| 3000 | TCP | Grafana | analysis machine (localhost) |
| 51820 | UDP | WireGuard | VPS + analysis machine |

---

## Quick start — local dev (no VPS)

Run all locally-testable components on Parrot:

```bash
# 1. Web hive on port 5000
bash phase2b/hive-web/setup.sh
bash phase2b/hive-web/run.sh &

# 2. ELK stack (requires Docker, 4GB RAM)
cd phase4a/phase4a-elk
docker compose up -d
bash scripts/create-indices.sh   # after ~60s
bash scripts/test-ingest.sh
cd ../..

# 3. Grafana (after ELK is up)
# See Phase 4b section above

# 4. IP enrichment (requires API keys)
cd phase4c/phase4c-enrichment
source venv/bin/activate
python enricher.py
```

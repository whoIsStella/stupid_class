# hive — CSC651 Hive Infrastructure

Multi-surface repo for observing real-world attack traffic.

The public deception surfaces live on the VPS. The analysis-side pieces live on a separate machine. This README reflects the current repo.

## Runtime placement by phase

| Phase | What it is | Where it actually runs | VPS-only parts | Not on the VPS |
|---|---|---|---|---|
| Phase 1 | WireGuard transport | Split between VPS and local machine | `hive/phase1/wireguard/setup-wg-vps.sh` | `hive/phase1/wireguard/setup-wg-analysis.sh` |
| Phase 2a | Cowrie SSH/Telnet lure | Cowrie runs inside the phase 2a VM on the VPS; host forwards public `22/23` into it | Cowrie service + VM-side runtime | None in this repo snapshot |
| Phase 2b | Flask web lure | Production service runs on the VPS | `hive/phase2b/hive-web/hive-web.service` and deployed app under `/opt/hive/hive-web/` | Local dev helpers `hive/hive-web/setup.sh` and `hive/hive-web/run.sh` |
| Phase 2c | Suricata IDS | VPS host directly on `eth0` | Entire phase | None |
| Phase 3a | tcpdump PCAP capture | VPS host directly | Entire phase | None |
| Phase 3b | Log shipping | Split: Filebeat on VPS, Logstash on local machine | `hive/phase3b/filebeat/` and `hive/phase3b/systemd/filebeat-override.conf` | `hive/phase3b/logstash/hive-input.conf` |
| Phase 4a | Logstash normalization/indexing | Analysis machine | None | Entire phase |
| Phase 4b | Grafana dashboards | Dashboard definitions only | None | Entire phase |
| Phase 4c | IP enrichment job | Analysis machine by default (`localhost:9200`) | None | Entire phase |

## What `deploy-to-vps.sh` does

```bash
bash hive/scripts/deploy-to-vps.sh
```

This pushes only VPS-side material:

- phase 2a Cowrie config and `cowrie.service`
- phase 2b web app files and `hive-web.service`
- phase 2c Suricata config, local rules, and systemd override
- phase 3a tcpdump capture script and `pcap-capture.service`
- phase 3b Filebeat-side files
- phase 1 VPS WireGuard setup script

It does not set up your local machine.

## Set up everything that is not on the VPS

### Prerequisites on your local machine

Install these on your local machine yourself first:

- WireGuard
- Elasticsearch, listening on `localhost:9200`
- Logstash, managed as a local service
- Grafana, if you want dashboards
- Python 3.10+ for phase 4c

Repo boundary:

- This repo does include: WireGuard helper scripts, Logstash pipeline files, dashboard JSON, enrichment code, and a secrets helper.
- This repo does not include: standalone Elasticsearch installers, standalone Logstash installers, or standalone Grafana installers outside of the bundled Docker Compose stack.

### 1. Bring up the analysis-side WireGuard peer

On the VPS, generate the VPS keypair if you have not already:

```bash
sudo bash /opt/hive/scripts/setup-wg-vps.sh
```

Copy the printed VPS public key, then on your local machine run:

```bash
sudo bash hive/phase1/wireguard/setup-wg-analysis.sh --peer <VPS_PUBKEY>
```

That prints the analysis-machine public key. Paste it back on the VPS:

```bash
sudo bash /opt/hive/scripts/setup-wg-vps.sh --peer <ANALYSIS_PUBKEY>
```

Verify the tunnel:

```bash
ping 10.0.0.1   # from the local machine
# and from the VPS:
ping 10.0.0.2
```

### 2. Install local secrets used by dashboards and enrichment

Create a filled secrets file from the template:

```bash
cp hive/secrets.env.template /tmp/hive-secrets.env
```

Edit `/tmp/hive-secrets.env`, then deploy it:

```bash
sudo bash hive/scripts/deploy-secrets.sh /tmp/hive-secrets.env
```

This writes `/etc/hive/secrets.env` with:

- `GRAFANA_ADMIN_PASSWORD`
- `ABUSEIPDB_API_KEY`
- `SHODAN_API_KEY`

The repo does not automatically source this file for you. For manual runs, load it into the shell first:

```bash
set -a
source /etc/hive/secrets.env
set +a
```

### 3. Optional: run the web lure locally for validation

Phase 2b runs on the VPS in production, but the top-level `hive/hive-web/` directory contains local helpers for testing the Flask lure off-VPS:

```bash
bash hive/hive-web/setup.sh
bash hive/hive-web/run.sh
```

Default local URL:

```text
http://localhost:5000
```

Useful smoke checks:

```bash
curl http://localhost:5000/
curl http://localhost:5000/.env
curl http://localhost:5000/wp-admin
curl http://localhost:5000/phpmyadmin
```

### 4. Optional: deploy Logstash pipelines outside of Docker

If you are not using the Docker Compose stack (described below in step 5) and want to run Logstash manually on your host:

#### Option A — phase 3b minimal ingest

Use this when you only need Filebeat → Logstash → Elasticsearch routing.

```bash
sudo cp hive/phase3b/logstash/hive-input.conf /etc/logstash/conf.d/hive-input.conf
sudo systemctl restart logstash
sudo systemctl status logstash
```

What it does:

- Listens for Beats on `10.0.0.2:5044`
- Routes web, Cowrie, and Suricata events into the right indices
- Writes to local Elasticsearch at `localhost:9200`

#### Option B — phase 4a normalized pipelines

Use this when you want the richer per-surface filters and GeoIP enrichment. This is the better fit for the full analysis stack.

```bash
sudo cp hive/phase4a/phase4a-elk/logstash/pipeline/*.conf /etc/logstash/conf.d/
```

Before restarting Logstash, edit `/etc/logstash/conf.d/00-input.conf` and change:

```text
host => "0.0.0.0"
```

to:

```text
host => "10.0.0.2"
```

Then restart Logstash:

```bash
sudo systemctl restart logstash
sudo systemctl status logstash
```

Notes:

- All phase 4a outputs expect Elasticsearch on `localhost:9200`.
- `pcap-meta.conf` is optional; it is for manually imported PCAP metadata JSON, not Filebeat-shipped logs.
- Do not leave `phase3b/logstash/hive-input.conf` installed alongside the phase 4a pipeline set.

### 5. Set up the ELK + Grafana Stack (Docker Compose)

Phase 4a and 4b include a bundled Docker Compose stack for Elasticsearch, Logstash, Kibana, and Grafana. It automatically mounts the phase 4a Logstash pipelines and phase 4b Grafana dashboards.

Prerequisites: Docker + Docker Compose, minimum 4GB RAM free.

```bash
cd hive/phase4a/phase4a-elk

# Add Grafana to the stack
# Copy 'grafana' service block from phase4b/phase4b-grafana/docker-compose-addition.yml
# into phase4a-elk/docker-compose.yml if not already present.

# Start the stack
docker compose up -d

# Wait ~60s for Elasticsearch, then verify services are running
bash scripts/verify-stack.sh

# Open Kibana and Grafana (login: admin / honeypot2025)
xdg-open http://localhost:5601
xdg-open http://localhost:3000

# Re-import Grafana dashboards manually if they didn't provision
bash ../../phase4b/phase4b-grafana/scripts/import-dashboards.sh
```

These dashboards expect the indices created by phases 3b, 4a, and 4c.

### 6. Set up the phase 4c enrichment job

Create a virtual environment and install dependencies:

```bash
cd hive/phase4c/phase4c-enrichment
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Load secrets and point the cache somewhere writable if you are not using `/var/lib/hive/`:

```bash
set -a
source /etc/hive/secrets.env
set +a

export HIVE_CACHE_DB="$HOME/hive-data/enrichment_cache/enrichment_cache.db"
mkdir -p "$(dirname "$HIVE_CACHE_DB")"
```

Run the smoke test:

```bash
bash scripts/test-enrichment.sh
```

Run one enrichment pass:

```bash
python enricher.py
```

Phase 4c defaults to local Elasticsearch:

- `ES_HOST=localhost`
- `ES_PORT=9200`

If you want recurring enrichment, wrap `python enricher.py` in your own cron job or systemd timer. This repo snapshot does not include a scheduler wrapper.

## End-to-end verification

After the VPS services and local-side pieces are up:

```bash
# local machine
curl http://localhost:9200/_cluster/health
curl http://localhost:9200/_cat/indices?v
sudo systemctl status logstash
```

You should eventually see indices such as:

- `hive-web-*`
- `hive-cowrie-*`
- `hive-suricata-*`
- `hive-enriched-*` after phase 4c runs

On the VPS, the log sources that feed the analysis machine are:

- `/var/log/hive/web.json`
- `/var/log/hive/cowrie.json`
- `/var/log/hive/eve.json`
- `/var/log/hive/pcap/` for packet captures

## Port reference

| Port | Protocol | Service | Where |
|---|---|---|---|
| 22 | TCP | Cowrie SSH lure (forwarded) | VPS public edge → phase 2a VM |
| 23 | TCP | Cowrie Telnet lure (forwarded) | VPS public edge → phase 2a VM |
| 80 | TCP | Flask web lure | VPS public edge |
| 443 | TCP | Flask web lure / TLS bait surface | VPS public edge |
| 2222 | TCP | Cowrie SSH listener | Inside phase 2a VM |
| 2323 | TCP | Cowrie Telnet listener | Inside phase 2a VM |
| 5000 | TCP | Flask local dev port | Analysis/local dev only |
| 5044 | TCP | Logstash Beats input | Analysis machine (`wg0` / `10.0.0.2`) |
| 9200 | TCP | Elasticsearch | Analysis machine (`localhost`) |
| 3000 | TCP | Grafana | Analysis machine |
| 51820 | UDP | WireGuard | VPS + analysis machine |

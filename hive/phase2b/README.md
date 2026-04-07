# Phase 2b — Flask Web Hive

Phase 2b provides the HTTP/HTTPS deception layer for the hive. It serves a bank-themed Flask application that imitates a public site plus common attacker targets such as admin pages, WordPress, phpMyAdmin, cPanel, and exposed API/config endpoints, while logging every request to `/var/log/hive/web.json`.

## What lives here

- `hive-web/app.py` — Flask routes, fake headers, bait endpoints, and response behavior
- `hive-web/logger.py` — JSON request logging for web hits and form submissions
- `hive-web/templates/` — HTML pages for the public site and common attack targets
- `hive-web/static/` — styling and image assets for the bank persona
- `hive-web/requirements.txt` — Python dependencies for the web hive
- `hive-web/hive-web.service` — systemd unit used on the VPS

## Notes

- `hive/scripts/deploy-to-vps.sh` syncs `phase2b/hive-web/` into `/opt/hive/hive-web/`.
- The runtime helpers `run.sh` and `setup.sh` live in the top-level `hive/hive-web/` directory, not under `phase2b/`.
- In production, `hive-web.service` starts the app on port `80` and writes JSON logs to `/var/log/hive/web.json`.
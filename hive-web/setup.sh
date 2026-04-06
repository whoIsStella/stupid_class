#!/usr/bin/env bash
# setup.sh — one-time setup for hive-web
# Works as non-root (local dev) and root (microVM guest).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Colours ────────────────────────────────────────────────────────────────────
red()   { printf '\033[0;31m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
info()  { printf '  \033[0;34m→\033[0m %s\n' "$*"; }

echo ""
echo "  hive-web setup"
echo "  ──────────────"

# ── Environment detection ──────────────────────────────────────────────────────
if [ "$(id -u)" -eq 0 ]; then
    MODE="production"
    LOG_DIR="/var/log/hive"
else
    MODE="dev"
    LOG_DIR="$SCRIPT_DIR/logs"
fi
info "mode: $MODE"
info "log dir: $LOG_DIR"

# ── Python ─────────────────────────────────────────────────────────────────────
PYTHON=""
for candidate in python3.11 python3.10 python3; do
    if command -v "$candidate" &>/dev/null; then
        ver=$("$candidate" -c 'import sys; print(sys.version_info >= (3,10))')
        if [ "$ver" = "True" ]; then
            PYTHON="$candidate"
            break
        fi
    fi
done

if [ -z "$PYTHON" ]; then
    red "Python 3.10+ not found. Install it and re-run."
    exit 1
fi
info "python: $($PYTHON --version)"

# ── Virtualenv ─────────────────────────────────────────────────────────────────
if [ ! -d ".venv" ]; then
    info "creating .venv"
    "$PYTHON" -m venv .venv
else
    info ".venv already exists — skipping creation"
fi

info "installing dependencies"
.venv/bin/pip install --quiet --upgrade pip
.venv/bin/pip install --quiet -r requirements.txt

# ── Log directory ──────────────────────────────────────────────────────────────
info "creating log directory: $LOG_DIR"
mkdir -p "$LOG_DIR"
chmod 755 "$LOG_DIR"

# ── fake_responses/ ────────────────────────────────────────────────────────────
info "writing fake_responses/"
mkdir -p fake_responses

cat > fake_responses/env.txt << 'ENVEOF'
APP_ENV=production
APP_DEBUG=false
APP_KEY=base64:aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789abcdefgh==
APP_URL=https://www.cascadecommbank.com

DB_CONNECTION=mysql
DB_HOST=db01.cascadecommbank.local
DB_PORT=3306
DB_DATABASE=cascade_banking
DB_USERNAME=cascade_app
DB_PASSWORD=Cascade#2019!

REDIS_HOST=redis01.cascadecommbank.local
REDIS_PASSWORD=null
REDIS_PORT=6379

SESSION_DRIVER=redis
SESSION_LIFETIME=120
SESSION_SECURE_COOKIE=true

MAIL_DRIVER=smtp
MAIL_HOST=mail.cascadecommbank.com
MAIL_PORT=587
MAIL_USERNAME=noreply@cascadecommbank.com
MAIL_PASSWORD=M@ilR3lay2019
MAIL_ENCRYPTION=tls
MAIL_FROM_NAME="Cascade Community Bank"

AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AWS_DEFAULT_REGION=us-west-2
S3_BUCKET=cascade-bank-docs-prod
S3_URL=

TWILIO_SID=ACxxFAKExxFAKExxFAKExxFAKExxFAKExx
TWILIO_TOKEN=xxFAKExxFAKExxFAKExxFAKExxFAKExx
TWILIO_FROM=+15035550142

LOG_CHANNEL=stack
LOG_LEVEL=error
ENVEOF

cat > fake_responses/api_users.json << 'JSONEOF'
[
  {
    "id": 1,
    "username": "jmitchell",
    "email": "j.mitchell@cascadecommbank.com",
    "full_name": "Janet Mitchell",
    "role": "admin",
    "department": "IT Operations",
    "active": true,
    "last_login": "2025-03-18T09:14:22Z",
    "created_at": "2019-04-02T08:00:00Z"
  },
  {
    "id": 2,
    "username": "sthompson",
    "email": "s.thompson@cascadecommbank.com",
    "full_name": "Scott Thompson",
    "role": "teller",
    "department": "Retail Banking",
    "active": true,
    "last_login": "2025-03-19T14:03:55Z",
    "created_at": "2021-11-15T08:00:00Z"
  },
  {
    "id": 3,
    "username": "rbaker",
    "email": "r.baker@cascadecommbank.com",
    "full_name": "Rebecca Baker",
    "role": "auditor",
    "department": "Compliance",
    "active": true,
    "last_login": "2025-03-17T16:44:01Z",
    "created_at": "2020-06-30T08:00:00Z"
  }
]
JSONEOF

cat > fake_responses/db_dump_header.sql << 'SQLEOF'
-- MySQL dump 10.13  Distrib 5.7.42, for Linux (x86_64)
--
-- Host: db01.cascadecommbank.local    Database: cascade_banking
-- ------------------------------------------------------
-- Server version	5.7.42-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;

DROP TABLE IF EXISTS `customers`;
CREATE TABLE `customers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `first_name` varchar(64) NOT NULL,
  `last_name` varchar(64) NOT NULL,
  `email` varchar(128) DEFAULT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `ssn_last4` char(4) DEFAULT NULL,
  `date_of_birth` date DEFAULT NULL,
  `address` varchar(255) DEFAULT NULL,
  `city` varchar(64) DEFAULT NULL,
  `state` char(2) DEFAULT NULL,
  `zip` varchar(10) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

DROP TABLE IF EXISTS `accounts`;
CREATE TABLE `accounts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `customer_id` int(11) NOT NULL,
  `account_number` char(12) NOT NULL,
  `routing_number` char(9) NOT NULL DEFAULT '123187654',
  `account_type` enum('checking','savings','money_market','cd') NOT NULL,
  `balance` decimal(13,2) NOT NULL DEFAULT '0.00',
  `opened_date` date NOT NULL,
  `status` enum('active','frozen','closed') NOT NULL DEFAULT 'active',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `customers` VALUES (1,'Robert','Hargrove','r.hargrove@gmail.com','503-555-0171','7823','1961-04-14','4421 NE Burnside St','Portland','OR','97213','2019-05-01 08:22:14');
INSERT INTO `customers` VALUES (2,'Linda','Pearce','lpearce@comcast.net','360-555-0234','4490','1974-09-28','812 Oak Ave','Vancouver','WA','98661','2019-07-12 10:44:02');

INSERT INTO `accounts` VALUES (1,1,'480122039841','123187654','checking',4218.57,'2019-05-01','active');
INSERT INTO `accounts` VALUES (2,1,'480122039858','123187654','savings',12045.00,'2019-05-01','active');
INSERT INTO `accounts` VALUES (3,2,'480133847201','123187654','checking',887.23,'2019-07-12','active');
INSERT INTO `accounts` VALUES (4,2,'480133847218','123187654',

-- [TRUNCATED: file corrupt or transfer interrupted]
SQLEOF

# ── Done ───────────────────────────────────────────────────────────────────────
echo ""
green "  Setup complete."
echo ""
echo "  To start:"
if [ "$MODE" = "dev" ]; then
    echo "    ./run.sh"
    echo ""
    echo "  Logs → $LOG_DIR/web.json"
else
    echo "    ./run.sh                          (foreground)"
    echo "    systemctl enable --now hive-web   (service)"
    echo ""
    echo "  Logs → $LOG_DIR/web.json"
fi
echo ""

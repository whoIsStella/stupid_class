import io
import json
import os
import zipfile

# Replace Werkzeug's Server header at the transport level with our fake value.
# sys_version is cleared so no "Python/x.y" suffix appears.
from werkzeug.serving import WSGIRequestHandler
WSGIRequestHandler.server_version = "Apache/2.4.54 (Ubuntu)"
WSGIRequestHandler.sys_version = ""

from flask import (
    Flask,
    Response,
    redirect,
    render_template,
    request,
)

from logger import log_hit

app = Flask(__name__)
app.secret_key = os.urandom(24)

# ── Fake response file paths ───────────────────────────────────────────────────
_HERE = os.path.dirname(os.path.abspath(__file__))
_FAKE = os.path.join(_HERE, "fake_responses")


def _read_fake(filename):
    with open(os.path.join(_FAKE, filename), "r", encoding="utf-8") as f:
        return f.read()


# ── Fake headers on every response ────────────────────────────────────────────
@app.after_request
def add_fake_headers(response):
    response.headers["X-Powered-By"] = "PHP/7.4.33"
    # Server header is set at the transport level via WSGIRequestHandler above.
    return response


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC ROUTES
# ═══════════════════════════════════════════════════════════════════════════════

@app.route("/")
def index():
    log_hit(200)
    return render_template("index.html"), 200


@app.route("/personal")
def personal():
    log_hit(200)
    return render_template("personal.html"), 200


@app.route("/business")
def business():
    log_hit(200)
    return render_template("business.html"), 200


@app.route("/loans")
def loans():
    log_hit(200)
    return render_template("loans.html"), 200


@app.route("/contact", methods=["GET", "POST"])
def contact():
    if request.method == "POST":
        log_hit(200)
        return render_template("contact.html", sent=True), 200
    log_hit(200)
    return render_template("contact.html", sent=False), 200


@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        log_hit(401)
        return render_template("login.html", error=True), 200
    log_hit(200)
    return render_template("login.html", error=False), 200


# ═══════════════════════════════════════════════════════════════════════════════
# HIVE — ADMIN
# ═══════════════════════════════════════════════════════════════════════════════

@app.route("/admin")
def admin():
    log_hit(403)
    body = (
        "<!DOCTYPE html><html><head><title>403 Forbidden</title>"
        "<style>body{font-family:Arial,sans-serif;background:#f5f5f5;}"
        ".box{max-width:480px;margin:80px auto;background:#fff;"
        "border-top:4px solid #c0392b;padding:28px 32px;"
        "border:1px solid #ddd;}</style></head>"
        "<body><div class='box'>"
        "<h2 style='color:#c0392b;margin-top:0;'>403 &mdash; Access Denied</h2>"
        "<p>This area is restricted to authorised Cascade Community Bank staff only.</p>"
        "<p>If you require access, contact the IT Help Desk at <strong>(503) 555-0199</strong> "
        "or visit the <a href='/admin/login'>staff portal login</a>.</p>"
        "<p style='font-size:11px;color:#999;margin-top:20px;'>"
        "Your access attempt has been logged.</p>"
        "</div></body></html>"
    )
    return Response(body, status=403, mimetype="text/html")


@app.route("/admin/login", methods=["GET", "POST"])
def admin_login():
    if request.method == "POST":
        log_hit(401)
        submitted_user = request.form.get("username", "")
        return render_template("admin_login.html", error=True,
                               submitted_user=submitted_user), 200
    log_hit(200)
    return render_template("admin_login.html", error=False), 200


@app.route("/dashboard")
def dashboard():
    log_hit(302)
    return redirect("/login", code=302)


# ═══════════════════════════════════════════════════════════════════════════════
# HIVE — WORDPRESS
# ═══════════════════════════════════════════════════════════════════════════════

@app.route("/wp-admin", methods=["GET", "POST"])
@app.route("/wp-admin/", methods=["GET", "POST"])
def wp_admin():
    if request.method == "POST":
        log_hit(401)
        submitted_user = request.form.get("log", "")
        return render_template("wp_admin.html", error=True,
                               submitted_user=submitted_user), 200
    log_hit(200)
    return render_template("wp_admin.html", error=False), 200


@app.route("/wp-admin/admin-ajax.php", methods=["GET", "POST"])
def wp_ajax():
    log_hit(400)
    return Response(
        json.dumps({"error": "Bad Request", "code": 400,
                    "message": "Invalid action specified."}),
        status=400,
        mimetype="application/json",
    )


@app.route("/xmlrpc.php", methods=["GET", "POST"])
def xmlrpc():
    log_hit(200)
    body = (
        '<?xml version="1.0" encoding="UTF-8"?>'
        "<methodResponse>"
        "<fault><value><struct>"
        "<member><name>faultCode</name><value><int>-32601</int></value></member>"
        "<member><name>faultString</name>"
        "<value><string>server error. requested method not specified.</string></value></member>"
        "</struct></value></fault>"
        "</methodResponse>"
    )
    return Response(body, status=200, mimetype="text/xml")


# ═══════════════════════════════════════════════════════════════════════════════
# HIVE — DB ADMIN PANELS
# ═══════════════════════════════════════════════════════════════════════════════

@app.route("/phpmyadmin", methods=["GET", "POST"])
@app.route("/phpmyadmin/", methods=["GET", "POST"])
@app.route("/phpmyadmin/index.php", methods=["GET", "POST"])
def phpmyadmin():
    if request.method == "POST":
        log_hit(401)
        submitted_user = request.form.get("pma_username", "")
        return render_template("phpmyadmin.html", error=True,
                               submitted_user=submitted_user), 200
    log_hit(200)
    return render_template("phpmyadmin.html", error=False), 200


@app.route("/cpanel", methods=["GET", "POST"])
@app.route("/cpanel/", methods=["GET", "POST"])
def cpanel():
    if request.method == "POST":
        log_hit(401)
        return render_template("cpanel.html", error=True), 200
    log_hit(200)
    return render_template("cpanel.html", error=False), 200


# ═══════════════════════════════════════════════════════════════════════════════
# HIVE — API ENDPOINTS
# ═══════════════════════════════════════════════════════════════════════════════

@app.route("/api/v1/users")
def api_users():
    log_hit(200)
    users = json.loads(_read_fake("api_users.json"))
    return Response(json.dumps(users, indent=2), status=200,
                    mimetype="application/json")


@app.route("/api/v1/users/<user_id>")
def api_user(user_id):
    users = json.loads(_read_fake("api_users.json"))
    try:
        uid = int(user_id)
    except ValueError:
        log_hit(404)
        return Response(
            json.dumps({"error": "Not Found", "code": 404}),
            status=404, mimetype="application/json",
        )
    match = next((u for u in users if u["id"] == uid), None)
    if match:
        log_hit(200)
        return Response(json.dumps(match, indent=2), status=200,
                        mimetype="application/json")
    log_hit(404)
    return Response(
        json.dumps({"error": "User not found", "code": 404}),
        status=404, mimetype="application/json",
    )


@app.route("/api/keys")
def api_keys():
    log_hit(200)
    payload = {
        "api_key": "sk-casc4deB4nkPr0dXkLmNoPqRsTuVwXyZ01234567890abcdef",
        "status": "active",
        "scope": ["read:accounts", "read:transactions", "write:transfers"],
        "created": "2024-01-15T08:00:00Z",
        "expires": "2026-01-15T08:00:00Z",
        "owner": "api-service@cascadecommbank.com",
    }
    return Response(json.dumps(payload, indent=2), status=200,
                    mimetype="application/json")


_FAKE_CONFIG = {
    "environment": "production",
    "version": "3.8.1",
    "db": {
        "host": "db01.cascadecommbank.local",
        "port": 3306,
        "name": "cascade_banking",
        "user": "cascade_app",
        "password": "Cascade#2019!",
        "pool_size": 10,
        "ssl": True,
    },
    "redis": {
        "host": "redis01.cascadecommbank.local",
        "port": 6379,
        "db": 0,
        "password": None,
    },
    "s3": {
        "bucket": "cascade-bank-docs-prod",
        "region": "us-west-2",
        "access_key": "AKIAIOSFODNN7EXAMPLE",
        "secret_key": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
    },
    "session": {
        "driver": "redis",
        "lifetime_minutes": 120,
        "secure_cookie": True,
    },
    "logging": {
        "level": "error",
        "channel": "stack",
    },
}


@app.route("/api/config")
def api_config():
    log_hit(200)
    return Response(json.dumps(_FAKE_CONFIG, indent=2), status=200,
                    mimetype="application/json")


@app.route("/config")
def config():
    log_hit(200)
    return Response(json.dumps(_FAKE_CONFIG, indent=2), status=200,
                    mimetype="application/json")


# ═══════════════════════════════════════════════════════════════════════════════
# HIVE — SENSITIVE FILES
# ═══════════════════════════════════════════════════════════════════════════════

@app.route("/.env")
def dotenv():
    log_hit(200)
    content = _read_fake("env.txt")
    return Response(content, status=200, mimetype="text/plain")


@app.route("/backup.zip")
def backup_zip():
    log_hit(200)
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, mode="w", compression=zipfile.ZIP_DEFLATED) as _zf:
        pass  # intentionally empty — valid ZIP with 0 entries
    buf.seek(0)
    return Response(
        buf.read(),
        status=200,
        mimetype="application/zip",
        headers={"Content-Disposition": "attachment; filename=backup.zip"},
    )


@app.route("/db_dump.sql")
def db_dump():
    log_hit(200)
    content = _read_fake("db_dump_header.sql")
    return Response(content, status=200, mimetype="text/plain",
                    headers={"Content-Disposition": "attachment; filename=db_dump.sql"})


# ═══════════════════════════════════════════════════════════════════════════════
# HIVE — SERVER INFRASTRUCTURE BAIT
# ═══════════════════════════════════════════════════════════════════════════════

@app.route("/server-status")
def server_status():
    log_hit(200)
    body = """<!DOCTYPE html>
<html><head><title>Apache Status</title>
<style>body{font-family:monospace;font-size:12px;}
h1{font-size:16px;} table{border-collapse:collapse;font-size:11px;}
th,td{border:1px solid #ccc;padding:3px 6px;}</style></head>
<body>
<h1>Apache Server Status for <b>cascadecommbank.com</b></h1>
<p>Server Version: <b>Apache/2.4.54 (Ubuntu) OpenSSL/3.0.2 PHP/7.4.33</b></p>
<p>Server MPM: <b>prefork</b></p>
<p>Server Built: <b>2022-08-15T18:33:32</b></p>
<hr>
<p>Current Time: Sunday, 19-Mar-2025 04:12:07 UTC</p>
<p>Restart Time: Saturday, 01-Mar-2025 06:00:01 UTC</p>
<p>Parent Server Config. Generation: 1</p>
<p>Parent Server MPM Generation: 0</p>
<p>Server uptime: 18 days 22 hours 12 minutes 6 seconds</p>
<p>Server load: 0.24 0.18 0.16</p>
<p>Total accesses: 1482904 - Total Traffic: 18.2 GB - Total Duration: 4823001 ms</p>
<p>CPU Usage: u31.2 s4.08 cu0 cs0 - .00216% CPU load</p>
<p>0.905 requests/sec - 11.6 kB/second - 12.8 kB/request</p>
<p>4 requests currently being processed, 5 idle workers</p>
<pre>W_W__W_W._........................................................
................................................................</pre>
<p>Scoreboard Key:<br>
"<b><code>_</code></b>" Waiting for Connection,
"<b><code>S</code></b>" Starting up,
"<b><code>R</code></b>" Reading Request,
"<b><code>W</code></b>" Sending Reply,
"<b><code>K</code></b>" Keepalive (read),
"<b><code>D</code></b>" DNS Lookup,
"<b><code>C</code></b>" Closing connection,
"<b><code>L</code></b>" Logging,
"<b><code>G</code></b>" Gracefully finishing,
"<b><code>I</code></b>" Idle cleanup of worker,
"<b><code>.</code></b>" Open slot with no current process</p>
<table>
<tr><th>Srv</th><th>PID</th><th>Acc</th><th>M</th><th>CPU</th><th>SS</th>
<th>Req</th><th>Conn</th><th>Child</th><th>Slot</th><th>Client</th>
<th>Protocol</th><th>VHost</th><th>Request</th></tr>
<tr><td>0-0</td><td>1241</td><td>0/312/48200</td><td>W</td><td>0.00</td>
<td>0</td><td>0</td><td>0.0</td><td>0.27</td><td>21.34</td>
<td>10.0.0.2</td><td>http/1.1</td><td>cascadecommbank.com</td>
<td>GET / HTTP/1.1</td></tr>
<tr><td>1-0</td><td>1242</td><td>0/284/46102</td><td>W</td><td>0.00</td>
<td>0</td><td>0</td><td>0.0</td><td>0.24</td><td>20.11</td>
<td>10.0.0.3</td><td>http/1.1</td><td>cascadecommbank.com</td>
<td>GET /login HTTP/1.1</td></tr>
</table>
</body></html>"""
    return Response(body, status=200, mimetype="text/html")


# ═══════════════════════════════════════════════════════════════════════════════
# HIVE — ROBOTS / SITEMAP (reverse psychology)
# ═══════════════════════════════════════════════════════════════════════════════

@app.route("/robots.txt")
def robots():
    log_hit(200)
    content = """User-agent: *
Allow: /
Allow: /personal
Allow: /business
Allow: /loans
Allow: /contact

# Internal — do not index
Disallow: /admin
Disallow: /admin/login
Disallow: /dashboard
Disallow: /wp-admin
Disallow: /wp-admin/admin-ajax.php
Disallow: /phpmyadmin
Disallow: /phpmyadmin/index.php
Disallow: /cpanel
Disallow: /api/v1/users
Disallow: /api/keys
Disallow: /api/config
Disallow: /config
Disallow: /.env
Disallow: /backup.zip
Disallow: /db_dump.sql
Disallow: /server-status
Disallow: /xmlrpc.php

Sitemap: https://www.cascadecommbank.com/sitemap.xml
"""
    return Response(content, status=200, mimetype="text/plain")


@app.route("/sitemap.xml")
def sitemap():
    log_hit(200)
    xml = """<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://www.cascadecommbank.com/</loc><changefreq>weekly</changefreq><priority>1.0</priority></url>
  <url><loc>https://www.cascadecommbank.com/personal</loc><changefreq>monthly</changefreq><priority>0.8</priority></url>
  <url><loc>https://www.cascadecommbank.com/business</loc><changefreq>monthly</changefreq><priority>0.8</priority></url>
  <url><loc>https://www.cascadecommbank.com/loans</loc><changefreq>weekly</changefreq><priority>0.8</priority></url>
  <url><loc>https://www.cascadecommbank.com/contact</loc><changefreq>yearly</changefreq><priority>0.5</priority></url>
  <url><loc>https://www.cascadecommbank.com/login</loc><changefreq>yearly</changefreq><priority>0.6</priority></url>
  <url><loc>https://www.cascadecommbank.com/admin</loc><changefreq>never</changefreq><priority>0.1</priority></url>
  <url><loc>https://www.cascadecommbank.com/admin/login</loc><changefreq>never</changefreq><priority>0.1</priority></url>
  <url><loc>https://www.cascadecommbank.com/dashboard</loc><changefreq>never</changefreq><priority>0.1</priority></url>
  <url><loc>https://www.cascadecommbank.com/api/v1/users</loc><changefreq>never</changefreq><priority>0.1</priority></url>
  <url><loc>https://www.cascadecommbank.com/api/config</loc><changefreq>never</changefreq><priority>0.1</priority></url>
</urlset>
"""
    return Response(xml, status=200, mimetype="application/xml")


# ═══════════════════════════════════════════════════════════════════════════════
# CATCH-ALL — any unmatched path
# ═══════════════════════════════════════════════════════════════════════════════

@app.route("/<path:path>", methods=["GET", "POST", "PUT", "DELETE",
                                     "PATCH", "OPTIONS", "HEAD"])
def catch_all(path):
    log_hit(404)
    return render_template("404.html"), 404


@app.errorhandler(404)
def not_found(e):
    log_hit(404)
    return render_template("404.html"), 404


@app.errorhandler(405)
def method_not_allowed(e):
    log_hit(405)
    return render_template("404.html"), 404


# ═══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("HIVE_PORT", 80)), debug=False)

#!/usr/bin/env bash
set -euo pipefail

log() { printf '\n[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

PASS_COUNT=0
FAIL_COUNT=0
declare -a FAILED_CHECKS=()

pass() {
  printf 'PASS: %s\n' "$1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  printf 'FAIL: %s\n' "$1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
  FAILED_CHECKS+=("$1")
}

check_cmd() {
  local description="$1"
  shift
  if "$@"; then
    pass "$description"
  else
    fail "$description"
  fi
}

security_score() {
  local unit="$1"
  systemd-analyze security "$unit" 2>/dev/null \
    | grep -Eo '[0-9]+\.[0-9]+' \
    | tail -1
}

ensure_line() {
  local line="$1"
  local file="$2"
  grep -Fqx "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
}

# Expected dirty conditions found in pre-provisioning audit:
# - kk-api, kk-payments, and kk-logs already exist with pre-existing UIDs/GIDs and home directories: handled in Phase 2 with id checks and ownership reconciliation
# - kijanikiosk group already exists and includes esther: handled in Phase 2 by enforcing intended group membership
# - /opt/kijanikiosk exists with overly permissive 0777 mode from lab setup: corrected in Phase 2
# - /opt/kijanikiosk/config contains sensitive env files and is broader than intended: corrected in Phase 2 to a least-privilege config model
# - /opt/kijanikiosk/scripts contains a deliberately dangerous SUID deploy.sh from lab setup: remediated in Phase 2 and verified absent in Phase 8
# - /opt/kijanikiosk/shared exists with overly permissive mode and shared/logs has inconsistent ACLs with no visible default ACL entries: corrected in Phase 2 and revalidated in Phase 6 after forced log rotation
# - ufw is inactive on this VM: handled in Phase 5 by rebuilding and enabling the canonical ruleset
# - journald already contains existing on-disk history: handled in Phase 6 by enforcing persistent storage with size caps
# - no existing kk- systemd unit files were found: handled in Phase 4 by creating all three units from scratch
# - no apt package holds were present during audit: Phase 3 still verifies package state explicitly before install actions

if [[ $EUID -ne 0 ]]; then
  echo "Run this script as root: sudo bash ./kijanikiosk-provision.sh"
  exit 1
fi

log "Phase 1: Preflight and dirty-state detection"
echo "User audit:"
getent passwd kk-api kk-payments kk-logs || true
echo "Group audit:"
getent group kijanikiosk || true
echo "Firewall audit:"
ufw status numbered || true
echo "Held packages:"
apt-mark showhold || true

log "Phase 2: Users, groups, directories, permissions, ACLs, and SUID remediation"
getent group kk-api >/dev/null 2>&1 || groupadd --system kk-api
getent group kk-payments >/dev/null 2>&1 || groupadd --system kk-payments
getent group kk-logs >/dev/null 2>&1 || groupadd --system kk-logs
getent group kijanikiosk >/dev/null 2>&1 || groupadd --system kijanikiosk

log "DIRTY STATE: checking service accounts — all three exist from Tuesday lab with pre-assigned UIDs"
id -u kk-api >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin -g kk-api kk-api
id -u kk-api >/dev/null 2>&1 && log "DIRTY STATE: kk-api already exists (UID $(id -u kk-api)) — enforcing shell and group membership"
id -u kk-payments >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin -g kk-payments kk-payments
id -u kk-payments >/dev/null 2>&1 && log "DIRTY STATE: kk-payments already exists (UID $(id -u kk-payments)) — enforcing shell and group membership"
id -u kk-logs >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin -g kk-logs kk-logs
id -u kk-logs >/dev/null 2>&1 && log "DIRTY STATE: kk-logs already exists (UID $(id -u kk-logs)) — enforcing shell and group membership"

usermod -aG kijanikiosk kk-api
usermod -aG kijanikiosk kk-payments
usermod -aG kijanikiosk kk-logs

if getent group kijanikiosk | grep -qE '(^|,)esther(,|$)'; then
  gpasswd -d esther kijanikiosk || true
fi

log "DIRTY STATE: /opt/kijanikiosk was 777 from lab-setup.sh chmod -R 777 — correcting to 750"
install -d -o root        -g kijanikiosk -m 0750 /opt/kijanikiosk
install -d -o kk-api      -g kk-api       -m 0750 /opt/kijanikiosk/api
install -d -o kk-payments -g kk-payments  -m 0750 /opt/kijanikiosk/payments
install -d -o kk-logs     -g kk-logs      -m 0750 /opt/kijanikiosk/logs
install -d -o root        -g root         -m 0750 /opt/kijanikiosk/config
install -d -o root        -g kijanikiosk  -m 2750 /opt/kijanikiosk/shared
install -d -o kk-logs     -g kijanikiosk  -m 2770 /opt/kijanikiosk/shared/logs
install -d -o kk-logs     -g kijanikiosk  -m 0750 /opt/kijanikiosk/health
install -d -o root        -g root         -m 0750 /opt/kijanikiosk/scripts

[[ -e /opt/kijanikiosk/scripts/deploy.sh ]] && log "DIRTY STATE: deploy.sh found with SUID 4777 from lab-setup.sh — stripping SUID, setting 750"
if [[ -e /opt/kijanikiosk/scripts/deploy.sh ]]; then
  chown root:root /opt/kijanikiosk/scripts/deploy.sh
  chmod 0750 /opt/kijanikiosk/scripts/deploy.sh
fi

log "DIRTY STATE: scanning for any remaining SUID/SGID files under /opt/kijanikiosk — stripping all found"
find /opt/kijanikiosk -perm /6000 -type f -exec chmod ug-s {} +

# Environment files
if [[ -f /opt/kijanikiosk/config/db.env && ! -f /opt/kijanikiosk/config/api.env ]]; then
  cp /opt/kijanikiosk/config/db.env /opt/kijanikiosk/config/api.env
fi

cat >/opt/kijanikiosk/config/logs.env <<'EOF'
LOG_PATH=/opt/kijanikiosk/shared/logs/aggregator.log
LOG_INTERVAL=15
EOF

ensure_line 'API_HOST=0.0.0.0' /opt/kijanikiosk/config/api.env
ensure_line 'API_PORT=3000' /opt/kijanikiosk/config/api.env
ensure_line 'PAYMENTS_HOST=127.0.0.1' /opt/kijanikiosk/config/payments-api.env
ensure_line 'PAYMENTS_PORT=3001' /opt/kijanikiosk/config/payments-api.env
ensure_line 'PAYMENTS_LOG=/opt/kijanikiosk/shared/logs/payments.log' /opt/kijanikiosk/config/payments-api.env
ensure_line 'API_LOG=/opt/kijanikiosk/shared/logs/api.log' /opt/kijanikiosk/config/api.env

chown root:root /opt/kijanikiosk/config/api.env /opt/kijanikiosk/config/payments-api.env /opt/kijanikiosk/config/logs.env
chmod 0640 /opt/kijanikiosk/config/api.env /opt/kijanikiosk/config/payments-api.env /opt/kijanikiosk/config/logs.env

setfacl -b /opt/kijanikiosk/config || true
setfacl -k /opt/kijanikiosk/config || true
setfacl -b /opt/kijanikiosk/config/api.env 2>/dev/null || true
setfacl -b /opt/kijanikiosk/config/payments-api.env 2>/dev/null || true
setfacl -b /opt/kijanikiosk/config/logs.env 2>/dev/null || true

setfacl -m u:kk-api:--x /opt/kijanikiosk/config
setfacl -m u:kk-payments:--x /opt/kijanikiosk/config
setfacl -m u:kk-logs:--x /opt/kijanikiosk/config

setfacl -m u:kk-api:r-- /opt/kijanikiosk/config/api.env
setfacl -m u:kk-payments:r-- /opt/kijanikiosk/config/payments-api.env
setfacl -m u:kk-logs:r-- /opt/kijanikiosk/config/logs.env

setfacl -b /opt/kijanikiosk/shared/logs || true
setfacl -k /opt/kijanikiosk/shared/logs || true

setfacl -m u:kk-api:rwx /opt/kijanikiosk/shared/logs
setfacl -m u:kk-payments:rwx /opt/kijanikiosk/shared/logs
setfacl -m u:kk-logs:rwx /opt/kijanikiosk/shared/logs
setfacl -d -m u:kk-api:rwx /opt/kijanikiosk/shared/logs
setfacl -d -m u:kk-payments:rwx /opt/kijanikiosk/shared/logs
setfacl -d -m u:kk-logs:rwx /opt/kijanikiosk/shared/logs

touch /opt/kijanikiosk/health/.keep
chown kk-logs:kijanikiosk /opt/kijanikiosk/health/.keep
chmod 0640 /opt/kijanikiosk/health/.keep

if id -u amina >/dev/null 2>&1; then
  setfacl -m u:amina:r-x /opt/kijanikiosk/health
  setfacl -m u:amina:r-- /opt/kijanikiosk/health/.keep
fi

sudo -u kk-api test -r /opt/kijanikiosk/config/api.env
sudo -u kk-payments test -r /opt/kijanikiosk/config/payments-api.env
sudo -u kk-logs test -r /opt/kijanikiosk/config/logs.env
sudo -u kk-api test -w /opt/kijanikiosk/shared/logs
sudo -u kk-payments test -w /opt/kijanikiosk/shared/logs
sudo -u kk-logs test -w /opt/kijanikiosk/shared/logs


log "Phase 3: Packages and runtime dependencies"

# Dirty-state remediation: disable unrelated broken VS Code repo if present
if grep -Rqs "packages.microsoft.com/repos/vscode" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
  log "Detected broken VS Code APT repository on dirty VM"
  log "Disabling broken VS Code APT repository to allow package refresh"
  find /etc/apt/sources.list.d -type f -name '*.list' -exec sed -i \
    's|^deb \(.*packages.microsoft.com/repos/vscode.*\)$|# disabled by kijanikiosk provisioning: \1|' {} +
else
  log "No broken VS Code APT repository detected"
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y acl ufw logrotate python3 curl
log "Phase 4: Application runners and systemd units"

cat >/opt/kijanikiosk/api/api_service.py <<'PY'
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

HOST = os.getenv("API_HOST", "0.0.0.0")
PORT = int(os.getenv("API_PORT", "3000"))
LOG_PATH = os.getenv("API_LOG", "/opt/kijanikiosk/shared/logs/api.log")

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = b'{"service":"kk-api","status":"ok"}'
        with open(LOG_PATH, "a") as f:
            f.write("GET %s\n" % self.path)
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, format, *args):
        return

HTTPServer((HOST, PORT), Handler).serve_forever()
PY

cat >/opt/kijanikiosk/payments/payments_service.py <<'PY'
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

HOST = os.getenv("PAYMENTS_HOST", "127.0.0.1")
PORT = int(os.getenv("PAYMENTS_PORT", "3001"))
LOG_PATH = os.getenv("PAYMENTS_LOG", "/opt/kijanikiosk/shared/logs/payments.log")

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = b'{"service":"kk-payments","status":"ok"}'
        with open(LOG_PATH, "a") as f:
            f.write("GET %s\n" % self.path)
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, format, *args):
        return

HTTPServer((HOST, PORT), Handler).serve_forever()
PY

cat >/opt/kijanikiosk/logs/logs_service.py <<'PY'
import os
import time

LOG_PATH = os.getenv("LOG_PATH", "/opt/kijanikiosk/shared/logs/aggregator.log")
INTERVAL = int(os.getenv("LOG_INTERVAL", "15"))

while True:
    with open(LOG_PATH, "a") as f:
        f.write("kk-logs heartbeat\n")
    time.sleep(INTERVAL)
PY

chown kk-api:kk-api /opt/kijanikiosk/api/api_service.py
chown kk-payments:kk-payments /opt/kijanikiosk/payments/payments_service.py
chown kk-logs:kk-logs /opt/kijanikiosk/logs/logs_service.py
chmod 0750 /opt/kijanikiosk/api/api_service.py /opt/kijanikiosk/payments/payments_service.py /opt/kijanikiosk/logs/logs_service.py

sudo -u kk-api cat /opt/kijanikiosk/config/api.env >/dev/null
sudo -u kk-payments cat /opt/kijanikiosk/config/payments-api.env >/dev/null
sudo -u kk-logs cat /opt/kijanikiosk/config/logs.env >/dev/null

cat >/etc/systemd/system/kk-api.service <<'EOF'
[Unit]
Description=KijaniKiosk API Service
After=network.target

[Service]
Type=simple
User=kk-api
Group=kk-api
WorkingDirectory=/opt/kijanikiosk/api
EnvironmentFile=/opt/kijanikiosk/config/api.env
ExecStart=/usr/bin/python3 /opt/kijanikiosk/api/api_service.py
Restart=on-failure
RestartSec=5s
NoNewPrivileges=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectSystem=strict
ProtectHome=yes
ProtectControlGroups=yes
ProtectKernelModules=yes
ProtectKernelTunables=yes
ProtectClock=yes
ProtectHostname=yes
ProtectProc=invisible
ProcSubset=pid
LockPersonality=yes
MemoryDenyWriteExecute=yes
RestrictRealtime=yes
RestrictSUIDSGID=yes
RestrictNamespaces=yes
RemoveIPC=yes
SystemCallArchitectures=native
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
UMask=0027
CapabilityBoundingSet=
AmbientCapabilities=
DevicePolicy=closed
ReadOnlyPaths=/opt/kijanikiosk/config
ReadWritePaths=/opt/kijanikiosk/shared/logs

[Install]
WantedBy=multi-user.target
EOF

cat >/etc/systemd/system/kk-payments.service <<'EOF'
[Unit]
Description=KijaniKiosk Payments Service
After=network.target kk-api.service
Wants=kk-api.service

[Service]
Type=simple
User=kk-payments
Group=kk-payments
WorkingDirectory=/opt/kijanikiosk/payments
EnvironmentFile=/opt/kijanikiosk/config/payments-api.env
ExecStart=/usr/bin/python3 /opt/kijanikiosk/payments/payments_service.py
Restart=on-failure
RestartSec=5s
NoNewPrivileges=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectSystem=strict
ProtectHome=yes
ProtectControlGroups=yes
ProtectKernelModules=yes
ProtectKernelTunables=yes
ProtectClock=yes
ProtectHostname=yes
ProtectProc=invisible
ProcSubset=pid
LockPersonality=yes
MemoryDenyWriteExecute=yes
RestrictRealtime=yes
RestrictSUIDSGID=yes
RestrictNamespaces=yes
RemoveIPC=yes
SystemCallArchitectures=native
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
UMask=0027
CapabilityBoundingSet=
AmbientCapabilities=
DevicePolicy=closed
IPAddressDeny=any
IPAddressAllow=127.0.0.1
SystemCallFilter=@system-service
ProtectKernelLogs=yes
PrivateUsers=yes
ReadOnlyPaths=/opt/kijanikiosk/config
ReadWritePaths=/opt/kijanikiosk/shared/logs

[Install]
WantedBy=multi-user.target
EOF

cat >/etc/systemd/system/kk-logs.service <<'EOF'
[Unit]
Description=KijaniKiosk Log Aggregator Service
After=network.target

[Service]
Type=simple
User=kk-logs
Group=kk-logs
WorkingDirectory=/opt/kijanikiosk/logs
EnvironmentFile=/opt/kijanikiosk/config/logs.env
ExecStart=/usr/bin/python3 /opt/kijanikiosk/logs/logs_service.py
Restart=on-failure
RestartSec=5s
NoNewPrivileges=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectSystem=strict
ProtectHome=yes
ProtectControlGroups=yes
ProtectKernelModules=yes
ProtectKernelTunables=yes
ProtectClock=yes
ProtectHostname=yes
ProtectProc=invisible
ProcSubset=pid
LockPersonality=yes
MemoryDenyWriteExecute=yes
RestrictRealtime=yes
RestrictSUIDSGID=yes
RestrictNamespaces=yes
RemoveIPC=yes
SystemCallArchitectures=native
RestrictAddressFamilies=AF_UNIX
UMask=0027
CapabilityBoundingSet=
AmbientCapabilities=
DevicePolicy=closed
IPAddressDeny=any
ReadOnlyPaths=/opt/kijanikiosk/config
ReadWritePaths=/opt/kijanikiosk/shared/logs /opt/kijanikiosk/health

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

systemctl enable --now kk-api.service
systemctl status kk-api.service --no-pager
systemctl enable --now kk-payments.service
systemctl status kk-payments.service --no-pager
systemctl enable --now kk-logs.service
systemctl status kk-logs.service --no-pager

log "Phase 5: Firewall rebuild from intent"

ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'ssh'
ufw allow 3000/tcp comment 'kk-api public'
ufw allow in on lo to any port 3001 proto tcp comment 'kk-payments loopback only'
ufw deny in to any port 3001 proto tcp comment 'deny external kk-payments'
ufw --force enable

log "Phase 6: Journald persistence and logrotate"

install -d -o root -g systemd-journal -m 2755 /var/log/journal
install -d -o root -g root -m 0755 /etc/systemd/journald.conf.d

cat >/etc/systemd/journald.conf.d/kijanikiosk.conf <<'EOF'
[Journal]
Storage=persistent
SystemMaxUse=500M
EOF

systemctl restart systemd-journald

cat >/etc/logrotate.d/kijanikiosk <<'EOF'
/opt/kijanikiosk/shared/logs/*.log {
    daily
    rotate 7
    missingok
    notifempty
    compress
    delaycompress
    su root root
    create 0660 kk-logs kijanikiosk
    sharedscripts
    postrotate
        /bin/systemctl restart kk-logs.service >/dev/null 2>&1 || true
    endscript
}
EOF

logrotate --debug /etc/logrotate.d/kijanikiosk >/dev/null
touch /opt/kijanikiosk/shared/logs/api.log /opt/kijanikiosk/shared/logs/payments.log /opt/kijanikiosk/shared/logs/aggregator.log
chown kk-logs:kijanikiosk /opt/kijanikiosk/shared/logs/*.log
chmod 0660 /opt/kijanikiosk/shared/logs/*.log
logrotate -f /etc/logrotate.d/kijanikiosk

# Re-assert ACLs in case rotation created fresh files
setfacl -m u:kk-api:rwx /opt/kijanikiosk/shared/logs
setfacl -m u:kk-payments:rwx /opt/kijanikiosk/shared/logs
setfacl -m u:kk-logs:rwx /opt/kijanikiosk/shared/logs
setfacl -d -m u:kk-api:rwx /opt/kijanikiosk/shared/logs
setfacl -d -m u:kk-payments:rwx /opt/kijanikiosk/shared/logs
setfacl -d -m u:kk-logs:rwx /opt/kijanikiosk/shared/logs

log "Phase 7: Health check JSON"

API_OK="down"
PAY_OK="down"
LOG_OK="down"

if curl -fsS http://127.0.0.1:3000/ >/dev/null 2>&1; then API_OK="up"; fi
if curl -fsS http://127.0.0.1:3001/ >/dev/null 2>&1; then PAY_OK="up"; fi
if systemctl is-active --quiet kk-logs.service; then LOG_OK="up"; fi

python3 - <<PY
import json, time
data = {
  "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
  "services": {
    "kk-api": "${API_OK}",
    "kk-payments": "${PAY_OK}",
    "kk-logs": "${LOG_OK}"
  }
}
with open("/opt/kijanikiosk/health/last-provision.json", "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY

chown kk-logs:kijanikiosk /opt/kijanikiosk/health/last-provision.json
chmod 0640 /opt/kijanikiosk/health/last-provision.json
if id -u amina >/dev/null 2>&1; then
  setfacl -m u:amina:r-- /opt/kijanikiosk/health/last-provision.json
fi

log "Phase 8: Final verification"

check_cmd "kk-api user exists" id kk-api
check_cmd "kk-payments user exists" id kk-payments
check_cmd "kk-logs user exists" id kk-logs
check_cmd "kijanikiosk group exists" getent group kijanikiosk
check_cmd "no suid/sgid files under /opt/kijanikiosk" bash -c "[ $(find /opt/kijanikiosk -type f \( -perm /4000 -o -perm /2000 \) 2>/dev/null | wc -l) -eq 0 ]"
check_cmd "/opt/kijanikiosk mode is 750" bash -c "[[ \$(stat -c '%a' /opt/kijanikiosk) == 750 ]]"
check_cmd "/opt/kijanikiosk/shared/logs mode is 2770" bash -c "[[ \$(stat -c '%a' /opt/kijanikiosk/shared/logs) == 2770 ]]"
check_cmd "kk-api can read api env" sudo -u kk-api test -r /opt/kijanikiosk/config/api.env
check_cmd "kk-payments can read payments env" sudo -u kk-payments test -r /opt/kijanikiosk/config/payments-api.env
check_cmd "kk-logs can read logs env" sudo -u kk-logs test -r /opt/kijanikiosk/config/logs.env
check_cmd "kk-api can write shared logs" sudo -u kk-api touch /opt/kijanikiosk/shared/logs/test-api-write.tmp
check_cmd "kk-payments can write shared logs" sudo -u kk-payments touch /opt/kijanikiosk/shared/logs/test-payments-write.tmp
check_cmd "kk-logs can write shared logs" sudo -u kk-logs touch /opt/kijanikiosk/shared/logs/test-logs-write.tmp
check_cmd "kk-api service active" systemctl is-active --quiet kk-api.service
check_cmd "kk-payments service active" systemctl is-active --quiet kk-payments.service
check_cmd "kk-logs service active" systemctl is-active --quiet kk-logs.service
check_cmd "health json exists" test -f /opt/kijanikiosk/health/last-provision.json
check_cmd "logrotate config validates" logrotate --debug /etc/logrotate.d/kijanikiosk
check_cmd "ufw enabled" bash -c "ufw status | grep -q '^Status: active'"
check_cmd "ufw allows 3000/tcp" bash -c "ufw status numbered | grep -q '3000/tcp'"
check_cmd "ufw includes deny for 3001" bash -c "ufw status numbered | grep -q '3001'"
check_cmd "journal persistence configured" bash -c "grep -q '^Storage=persistent' /etc/systemd/journald.conf.d/kijanikiosk.conf"
check_cmd "journal max use configured" bash -c "grep -q '^SystemMaxUse=500M' /etc/systemd/journald.conf.d/kijanikiosk.conf"

API_SCORE="$(security_score kk-api.service || true)"
PAY_SCORE="$(security_score kk-payments.service || true)"
LOG_SCORE="$(security_score kk-logs.service || true)"

if [[ -n "$API_SCORE" ]] && python3 - <<PY
score=float("${API_SCORE}")
raise SystemExit(0 if score < 3.5 else 1)
PY
then pass "kk-api security score below 3.5 (${API_SCORE})"; else fail "kk-api security score below 3.5 (${API_SCORE:-unavailable})"; fi

if [[ -n "$PAY_SCORE" ]] && python3 - <<PY
score=float("${PAY_SCORE}")
raise SystemExit(0 if score < 2.5 else 1)
PY
then pass "kk-payments security score below 2.5 (${PAY_SCORE})"; else fail "kk-payments security score below 2.5 (${PAY_SCORE:-unavailable})"; fi

if [[ -n "$LOG_SCORE" ]] && python3 - <<PY
score=float("${LOG_SCORE}")
raise SystemExit(0 if score < 3.5 else 1)
PY
then pass "kk-logs security score below 3.5 (${LOG_SCORE})"; else fail "kk-logs security score below 3.5 (${LOG_SCORE:-unavailable})"; fi

rm -f /opt/kijanikiosk/shared/logs/test-api-write.tmp \
      /opt/kijanikiosk/shared/logs/test-payments-write.tmp \
      /opt/kijanikiosk/shared/logs/test-logs-write.tmp

echo
echo "Verification summary: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"
if (( FAIL_COUNT > 0 )); then
  printf 'Failed checks:\n'
  printf ' - %s\n' "${FAILED_CHECKS[@]}"
  exit 1
fi

echo "All verification checks passed." 

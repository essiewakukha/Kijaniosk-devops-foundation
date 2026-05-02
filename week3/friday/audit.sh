#!/bin/bash
echo "=== SERVICE ACCOUNTS ==="
getent passwd kk-api kk-payments kk-logs

echo "=== GROUP ==="
getent group kijanikiosk

echo "=== /opt/kijanikiosk LAYOUT ==="
ls -la /opt/kijanikiosk/

echo "=== ACL: shared/logs ==="
getfacl /opt/kijanikiosk/shared/logs/ 2>/dev/null

echo "=== ACL: config ==="
getfacl /opt/kijanikiosk/config/ 2>/dev/null

echo "=== UFW RULES ==="
sudo ufw status numbered

echo "=== PACKAGE HOLDS ==="
apt-mark showhold

echo "=== SYSTEMD UNITS ==="
systemctl list-unit-files | grep kk-

echo "=== SECURITY ANALYSIS: kk-api ==="
sudo systemd-analyze security kk-api.service 2>/dev/null | head -5

echo "=== LOG DISK USAGE ==="
du -sh /opt/kijanikiosk/shared/logs/

echo "=== JOURNAL DISK USAGE ==="
journalctl --disk-usage

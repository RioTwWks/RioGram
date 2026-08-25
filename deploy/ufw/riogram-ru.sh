#!/usr/bin/env bash
# UFW rules for RU frontend VPS (§8.4.4).
set -euo pipefail

echo "Applying UFW rules for RioGram RU frontend..."

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable
sudo ufw status verbose

echo "✅ RU UFW: SSH + Nginx (80/443) only"

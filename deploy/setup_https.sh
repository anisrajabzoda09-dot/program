#!/bin/bash
# ==============================================================
# NIGOH FAMILY — Automated HTTPS / SSL Setup for nigohfamily.qobus.tj
# Run this script with sudo on the server:
#   sudo bash /home/dev/munis/deploy/setup_https.sh
# ==============================================================

set -e

CONF_SRC="/home/dev/munis/deploy/nigohfamily.conf"
CONF_DEST="/etc/nginx/sites-available/nigohfamily"
CONF_LINK="/etc/nginx/sites-enabled/nigohfamily"

echo "=== 1. Нусхабардории конфигуратсияи Nginx ==="
cp "$CONF_SRC" "$CONF_DEST"
ln -sf "$CONF_DEST" "$CONF_LINK"

echo "=== 2. Санҷиши дурустии Nginx ==="
nginx -t

echo "=== 3. Аз нав боркунии Nginx ==="
systemctl reload nginx

echo "=== 4. Гирифтани сертификати ройгони SSL (Let's Encrypt / HTTPS) ==="
certbot --nginx -d nigohfamily.qobus.tj --non-interactive --agree-tos -m admin@qobus.tj || certbot --nginx -d nigohfamily.qobus.tj

echo "=== 5. Санҷиши пайванди амни HTTPS ==="
curl -sI https://nigohfamily.qobus.tj | head -n 5

echo ""
echo "🎉 Табрик! Сомонаи Нигоҳ дар пайванди амни зерин фаъол шуд:"
echo "👉 https://nigohfamily.qobus.tj"


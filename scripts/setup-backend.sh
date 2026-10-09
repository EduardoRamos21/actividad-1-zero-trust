#!/bin/bash
# ============================================================================
# setup-backend.sh — Instala la API SIN acceso a Internet
# ============================================================================
# El Backend no tiene Internet Gateway ni NAT. No ejecutes apt-get aquí.
# Este script espera que deploy-backend.sh ya haya copiado:
#   /tmp/node-linux-x64.tar.gz
#   /tmp/zerotrust-backend/   (código, node_modules y .env)
#
# Se ejecuta en el Backend como root:
#   sudo bash /tmp/setup-backend.sh
# ============================================================================

set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Ejecuta este script con sudo."
  exit 1
fi

if [[ ! -d /tmp/zerotrust-backend/src ]]; then
  echo "Falta /tmp/zerotrust-backend/src"
  echo "Copia el código desde el Frontend con deploy-backend.sh"
  exit 1
fi

if [[ ! -f /tmp/zerotrust-backend/.env ]]; then
  echo "Falta /tmp/zerotrust-backend/.env"
  exit 1
fi

if [[ ! -x /usr/local/bin/node ]]; then
  if [[ ! -f /tmp/node-linux-x64.tar.gz ]]; then
    echo "No hay Node.js y esta instancia no puede descargarlo."
    exit 1
  fi
  tar -xzf /tmp/node-linux-x64.tar.gz -C /usr/local --strip-components=1
fi

echo ">>> Node $(/usr/local/bin/node -v)"

rm -rf /opt/zerotrust-backend
mkdir -p /opt/zerotrust-backend
cp -a /tmp/zerotrust-backend/. /opt/zerotrust-backend/
sed -i 's/\r$//' /opt/zerotrust-backend/.env
chown -R ubuntu:ubuntu /opt/zerotrust-backend
chmod 600 /opt/zerotrust-backend/.env

cat > /etc/systemd/system/zerotrust-api.service <<'SERVICE'
[Unit]
Description=Zero Trust Backend API
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/zerotrust-backend
ExecStart=/usr/local/bin/node src/server.js
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=zerotrust-api

NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/zerotrust-backend
PrivateTmp=true

Environment=NODE_ENV=production
Environment=PORT=3000
EnvironmentFile=/opt/zerotrust-backend/.env

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable zerotrust-api
systemctl restart zerotrust-api
sleep 2
systemctl --no-pager --full status zerotrust-api
echo "API instalada. Prueba local: curl -fsS http://127.0.0.1:3000/api/health"

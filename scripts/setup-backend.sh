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

# ============================================================================
# UFW — Firewall de host en Backend (Zero Trust: defensa en profundidad)
# ============================================================================
# Variables de entorno esperadas (las pasa deploy-backend.sh):
#   FRONTEND_CIDR — CIDR de la VPC del Frontend (e.g. 10.0.0.0/16)
#   ADMIN_IP      — IP del admin /32 para SSH via peering (opcional)
FRONTEND_CIDR="${FRONTEND_CIDR:-10.0.0.0/16}"
ADMIN_IP="${ADMIN_IP:-}"

echo ">>> Configurando UFW en Backend"
echo "    Frontend CIDR: ${FRONTEND_CIDR}"
echo "    Admin IP:      ${ADMIN_IP:-no indicada}"

ufw --force reset

# Políticas por defecto: denegar TODO (entrada y salida)
ufw default deny incoming
ufw default deny outgoing

# API (puerto 3000) — SOLO desde la VPC del Frontend
ufw allow from "${FRONTEND_CIDR}" to any port 3000 proto tcp comment 'API desde Frontend'

# SSH — desde la VPC del Frontend (bastion pattern)
ufw allow from "${FRONTEND_CIDR}" to any port 22 proto tcp comment 'SSH desde Frontend (bastion)'

# Si se provee la IP del admin, permitir SSH directo (por si está ruteado)
if [[ -n "${ADMIN_IP}" ]]; then
  ufw allow from "${ADMIN_IP}" to any port 22 proto tcp comment 'SSH admin directo'
fi

# Egress: solo hacia el Frontend (respuestas API y SSH)
ufw allow out to "${FRONTEND_CIDR}" comment 'Salida hacia Frontend VPC'

# Permitir loopback (necesario para que la API responda a curl localhost)
ufw allow in on lo
ufw allow out on lo

ufw --force enable
echo "    UFW activo en Backend:"
ufw status verbose

echo ""
echo "API instalada y UFW configurado."
echo "Prueba local: curl -fsS http://127.0.0.1:3000/api/health"
echo "Estado UFW:   sudo ufw status numbered"

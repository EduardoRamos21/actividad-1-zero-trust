#!/bin/bash
# ============================================================================
# setup-frontend.sh — Nginx, Fail2Ban y Node en la instancia Frontend
# ============================================================================
# Ejecutar EN la EC2 del Frontend (Ubuntu 22.04), con sudo:
#
#   sudo ./setup-frontend.sh <DOMINIO> <IP_PRIVADA_BACKEND> [TU_IP_PUBLICA]
#
# Ejemplo:
#   sudo ./setup-frontend.sh miapp.duckdns.org 10.1.1.50 189.203.10.4
#
# Certbot se ejecuta después, con enable-https.sh, cuando el DNS ya apunte
# a la Elastic IP. Nginx arranca primero solo en el puerto 80: un bloque
# "listen 443 ssl" sin certificado impide que Nginx inicie.
# ============================================================================

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

if [[ "${EUID}" -ne 0 ]]; then
  echo "Ejecuta este script con sudo."
  exit 1
fi

if [[ "$#" -lt 2 ]]; then
  echo "Uso: sudo $0 <DOMINIO> <IP_PRIVADA_BACKEND> [TU_IP_PUBLICA]"
  echo "Ejemplo: sudo $0 miapp.duckdns.org 10.1.1.50 189.203.10.4"
  exit 1
fi

DOMAIN="$1"
BACKEND_IP="$2"
ADMIN_IP="${3:-}"
BACKEND_PORT=3000

echo "Dominio:    ${DOMAIN}"
echo "Backend:    ${BACKEND_IP}:${BACKEND_PORT}"
echo "IP admin:   ${ADMIN_IP:-no indicada; Fail2Ban puede bloquearte si pruebas desde tu propia IP}"

echo ">>> [1/5] Paquetes base"
apt-get update -y
apt-get install -y nginx curl ca-certificates xz-utils fail2ban certbot python3-certbot-nginx

echo ">>> [2/5] Node.js 20 (para construir o para npm install del backend)"
if ! command -v node >/dev/null 2>&1; then
  if curl -fsSL https://deb.nodesource.com/setup_20.x | bash -; then
    apt-get install -y nodejs
  fi
fi
if ! command -v node >/dev/null 2>&1; then
  NODE_VERSION="v20.18.1"
  curl -fsSL -o /tmp/node.tar.gz "https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-linux-x64.tar.gz"
  tar -xzf /tmp/node.tar.gz -C /usr/local --strip-components=1
fi
echo "    Node $(node -v) / npm $(npm -v)"

echo ">>> [3/5] Encabezados de seguridad (SecurityHeaders.com)"
mkdir -p /etc/nginx/snippets
cat > /etc/nginx/snippets/zerotrust-headers.conf <<'HEADERS'
# Encabezados que SecurityHeaders.com evalúa sobre el sitio público.
# CSP permite las fuentes de Google usadas por la interfaz; el resto es mismo origen.
add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data:; connect-src 'self'; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'; upgrade-insecure-requests" always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
add_header X-Frame-Options "DENY" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=(), interest-cohort=()" always;
add_header Cross-Origin-Opener-Policy "same-origin" always;
add_header Cross-Origin-Resource-Policy "same-origin" always;
add_header X-Permitted-Cross-Domain-Policies "none" always;
HEADERS

echo ">>> [4/5] Nginx como proxy inverso (HTTP; el 443 lo agrega Certbot)"
mkdir -p "/var/www/${DOMAIN}/html"
if [[ ! -f "/var/www/${DOMAIN}/html/index.html" ]]; then
  cat > "/var/www/${DOMAIN}/html/index.html" <<EOF
<!doctype html>
<html lang="es"><head><meta charset="utf-8"><title>Zero Trust</title></head>
<body><h1>Frontend pendiente de publicar</h1><p>${DOMAIN}</p></body></html>
EOF
fi

cat > "/etc/nginx/sites-available/${DOMAIN}" <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    server_tokens off;
    client_max_body_size 1m;

    include /etc/nginx/snippets/zerotrust-headers.conf;

    access_log /var/log/nginx/access.log;
    error_log  /var/log/nginx/error.log;

    root /var/www/${DOMAIN}/html;
    index index.html;

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location /api/ {
        proxy_pass http://${BACKEND_IP}:${BACKEND_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 10s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location ~ /\\. {
        deny all;
    }
}
EOF

ln -sfn "/etc/nginx/sites-available/${DOMAIN}" /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# El ALB es el cliente TCP. Sin esto, Fail2Ban vería la IP del balanceador.
cat > /etc/nginx/conf.d/real-ip-alb.conf <<'EOF'
set_real_ip_from 10.0.0.0/16;
real_ip_header X-Forwarded-For;
real_ip_recursive on;
EOF

nginx -t
systemctl enable nginx
systemctl restart nginx

echo ">>> [5/5] Fail2Ban — ban tras 3 logins fallidos"
# backend=auto lee archivos de log. backend=systemd los ignora.
# action_ sin correo: action_mwl exige sendmail y tumba el jail.
cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime  = 1800
findtime = 600
maxretry = 3
backend  = auto
banaction = iptables-multiport
ignoreip = 127.0.0.1/8 ::1 ${ADMIN_IP}

[sshd]
enabled  = true
port     = ssh
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 3
backend  = auto

[nginx-login-abuse]
enabled  = true
port     = http,https
filter   = nginx-login-abuse
logpath  = /var/log/nginx/access.log
maxretry = 3
findtime = 300
bantime  = 3600
backend  = auto
EOF

cat > /etc/fail2ban/filter.d/nginx-login-abuse.conf <<'F2B_FILTER'
[Definition]
failregex = ^<HOST> -.*"(GET|POST) /api/auth/login HTTP.*" 401
ignoreregex =
datepattern = %%d/%%b/%%ExY:%%H:%%M:%%S
F2B_FILTER

systemctl enable fail2ban
systemctl restart fail2ban

echo ">>> Prueba del filtro con una línea de ejemplo"
SAMPLE=/tmp/fail2ban-sample.log
echo '203.0.113.50 - - [07/Oct/2026:12:00:00 +0000] "POST /api/auth/login HTTP/1.1" 401 80 "-" "curl/8.0"' > "${SAMPLE}"
fail2ban-regex "${SAMPLE}" /etc/fail2ban/filter.d/nginx-login-abuse.conf || true

# ============================================================================
# [6/6] UFW — Firewall de host (Zero Trust: defensa en profundidad)
# ============================================================================
echo ">>> [6/6] Configurando UFW en Frontend"

# Resetear para partir de un estado limpio (no interactivo)
ufw --force reset

# Políticas por defecto: denegar todo entrante, permitir saliente
ufw default deny incoming
ufw default allow outgoing

# Puerto 80 — HTTP (Nginx, Certbot challenge, redirige a HTTPS)
ufw allow 80/tcp comment 'HTTP - Nginx / Certbot'

# Puerto 443 — HTTPS (tráfico web público)
ufw allow 443/tcp comment 'HTTPS - Nginx'

# SSH — SOLO desde la IP del administrador (/32)
if [[ -n "${ADMIN_IP}" ]]; then
  ufw allow from "${ADMIN_IP}" to any port 22 proto tcp comment 'SSH admin'
  echo "    SSH permitido solo desde ${ADMIN_IP}"
else
  echo "    ⚠️  No se indicó IP admin; SSH abierto temporalmente a todo."
  echo "       Cierra esto después con: ufw delete allow 22/tcp"
  ufw allow 22/tcp comment 'SSH temporal - cerrar después'
fi

# Activar UFW (--force para no pedir confirmación)
ufw --force enable
echo "    UFW activo:"
ufw status verbose

echo ""
echo "Nginx, Fail2Ban y UFW quedaron activos en HTTP."
echo "Siguiente paso, cuando el DNS de ${DOMAIN} apunte a la Elastic IP:"
echo "  sudo $(dirname "$0")/enable-https.sh ${DOMAIN}"
echo "Publica el build de React en /var/www/${DOMAIN}/html/"
echo "Estado de Fail2Ban: sudo fail2ban-client status nginx-login-abuse"
echo "Estado de UFW:      sudo ufw status numbered"

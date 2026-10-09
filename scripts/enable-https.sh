#!/bin/bash
# ============================================================================
# enable-https.sh — Certificado Let's Encrypt y redirección a HTTPS
# ============================================================================
# Ejecutar EN el Frontend cuando el dominio ya resuelva a la Elastic IP.
#
#   sudo ./enable-https.sh <DOMINIO> [correo]
#
# Sin correo, Let's Encrypt acepta el registro con --register-unsafely-without-email.
# ============================================================================

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

if [[ "${EUID}" -ne 0 ]]; then
  echo "Ejecuta este script con sudo."
  exit 1
fi

DOMAIN="${1:-}"
EMAIL="${2:-}"

if [[ -z "${DOMAIN}" ]]; then
  echo "Uso: sudo $0 <DOMINIO> [correo]"
  exit 1
fi

apt-get update -y
apt-get install -y certbot python3-certbot-nginx

echo ">>> Comprobando que ${DOMAIN} resuelve y que el puerto 80 responde"
getent hosts "${DOMAIN}" || true

if [[ -n "${EMAIL}" ]]; then
  certbot --nginx -d "${DOMAIN}" --non-interactive --agree-tos -m "${EMAIL}" --redirect
else
  certbot --nginx -d "${DOMAIN}" --non-interactive --agree-tos --register-unsafely-without-email --redirect
fi

# Certbot copia el server de :80 a :443 e incluye el snippet de encabezados.
nginx -t
systemctl reload nginx

echo ""
echo ">>> Certificados"
certbot certificates

echo ""
echo ">>> Encabezados HTTPS (esto es lo que evalúa SecurityHeaders.com)"
curl -fsSI "https://${DOMAIN}" | sed -n '1,40p' || echo "No pude leer https://${DOMAIN} desde el propio servidor."

echo ""
echo "Renovación automática: el paquete certbot deja un timer de systemd."
echo "  systemctl list-timers | grep certbot"
echo "  sudo certbot renew --dry-run"

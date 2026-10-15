#!/bin/bash
# ============================================================================
# deploy-backend.sh — Empaqueta la API en el Frontend y la envía al Backend
# ============================================================================
# Ejecutar EN el Frontend, como usuario ubuntu (no como root):
#
#   ./deploy-backend.sh <IP_PRIVADA_BACKEND> <LLAVE.pem> <URL_PUBLICA>
#
# Ejemplo:
#   ./deploy-backend.sh 10.1.1.50 ~/.ssh/lab-key.pem https://miapp.duckdns.org
#
# Antes, copia la carpeta backend del proyecto a ~/zerotrust-backend
# El Backend no tiene Internet: npm install ocurre aquí y Node viaja en un tar.gz.
# ============================================================================

set -euo pipefail

if [[ "$#" -lt 3 ]]; then
  echo "Uso: $0 <IP_PRIVADA_BACKEND> <LLAVE.pem> <URL_PUBLICA>"
  echo "Ejemplo: $0 10.1.1.50 ~/.ssh/lab-key.pem https://miapp.duckdns.org"
  exit 1
fi

BACKEND_IP="$1"
KEY_PATH="$2"
PUBLIC_URL="$3"
SRC="${SRC:-${HOME}/zerotrust-backend}"
NODE_VERSION="${NODE_VERSION:-v20.18.1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "${KEY_PATH}" ]]; then
  echo "No encuentro la llave: ${KEY_PATH}"
  exit 1
fi
if [[ ! -f "${SRC}/package.json" ]]; then
  echo "No encuentro ${SRC}/package.json"
  echo "Desde tu PC: scp -i llave.pem -r backend ubuntu@ELASTIC_IP:~/zerotrust-backend"
  exit 1
fi
if ! command -v npm >/dev/null 2>&1; then
  echo "npm no está instalado. Primero: sudo ./setup-frontend.sh"
  exit 1
fi

chmod 400 "${KEY_PATH}"
SSH_OPTS=(-i "${KEY_PATH}" -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes)

echo ">>> Dependencias de producción (en el Frontend, que sí tiene Internet)"
cd "${SRC}"
npm install --omit=dev

if [[ ! -f "${SRC}/.env" ]]; then
  SECRET="$(openssl rand -hex 64)"
  umask 077
  cat > "${SRC}/.env" <<EOF
PORT=3000
JWT_SECRET=${SECRET}
JWT_EXPIRES_IN=1h
CORS_ORIGIN=${PUBLIC_URL}
NODE_ENV=production
EOF
  echo ">>> .env creado con un JWT_SECRET nuevo"
else
  echo ">>> Se conserva el .env existente"
fi

TARBALL="/tmp/node-${NODE_VERSION}-linux-x64.tar.gz"
if [[ ! -f "${TARBALL}" ]]; then
  echo ">>> Descargando Node.js ${NODE_VERSION}"
  curl -fsSL -o "${TARBALL}" "https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-linux-x64.tar.gz"
fi

echo ">>> Enviando archivos a ${BACKEND_IP} por la red del peering"
tar -C "${SRC}" -czf /tmp/zerotrust-backend.tgz .
ssh "${SSH_OPTS[@]}" "ubuntu@${BACKEND_IP}" "rm -rf /tmp/zerotrust-backend && mkdir -p /tmp/zerotrust-backend"
scp "${SSH_OPTS[@]}" "${TARBALL}" "ubuntu@${BACKEND_IP}:/tmp/node-linux-x64.tar.gz"
scp "${SSH_OPTS[@]}" "${SCRIPT_DIR}/setup-backend.sh" "ubuntu@${BACKEND_IP}:/tmp/setup-backend.sh"
scp "${SSH_OPTS[@]}" /tmp/zerotrust-backend.tgz "ubuntu@${BACKEND_IP}:/tmp/zerotrust-backend.tgz"
ssh "${SSH_OPTS[@]}" "ubuntu@${BACKEND_IP}" "tar -xzf /tmp/zerotrust-backend.tgz -C /tmp/zerotrust-backend"

echo ">>> Instalando el servicio en el Backend (con UFW)"
FRONTEND_CIDR="${FRONTEND_CIDR:-10.0.0.0/16}"
ssh "${SSH_OPTS[@]}" "ubuntu@${BACKEND_IP}" "sudo FRONTEND_CIDR='${FRONTEND_CIDR}' ADMIN_IP='${ADMIN_IP:-}' bash /tmp/setup-backend.sh"

echo ">>> Salud de la API, vista desde el Frontend"
curl -fsS "http://${BACKEND_IP}:3000/api/health"
echo ""
echo "Backend en marcha. El navegador debe entrar por https://${PUBLIC_URL#https://}/api (Nginx), no por el puerto 3000."

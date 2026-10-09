// ============================================================================
// server.js - Punto de entrada del servidor
// ============================================================================
// Inicia el servidor Express en el puerto configurado
// ============================================================================

const app = require('./app');
const config = require('./config');

app.listen(config.port, '0.0.0.0', () => {
  console.log('╔══════════════════════════════════════════════════════════╗');
  console.log('║         ZERO TRUST BACKEND - API REST SEGURA            ║');
  console.log('╠══════════════════════════════════════════════════════════╣');
  console.log(`║  Estado:     ✅ Servidor activo                         ║`);
  console.log(`║  Puerto:     ${config.port}                                      ║`);
  console.log(`║  Entorno:    ${config.nodeEnv.padEnd(40)}║`);
  console.log(`║  CORS:       ${config.cors.origin.substring(0, 40).padEnd(40)}║`);
  console.log('║  Seguridad:  Helmet + JWT + Rate Limit + CORS           ║');
  console.log('╠══════════════════════════════════════════════════════════╣');
  console.log('║  Endpoints:                                             ║');
  console.log('║    POST /api/auth/login    → Iniciar sesión             ║');
  console.log('║    POST /api/auth/verify   → Verificar token           ║');
  console.log('║    GET  /api/dashboard     → Dashboard (protegido)     ║');
  console.log('║    GET  /api/health        → Health check              ║');
  console.log('╚══════════════════════════════════════════════════════════╝');
});

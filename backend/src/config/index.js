// ============================================================================
// config/index.js - Configuración centralizada del Backend
// ============================================================================
// Zero Trust: Todas las variables sensibles vienen de variables de entorno
// Nunca hardcodear secretos directamente en el código
// ============================================================================

require('dotenv').config();

const config = {
  // Servidor
  port: parseInt(process.env.PORT, 10) || 3000,
  nodeEnv: process.env.NODE_ENV || 'development',

  // JWT
  jwt: {
    secret: process.env.JWT_SECRET || 'default-dev-secret-CAMBIAR-EN-PRODUCCION',
    expiresIn: process.env.JWT_EXPIRES_IN || '1h',
  },

  // CORS
  cors: {
    origin: process.env.CORS_ORIGIN || 'http://localhost:5173',
  },
};

// Validación de seguridad al iniciar
const secretIsPlaceholder =
  config.jwt.secret.includes('CAMBIAR') ||
  config.jwt.secret.includes('CAMBIA_') ||
  config.jwt.secret.includes('default-dev-secret');

if (config.nodeEnv === 'production' && (secretIsPlaceholder || config.jwt.secret.length < 32)) {
  console.error('ERROR CRITICO: JWT_SECRET no es valido para produccion.');
  console.error('   Genera uno con: node -e "console.log(require(\'crypto\').randomBytes(64).toString(\'hex\'))"');
  process.exit(1);
}

module.exports = config;

// ============================================================================
// services/authService.js - Lógica de negocio de Autenticación
// ============================================================================
// Capa de servicio desacoplada de Express (Clean Architecture)
// Contiene TODA la lógica de negocio: validación, hashing, generación de JWT
// ============================================================================

const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const config = require('../config');

// --------------------------------------------------------------------------
// "Base de datos" en memoria para la práctica
// En producción se reemplazaría por una conexión a PostgreSQL/MongoDB
// --------------------------------------------------------------------------
const users = [
  {
    id: 1,
    username: 'admin',
    // Contraseña: "Admin123!" (hasheada con bcrypt, 12 rondas de salt)
    // Generada con: bcrypt.hashSync('Admin123!', 12)
    password: bcrypt.hashSync('Admin123!', 12),
    role: 'administrator',
    fullName: 'Administrador del Sistema',
  },
  {
    id: 2,
    username: 'auditor',
    // Contraseña: "Auditor123!"
    password: bcrypt.hashSync('Auditor123!', 12),
    role: 'auditor',
    fullName: 'Auditor de Seguridad',
  },
];

// --------------------------------------------------------------------------
// Autenticar usuario (validar credenciales y generar JWT)
// --------------------------------------------------------------------------
async function authenticate(username, password) {
  // 1. Buscar usuario por username
  const user = users.find((u) => u.username === username);
  if (!user) {
    // Zero Trust: No revelar si el usuario existe o no
    throw new AuthError('Credenciales inválidas', 401);
  }

  // 2. Comparar contraseña con hash almacenado
  const isValidPassword = await bcrypt.compare(password, user.password);
  if (!isValidPassword) {
    throw new AuthError('Credenciales inválidas', 401);
  }

  // 3. Generar JWT con claims mínimos (principio de mínimo privilegio)
  const tokenPayload = {
    sub: user.id,
    username: user.username,
    role: user.role,
  };

  const token = jwt.sign(tokenPayload, config.jwt.secret, {
    expiresIn: config.jwt.expiresIn,
    issuer: 'zerotrust-backend',
    audience: 'zerotrust-frontend',
  });

  // 4. Retornar datos del usuario (sin contraseña) y el token
  return {
    token,
    user: {
      id: user.id,
      username: user.username,
      role: user.role,
      fullName: user.fullName,
    },
  };
}

// --------------------------------------------------------------------------
// Verificar y decodificar un JWT
// --------------------------------------------------------------------------
function verifyToken(token) {
  try {
    const decoded = jwt.verify(token, config.jwt.secret, {
      issuer: 'zerotrust-backend',
      audience: 'zerotrust-frontend',
    });
    return decoded;
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      throw new AuthError('Token expirado. Inicia sesión nuevamente.', 401);
    }
    throw new AuthError('Token inválido.', 403);
  }
}

// --------------------------------------------------------------------------
// Clase de error personalizada para autenticación
// --------------------------------------------------------------------------
class AuthError extends Error {
  constructor(message, statusCode = 401) {
    super(message);
    this.name = 'AuthError';
    this.statusCode = statusCode;
  }
}

module.exports = {
  authenticate,
  verifyToken,
  AuthError,
};

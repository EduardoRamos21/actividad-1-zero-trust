// ============================================================================
// middleware/authMiddleware.js - Middleware de autenticación JWT
// ============================================================================
// Zero Trust: Cada solicitud debe ser autenticada y autorizada
// No se confía en ninguna solicitud automáticamente
// ============================================================================

const { verifyToken, AuthError } = require('../services/authService');

// --------------------------------------------------------------------------
// Middleware: Verificar JWT en cada solicitud protegida
// --------------------------------------------------------------------------
function authenticateToken(req, res, next) {
  // 1. Extraer el token del header Authorization
  const authHeader = req.headers['authorization'];

  if (!authHeader) {
    return res.status(401).json({
      success: false,
      error: 'Acceso denegado. No se proporcionó token de autenticación.',
    });
  }

  // 2. Validar formato "Bearer <token>"
  const parts = authHeader.split(' ');
  if (parts.length !== 2 || parts[0] !== 'Bearer') {
    return res.status(401).json({
      success: false,
      error: 'Formato de token inválido. Usa: Bearer <token>',
    });
  }

  const token = parts[1];

  // 3. Verificar y decodificar el token
  try {
    const decoded = verifyToken(token);

    // 4. Adjuntar datos del usuario decodificado al request
    req.user = {
      id: decoded.sub,
      username: decoded.username,
      role: decoded.role,
    };

    next();
  } catch (error) {
    if (error instanceof AuthError) {
      return res.status(error.statusCode).json({
        success: false,
        error: error.message,
      });
    }

    return res.status(403).json({
      success: false,
      error: 'Token inválido o expirado.',
    });
  }
}

// --------------------------------------------------------------------------
// Middleware: Verificar rol del usuario (autorización)
// --------------------------------------------------------------------------
function authorizeRoles(...allowedRoles) {
  return (req, res, next) => {
    if (!req.user || !allowedRoles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        error: 'No tienes permisos para acceder a este recurso.',
      });
    }
    next();
  };
}

module.exports = {
  authenticateToken,
  authorizeRoles,
};

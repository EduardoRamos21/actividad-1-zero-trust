// ============================================================================
// middleware/errorHandler.js - Manejador centralizado de errores
// ============================================================================
// Zero Trust: No revelar información interna del servidor en los errores
// ============================================================================

const { AuthError } = require('../services/authService');

function errorHandler(err, req, res, _next) {
  // Log interno (visible solo en el servidor)
  console.error(`[${new Date().toISOString()}] ERROR:`, {
    method: req.method,
    path: req.path,
    ip: req.ip,
    error: err.message,
    stack: process.env.NODE_ENV !== 'production' ? err.stack : undefined,
  });

  // Errores de autenticación
  if (err instanceof AuthError) {
    return res.status(err.statusCode).json({
      success: false,
      error: err.message,
    });
  }

  // Errores de validación (body malformado)
  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({
      success: false,
      error: 'El cuerpo de la solicitud tiene formato JSON inválido.',
    });
  }

  // Error genérico (no revelar detalles internos - Zero Trust)
  res.status(err.statusCode || 500).json({
    success: false,
    error:
      process.env.NODE_ENV === 'production'
        ? 'Error interno del servidor.'
        : err.message,
  });
}

module.exports = errorHandler;

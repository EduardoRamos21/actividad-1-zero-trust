// ============================================================================
// middleware/rateLimiter.js - Limitador de tasa de solicitudes
// ============================================================================
// Zero Trust: Protección contra fuerza bruta y abuso de la API
// ============================================================================

const rateLimit = require('express-rate-limit');

// Limiter general para toda la API
const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutos
  max: 100,                  // Máximo 100 solicitudes por ventana
  standardHeaders: true,     // Retorna info en headers `RateLimit-*`
  legacyHeaders: false,      // Deshabilita headers `X-RateLimit-*`
  message: {
    success: false,
    error: 'Demasiadas solicitudes. Intenta de nuevo en 15 minutos.',
  },
});

// Limiter estricto para endpoint de login (anti fuerza bruta)
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutos
  max: 10,                   // Máximo 10 intentos de login por ventana
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    error: 'Demasiados intentos de inicio de sesión. Intenta de nuevo en 15 minutos.',
  },
  // Registrar intentos bloqueados
  handler: (req, res, next, options) => {
    console.warn(`[RATE-LIMIT] IP bloqueada por exceso de intentos de login: ${req.ip}`);
    res.status(options.statusCode).json(options.message);
  },
});

module.exports = {
  generalLimiter,
  loginLimiter,
};

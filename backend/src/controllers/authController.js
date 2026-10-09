// ============================================================================
// controllers/authController.js - Controlador de Autenticación
// ============================================================================
// Capa de controlador: recibe HTTP request, delega al servicio, retorna response
// No contiene lógica de negocio (Clean Architecture)
// ============================================================================

const authService = require('../services/authService');

// --------------------------------------------------------------------------
// POST /api/auth/login - Iniciar sesión
// --------------------------------------------------------------------------
async function login(req, res, next) {
  try {
    const { username, password } = req.body;

    // Validación de entrada
    if (!username || !password) {
      return res.status(400).json({
        success: false,
        error: 'Se requieren usuario y contraseña.',
      });
    }

    // Validar longitud (prevenir ataques de payload excesivo)
    if (username.length > 50 || password.length > 128) {
      return res.status(400).json({
        success: false,
        error: 'Credenciales inválidas.',
      });
    }

    // Delegar al servicio de autenticación
    const result = await authService.authenticate(username, password);

    // Log de auditoría (visible en servidor, útil para Fail2Ban)
    console.log(
      `[AUTH-SUCCESS] Login exitoso: usuario="${username}" ip=${req.ip} timestamp=${new Date().toISOString()}`
    );

    res.status(200).json({
      success: true,
      data: result,
    });
  } catch (error) {
    // Log de intento fallido (Fail2Ban puede monitorear estos logs)
    console.warn(
      `[AUTH-FAILURE] Login fallido: usuario="${req.body?.username || 'unknown'}" ip=${req.ip} timestamp=${new Date().toISOString()}`
    );
    next(error);
  }
}

// --------------------------------------------------------------------------
// POST /api/auth/verify - Verificar si un token sigue siendo válido
// --------------------------------------------------------------------------
function verify(req, res) {
  // Si llega aquí, el middleware authenticateToken ya validó el token
  res.status(200).json({
    success: true,
    data: {
      valid: true,
      user: req.user,
    },
  });
}

module.exports = {
  login,
  verify,
};

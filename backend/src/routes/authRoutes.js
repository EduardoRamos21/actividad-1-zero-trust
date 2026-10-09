// ============================================================================
// routes/authRoutes.js - Rutas de Autenticación
// ============================================================================

const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const { authenticateToken } = require('../middleware/authMiddleware');
const { loginLimiter } = require('../middleware/rateLimiter');

// POST /api/auth/login - Iniciar sesión (con rate limit estricto)
router.post('/login', loginLimiter, authController.login);

// POST /api/auth/verify - Verificar token (requiere JWT válido)
router.post('/verify', authenticateToken, authController.verify);

module.exports = router;

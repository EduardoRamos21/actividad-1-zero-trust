// ============================================================================
// routes/dashboardRoutes.js - Rutas del Dashboard (Protegidas)
// ============================================================================

const express = require('express');
const router = express.Router();
const dashboardController = require('../controllers/dashboardController');
const { authenticateToken } = require('../middleware/authMiddleware');

// Todas las rutas de dashboard requieren autenticación JWT (Zero Trust)
router.use(authenticateToken);

// GET /api/dashboard - Datos del dashboard
router.get('/', dashboardController.getDashboard);

// GET /api/dashboard/health - Estado de salud
router.get('/health', dashboardController.getHealth);

module.exports = router;

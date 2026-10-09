// ============================================================================
// controllers/dashboardController.js - Controlador del Dashboard
// ============================================================================
// Endpoint protegido: solo accesible con JWT válido
// ============================================================================

const dashboardService = require('../services/dashboardService');

// --------------------------------------------------------------------------
// GET /api/dashboard - Obtener datos del dashboard
// --------------------------------------------------------------------------
function getDashboard(req, res) {
  const data = dashboardService.getDashboardData(req.user);

  res.status(200).json({
    success: true,
    data,
  });
}

// --------------------------------------------------------------------------
// GET /api/dashboard/health - Estado de salud del sistema
// --------------------------------------------------------------------------
function getHealth(req, res) {
  const health = dashboardService.getHealthCheck();

  res.status(200).json({
    success: true,
    data: health,
  });
}

module.exports = {
  getDashboard,
  getHealth,
};

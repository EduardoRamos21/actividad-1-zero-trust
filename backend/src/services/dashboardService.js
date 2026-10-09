// ============================================================================
// services/dashboardService.js - Lógica de negocio del Dashboard
// ============================================================================
// Capa de servicio desacoplada de Express (Clean Architecture)
// Simula datos del dashboard que solo usuarios autenticados pueden ver
// ============================================================================

// --------------------------------------------------------------------------
// Obtener datos del dashboard para un usuario autenticado
// --------------------------------------------------------------------------
function getDashboardData(user) {
  return {
    message: `Bienvenido al Dashboard, ${user.username}`,
    role: user.role,
    timestamp: new Date().toISOString(),
    serverInfo: {
      nodeVersion: process.version,
      platform: process.platform,
      uptime: `${Math.floor(process.uptime())} segundos`,
      memoryUsage: `${Math.round(process.memoryUsage().heapUsed / 1024 / 1024)} MB`,
    },
    securityStatus: {
      jwtValidated: true,
      httpsEnforced: true,
      corsRestricted: true,
      helmetHeaders: true,
      rateLimitActive: true,
      zeroTrustCompliant: true,
    },
    stats: {
      totalUsers: 2,
      activeConnections: 1,
      securityEvents: Math.floor(Math.random() * 100),
      blockedIPs: Math.floor(Math.random() * 20),
      lastScan: new Date().toISOString(),
    },
  };
}

// --------------------------------------------------------------------------
// Obtener estado de salud del sistema
// --------------------------------------------------------------------------
function getHealthCheck() {
  return {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: '1.0.0',
  };
}

module.exports = {
  getDashboardData,
  getHealthCheck,
};

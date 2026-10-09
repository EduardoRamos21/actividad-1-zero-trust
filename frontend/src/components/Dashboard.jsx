// ============================================================================
// components/Dashboard.jsx - Dashboard protegido con JWT
// ============================================================================
// Solo se renderiza si el usuario tiene un JWT válido
// Muestra datos del servidor obtenidos del Backend protegido
// ============================================================================

import { useState, useEffect } from 'react';
import { useAuth } from '../context/AuthContext';
import { dashboardApi } from '../services/api';
import './Dashboard.css';

export default function Dashboard() {
  const { user, logout } = useAuth();
  const [dashData, setDashData] = useState(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);

  // Cargar datos del dashboard al montar
  useEffect(() => {
    async function fetchDashboard() {
      try {
        const response = await dashboardApi.getData();
        setDashData(response.data);
      } catch (err) {
        setError(err.message || 'Error al cargar los datos del dashboard.');
        // Si el token expiró, cerrar sesión
        if (err.statusCode === 401 || err.statusCode === 403) {
          logout();
        }
      } finally {
        setLoading(false);
      }
    }

    fetchDashboard();
  }, [logout]);

  if (loading) {
    return (
      <div className="loading-screen">
        <div className="loading-spinner" />
        <p>Cargando dashboard...</p>
      </div>
    );
  }

  return (
    <div className="dashboard-layout">
      {/* Header / Navbar */}
      <header className="dashboard-header">
        <div className="header-brand">
          <div className="brand-icon">🛡️</div>
          <h2>Zero Trust Dashboard</h2>
        </div>
        <div className="header-user">
          <div className="user-info">
            <div className="user-name">{user?.fullName || user?.username}</div>
            <div className="user-role">{user?.role}</div>
          </div>
          <button className="logout-btn" onClick={logout}>
            Cerrar Sesión
          </button>
        </div>
      </header>

      {/* Contenido principal */}
      <main className="dashboard-main">
        {/* Bienvenida */}
        <div className="dashboard-welcome">
          <h1>Bienvenido, {user?.username} 👋</h1>
          <p>Panel de control de seguridad — Última consulta: {new Date().toLocaleString('es-MX')}</p>
        </div>

        {error && (
          <div className="dashboard-error">
            <p>⚠️ {error}</p>
            <button onClick={() => window.location.reload()}>Reintentar</button>
          </div>
        )}

        {dashData && (
          <>
            {/* Tarjetas de estadísticas */}
            <div className="stats-grid">
              <div className="stat-card">
                <div className="stat-icon">👥</div>
                <div className="stat-value">{dashData.stats.totalUsers}</div>
                <div className="stat-label">Usuarios Registrados</div>
              </div>
              <div className="stat-card">
                <div className="stat-icon">🔗</div>
                <div className="stat-value">{dashData.stats.activeConnections}</div>
                <div className="stat-label">Conexiones Activas</div>
              </div>
              <div className="stat-card">
                <div className="stat-icon">🔔</div>
                <div className="stat-value">{dashData.stats.securityEvents}</div>
                <div className="stat-label">Eventos de Seguridad</div>
              </div>
              <div className="stat-card">
                <div className="stat-icon">🚫</div>
                <div className="stat-value">{dashData.stats.blockedIPs}</div>
                <div className="stat-label">IPs Bloqueadas</div>
              </div>
            </div>

            {/* Panel de verificaciones de seguridad */}
            <div className="security-panel">
              <div className="panel-header">
                <h3>🔒 Estado de Seguridad Zero Trust</h3>
                <span className="panel-status active">● Activo</span>
              </div>
              <div className="security-checks">
                {Object.entries(dashData.securityStatus).map(([key, value]) => (
                  <div className="check-item" key={key}>
                    <span className="check-icon">{value ? '✅' : '❌'}</span>
                    <span>{formatCheckName(key)}</span>
                  </div>
                ))}
              </div>
            </div>

            {/* Información del servidor */}
            <div className="server-info">
              <h3>🖥️ Información del Servidor</h3>
              <div className="info-grid">
                <div className="info-item">
                  <span className="info-label">Node.js</span>
                  <span className="info-value">{dashData.serverInfo.nodeVersion}</span>
                </div>
                <div className="info-item">
                  <span className="info-label">Plataforma</span>
                  <span className="info-value">{dashData.serverInfo.platform}</span>
                </div>
                <div className="info-item">
                  <span className="info-label">Uptime</span>
                  <span className="info-value">{dashData.serverInfo.uptime}</span>
                </div>
                <div className="info-item">
                  <span className="info-label">Memoria</span>
                  <span className="info-value">{dashData.serverInfo.memoryUsage}</span>
                </div>
              </div>
            </div>
          </>
        )}
      </main>
    </div>
  );
}

// Helper: Formatear nombre de verificación de seguridad
function formatCheckName(key) {
  const names = {
    jwtValidated: 'JWT Validado',
    httpsEnforced: 'HTTPS Forzado',
    corsRestricted: 'CORS Restringido',
    helmetHeaders: 'Headers Helmet',
    rateLimitActive: 'Rate Limit Activo',
    zeroTrustCompliant: 'Zero Trust Compliant',
  };
  return names[key] || key;
}

// ============================================================================
// App.jsx - Componente raíz de la aplicación
// ============================================================================
// Enruta entre Login y Dashboard según el estado de autenticación
// ============================================================================

import { useAuth } from './context/AuthContext';
import Login from './components/Login';
import Dashboard from './components/Dashboard';
import ProtectedRoute from './components/ProtectedRoute';

export default function App() {
  const { isAuthenticated, loading } = useAuth();

  // Pantalla de carga inicial (verificando token existente)
  if (loading) {
    return (
      <div className="loading-screen">
        <div className="loading-spinner" />
        <p>Inicializando Zero Trust Portal...</p>
      </div>
    );
  }

  // Si no está autenticado: mostrar Login
  if (!isAuthenticated) {
    return <Login />;
  }

  // Si está autenticado: mostrar Dashboard protegido
  return (
    <ProtectedRoute>
      <Dashboard />
    </ProtectedRoute>
  );
}

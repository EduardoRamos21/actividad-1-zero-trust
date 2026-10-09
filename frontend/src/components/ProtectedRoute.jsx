// ============================================================================
// components/ProtectedRoute.jsx - Ruta protegida con verificación JWT
// ============================================================================
// Zero Trust: Verifica autenticación antes de renderizar contenido protegido
// ============================================================================

import { useAuth } from '../context/AuthContext';

export default function ProtectedRoute({ children }) {
  const { isAuthenticated, loading } = useAuth();

  // Mientras verifica el token, mostrar spinner
  if (loading) {
    return (
      <div className="loading-screen">
        <div className="loading-spinner" />
        <p>Verificando autenticación...</p>
      </div>
    );
  }

  // Si no está autenticado, no renderizar el contenido protegido
  if (!isAuthenticated) {
    return null; // El App.jsx redirigirá al login
  }

  return children;
}

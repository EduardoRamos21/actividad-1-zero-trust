// ============================================================================
// context/AuthContext.jsx - Contexto de Autenticación (React Context)
// ============================================================================
// Maneja el estado global de autenticación: login, logout, verificación JWT
// Zero Trust: El token se verifica en cada carga de la app
// ============================================================================

import { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { authApi } from '../services/api';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [token, setToken] = useState(localStorage.getItem('token'));
  const [loading, setLoading] = useState(true);

  // Al montar: verificar si hay un token existente y si sigue siendo válido
  useEffect(() => {
    async function verifyExistingToken() {
      if (!token) {
        setLoading(false);
        return;
      }

      try {
        const response = await authApi.verify();
        setUser(response.data.user);
      } catch {
        // Token inválido o expirado → limpiar sesión
        localStorage.removeItem('token');
        setToken(null);
        setUser(null);
      } finally {
        setLoading(false);
      }
    }

    verifyExistingToken();
  }, [token]);

  // Login: autenticar con credenciales y guardar JWT
  const login = useCallback(async (username, password) => {
    const response = await authApi.login(username, password);
    const { token: newToken, user: userData } = response.data;

    localStorage.setItem('token', newToken);
    setToken(newToken);
    setUser(userData);

    return userData;
  }, []);

  // Logout: limpiar token y estado
  const logout = useCallback(() => {
    localStorage.removeItem('token');
    setToken(null);
    setUser(null);
  }, []);

  // Valor proporcionado al contexto
  const value = {
    user,
    token,
    loading,
    isAuthenticated: !!user && !!token,
    login,
    logout,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

// Hook personalizado para consumir el contexto
export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth debe usarse dentro de un AuthProvider');
  }
  return context;
}

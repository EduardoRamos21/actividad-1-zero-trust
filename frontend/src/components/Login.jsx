// ============================================================================
// components/Login.jsx - Pantalla de Inicio de Sesión
// ============================================================================
// Formulario de login que se comunica con el Backend via JWT
// Zero Trust: Valida entrada del usuario antes de enviar
// ============================================================================

import { useState } from 'react';
import { useAuth } from '../context/AuthContext';
import './Login.css';

export default function Login() {
  const { login } = useAuth();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');

    // Validación del lado del cliente
    if (!username.trim() || !password.trim()) {
      setError('Por favor, ingresa usuario y contraseña.');
      return;
    }

    setIsLoading(true);

    try {
      await login(username, password);
    } catch (err) {
      setError(err.message || 'Error de autenticación. Verifica tus credenciales.');
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <div className="login-container">
      <div className="login-card">
        {/* Header */}
        <div className="login-header">
          <div className="login-icon">🛡️</div>
          <h1>Zero Trust Portal</h1>
          <p>Autenticación requerida para continuar</p>
        </div>

        {/* Formulario */}
        <form className="login-form" onSubmit={handleSubmit}>
          {/* Mensaje de error */}
          {error && (
            <div className="error-message">
              <span>⚠️</span>
              <span>{error}</span>
            </div>
          )}

          {/* Campo de usuario */}
          <div className="form-group">
            <label htmlFor="username">Usuario</label>
            <div className="input-wrapper">
              <input
                id="username"
                type="text"
                className="form-input"
                placeholder="Ingresa tu usuario"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                autoComplete="username"
                disabled={isLoading}
                maxLength={50}
              />
              <span className="input-icon">👤</span>
            </div>
          </div>

          {/* Campo de contraseña */}
          <div className="form-group">
            <label htmlFor="password">Contraseña</label>
            <div className="input-wrapper">
              <input
                id="password"
                type="password"
                className="form-input"
                placeholder="Ingresa tu contraseña"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                autoComplete="current-password"
                disabled={isLoading}
                maxLength={128}
              />
              <span className="input-icon">🔒</span>
            </div>
          </div>

          {/* Botón de login */}
          <button
            type="submit"
            className="login-btn"
            disabled={isLoading}
          >
            {isLoading ? (
              <span className="btn-loading">
                <span className="btn-spinner" />
                Autenticando...
              </span>
            ) : (
              'Iniciar Sesión'
            )}
          </button>
        </form>

        {/* Footer con badges de seguridad */}
        <div className="login-footer">
          <div className="security-badges">
            <span className="badge">🔐 HTTPS</span>
            <span className="badge">🎫 JWT</span>
            <span className="badge">🛡️ Zero Trust</span>
            <span className="badge">🧱 Helmet</span>
          </div>
        </div>
      </div>
    </div>
  );
}

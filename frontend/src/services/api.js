// ============================================================================
// services/api.js - Servicio de comunicación con el Backend
// ============================================================================
// Centraliza todas las llamadas HTTP al Backend
// Incluye manejo de token JWT en headers de autorización
// ============================================================================

// En producción Nginx sirve el React y hace proxy de /api en el mismo origen,
// así que la URL base va vacía y las llamadas son relativas (/api/...).
// En desarrollo Vite apunta al backend local.
function resolveApiBaseUrl() {
  const configured = import.meta.env.VITE_API_URL;
  if (configured === undefined || configured === '') {
    return import.meta.env.DEV ? 'http://localhost:3000' : '';
  }
  return String(configured).replace(/\/$/, '');
}

const API_BASE_URL = resolveApiBaseUrl();

// --------------------------------------------------------------------------
// Helper: Realizar solicitud HTTP con manejo de errores
// --------------------------------------------------------------------------
async function request(endpoint, options = {}) {
  const url = `${API_BASE_URL}${endpoint}`;

  const config = {
    headers: {
      'Content-Type': 'application/json',
      ...options.headers,
    },
    ...options,
  };

  // Agregar token JWT si existe
  const token = localStorage.getItem('token');
  if (token) {
    config.headers['Authorization'] = `Bearer ${token}`;
  }

  try {
    const response = await fetch(url, config);
    const data = await response.json();

    if (!response.ok) {
      throw new ApiError(data.error || 'Error en la solicitud', response.status);
    }

    return data;
  } catch (error) {
    if (error instanceof ApiError) throw error;

    // Error de red (backend no accesible)
    throw new ApiError('No se pudo conectar con el servidor. Verifica la conexión.', 0);
  }
}

// --------------------------------------------------------------------------
// Clase de error personalizada para la API
// --------------------------------------------------------------------------
class ApiError extends Error {
  constructor(message, statusCode) {
    super(message);
    this.name = 'ApiError';
    this.statusCode = statusCode;
  }
}

// --------------------------------------------------------------------------
// Endpoints de Autenticación
// --------------------------------------------------------------------------
const authApi = {
  login: (username, password) =>
    request('/api/auth/login', {
      method: 'POST',
      body: JSON.stringify({ username, password }),
    }),

  verify: () =>
    request('/api/auth/verify', {
      method: 'POST',
    }),
};

// --------------------------------------------------------------------------
// Endpoints del Dashboard
// --------------------------------------------------------------------------
const dashboardApi = {
  getData: () => request('/api/dashboard'),
  getHealth: () => request('/api/dashboard/health'),
};

export { authApi, dashboardApi, ApiError };

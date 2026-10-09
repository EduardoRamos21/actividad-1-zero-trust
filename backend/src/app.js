// ============================================================================
// app.js - Configuración de la aplicación Express
// ============================================================================
// Configura todos los middlewares de seguridad, rutas y manejo de errores
// Helmet inyecta encabezados de seguridad HTTP para puntuación A en
// SecurityHeaders.com
// ============================================================================

const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');
const config = require('./config');
const { generalLimiter } = require('./middleware/rateLimiter');
const errorHandler = require('./middleware/errorHandler');

// Importar rutas
const authRoutes = require('./routes/authRoutes');
const dashboardRoutes = require('./routes/dashboardRoutes');

const app = express();

// Nginx termina TLS y reenvía X-Forwarded-For. Sin esto, express-rate-limit
// rechaza las peticiones o cuenta a todos los usuarios como una sola IP.
app.set('trust proxy', 1);

// ============================================================================
// MIDDLEWARES DE SEGURIDAD (Zero Trust)
// ============================================================================

// 1. Helmet - Encabezados de seguridad HTTP.
// La calificación de SecurityHeaders.com se mide sobre el sitio público (Nginx).
// Estos encabezados protegen además las respuestas de la API.
app.use(
  helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: ["'self'"],
        styleSrc: ["'self'"],
        imgSrc: ["'self'", 'data:'],
        connectSrc: ["'self'"],
        fontSrc: ["'self'"],
        objectSrc: ["'none'"],
        mediaSrc: ["'self'"],
        frameSrc: ["'none'"],
        baseUri: ["'self'"],
        formAction: ["'self'"],
        frameAncestors: ["'none'"],
        upgradeInsecureRequests: [],
      },
    },
    // COEP require-corp rompe recursos cruzados; la API no lo necesita.
    crossOriginEmbedderPolicy: false,
    crossOriginOpenerPolicy: { policy: 'same-origin' },
    // same-site permite el dev server (localhost:5173 -> localhost:3000)
    // y también el mismo dominio en producción.
    crossOriginResourcePolicy: { policy: 'same-site' },
    hsts: {
      maxAge: 31536000,
      includeSubDomains: true,
      preload: true,
    },
    frameguard: { action: 'deny' },
    referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
    hidePoweredBy: true,
    // DNS Prefetch Control
    dnsPrefetchControl: { allow: false },
    // IE no sniff
    ieNoOpen: true,
    // No abrir descargas automáticamente
    noSniff: true,
    // Permissions-Policy (antes Feature-Policy)
    permittedCrossDomainPolicies: { permittedPolicies: 'none' },
  })
);

// Permissions-Policy header adicional (Helmet no lo cubre completamente)
app.use((req, res, next) => {
  res.setHeader(
    'Permissions-Policy',
    'camera=(), microphone=(), geolocation=(), interest-cohort=()'
  );
  next();
});

// 2. CORS - Orígenes permitidos (solo el Frontend)
app.use(
  cors({
    origin: config.cors.origin,
    methods: ['GET', 'POST'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true,
    maxAge: 86400, // Pre-flight cache: 24 horas
  })
);

// 3. Rate Limiter general
app.use(generalLimiter);

// 4. Parser de JSON con límite de tamaño (prevenir payload bombing)
app.use(express.json({ limit: '10kb' }));

// 5. Logger de solicitudes HTTP (formato combinado para Fail2Ban)
app.use(morgan('combined'));

// ============================================================================
// RUTAS DE LA API
// ============================================================================

// Ruta de health check (no protegida, para monitoreo)
app.get('/api/health', (req, res) => {
  res.status(200).json({
    success: true,
    data: {
      status: 'online',
      timestamp: new Date().toISOString(),
    },
  });
});

// Rutas de autenticación: /api/auth/login, /api/auth/verify
app.use('/api/auth', authRoutes);

// Rutas del dashboard (protegidas con JWT): /api/dashboard
app.use('/api/dashboard', dashboardRoutes);

// ============================================================================
// MANEJO DE ERRORES
// ============================================================================

// Ruta no encontrada (404)
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: 'Recurso no encontrado.',
  });
});

// Manejador centralizado de errores
app.use(errorHandler);

module.exports = app;

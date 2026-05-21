/**
 * ============================================================================
 * @file        app.js
 * @description Express application configuration file for KOSHIV Bus Booking System
 *              - Initializes Express app
 *              - Configures all middleware (security, logging, rate limiting)
 *              - Registers API routes (v1)
 *              - Sets up error handling
 *              
 *              RULE 1.1: NO DUMMY DATA - All code production ready
 *              RULE 1.3: NO LOCALHOST - Uses 100.81.13.80 from .env
 *              RULE 6: All security headers applied via helmet + custom middleware
 *              RULE 1.9: REQUEST VALIDATION - Joi schemas for all inputs
 * 
 * @version     1.0.0.0.0
 * @author      Koushal Jha
 * @email       koushaljha.cs@gmail.com
 * @date        May 2026
 * @project     KOSHIV BUS BOOKING SYSTEM - Authentication Module Only
 * 
 * NOTE: No hardcoding - all config from environment variables
 *       No booking, no admin, no payment APIs in this phase
 *       Only authentication APIs (13 endpoints as listed in requirements)
 * ============================================================================
 */

const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const dotenv = require('dotenv');
const path = require('path');

// Load environment variables from .env file (RULE 1.3: Uses 100.81.13.80 from env)
dotenv.config({ path: path.join(__dirname, '..', '.env') });

// Import custom middleware
const securityHeaders = require('./middleware/securityHeaders.middleware');
const requestId = require('./middleware/requestId.middleware');
const logging = require('./middleware/logging.middleware');
const sqlInjection = require('./middleware/sqlInjection.middleware');
const errorHandler = require('./middleware/error.middleware');
const rateLimit = require('./middleware/rateLimit.middleware');

// Import API routes (v1 as per requirement)
const captchaRoutes = require('./routes/v1/captcha.routes');
const authRoutes = require('./routes/v1/auth.routes');

const app = express();

/**
 * ============================================================================
 * SECURITY MIDDLEWARE CONFIGURATION
 * ============================================================================
 * RULE 6: All API responses must have security headers
 * RULE 5.3: Rate limiting on all endpoints
 * RULE 5.4: User-Agent validation
 * 
 * All values are read from environment variables - NO HARDCODING
 * ============================================================================
 */

// Helmet for security headers (X-Content-Type-Options, X-Frame-Options, X-XSS-Protection, HSTS, CSP)
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'none'"],  // CSP: default-src 'none' as per RULE 6
      styleSrc: ["'unsafe-inline'"],
      scriptSrc: ["'self'"],
    },
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true,
  },
}));

// Custom security headers middleware (adds all headers from RULE 6)
app.use(securityHeaders);

/**
 * CORS Configuration - Reads from environment variable
 * No hardcoded origins - ALLOWED_ORIGINS from .env
 */
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS ? process.env.ALLOWED_ORIGINS.split(',') : '*',
  credentials: true,
  optionsSuccessStatus: 200,
}));

/**
 * Request ID Middleware (RULE 4 API 1: X-Request-ID header required)
 * Generates UUID for each request - used for tracking and logging
 */
app.use(requestId);

// Request body parsing with size limits (prevents large payload attacks)
app.use(express.json({ limit: '10kb' }));
app.use(express.urlencoded({ extended: true, limit: '10kb' }));

/**
 * SQL Injection Prevention Middleware (RULE 1.4)
 * Scans request body, query, and params for SQL injection patterns
 * Uses parameterized queries in repositories ($1, $2, $3)
 */
app.use(sqlInjection);

// Global rate limiting middleware (RULE 1.8, RULE 5.3)
// Specific endpoint limits are defined in route-level rate limiters
app.use(rateLimit.global);

// Request/Response logging middleware (RULE 1.7: No passwords in logs)
app.use(logging);

/**
 * ============================================================================
 * HEALTH CHECK ENDPOINT
 * ============================================================================
 * Used by load balancers and monitoring tools to verify service status
 * No authentication required
 * Rate limit: 10 per minute (not enforced on health endpoint)
 * ============================================================================
 */
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'success',
    message: 'KOSHIV Bus API is running',
    version: process.env.API_VERSION || 'v1',
    environment: process.env.NODE_ENV || 'production',
    timestamp: new Date().toISOString(),
  });
});

/**
 * ============================================================================
 * API ROUTES REGISTRATION
 * ============================================================================
 * API 1-2:   Security routes (CAPTCHA) - /api/v1/security/*
 * API 3-13:  Authentication routes - /api/v1/identity/*
 * 
 * Base path: /api/v1 (from RULE 4 - API endpoints use /api/v1 prefix)
 * ============================================================================
 */

// Security routes: GET /api/v1/security/captcha, POST /api/v1/security/captcha/validate
app.use('/api/v1/security', captchaRoutes);

// Identity routes: register, login, logout, profile, token refresh, etc.
app.use('/api/v1/identity', authRoutes);

/**
 * ============================================================================
 * 404 HANDLER - Route not found
 * ============================================================================
 * Catches all unmatched routes and returns 404 error
 * ============================================================================
 */
app.use('*', (req, res) => {
  res.status(404).json({
    status: 'error',
    error: {
      code: 'NOT_FOUND',
      message: `Cannot ${req.method} ${req.originalUrl}`,
    },
    timestamp: new Date().toISOString(),
  });
});

// Global error handling middleware (must be last)
app.use(errorHandler);

module.exports = app;
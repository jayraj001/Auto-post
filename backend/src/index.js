require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { logger } = require('./utils/logger');
const { validateEnv } = require('./utils/validateEnv');
const { startQueueWorkers } = require('./queues/workers');

// ── Validate env before anything else ────────────────────────
validateEnv();

const app = express();

// ── Security Middleware ──────────────────────────────────────
app.use(helmet());
app.use(cors({ origin: process.env.FRONTEND_URL, credentials: true }));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Global rate limit
app.use(rateLimit({
  windowMs: 15 * 60 * 1000, // 15 min
  max: 200,
  message: { error: 'Too many requests, please try again later.' }
}));

// ── Request logger ────────────────────────────────────────────
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const ms = Date.now() - start;
    const level = res.statusCode >= 400 ? 'warn' : 'info';
    logger[level](`${req.method} ${req.path} ${res.statusCode} ${ms}ms`);
  });
  next();
});

// ── Routes ───────────────────────────────────────────────────
app.use('/api/auth',       require('./routes/auth'));
app.use('/api/accounts',   require('./routes/accounts'));
app.use('/api/oauth',      require('./routes/oauth'));
app.use('/api/posts',      require('./routes/posts'));
app.use('/api/ai',         require('./routes/ai'));
app.use('/api/analytics',  require('./routes/analytics'));
app.use('/api/automation', require('./routes/automation'));
app.use('/api/billing',    require('./routes/billing'));
app.use('/api/referrals',  require('./routes/referrals'));

// Health check
app.get('/health', (req, res) => res.json({ status: 'ok', ts: new Date() }));

// ── Error Handler ────────────────────────────────────────────
app.use((err, req, res, next) => {
  logger.error(`${req.method} ${req.path} → ${err.message}`);

  // Validation errors
  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({ error: 'Invalid JSON in request body' });
  }

  // JWT errors
  if (err.name === 'JsonWebTokenError') {
    return res.status(401).json({ error: 'Invalid token', code: 'INVALID_TOKEN' });
  }
  if (err.name === 'TokenExpiredError') {
    return res.status(401).json({ error: 'Token expired', code: 'TOKEN_EXPIRED' });
  }

  res.status(err.status || 500).json({
    error: err.message || 'Internal server error',
    code: err.code || 'SERVER_ERROR',
  });
});

// ── Start ────────────────────────────────────────────────────
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  logger.info(`AutoPost AI API running on port ${PORT}`);
  startQueueWorkers();
});

module.exports = app;

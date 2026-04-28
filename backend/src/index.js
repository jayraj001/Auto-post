require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { logger } = require('./utils/logger');
const { startQueueWorkers } = require('./queues/workers');

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

// ── Routes ───────────────────────────────────────────────────
app.use('/v1/auth',       require('./routes/auth'));
app.use('/v1/accounts',   require('./routes/accounts'));
app.use('/v1/posts',      require('./routes/posts'));
app.use('/v1/ai',         require('./routes/ai'));
app.use('/v1/analytics',  require('./routes/analytics'));
app.use('/v1/automation', require('./routes/automation'));
app.use('/v1/billing',    require('./routes/billing'));
app.use('/v1/referrals',  require('./routes/referrals'));

// Health check
app.get('/health', (req, res) => res.json({ status: 'ok', ts: new Date() }));

// ── Error Handler ────────────────────────────────────────────
app.use((err, req, res, next) => {
  logger.error(err.stack);
  res.status(err.status || 500).json({ error: err.message || 'Internal server error' });
});

// ── Start ────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  logger.info(`AutoPost AI API running on port ${PORT}`);
  startQueueWorkers();
});

module.exports = app;

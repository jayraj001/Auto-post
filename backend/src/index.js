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
  logger.error(err.stack);
  res.status(err.status || 500).json({ error: err.message || 'Internal server error' });
});

// ── Start ────────────────────────────────────────────────────
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  logger.info(`AutoPost AI API running on port ${PORT}`);
  startQueueWorkers();
});

module.exports = app;

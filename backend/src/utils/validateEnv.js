/**
 * Validates required environment variables on startup.
 * Logs warnings for missing optional vars, throws for critical ones.
 */
const { logger } = require('./logger');

const REQUIRED = [
  'JWT_SECRET',
  'ENCRYPTION_KEY',
  'SUPABASE_URL',
  'SUPABASE_SERVICE_KEY',
];

const OPTIONAL = {
  'REDIS_URL':              'Bull queue (post scheduling) will not work',
  'OPENAI_API_KEY':         'AI caption/hashtag generation will not work',
  'FACEBOOK_CLIENT_ID':     'Facebook OAuth will not work',
  'FACEBOOK_CLIENT_SECRET': 'Facebook OAuth will not work',
  'INSTAGRAM_APP_ID':       'Instagram OAuth will not work',
  'INSTAGRAM_APP_SECRET':   'Instagram OAuth will not work',
  'TWITTER_CLIENT_ID':      'Twitter OAuth will not work',
  'TWITTER_CLIENT_SECRET':  'Twitter OAuth will not work',
  'LINKEDIN_CLIENT_ID':     'LinkedIn OAuth will not work',
  'LINKEDIN_CLIENT_SECRET': 'LinkedIn OAuth will not work',
  'YOUTUBE_CLIENT_ID':      'YouTube OAuth will not work',
  'YOUTUBE_CLIENT_SECRET':  'YouTube OAuth will not work',
  'STRIPE_SECRET_KEY':      'Stripe payments will not work',
  'RAZORPAY_KEY_ID':        'Razorpay payments will not work',
};

function validateEnv() {
  const missing = [];

  // Check required
  for (const key of REQUIRED) {
    if (!process.env[key]) {
      missing.push(key);
    }
  }

  if (missing.length > 0) {
    logger.error(`Missing REQUIRED environment variables: ${missing.join(', ')}`);
    logger.error('Server cannot start. Add these to your .env file.');
    process.exit(1);
  }

  // Validate ENCRYPTION_KEY length (must be 32 chars for AES-256)
  if (process.env.ENCRYPTION_KEY.length !== 32) {
    logger.error(`ENCRYPTION_KEY must be exactly 32 characters (got ${process.env.ENCRYPTION_KEY.length})`);
    process.exit(1);
  }

  // Warn about optional
  const missingOptional = [];
  for (const [key, impact] of Object.entries(OPTIONAL)) {
    if (!process.env[key]) {
      missingOptional.push(`  ⚠  ${key} not set → ${impact}`);
    }
  }

  if (missingOptional.length > 0) {
    logger.warn('Optional env vars not configured:');
    missingOptional.forEach(msg => logger.warn(msg));
  }

  logger.info('✓ Environment validation passed');
}

module.exports = { validateEnv };

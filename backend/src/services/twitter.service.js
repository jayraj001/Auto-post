/**
 * Twitter / X Platform Service
 * Uses Twitter API v2
 */
const axios  = require('axios');
const { logger } = require('../utils/logger');

// ── Validate token ────────────────────────────────────────────
async function validateToken(token) {
  try {
    const res = await axios.get('https://api.twitter.com/2/users/me', {
      headers: { Authorization: `Bearer ${token}` },
      timeout: 5000,
    });
    return { valid: !!res.data.data?.id, userId: res.data.data?.id };
  } catch (err) {
    logger.warn(`Twitter token invalid: ${err.message}`);
    return { valid: false };
  }
}

// ── Refresh token ─────────────────────────────────────────────
async function refreshToken(refreshToken, clientId, clientSecret) {
  const res = await axios.post(
    'https://api.twitter.com/2/oauth2/token',
    new URLSearchParams({
      grant_type:    'refresh_token',
      refresh_token: refreshToken,
      client_id:     clientId,
    }),
    {
      auth:    { username: clientId, password: clientSecret },
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    }
  );
  return {
    accessToken:  res.data.access_token,
    refreshToken: res.data.refresh_token,
  };
}

// ── Publish post ──────────────────────────────────────────────
async function publishPost(post, account, token) {
  const caption = buildCaption(post);
  // Twitter limit: 280 chars
  const text = caption.length > 280 ? caption.substring(0, 277) + '...' : caption;

  const res = await axios.post(
    'https://api.twitter.com/2/tweets',
    { text },
    { headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' } }
  );

  const postId = res.data.data?.id;
  logger.info(`Twitter published: ${postId}`);
  return { success: true, platformPostId: postId };
}

function buildCaption(post) {
  const parts = [];
  if (post.caption)          parts.push(post.caption);
  if (post.hashtags?.length) parts.push(post.hashtags.join(' '));
  return parts.join('\n\n');
}

module.exports = { validateToken, refreshToken, publishPost };

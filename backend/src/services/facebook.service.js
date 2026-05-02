/**
 * Facebook Platform Service
 * Handles all Facebook Graph API interactions
 */
const axios  = require('axios');
const { logger } = require('../utils/logger');

const BASE = 'https://graph.facebook.com/v18.0';

// ── Validate token ────────────────────────────────────────────
async function validateToken(token) {
  try {
    const res = await axios.get(`${BASE}/me`, {
      params: { access_token: token },
      timeout: 5000,
    });
    return { valid: !!res.data.id, userId: res.data.id };
  } catch (err) {
    logger.warn(`Facebook token invalid: ${err.message}`);
    return { valid: false };
  }
}

// ── Publish post ──────────────────────────────────────────────
async function publishPost(post, account, token) {
  const pageId  = account.page_id;
  if (!pageId) throw new Error('No page ID — reconnect Facebook');

  const caption  = buildCaption(post);
  const mediaUrl = post.media_urls?.[0];

  const endpoint = mediaUrl ? `${BASE}/${pageId}/photos` : `${BASE}/${pageId}/feed`;
  const params   = mediaUrl
    ? { url: mediaUrl, message: caption, access_token: token }
    : { message: caption, access_token: token };

  const res = await axios.post(endpoint, null, { params });
  const postId = res.data.id || res.data.post_id;

  logger.info(`Facebook published: ${postId}`);
  return { success: true, platformPostId: postId };
}

// ── Get page token ────────────────────────────────────────────
async function getPageToken(userToken, pageId) {
  const res = await axios.get(`${BASE}/${pageId}`, {
    params: { fields: 'access_token', access_token: userToken },
  });
  return res.data.access_token;
}

function buildCaption(post) {
  const parts = [];
  if (post.caption)          parts.push(post.caption);
  if (post.hashtags?.length) parts.push(post.hashtags.join(' '));
  return parts.join('\n\n');
}

module.exports = { validateToken, publishPost, getPageToken };

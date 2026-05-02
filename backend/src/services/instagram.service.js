/**
 * Instagram Platform Service
 * Uses Meta Graph API (requires Facebook Page linked to Instagram Business account)
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
    logger.warn(`Instagram token invalid: ${err.message}`);
    return { valid: false };
  }
}

// ── Publish post ──────────────────────────────────────────────
async function publishPost(post, account, token) {
  const pageId   = account.page_id;
  if (!pageId) throw new Error('No page ID — reconnect Instagram');

  const mediaUrl = post.media_urls?.[0];
  if (!mediaUrl) throw new Error('Instagram requires at least one media URL');

  const caption = buildCaption(post);

  // Step 1: Create media container
  const containerParams = post.media_type === 'video'
    ? { video_url: mediaUrl, caption, media_type: 'REELS', access_token: token }
    : { image_url: mediaUrl, caption, access_token: token };

  const containerRes = await axios.post(
    `${BASE}/${pageId}/media`,
    null,
    { params: containerParams }
  );

  const containerId = containerRes.data.id;
  if (!containerId) throw new Error('Failed to create Instagram media container');

  // Step 2: Wait for container to be ready (video needs processing time)
  if (post.media_type === 'video') {
    await waitForContainer(pageId, containerId, token);
  }

  // Step 3: Publish container
  const publishRes = await axios.post(
    `${BASE}/${pageId}/media_publish`,
    null,
    { params: { creation_id: containerId, access_token: token } }
  );

  const postId = publishRes.data.id;
  logger.info(`Instagram published: ${postId}`);
  return { success: true, platformPostId: postId };
}

// ── Wait for video container to be ready ─────────────────────
async function waitForContainer(pageId, containerId, token, maxAttempts = 10) {
  for (let i = 0; i < maxAttempts; i++) {
    await new Promise(r => setTimeout(r, 3000));
    const res = await axios.get(`${BASE}/${containerId}`, {
      params: { fields: 'status_code', access_token: token },
    });
    if (res.data.status_code === 'FINISHED') return;
    if (res.data.status_code === 'ERROR') throw new Error('Instagram media processing failed');
  }
  throw new Error('Instagram media container timed out');
}

function buildCaption(post) {
  const parts = [];
  if (post.caption)          parts.push(post.caption);
  if (post.hashtags?.length) parts.push(post.hashtags.join(' '));
  return parts.join('\n\n');
}

module.exports = { validateToken, publishPost };

/**
 * LinkedIn Platform Service
 * Uses LinkedIn UGC Posts API
 */
const axios  = require('axios');
const { logger } = require('../utils/logger');

// ── Validate token ────────────────────────────────────────────
async function validateToken(token) {
  try {
    const res = await axios.get('https://api.linkedin.com/v2/me', {
      headers: { Authorization: `Bearer ${token}` },
      timeout: 5000,
    });
    return { valid: !!res.data.id, userId: res.data.id };
  } catch (err) {
    logger.warn(`LinkedIn token invalid: ${err.message}`);
    return { valid: false };
  }
}

// ── Publish post ──────────────────────────────────────────────
async function publishPost(post, account, token) {
  const caption  = buildCaption(post);
  const mediaUrl = post.media_urls?.[0];

  let shareMediaCategory = 'NONE';
  let media = [];

  if (mediaUrl) {
    shareMediaCategory = post.media_type === 'video' ? 'VIDEO' : 'IMAGE';
    media = [{
      status:      'READY',
      description: { text: caption.substring(0, 200) },
      media:       mediaUrl,
      title:       { text: post.caption?.substring(0, 100) || 'Post' },
    }];
  }

  const body = {
    author:         `urn:li:person:${account.platform_user_id}`,
    lifecycleState: 'PUBLISHED',
    specificContent: {
      'com.linkedin.ugc.ShareContent': {
        shareCommentary:    { text: caption },
        shareMediaCategory,
        media,
      },
    },
    visibility: {
      'com.linkedin.ugc.MemberNetworkVisibility': 'PUBLIC',
    },
  };

  const res = await axios.post(
    'https://api.linkedin.com/v2/ugcPosts',
    body,
    { headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' } }
  );

  const postId = res.data.id;
  logger.info(`LinkedIn published: ${postId}`);
  return { success: true, platformPostId: postId };
}

function buildCaption(post) {
  const parts = [];
  if (post.caption)          parts.push(post.caption);
  if (post.hashtags?.length) parts.push(post.hashtags.join(' '));
  return parts.join('\n\n');
}

module.exports = { validateToken, publishPost };

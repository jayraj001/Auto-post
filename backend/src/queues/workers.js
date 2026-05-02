const { postQueue } = require('./postQueue');
const { supabase }  = require('../utils/supabase');
const { decrypt }   = require('../utils/encrypt');
const { logger }    = require('../utils/logger');
const axios         = require('axios');

// ─────────────────────────────────────────────────────────────
// Start all queue workers
// ─────────────────────────────────────────────────────────────
function startQueueWorkers() {
  // worker.process('publish-post', async job => { ... })
  postQueue.process('publish-post', 3, async (job) => {
    return await publishPostJob(job);
  });

  // Keep backward compat with old 'publish' job name
  postQueue.process('publish', 3, async (job) => {
    return await publishPostJob(job);
  });

  postQueue.on('completed', (job, result) => {
    logger.info(`Job ${job.id} completed: post ${job.data.postId}`);
  });

  postQueue.on('failed', (job, err) => {
    logger.error(`Job ${job.id} failed (attempt ${job.attemptsMade}): ${err.message}`);
  });

  postQueue.on('stalled', (job) => {
    logger.warn(`Job ${job.id} stalled — will retry`);
  });

  logger.info('Post queue workers started (concurrency: 3)');
}

// ─────────────────────────────────────────────────────────────
// Main job handler
// worker.process('publish-post', async job => { ... })
// ─────────────────────────────────────────────────────────────
async function publishPostJob(job) {
  const { postId } = job.data;
  logger.info(`[Job ${job.id}] Publishing post: ${postId}`);

  // 1. Fetch post
  const { data: post, error: postErr } = await supabase
    .from('posts')
    .select('*')
    .eq('id', postId)
    .single();

  if (postErr || !post) {
    throw new Error(`Post ${postId} not found`);
  }

  // 2. Fetch connected accounts for this user + platforms
  const { data: accounts, error: accErr } = await supabase
    .from('social_accounts')
    .select('*')
    .eq('user_id', post.user_id)
    .in('platform', post.platforms)
    .eq('is_active', true);

  if (accErr) throw new Error(accErr.message);

  if (!accounts || accounts.length === 0) {
    await markFailed(postId, 'No connected accounts for selected platforms');
    return { success: false, error: 'No connected accounts' };
  }

  // 3. Publish to each platform
  const results = [];
  for (const account of accounts) {
    const result = await publishToPlatform(post, account);
    results.push(result);
    logger.info(`[Job ${job.id}] ${account.platform}: ${result.success ? '✓' : '✗'} ${result.error || ''}`);
  }

  // 4. Update post status
  const allSuccess = results.every(r => r.success);
  const anySuccess = results.some(r => r.success);

  await supabase.from('posts').update({
    status:       allSuccess ? 'published' : anySuccess ? 'partial' : 'failed',
    published_at: anySuccess ? new Date().toISOString() : null,
    updated_at:   new Date().toISOString(),
  }).eq('id', postId);

  // 5. Store per-platform results
  for (const result of results) {
    await supabase.from('post_results').insert({
      post_id:          postId,
      platform:         result.platform,
      status:           result.success ? 'published' : 'failed',
      platform_post_id: result.platformPostId || null,
      error_message:    result.error || null,
      published_at:     result.success ? new Date().toISOString() : null,
    });
  }

  logger.info(`[Job ${job.id}] Done. Results: ${JSON.stringify(results)}`);
  return results;
}

// ─────────────────────────────────────────────────────────────
// Publish to a single platform
// ─────────────────────────────────────────────────────────────
async function publishToPlatform(post, account) {
  const platform = account.platform;

  try {
    // Decrypt token
    let token;
    try {
      token = decrypt(account.access_token);
    } catch (e) {
      return { platform, success: false, error: 'Token decryption failed' };
    }

    // Validate token before calling API
    const isValid = await validateToken(platform, token);
    if (!isValid) {
      await supabase.from('social_accounts')
        .update({ token_expired: true, is_active: false, status: 'expired' })
        .eq('id', account.id);
      return { platform, success: false, error: 'Token expired — user must reconnect' };
    }

    // Call platform API
    switch (platform) {
      case 'facebook':  return await callFacebookAPI(post, account, token);
      case 'instagram': return await callInstagramAPI(post, account, token);
      case 'twitter':   return await callTwitterAPI(post, account, token);
      case 'linkedin':  return await callLinkedInAPI(post, account, token);
      case 'youtube':   return await callYouTubeAPI(post, account, token);
      default:
        return { platform, success: false, error: `Unsupported: ${platform}` };
    }
  } catch (err) {
    logger.error(`Publish error [${platform}]: ${err.message}`);

    // Rate limit — re-queue with delay
    if (err.response?.status === 429) {
      const retryAfter = parseInt(err.response.headers['retry-after'] || '60', 10);
      logger.warn(`Rate limited [${platform}] — retry in ${retryAfter}s`);
      await postQueue.add('publish-post', { postId: post.id }, {
        delay:    retryAfter * 1000,
        attempts: 3,
      });
      return { platform, success: false, error: 'Rate limited — requeued' };
    }

    return { platform, success: false, error: err.message };
  }
}

// ─────────────────────────────────────────────────────────────
// Facebook API
// worker.process('publish-post', async job => { call Facebook API })
// ─────────────────────────────────────────────────────────────
async function callFacebookAPI(post, account, token) {
  const platform = 'facebook';
  const pageId   = account.page_id;

  if (!pageId) {
    return { platform, success: false, error: 'No page ID — reconnect Facebook' };
  }

  const caption  = buildCaption(post);
  const mediaUrl = post.media_urls?.[0];

  const endpoint = mediaUrl
    ? `https://graph.facebook.com/v18.0/${pageId}/photos`
    : `https://graph.facebook.com/v18.0/${pageId}/feed`;

  const params = mediaUrl
    ? { url: mediaUrl, message: caption, access_token: token }
    : { message: caption, access_token: token };

  const res = await axios.post(endpoint, null, { params });

  logger.info(`Facebook post published: ${res.data.id || res.data.post_id}`);
  return { platform, success: true, platformPostId: res.data.id || res.data.post_id };
}

// ─────────────────────────────────────────────────────────────
// Instagram API
// ─────────────────────────────────────────────────────────────
async function callInstagramAPI(post, account, token) {
  const platform = 'instagram';
  const pageId   = account.page_id;

  if (!pageId) {
    return { platform, success: false, error: 'No page ID — reconnect Instagram' };
  }

  const caption  = buildCaption(post);
  const mediaUrl = post.media_urls?.[0];

  if (!mediaUrl) {
    return { platform, success: false, error: 'Instagram requires media (image/video)' };
  }

  // Step 1: Create media container
  const containerRes = await axios.post(
    `https://graph.facebook.com/v18.0/${pageId}/media`,
    null,
    { params: { image_url: mediaUrl, caption, access_token: token } }
  );

  // Step 2: Publish container
  const publishRes = await axios.post(
    `https://graph.facebook.com/v18.0/${pageId}/media_publish`,
    null,
    { params: { creation_id: containerRes.data.id, access_token: token } }
  );

  logger.info(`Instagram post published: ${publishRes.data.id}`);
  return { platform, success: true, platformPostId: publishRes.data.id };
}

// ─────────────────────────────────────────────────────────────
// Twitter API
// ─────────────────────────────────────────────────────────────
async function callTwitterAPI(post, account, token) {
  const platform = 'twitter';
  const caption  = buildCaption(post);
  const text     = caption.length > 280 ? caption.substring(0, 277) + '...' : caption;

  const res = await axios.post(
    'https://api.twitter.com/2/tweets',
    { text },
    { headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' } }
  );

  logger.info(`Twitter post published: ${res.data.data?.id}`);
  return { platform, success: true, platformPostId: res.data.data?.id };
}

// ─────────────────────────────────────────────────────────────
// LinkedIn API
// ─────────────────────────────────────────────────────────────
async function callLinkedInAPI(post, account, token) {
  const platform = 'linkedin';
  const caption  = buildCaption(post);

  const body = {
    author:         `urn:li:person:${account.platform_user_id}`,
    lifecycleState: 'PUBLISHED',
    specificContent: {
      'com.linkedin.ugc.ShareContent': {
        shareCommentary:    { text: caption },
        shareMediaCategory: 'NONE',
      },
    },
    visibility: { 'com.linkedin.ugc.MemberNetworkVisibility': 'PUBLIC' },
  };

  const res = await axios.post(
    'https://api.linkedin.com/v2/ugcPosts',
    body,
    { headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' } }
  );

  logger.info(`LinkedIn post published: ${res.data.id}`);
  return { platform, success: true, platformPostId: res.data.id };
}

// ─────────────────────────────────────────────────────────────
// YouTube API
// ─────────────────────────────────────────────────────────────
async function callYouTubeAPI(post, account, token) {
  const platform = 'youtube';

  if (post.media_type !== 'video') {
    return { platform, success: false, error: 'YouTube requires video content' };
  }

  // TODO: implement resumable upload
  // https://developers.google.com/youtube/v3/guides/resumable_uploads
  logger.warn(`YouTube upload not yet implemented for post ${post.id}`);
  return { platform, success: false, error: 'YouTube upload coming soon' };
}

// ─────────────────────────────────────────────────────────────
// Token validation
// ─────────────────────────────────────────────────────────────
async function validateToken(platform, token) {
  try {
    switch (platform) {
      case 'facebook':
      case 'instagram': {
        const res = await axios.get('https://graph.facebook.com/v18.0/me', {
          params: { access_token: token }, timeout: 5000,
        });
        return !!res.data.id;
      }
      case 'twitter': {
        const res = await axios.get('https://api.twitter.com/2/users/me', {
          headers: { Authorization: `Bearer ${token}` }, timeout: 5000,
        });
        return !!res.data.data?.id;
      }
      case 'linkedin': {
        const res = await axios.get('https://api.linkedin.com/v2/me', {
          headers: { Authorization: `Bearer ${token}` }, timeout: 5000,
        });
        return !!res.data.id;
      }
      case 'youtube': {
        const res = await axios.get('https://www.googleapis.com/youtube/v3/channels', {
          params: { part: 'id', mine: true },
          headers: { Authorization: `Bearer ${token}` }, timeout: 5000,
        });
        return res.data.items?.length > 0;
      }
      default: return false;
    }
  } catch (err) {
    logger.warn(`Token validation failed [${platform}]: ${err.message}`);
    return false;
  }
}

// ─────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────
function buildCaption(post) {
  const parts = [];
  if (post.caption)          parts.push(post.caption);
  if (post.hashtags?.length) parts.push(post.hashtags.join(' '));
  return parts.join('\n\n');
}

async function markFailed(postId, reason) {
  await supabase.from('posts').update({
    status:     'failed',
    updated_at: new Date().toISOString(),
  }).eq('id', postId);
  logger.error(`Post ${postId} marked failed: ${reason}`);
}

module.exports = { startQueueWorkers };

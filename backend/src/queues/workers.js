/**
 * Post Queue Workers
 * - Idempotency: skips already-published posts
 * - Token refresh: auto-refreshes expired tokens before publishing
 * - Partial success: handles per-platform failures independently
 * - Structured logging: every step logged with job ID
 * - Retry with backoff: Bull handles 3 attempts with exponential backoff
 */
const { postQueue }  = require('./postQueue');
const { supabase }   = require('../utils/supabase');
const { decrypt, encrypt } = require('../utils/encrypt');
const { logger }     = require('../utils/logger');

// ── Platform services ─────────────────────────────────────────
const facebookService  = require('../services/facebook.service');
const instagramService = require('../services/instagram.service');
const twitterService   = require('../services/twitter.service');
const linkedinService  = require('../services/linkedin.service');

const PLATFORM_SERVICES = {
  facebook:  facebookService,
  instagram: instagramService,
  twitter:   twitterService,
  linkedin:  linkedinService,
};

// ─────────────────────────────────────────────────────────────
// Start workers
// ─────────────────────────────────────────────────────────────
function startQueueWorkers() {
  // worker.process('publish-post', async job => { ... })
  postQueue.process('publish-post', 3, publishPostJob);
  postQueue.process('publish',      3, publishPostJob); // backward compat

  postQueue.on('completed', (job) =>
    logger.info(`[Job ${job.id}] ✓ completed — post ${job.data.postId}`)
  );
  postQueue.on('failed', (job, err) =>
    logger.error(`[Job ${job.id}] ✗ failed (attempt ${job.attemptsMade}/${job.opts.attempts}): ${err.message}`)
  );
  postQueue.on('stalled', (job) =>
    logger.warn(`[Job ${job.id}] stalled — will retry`)
  );

  logger.info('Post queue workers started (concurrency: 3)');
}

// ─────────────────────────────────────────────────────────────
// Main job: publish-post
// ─────────────────────────────────────────────────────────────
async function publishPostJob(job) {
  const { postId } = job.data;
  const log = (msg) => logger.info(`[Job ${job.id}] ${msg}`);
  const warn = (msg) => logger.warn(`[Job ${job.id}] ${msg}`);

  log(`Starting publish for post: ${postId}`);

  // ── 1. Fetch post ─────────────────────────────────────────
  const { data: post, error: postErr } = await supabase
    .from('posts').select('*').eq('id', postId).single();

  if (postErr || !post) throw new Error(`Post ${postId} not found`);

  // ── 2. Idempotency check ──────────────────────────────────
  if (post.status === 'published') {
    warn(`Post ${postId} already published — skipping`);
    return { skipped: true, reason: 'already_published' };
  }

  // ── 3. Fetch connected accounts ───────────────────────────
  const { data: accounts, error: accErr } = await supabase
    .from('social_accounts')
    .select('*')
    .eq('user_id', post.user_id)
    .in('platform', post.platforms)
    .eq('is_active', true);

  if (accErr) throw new Error(accErr.message);

  if (!accounts?.length) {
    await markFailed(postId, 'No connected accounts for selected platforms');
    return { success: false, error: 'no_accounts' };
  }

  // ── 4. Check for already-published platforms (idempotency) ─
  const { data: existingResults } = await supabase
    .from('post_results')
    .select('platform, status')
    .eq('post_id', postId)
    .eq('status', 'published');

  const alreadyPublished = new Set(existingResults?.map(r => r.platform) || []);

  // ── 5. Publish to each platform ───────────────────────────
  const results = [];

  for (const account of accounts) {
    const platform = account.platform;

    // Skip if already published to this platform
    if (alreadyPublished.has(platform)) {
      warn(`${platform} already published — skipping`);
      results.push({ platform, success: true, skipped: true });
      continue;
    }

    const result = await publishToPlatform(post, account, job.id);
    results.push(result);
  }

  // ── 6. Update post status ─────────────────────────────────
  const successCount = results.filter(r => r.success).length;
  const totalCount   = results.filter(r => !r.skipped).length;

  let finalStatus;
  if (successCount === 0)          finalStatus = 'failed';
  else if (successCount < totalCount) finalStatus = 'partial';
  else                             finalStatus = 'published';

  await supabase.from('posts').update({
    status:       finalStatus,
    published_at: successCount > 0 ? new Date().toISOString() : null,
    updated_at:   new Date().toISOString(),
  }).eq('id', postId);

  // ── 7. Save per-platform results ──────────────────────────
  for (const result of results) {
    if (result.skipped) continue;

    await supabase.from('post_results').upsert({
      post_id:          postId,
      platform:         result.platform,
      status:           result.success ? 'published' : 'failed',
      platform_post_id: result.platformPostId || null,
      error_message:    result.error || null,
      published_at:     result.success ? new Date().toISOString() : null,
    }, { onConflict: 'post_id,platform' });
  }

  log(`Done. Status: ${finalStatus} | Results: ${JSON.stringify(
    results.map(r => ({ platform: r.platform, success: r.success, error: r.error }))
  )}`);

  return { postId, status: finalStatus, results };
}

// ─────────────────────────────────────────────────────────────
// Publish to a single platform with token refresh
// ─────────────────────────────────────────────────────────────
async function publishToPlatform(post, account, jobId) {
  const platform = account.platform;
  const service  = PLATFORM_SERVICES[platform];

  if (!service) {
    return { platform, success: false, error: `No service for ${platform}` };
  }

  try {
    // Decrypt token
    let token;
    try {
      token = decrypt(account.access_token);
    } catch (e) {
      return { platform, success: false, error: 'Token decryption failed' };
    }

    // Validate token
    const { valid } = await service.validateToken(token);

    if (!valid) {
      // Try token refresh (Twitter + YouTube support it)
      const refreshed = await tryRefreshToken(account, platform);

      if (refreshed) {
        token = refreshed;
        logger.info(`[Job ${jobId}] Token refreshed for ${platform}`);
      } else {
        // Mark expired
        await supabase.from('social_accounts').update({
          token_expired: true,
          is_active:     false,
          status:        'expired',
        }).eq('id', account.id);

        return { platform, success: false, error: 'Token expired — user must reconnect' };
      }
    }

    // Publish
    const result = await service.publishPost(post, account, token);
    return { platform, ...result };

  } catch (err) {
    logger.error(`[Job ${jobId}] ${platform} error: ${err.message}`);

    // Rate limit — re-queue with delay
    if (err.response?.status === 429) {
      const retryAfter = parseInt(err.response.headers['retry-after'] || '60', 10);
      logger.warn(`[Job ${jobId}] Rate limited [${platform}] — retry in ${retryAfter}s`);
      await postQueue.add('publish-post',
        { postId: post.id },
        { delay: retryAfter * 1000, attempts: 3 }
      );
      return { platform, success: false, error: 'Rate limited — requeued' };
    }

    return { platform, success: false, error: err.message };
  }
}

// ─────────────────────────────────────────────────────────────
// Token auto-refresh
// ─────────────────────────────────────────────────────────────
async function tryRefreshToken(account, platform) {
  if (!account.refresh_token) return null;

  try {
    let newAccessToken = null;

    if (platform === 'twitter' && process.env.TWITTER_CLIENT_ID) {
      const refreshed = await twitterService.refreshToken(
        decrypt(account.refresh_token),
        process.env.TWITTER_CLIENT_ID,
        process.env.TWITTER_CLIENT_SECRET
      );
      newAccessToken = refreshed.accessToken;

      // Save new tokens
      await supabase.from('social_accounts').update({
        access_token:  encrypt(newAccessToken),
        refresh_token: refreshed.refreshToken ? encrypt(refreshed.refreshToken) : account.refresh_token,
        token_expired: false,
        is_active:     true,
        status:        'connected',
      }).eq('id', account.id);

    } else if (platform === 'youtube' && process.env.YOUTUBE_CLIENT_ID) {
      const { data } = await require('axios').post('https://oauth2.googleapis.com/token', {
        grant_type:    'refresh_token',
        refresh_token: decrypt(account.refresh_token),
        client_id:     process.env.YOUTUBE_CLIENT_ID || process.env.GOOGLE_CLIENT_ID,
        client_secret: process.env.YOUTUBE_CLIENT_SECRET || process.env.GOOGLE_CLIENT_SECRET,
      });
      newAccessToken = data.access_token;

      await supabase.from('social_accounts').update({
        access_token:  encrypt(newAccessToken),
        token_expired: false,
        is_active:     true,
        status:        'connected',
      }).eq('id', account.id);
    }

    return newAccessToken;
  } catch (err) {
    logger.warn(`Token refresh failed [${platform}]: ${err.message}`);
    return null;
  }
}

// ─────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────
async function markFailed(postId, reason) {
  await supabase.from('posts').update({
    status:     'failed',
    updated_at: new Date().toISOString(),
  }).eq('id', postId);
  logger.error(`Post ${postId} marked failed: ${reason}`);
}

module.exports = { startQueueWorkers };

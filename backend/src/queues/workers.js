const { postQueue } = require('./postQueue');
const { supabase } = require('../utils/supabase');
const { decrypt } = require('../utils/encrypt');
const { logger } = require('../utils/logger');
const axios = require('axios');

// ── Platform Publishers ───────────────────────────────────────

async function publishToInstagram(account, post) {
  const token = decrypt(account.access_token);
  const caption = [post.caption, ...(post.hashtags || [])].join('\n\n');

  if (!post.media_urls?.length) throw new Error('Instagram requires media');

  // Step 1: Create media container
  const containerRes = await axios.post(
    `https://graph.instagram.com/${account.platform_user_id}/media`,
    { image_url: post.media_urls[0], caption, access_token: token }
  );

  // Step 2: Publish container
  const publishRes = await axios.post(
    `https://graph.instagram.com/${account.platform_user_id}/media_publish`,
    { creation_id: containerRes.data.id, access_token: token }
  );

  return publishRes.data.id;
}

async function publishToFacebook(account, post) {
  const token = decrypt(account.access_token);
  const pageId = account.page_id || account.platform_user_id;
  const caption = [post.caption, ...(post.hashtags || [])].join('\n\n');

  const endpoint = post.media_urls?.length
    ? `https://graph.facebook.com/${pageId}/photos`
    : `https://graph.facebook.com/${pageId}/feed`;

  const payload = post.media_urls?.length
    ? { url: post.media_urls[0], caption, access_token: token }
    : { message: caption, access_token: token };

  const res = await axios.post(endpoint, payload);
  return res.data.id || res.data.post_id;
}

async function publishToTwitter(account, post) {
  const token = decrypt(account.access_token);
  const text = [post.caption, ...(post.hashtags || [])].join(' ').substring(0, 280);

  const res = await axios.post(
    'https://api.twitter.com/2/tweets',
    { text },
    { headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' } }
  );
  return res.data.data.id;
}

async function publishToLinkedIn(account, post) {
  const token = decrypt(account.access_token);
  const text = [post.caption, ...(post.hashtags || [])].join('\n\n');

  const res = await axios.post(
    'https://api.linkedin.com/v2/ugcPosts',
    {
      author: `urn:li:person:${account.platform_user_id}`,
      lifecycleState: 'PUBLISHED',
      specificContent: {
        'com.linkedin.ugc.ShareContent': {
          shareCommentary: { text },
          shareMediaCategory: 'NONE'
        }
      },
      visibility: { 'com.linkedin.ugc.MemberNetworkVisibility': 'PUBLIC' }
    },
    { headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' } }
  );
  return res.data.id;
}

// ── YouTube Publisher ─────────────────────────────────────────
// Uses YouTube Data API v3 to upload a video or create a community post
async function publishToYouTube(account, post) {
  const token = decrypt(account.access_token);

  // YouTube supports video uploads and community posts
  // For community posts (text + image), use the community post endpoint
  if (!post.media_urls?.length) {
    // Community post (text only) – requires channel membership feature
    // Fall back to a simple video description update or skip
    throw new Error('YouTube requires a video file URL');
  }

  const title    = post.caption?.substring(0, 100) || 'New Video';
  const description = [post.caption, ...(post.hashtags || [])].join('\n\n');
  const tags     = (post.hashtags || []).map(h => h.replace('#', ''));

  // Step 1: Insert video metadata
  const metaRes = await axios.post(
    'https://www.googleapis.com/youtube/v3/videos?part=snippet,status',
    {
      snippet: {
        title,
        description,
        tags,
        categoryId: '22' // People & Blogs
      },
      status: {
        privacyStatus: 'public',
        selfDeclaredMadeForKids: false
      }
    },
    { headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' } }
  );

  const videoId = metaRes.data.id;

  // Step 2: Upload video via resumable upload
  const videoUrl = post.media_urls[0];
  const videoStream = await axios.get(videoUrl, { responseType: 'stream' });

  await axios.put(
    `https://www.googleapis.com/upload/youtube/v3/videos?uploadType=resumable&videoId=${videoId}`,
    videoStream.data,
    {
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'video/*',
        'X-Upload-Content-Type': 'video/*'
      }
    }
  );

  return videoId;
}

const PUBLISHERS = {
  instagram: publishToInstagram,
  facebook:  publishToFacebook,
  twitter:   publishToTwitter,
  linkedin:  publishToLinkedIn,
  youtube:   publishToYouTube
};

// ── Main Worker ───────────────────────────────────────────────
async function processPost(job) {
  const { postId } = job.data;
  logger.info(`Processing post ${postId}`);

  // Fetch post
  const { data: post, error: postErr } = await supabase
    .from('posts').select('*').eq('id', postId).single();
  if (postErr || !post) throw new Error(`Post ${postId} not found`);

  // Update status
  await supabase.from('posts').update({ status: 'publishing' }).eq('id', postId);

  // Fetch user's connected accounts for each platform
  const { data: accounts } = await supabase
    .from('social_accounts')
    .select('*')
    .eq('user_id', post.user_id)
    .in('platform', post.platforms)
    .eq('is_active', true);

  const results = [];

  for (const account of accounts || []) {
    // Create result record
    const { data: result } = await supabase.from('post_results').insert({
      post_id: postId,
      social_account_id: account.id,
      platform: account.platform,
      status: 'pending'
    }).select().single();

    try {
      const publisher = PUBLISHERS[account.platform];
      if (!publisher) throw new Error(`No publisher for ${account.platform}`);

      const platformPostId = await publisher(account, post);

      await supabase.from('post_results').update({
        status: 'success',
        platform_post_id: platformPostId,
        published_at: new Date()
      }).eq('id', result.id);

      results.push({ platform: account.platform, success: true, id: platformPostId });
    } catch (err) {
      logger.error(`Failed to publish to ${account.platform}: ${err.message}`);
      await supabase.from('post_results').update({
        status: 'failed',
        error_message: err.message
      }).eq('id', result.id);

      results.push({ platform: account.platform, success: false, error: err.message });
    }
  }

  const allFailed = results.every(r => !r.success);
  await supabase.from('posts').update({
    status: allFailed ? 'failed' : 'published',
    published_at: allFailed ? null : new Date()
  }).eq('id', postId);

  return results;
}

// ── Start Workers ─────────────────────────────────────────────
function startQueueWorkers() {
  postQueue.process('publish', 5, async (job) => {
    return processPost(job);
  });

  postQueue.on('completed', (job, result) => {
    logger.info(`Post ${job.data.postId} published`, result);
  });

  postQueue.on('failed', (job, err) => {
    logger.error(`Post ${job.data.postId} failed: ${err.message}`);
  });

  logger.info('Queue workers started');
}

module.exports = { startQueueWorkers };

const router = require('express').Router();
const { authenticate } = require('../middleware/auth');
const { supabase } = require('../utils/supabase');

// ── Overview Dashboard ────────────────────────────────────────
router.get('/overview', authenticate, async (req, res) => {
  const userId = req.user.id;

  const [postsRes, accountsRes, analyticsRes] = await Promise.all([
    supabase.from('posts').select('id, status', { count: 'exact' }).eq('user_id', userId),
    supabase.from('social_accounts').select('id, platform, username').eq('user_id', userId).eq('is_active', true),
    supabase.from('post_analytics')
      .select('likes, comments, shares, reach, impressions, engagement_rate, post_results!inner(posts!inner(user_id))')
      .eq('post_results.posts.user_id', userId)
  ]);

  const posts = postsRes.data || [];
  const analytics = analyticsRes.data || [];

  const totalLikes       = analytics.reduce((s, a) => s + (a.likes || 0), 0);
  const totalReach       = analytics.reduce((s, a) => s + (a.reach || 0), 0);
  const totalImpressions = analytics.reduce((s, a) => s + (a.impressions || 0), 0);
  const avgEngagement    = analytics.length
    ? (analytics.reduce((s, a) => s + (a.engagement_rate || 0), 0) / analytics.length).toFixed(2)
    : 0;

  res.json({
    total_posts:       posts.length,
    published_posts:   posts.filter(p => p.status === 'published').length,
    scheduled_posts:   posts.filter(p => p.status === 'scheduled').length,
    connected_accounts: accountsRes.data?.length || 0,
    total_likes:       totalLikes,
    total_reach:       totalReach,
    total_impressions: totalImpressions,
    avg_engagement:    +avgEngagement
  });
});

// ── Top Performing Posts ──────────────────────────────────────
router.get('/top-posts', authenticate, async (req, res) => {
  const { limit = 5, metric = 'engagement_rate' } = req.query;

  const { data, error } = await supabase
    .from('post_analytics')
    .select(`
      *,
      post_results!inner(
        platform,
        posts!inner(id, caption, media_urls, user_id)
      )
    `)
    .eq('post_results.posts.user_id', req.user.id)
    .order(metric, { ascending: false })
    .limit(+limit);

  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

// ── Growth Tracking ───────────────────────────────────────────
router.get('/growth', authenticate, async (req, res) => {
  const { days = 30 } = req.query;
  const from = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();

  const { data, error } = await supabase
    .from('account_analytics')
    .select('*, social_accounts!inner(user_id, platform, username)')
    .eq('social_accounts.user_id', req.user.id)
    .gte('recorded_at', from)
    .order('recorded_at');

  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

// ── Engagement Trends ─────────────────────────────────────────
router.get('/engagement', authenticate, async (req, res) => {
  const { platform, days = 30 } = req.query;
  const from = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();

  let q = supabase
    .from('post_analytics')
    .select(`
      engagement_rate, likes, comments, shares, reach, fetched_at,
      post_results!inner(platform, posts!inner(user_id, scheduled_at))
    `)
    .eq('post_results.posts.user_id', req.user.id)
    .gte('post_results.posts.scheduled_at', from);

  if (platform) q = q.eq('post_results.platform', platform);

  const { data, error } = await q.order('fetched_at');
  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

// ── Force sync analytics from platforms ──────────────────────
router.post('/sync', authenticate, async (req, res) => {
  // In production: queue a job to fetch fresh analytics from each platform API
  // For now, return a queued confirmation
  res.json({ message: 'Analytics sync queued. Data will update within 5 minutes.' });
});

module.exports = router;

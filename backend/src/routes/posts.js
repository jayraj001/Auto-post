const router = require('express').Router();
const { body, query, validationResult } = require('express-validator');
const { authenticate, requirePlan } = require('../middleware/auth');
const { supabase } = require('../utils/supabase');
const { postQueue } = require('../queues/postQueue');

// ── List posts ────────────────────────────────────────────────
router.get('/', authenticate, async (req, res) => {
  const { status, platform, from, to, page = 1, limit = 20 } = req.query;
  let q = supabase.from('posts').select('*, post_results(*)').eq('user_id', req.user.id);

  if (status) q = q.eq('status', status);
  if (from)   q = q.gte('scheduled_at', from);
  if (to)     q = q.lte('scheduled_at', to);

  q = q.order('created_at', { ascending: false })
       .range((page - 1) * limit, page * limit - 1);

  const { data, error, count } = await q;
  if (error) return res.status(500).json({ error: error.message });
  res.json({ posts: data, page: +page, limit: +limit });
});

// ── Calendar view ─────────────────────────────────────────────
router.get('/calendar', authenticate, async (req, res) => {
  const { month, year } = req.query;
  const from = `${year}-${month}-01`;
  const to   = `${year}-${month}-31`;

  const { data, error } = await supabase.from('posts')
    .select('id, caption, platforms, status, scheduled_at, media_type')
    .eq('user_id', req.user.id)
    .gte('scheduled_at', from)
    .lte('scheduled_at', to)
    .order('scheduled_at');

  if (error) return res.status(500).json({ error: error.message });

  // Group by date
  const calendar = data.reduce((acc, post) => {
    const date = post.scheduled_at?.split('T')[0];
    if (!acc[date]) acc[date] = [];
    acc[date].push(post);
    return acc;
  }, {});

  res.json(calendar);
});

// ── Create post ───────────────────────────────────────────────
router.post('/', authenticate, [
  body('platforms').isArray({ min: 1 }),
  body('caption').optional().isString(),
  body('scheduled_at').optional().isISO8601()
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

  const { caption, hashtags, media_urls, media_type, platforms, scheduled_at, ai_generated } = req.body;

  const { data: post, error } = await supabase.from('posts').insert({
    user_id: req.user.id,
    caption, hashtags, media_urls, media_type, platforms,
    scheduled_at,
    status: scheduled_at ? 'scheduled' : 'draft',
    ai_generated: !!ai_generated
  }).select().single();

  if (error) return res.status(500).json({ error: error.message });

  // Queue if scheduled
  if (scheduled_at) {
    const delay = new Date(scheduled_at).getTime() - Date.now();
    if (delay > 0) {
      await postQueue.add('publish', { postId: post.id }, { delay });
    }
  }

  res.status(201).json(post);
});

// ── Bulk create ───────────────────────────────────────────────
router.post('/bulk', authenticate, requirePlan('pro', 'premium'), async (req, res) => {
  const { posts } = req.body;
  if (!Array.isArray(posts) || posts.length === 0) {
    return res.status(400).json({ error: 'posts array required' });
  }

  const rows = posts.map(p => ({ ...p, user_id: req.user.id, status: p.scheduled_at ? 'scheduled' : 'draft' }));
  const { data, error } = await supabase.from('posts').insert(rows).select();
  if (error) return res.status(500).json({ error: error.message });

  // Queue all scheduled
  for (const post of data) {
    if (post.scheduled_at) {
      const delay = new Date(post.scheduled_at).getTime() - Date.now();
      if (delay > 0) await postQueue.add('publish', { postId: post.id }, { delay });
    }
  }

  res.status(201).json({ created: data.length, posts: data });
});

// ── Get single post ───────────────────────────────────────────
router.get('/:id', authenticate, async (req, res) => {
  const { data, error } = await supabase.from('posts')
    .select('*, post_results(*, post_analytics(*))')
    .eq('id', req.params.id)
    .eq('user_id', req.user.id)
    .single();

  if (error || !data) return res.status(404).json({ error: 'Post not found' });
  res.json(data);
});

// ── Update post ───────────────────────────────────────────────
router.put('/:id', authenticate, async (req, res) => {
  const { caption, hashtags, media_urls, platforms, scheduled_at } = req.body;

  const { data, error } = await supabase.from('posts')
    .update({ caption, hashtags, media_urls, platforms, scheduled_at, updated_at: new Date() })
    .eq('id', req.params.id)
    .eq('user_id', req.user.id)
    .select().single();

  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

// ── Delete post ───────────────────────────────────────────────
router.delete('/:id', authenticate, async (req, res) => {
  const { error } = await supabase.from('posts')
    .delete()
    .eq('id', req.params.id)
    .eq('user_id', req.user.id);

  if (error) return res.status(500).json({ error: error.message });
  res.json({ success: true });
});

// ── Publish now ───────────────────────────────────────────────
router.post('/:id/publish', authenticate, async (req, res) => {
  const { data: post } = await supabase.from('posts')
    .select('*').eq('id', req.params.id).eq('user_id', req.user.id).single();

  if (!post) return res.status(404).json({ error: 'Post not found' });

  await postQueue.add('publish', { postId: post.id }, { priority: 1 });
  res.json({ message: 'Post queued for immediate publishing' });
});

// ── Repost ────────────────────────────────────────────────────
router.post('/:id/repost', authenticate, async (req, res) => {
  const { scheduled_at } = req.body;
  const { data: original } = await supabase.from('posts')
    .select('*').eq('id', req.params.id).eq('user_id', req.user.id).single();

  if (!original) return res.status(404).json({ error: 'Post not found' });

  const { data: repost, error } = await supabase.from('posts').insert({
    user_id: req.user.id,
    caption: original.caption,
    hashtags: original.hashtags,
    media_urls: original.media_urls,
    media_type: original.media_type,
    platforms: original.platforms,
    scheduled_at,
    status: scheduled_at ? 'scheduled' : 'draft',
    is_repost: true,
    original_post_id: original.id
  }).select().single();

  if (error) return res.status(500).json({ error: error.message });
  res.status(201).json(repost);
});

// ── Retry failed post ─────────────────────────────────────────
router.post('/:id/retry', authenticate, async (req, res) => {
  const { data: post } = await supabase.from('posts')
    .select('*').eq('id', req.params.id).eq('user_id', req.user.id).single();

  if (!post) return res.status(404).json({ error: 'Post not found' });

  if (!['failed', 'partial'].includes(post.status)) {
    return res.status(400).json({
      error: `Cannot retry post with status: ${post.status}`,
      code:  'INVALID_STATUS',
    });
  }

  // Reset status to scheduled
  await supabase.from('posts').update({
    status:     'scheduled',
    updated_at: new Date().toISOString(),
  }).eq('id', post.id);

  // Re-queue with high priority
  await postQueue.add('publish-post', { postId: post.id }, { priority: 1 });

  res.json({ message: 'Post queued for retry', postId: post.id });
});

module.exports = router;

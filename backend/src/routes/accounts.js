const router = require('express').Router();
const { authenticate } = require('../middleware/auth');
const { supabase } = require('../utils/supabase');
const { encrypt, decrypt } = require('../utils/encrypt');
const axios = require('axios');

// ── List connected accounts ───────────────────────────────────
router.get('/', authenticate, async (req, res) => {
  const { data, error } = await supabase
    .from('social_accounts')
    .select('id, platform, username, display_name, avatar_url, is_active, created_at')
    .eq('user_id', req.user.id);

  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

// ── Connect Instagram / Facebook ──────────────────────────────
router.post('/connect/instagram', authenticate, async (req, res) => {
  const { access_token, platform_user_id, username, display_name, avatar_url, page_id } = req.body;
  if (!access_token || !platform_user_id) return res.status(400).json({ error: 'Missing required fields' });

  const { data, error } = await supabase.from('social_accounts').upsert({
    user_id: req.user.id,
    platform: 'instagram',
    platform_user_id,
    username,
    display_name,
    avatar_url,
    access_token: encrypt(access_token),
    page_id,
    is_active: true
  }, { onConflict: 'user_id,platform,platform_user_id' }).select().single();

  if (error) return res.status(500).json({ error: error.message });
  res.json({ id: data.id, platform: data.platform, username: data.username });
});

router.post('/connect/facebook', authenticate, async (req, res) => {
  const { access_token, platform_user_id, username, display_name, avatar_url, page_id } = req.body;

  const { data, error } = await supabase.from('social_accounts').upsert({
    user_id: req.user.id,
    platform: 'facebook',
    platform_user_id,
    username,
    display_name,
    avatar_url,
    access_token: encrypt(access_token),
    page_id,
    is_active: true
  }, { onConflict: 'user_id,platform,platform_user_id' }).select().single();

  if (error) return res.status(500).json({ error: error.message });
  res.json({ id: data.id, platform: data.platform, username: data.username });
});

router.post('/connect/twitter', authenticate, async (req, res) => {
  const { access_token, refresh_token, platform_user_id, username, display_name, avatar_url } = req.body;

  const { data, error } = await supabase.from('social_accounts').upsert({
    user_id: req.user.id,
    platform: 'twitter',
    platform_user_id,
    username,
    display_name,
    avatar_url,
    access_token: encrypt(access_token),
    refresh_token: refresh_token ? encrypt(refresh_token) : null,
    is_active: true
  }, { onConflict: 'user_id,platform,platform_user_id' }).select().single();

  if (error) return res.status(500).json({ error: error.message });
  res.json({ id: data.id, platform: data.platform, username: data.username });
});

router.post('/connect/linkedin', authenticate, async (req, res) => {
  const { access_token, platform_user_id, username, display_name, avatar_url } = req.body;

  const { data, error } = await supabase.from('social_accounts').upsert({
    user_id: req.user.id,
    platform: 'linkedin',
    platform_user_id,
    username,
    display_name,
    avatar_url,
    access_token: encrypt(access_token),
    is_active: true
  }, { onConflict: 'user_id,platform,platform_user_id' }).select().single();

  if (error) return res.status(500).json({ error: error.message });
  res.json({ id: data.id, platform: data.platform, username: data.username });
});

// ── Connect YouTube ───────────────────────────────────────────
router.post('/connect/youtube', authenticate, async (req, res) => {
  const { access_token, refresh_token, platform_user_id, username, display_name, avatar_url } = req.body;
  if (!access_token || !platform_user_id) return res.status(400).json({ error: 'Missing required fields' });

  const { data, error } = await supabase.from('social_accounts').upsert({
    user_id: req.user.id,
    platform: 'youtube',
    platform_user_id,
    username,
    display_name,
    avatar_url,
    access_token: encrypt(access_token),
    refresh_token: refresh_token ? encrypt(refresh_token) : null,
    is_active: true
  }, { onConflict: 'user_id,platform,platform_user_id' }).select().single();

  if (error) return res.status(500).json({ error: error.message });
  res.json({ id: data.id, platform: data.platform, username: data.username });
});

// ── Disconnect account ────────────────────────────────────────
router.delete('/:id', authenticate, async (req, res) => {
  const { error } = await supabase.from('social_accounts')
    .delete()
    .eq('id', req.params.id)
    .eq('user_id', req.user.id);

  if (error) return res.status(500).json({ error: error.message });
  res.json({ success: true });
});

// ── Account stats ─────────────────────────────────────────────
router.get('/:id/stats', authenticate, async (req, res) => {
  const { data, error } = await supabase
    .from('account_analytics')
    .select('*')
    .eq('social_account_id', req.params.id)
    .order('recorded_at', { ascending: false })
    .limit(30);

  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

module.exports = router;

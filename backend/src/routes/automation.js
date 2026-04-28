const router = require('express').Router();
const { authenticate, requirePlan } = require('../middleware/auth');
const { supabase } = require('../utils/supabase');

// ── Automation Rules ──────────────────────────────────────────
router.get('/rules', authenticate, requirePlan('pro', 'premium'), async (req, res) => {
  const { data, error } = await supabase.from('automation_rules')
    .select('*').eq('user_id', req.user.id).order('created_at', { ascending: false });
  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

router.post('/rules', authenticate, requirePlan('pro', 'premium'), async (req, res) => {
  const { name, trigger, trigger_config, action, action_config } = req.body;
  if (!name || !trigger || !action) return res.status(400).json({ error: 'name, trigger, action required' });

  const { data, error } = await supabase.from('automation_rules').insert({
    user_id: req.user.id, name, trigger, trigger_config, action, action_config
  }).select().single();

  if (error) return res.status(500).json({ error: error.message });
  res.status(201).json(data);
});

router.put('/rules/:id', authenticate, requirePlan('pro', 'premium'), async (req, res) => {
  const { name, trigger_config, action_config, is_active } = req.body;

  const { data, error } = await supabase.from('automation_rules')
    .update({ name, trigger_config, action_config, is_active })
    .eq('id', req.params.id)
    .eq('user_id', req.user.id)
    .select().single();

  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

router.delete('/rules/:id', authenticate, requirePlan('pro', 'premium'), async (req, res) => {
  const { error } = await supabase.from('automation_rules')
    .delete().eq('id', req.params.id).eq('user_id', req.user.id);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ success: true });
});

// ── Auto Reply Templates ──────────────────────────────────────
router.get('/replies', authenticate, requirePlan('pro', 'premium'), async (req, res) => {
  const { data, error } = await supabase.from('auto_reply_templates')
    .select('*').eq('user_id', req.user.id);
  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

router.post('/replies', authenticate, requirePlan('pro', 'premium'), async (req, res) => {
  const { platform, trigger_keywords, reply_text, is_ai_reply } = req.body;
  if (!platform || !reply_text) return res.status(400).json({ error: 'platform and reply_text required' });

  const { data, error } = await supabase.from('auto_reply_templates').insert({
    user_id: req.user.id, platform, trigger_keywords, reply_text, is_ai_reply
  }).select().single();

  if (error) return res.status(500).json({ error: error.message });
  res.status(201).json(data);
});

module.exports = router;

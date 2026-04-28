const router = require('express').Router();
const { authenticate } = require('../middleware/auth');
const { supabase } = require('../utils/supabase');

router.get('/', authenticate, async (req, res) => {
  const { data: referrals } = await supabase.from('referrals')
    .select('*, referred:referred_id(name, email, created_at)')
    .eq('referrer_id', req.user.id);

  res.json({
    referral_code: req.user.referral_code,
    referral_link: `https://autopostai.com/signup?ref=${req.user.referral_code}`,
    total_referrals: referrals?.length || 0,
    rewarded: referrals?.filter(r => r.reward_given).length || 0,
    referrals: referrals || []
  });
});

router.post('/apply', authenticate, async (req, res) => {
  const { code } = req.body;
  if (!code) return res.status(400).json({ error: 'Referral code required' });

  const { data: referrer } = await supabase.from('users').select('id').eq('referral_code', code).single();
  if (!referrer) return res.status(404).json({ error: 'Invalid referral code' });
  if (referrer.id === req.user.id) return res.status(400).json({ error: 'Cannot use your own code' });

  const { data: existing } = await supabase.from('referrals')
    .select('id').eq('referred_id', req.user.id).single();
  if (existing) return res.status(409).json({ error: 'Referral already applied' });

  await supabase.from('referrals').insert({ referrer_id: referrer.id, referred_id: req.user.id });
  await supabase.from('users').update({ referred_by: referrer.id }).eq('id', req.user.id);

  res.json({ message: 'Referral applied successfully' });
});

module.exports = router;

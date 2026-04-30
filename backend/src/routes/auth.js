const router = require('express').Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { body, validationResult } = require('express-validator');
const { supabase } = require('../utils/supabase');
const { authenticate } = require('../middleware/auth');

const signToken = (userId) =>
  jwt.sign({ userId }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN });

// ── Register ─────────────────────────────────────────────────
router.post('/register', [
  body('email').isEmail(),
  body('name').notEmpty(),
  body('password').isLength({ min: 8 })
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

  const { email, name, password, referral_code } = req.body;

  // Check existing
  const { data: existing } = await supabase.from('users').select('id').eq('email', email).single();
  if (existing) return res.status(409).json({ error: 'Email already registered' });

  const password_hash = await bcrypt.hash(password, 12);
  const trial_ends_at = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days

  // Find referrer
  let referred_by = null;
  if (referral_code) {
    const { data: referrer } = await supabase.from('users').select('id').eq('referral_code', referral_code).single();
    if (referrer) referred_by = referrer.id;
  }

  const { data: user, error } = await supabase.from('users').insert({
    email, name, password_hash, trial_ends_at, referred_by, plan: 'free'
  }).select().single();

  if (error) return res.status(500).json({ error: error.message });

  // Log referral
  if (referred_by) {
    await supabase.from('referrals').insert({ referrer_id: referred_by, referred_id: user.id });
  }

  res.status(201).json({ token: signToken(user.id), user: sanitize(user) });
});

// ── Login ─────────────────────────────────────────────────────
router.post('/login', [
  body('email').isEmail().withMessage('Enter a valid email'),
  body('password').notEmpty().withMessage('Password is required')
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

  const { email, password } = req.body;

  // Find user
  const { data: user, error: dbError } = await supabase
    .from('users')
    .select('*')
    .eq('email', email.toLowerCase().trim())
    .single();

  // Specific: user not found
  if (dbError || !user) {
    return res.status(401).json({
      error: 'No account found with this email.',
      code: 'USER_NOT_FOUND'
    });
  }

  // Specific: wrong password
  const passwordMatch = await bcrypt.compare(password, user.password_hash);
  if (!passwordMatch) {
    return res.status(401).json({
      error: 'Incorrect password. Please try again.',
      code: 'WRONG_PASSWORD'
    });
  }

  // Specific: account disabled
  if (user.is_disabled) {
    return res.status(403).json({
      error: 'This account has been disabled. Contact support.',
      code: 'ACCOUNT_DISABLED'
    });
  }

  res.json({ token: signToken(user.id), user: sanitize(user) });
});

// ── Google OAuth callback ─────────────────────────────────────
router.post('/google', async (req, res) => {
  const { google_id, email, name, avatar_url } = req.body;
  if (!google_id || !email) return res.status(400).json({ error: 'Missing Google data' });

  let { data: user } = await supabase.from('users').select('*').eq('google_id', google_id).single();

  if (!user) {
    const trial_ends_at = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    const { data: newUser, error } = await supabase.from('users')
      .insert({ google_id, email, name, avatar_url, trial_ends_at, plan: 'free' })
      .select().single();
    if (error) return res.status(500).json({ error: error.message });
    user = newUser;
  }

  res.json({ token: signToken(user.id), user: sanitize(user) });
});

// ── Me ────────────────────────────────────────────────────────
router.get('/me', authenticate, (req, res) => res.json(sanitize(req.user)));

// ── Refresh ───────────────────────────────────────────────────
router.post('/refresh', authenticate, (req, res) => {
  res.json({ token: signToken(req.user.id) });
});

const sanitize = (u) => {
  const { password_hash, ...safe } = u;
  return safe;
};

module.exports = router;

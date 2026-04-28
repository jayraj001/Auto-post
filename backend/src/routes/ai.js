const router = require('express').Router();
const { body, validationResult } = require('express-validator');
const { authenticate, requirePlan } = require('../middleware/auth');
const { supabase } = require('../utils/supabase');
const OpenAI = require('openai');

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

// Helper: log AI usage
const logUsage = async (userId, type, prompt, result, tokens) => {
  await supabase.from('ai_generations').insert({ user_id: userId, type, prompt, result, tokens_used: tokens });
};

// ── Caption Generator ─────────────────────────────────────────
router.post('/caption', authenticate, [
  body('topic').notEmpty(),
  body('tone').optional().isIn(['excited', 'professional', 'casual', 'funny', 'inspirational']),
  body('length').optional().isIn(['short', 'medium', 'long'])
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

  const { topic, tone = 'casual', length = 'medium', platform = 'instagram', brand_voice } = req.body;

  const lengthGuide = { short: '1-2 sentences', medium: '3-4 sentences', long: '5-7 sentences' };

  const prompt = `You are a social media expert. Write a ${tone} ${platform} caption about: "${topic}".
Length: ${lengthGuide[length]}.
${brand_voice ? `Brand voice: ${brand_voice}` : ''}
Include relevant emojis. Do NOT include hashtags (those come separately).
Return JSON: { "caption": "...", "alternatives": ["...", "..."] }`;

  const completion = await openai.chat.completions.create({
    model: 'gpt-4o',
    messages: [{ role: 'user', content: prompt }],
    response_format: { type: 'json_object' }
  });

  const result = JSON.parse(completion.choices[0].message.content);
  await logUsage(req.user.id, 'caption', topic, result.caption, completion.usage.total_tokens);

  res.json({ ...result, tokens_used: completion.usage.total_tokens });
});

// ── Hashtag Generator ─────────────────────────────────────────
router.post('/hashtags', authenticate, [
  body('niche').notEmpty(),
  body('post_topic').notEmpty()
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

  const { niche, post_topic, count = 20 } = req.body;

  const prompt = `Generate ${count} Instagram hashtags for a post about "${post_topic}" in the "${niche}" niche.
Mix: trending (high volume), niche-specific (medium), and long-tail (low competition).
Return JSON: { "trending": [...], "niche": [...], "long_tail": [...], "all": [...] }`;

  const completion = await openai.chat.completions.create({
    model: 'gpt-4o',
    messages: [{ role: 'user', content: prompt }],
    response_format: { type: 'json_object' }
  });

  const result = JSON.parse(completion.choices[0].message.content);
  await logUsage(req.user.id, 'hashtags', post_topic, JSON.stringify(result.all), completion.usage.total_tokens);

  res.json(result);
});

// ── Viral Hook Generator ──────────────────────────────────────
router.post('/hook', authenticate, [
  body('topic').notEmpty()
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

  const { topic, platform = 'instagram', hook_type = 'curiosity' } = req.body;

  const prompt = `Write 5 viral ${hook_type} hooks for a ${platform} post about: "${topic}".
Hooks should stop the scroll in the first 3 seconds.
Types: curiosity, controversy, value, story, fear-of-missing-out.
Return JSON: { "hooks": [{ "text": "...", "type": "..." }] }`;

  const completion = await openai.chat.completions.create({
    model: 'gpt-4o',
    messages: [{ role: 'user', content: prompt }],
    response_format: { type: 'json_object' }
  });

  const result = JSON.parse(completion.choices[0].message.content);
  await logUsage(req.user.id, 'hook', topic, JSON.stringify(result.hooks), completion.usage.total_tokens);

  res.json(result);
});

// ── Content Ideas ─────────────────────────────────────────────
router.post('/content-ideas', authenticate, [
  body('niche').notEmpty()
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

  const { niche, count = 10, goal = 'engagement' } = req.body;

  const prompt = `Generate ${count} viral content ideas for a ${niche} account focused on ${goal}.
For each idea include: title, format (reel/carousel/story/post), why it works.
Return JSON: { "ideas": [{ "title": "...", "format": "...", "why": "...", "hook": "..." }] }`;

  const completion = await openai.chat.completions.create({
    model: 'gpt-4o',
    messages: [{ role: 'user', content: prompt }],
    response_format: { type: 'json_object' }
  });

  const result = JSON.parse(completion.choices[0].message.content);
  res.json(result);
});

// ── Best Time to Post ─────────────────────────────────────────
router.post('/best-time', authenticate, async (req, res) => {
  const { platform, niche, timezone = 'Asia/Kolkata' } = req.body;

  const prompt = `Based on data for ${platform} in the ${niche} niche, what are the top 5 best times to post?
Consider timezone: ${timezone}.
Return JSON: { "best_times": [{ "day": "Monday", "time": "09:00", "reason": "..." }], "summary": "..." }`;

  const completion = await openai.chat.completions.create({
    model: 'gpt-4o',
    messages: [{ role: 'user', content: prompt }],
    response_format: { type: 'json_object' }
  });

  res.json(JSON.parse(completion.choices[0].message.content));
});

// ── Image Generator (DALL-E 3) ────────────────────────────────
router.post('/image', authenticate, requirePlan('pro', 'premium'), [
  body('prompt').notEmpty()
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

  const { prompt, size = '1024x1024', style = 'vivid' } = req.body;

  const response = await openai.images.generate({
    model: 'dall-e-3',
    prompt: `Social media post image: ${prompt}. Professional, high quality, eye-catching.`,
    n: 1,
    size,
    style
  });

  await logUsage(req.user.id, 'image', prompt, response.data[0].url, 0);
  res.json({ url: response.data[0].url, revised_prompt: response.data[0].revised_prompt });
});

// ── Trending Topics ───────────────────────────────────────────
router.get('/trending', authenticate, async (req, res) => {
  const { niche = 'general' } = req.query;

  const prompt = `What are the top 10 trending topics and content formats on social media right now for the "${niche}" niche?
Return JSON: { "trends": [{ "topic": "...", "platforms": [...], "content_format": "...", "virality_score": 1-10 }] }`;

  const completion = await openai.chat.completions.create({
    model: 'gpt-4o',
    messages: [{ role: 'user', content: prompt }],
    response_format: { type: 'json_object' }
  });

  res.json(JSON.parse(completion.choices[0].message.content));
});

module.exports = router;

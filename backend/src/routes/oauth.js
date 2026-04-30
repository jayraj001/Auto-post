/**
 * OAuth Routes — Redirect-based OAuth flows for all platforms
 * Each platform follows: /oauth/:platform → redirect → callback → store token
 */
const router = require('express').Router();
const axios  = require('axios');
const { supabase } = require('../utils/supabase');
const { encrypt } = require('../utils/encrypt');
const { logger } = require('../utils/logger');

// ── Helpers ───────────────────────────────────────────────────
const FRONTEND_REDIRECT = process.env.FRONTEND_URL || 'http://localhost:3001';

function oauthError(res, msg) {
  return res.redirect(`${FRONTEND_REDIRECT}/oauth-result?error=${encodeURIComponent(msg)}`);
}

function oauthSuccess(res, platform, username) {
  return res.redirect(
    `${FRONTEND_REDIRECT}/oauth-result?success=true&platform=${platform}&username=${encodeURIComponent(username)}`
  );
}

// ── Instagram / Facebook (Meta) ───────────────────────────────
// Step 1: Redirect to Meta OAuth
router.get('/instagram', (req, res) => {
  const { state } = req.query;
  const params = new URLSearchParams({
    client_id:     process.env.FACEBOOK_CLIENT_ID || process.env.INSTAGRAM_APP_ID,
    redirect_uri:  process.env.FACEBOOK_REDIRECT_URI || `${process.env.APP_URL}/api/oauth/instagram/callback`,
    scope:         'instagram_basic,instagram_content_publish,pages_show_list',
    response_type: 'code',
    state:         state || '',
  });
  res.redirect(`https://www.facebook.com/v18.0/dialog/oauth?${params}`);
});

// Facebook OAuth — separate entry point
router.get('/facebook', (req, res) => {
  const { state } = req.query;
  const params = new URLSearchParams({
    client_id:     process.env.FACEBOOK_CLIENT_ID || process.env.FACEBOOK_APP_ID,
    redirect_uri:  process.env.FACEBOOK_REDIRECT_URI,
    scope:         'pages_manage_posts,pages_read_engagement,pages_show_list',
    response_type: 'code',
    state:         state || '',
  });
  res.redirect(`https://www.facebook.com/v18.0/dialog/oauth?${params}`);
});

// Step 2: Shared Meta callback (handles both Instagram + Facebook)
router.get('/instagram/callback', handleMetaCallback('instagram'));
router.get('/facebook/callback',  handleMetaCallback('facebook'));

function handleMetaCallback(platform) {
  return async (req, res) => {
    const { code, state, error } = req.query;
    if (error) return oauthError(res, error);

    try {
      const clientId     = process.env.FACEBOOK_CLIENT_ID || process.env.INSTAGRAM_APP_ID;
      const clientSecret = process.env.FACEBOOK_CLIENT_SECRET || process.env.INSTAGRAM_APP_SECRET;
      const redirectUri  = process.env.FACEBOOK_REDIRECT_URI ||
        `${process.env.APP_URL}/api/oauth/${platform}/callback`;

      // Exchange code for token
      const tokenRes = await axios.get('https://graph.facebook.com/v18.0/oauth/access_token', {
        params: { client_id: clientId, client_secret: clientSecret, redirect_uri: redirectUri, code },
      });

      const { access_token } = tokenRes.data;

      // Get user info
      const meRes = await axios.get('https://graph.facebook.com/v18.0/me', {
        params: { fields: 'id,name,picture', access_token },
      });

      const userId      = meRes.data.id;
      const displayName = meRes.data.name;
      const avatarUrl   = meRes.data.picture?.data?.url;

      // Get pages
      const pagesRes = await axios.get(`https://graph.facebook.com/v18.0/${userId}/accounts`, {
        params: { access_token },
      });

      const page      = pagesRes.data.data?.[0];
      const pageId    = page?.id;
      const pageToken = page?.access_token || access_token;

      const { error: dbError } = await supabase.from('social_accounts').upsert({
        platform,
        platform_user_id: userId,
        username:     displayName.toLowerCase().replace(/\s/g, ''),
        display_name: displayName,
        avatar_url:   avatarUrl,
        access_token: encrypt(pageToken),
        page_id:      pageId,
        is_active:    true,
      }, { onConflict: 'platform,platform_user_id' });

      if (dbError) throw new Error(dbError.message);
      oauthSuccess(res, platform, displayName);
    } catch (err) {
      logger.error(`${platform} OAuth error:`, err.message);
      oauthError(res, `${platform} connection failed`);
    }
  };
}

// ── Twitter / X ───────────────────────────────────────────────
router.get('/twitter', (req, res) => {
  const params = new URLSearchParams({
    response_type: 'code',
    client_id: process.env.TWITTER_CLIENT_ID,
    redirect_uri: `${process.env.APP_URL}/api/oauth/twitter/callback`,
    scope: 'tweet.read tweet.write users.read offline.access',
    state: req.query.state || 'state',
    code_challenge: 'challenge',
    code_challenge_method: 'plain',
  });
  res.redirect(`https://twitter.com/i/oauth2/authorize?${params}`);
});

router.get('/twitter/callback', async (req, res) => {
  const { code, error } = req.query;
  if (error) return oauthError(res, error);

  try {
    const tokenRes = await axios.post(
      'https://api.twitter.com/2/oauth2/token',
      new URLSearchParams({
        code,
        grant_type: 'authorization_code',
        client_id: process.env.TWITTER_CLIENT_ID,
        redirect_uri: `${process.env.APP_URL}/api/oauth/twitter/callback`,
        code_verifier: 'challenge',
      }),
      {
        auth: {
          username: process.env.TWITTER_CLIENT_ID,
          password: process.env.TWITTER_CLIENT_SECRET,
        },
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      }
    );

    const { access_token, refresh_token } = tokenRes.data;

    const meRes = await axios.get('https://api.twitter.com/2/users/me', {
      headers: { Authorization: `Bearer ${access_token}` },
    });

    const { id, name, username } = meRes.data.data;

    await supabase.from('social_accounts').upsert({
      platform: 'twitter',
      platform_user_id: id,
      username,
      display_name: name,
      access_token: encrypt(access_token),
      refresh_token: refresh_token ? encrypt(refresh_token) : null,
      is_active: true,
    }, { onConflict: 'platform,platform_user_id' });

    oauthSuccess(res, 'twitter', username);
  } catch (err) {
    logger.error('Twitter OAuth error:', err.message);
    oauthError(res, 'Twitter connection failed');
  }
});

// ── LinkedIn ──────────────────────────────────────────────────
router.get('/linkedin', (req, res) => {
  const params = new URLSearchParams({
    response_type: 'code',
    client_id: process.env.LINKEDIN_CLIENT_ID || process.env.GOOGLE_CLIENT_ID,
    redirect_uri: `${process.env.APP_URL}/api/oauth/linkedin/callback`,
    scope: 'r_liteprofile r_emailaddress w_member_social',
    state: req.query.state || 'state',
  });
  res.redirect(`https://www.linkedin.com/oauth/v2/authorization?${params}`);
});

router.get('/linkedin/callback', async (req, res) => {
  const { code, error } = req.query;
  if (error) return oauthError(res, error);

  try {
    const tokenRes = await axios.post(
      'https://www.linkedin.com/oauth/v2/accessToken',
      new URLSearchParams({
        grant_type: 'authorization_code',
        code,
        redirect_uri: `${process.env.APP_URL}/api/oauth/linkedin/callback`,
        client_id: process.env.LINKEDIN_CLIENT_ID,
        client_secret: process.env.LINKEDIN_CLIENT_SECRET,
      }),
      { headers: { 'Content-Type': 'application/x-www-form-urlencoded' } }
    );

    const { access_token } = tokenRes.data;

    const meRes = await axios.get('https://api.linkedin.com/v2/me', {
      headers: { Authorization: `Bearer ${access_token}` },
    });

    const id = meRes.data.id;
    const firstName = meRes.data.localizedFirstName;
    const lastName = meRes.data.localizedLastName;
    const displayName = `${firstName} ${lastName}`;

    await supabase.from('social_accounts').upsert({
      platform: 'linkedin',
      platform_user_id: id,
      username: displayName.toLowerCase().replace(/\s/g, '.'),
      display_name: displayName,
      access_token: encrypt(access_token),
      is_active: true,
    }, { onConflict: 'platform,platform_user_id' });

    oauthSuccess(res, 'linkedin', displayName);
  } catch (err) {
    logger.error('LinkedIn OAuth error:', err.message);
    oauthError(res, 'LinkedIn connection failed');
  }
});

// ── YouTube (Google OAuth) ────────────────────────────────────
router.get('/youtube', (req, res) => {
  const params = new URLSearchParams({
    client_id: process.env.YOUTUBE_CLIENT_ID || process.env.GOOGLE_CLIENT_ID,
    redirect_uri: `${process.env.APP_URL}/api/oauth/youtube/callback`,
    response_type: 'code',
    scope: 'https://www.googleapis.com/auth/youtube.upload https://www.googleapis.com/auth/youtube.readonly',
    access_type: 'offline',
    prompt: 'consent',
    state: req.query.state || '',
  });
  res.redirect(`https://accounts.google.com/o/oauth2/v2/auth?${params}`);
});

router.get('/youtube/callback', async (req, res) => {
  const { code, error } = req.query;
  if (error) return oauthError(res, error);

  try {
    const tokenRes = await axios.post('https://oauth2.googleapis.com/token', {
      code,
      client_id: process.env.YOUTUBE_CLIENT_ID || process.env.GOOGLE_CLIENT_ID,
      client_secret: process.env.YOUTUBE_CLIENT_SECRET || process.env.GOOGLE_CLIENT_SECRET,
      redirect_uri: `${process.env.APP_URL}/api/oauth/youtube/callback`,
      grant_type: 'authorization_code',
    });

    const { access_token, refresh_token } = tokenRes.data;

    const channelRes = await axios.get(
      'https://www.googleapis.com/youtube/v3/channels',
      {
        params: { part: 'snippet', mine: true },
        headers: { Authorization: `Bearer ${access_token}` },
      }
    );

    const channel = channelRes.data.items?.[0];
    const channelId = channel?.id;
    const channelTitle = channel?.snippet?.title;
    const avatarUrl = channel?.snippet?.thumbnails?.default?.url;

    await supabase.from('social_accounts').upsert({
      platform: 'youtube',
      platform_user_id: channelId,
      username: channelTitle?.toLowerCase().replace(/\s/g, ''),
      display_name: channelTitle,
      avatar_url: avatarUrl,
      access_token: encrypt(access_token),
      refresh_token: refresh_token ? encrypt(refresh_token) : null,
      is_active: true,
    }, { onConflict: 'platform,platform_user_id' });

    oauthSuccess(res, 'youtube', channelTitle);
  } catch (err) {
    logger.error('YouTube OAuth error:', err.message);
    oauthError(res, 'YouTube connection failed');
  }
});

// ── Token refresh (called by workers before publishing) ───────
router.post('/refresh/:platform/:accountId', async (req, res) => {
  const { platform, accountId } = req.params;

  try {
    const { data: account } = await supabase
      .from('social_accounts')
      .select('refresh_token')
      .eq('id', accountId)
      .single();

    if (!account?.refresh_token) {
      return res.status(400).json({ error: 'No refresh token available' });
    }

    let newToken;

    if (platform === 'twitter') {
      const tokenRes = await axios.post(
        'https://api.twitter.com/2/oauth2/token',
        new URLSearchParams({
          grant_type: 'refresh_token',
          refresh_token: account.refresh_token,
          client_id: process.env.TWITTER_CLIENT_ID,
        }),
        { auth: { username: process.env.TWITTER_CLIENT_ID, password: process.env.TWITTER_CLIENT_SECRET } }
      );
      newToken = tokenRes.data.access_token;
    } else if (platform === 'youtube') {
      const tokenRes = await axios.post('https://oauth2.googleapis.com/token', {
        grant_type: 'refresh_token',
        refresh_token: account.refresh_token,
        client_id: process.env.YOUTUBE_CLIENT_ID || process.env.GOOGLE_CLIENT_ID,
        client_secret: process.env.YOUTUBE_CLIENT_SECRET || process.env.GOOGLE_CLIENT_SECRET,
      });
      newToken = tokenRes.data.access_token;
    } else {
      return res.status(400).json({ error: `Refresh not supported for ${platform}` });
    }

    await supabase.from('social_accounts')
      .update({ access_token: encrypt(newToken), token_expired: false })
      .eq('id', accountId);

    res.json({ success: true });
  } catch (err) {
    logger.error(`Token refresh error for ${platform}:`, err.message);
    // Mark token as expired so UI shows reconnect prompt
    await supabase.from('social_accounts')
      .update({ token_expired: true, is_active: false })
      .eq('id', accountId);
    res.status(500).json({ error: 'Token refresh failed' });
  }
});

module.exports = router;

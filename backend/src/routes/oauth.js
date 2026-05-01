/**
 * OAuth Routes
 *
 * GET  /api/oauth/:platform           → redirect to provider login
 * GET  /api/oauth/:platform/callback  → receive code, store token
 * POST /api/oauth/refresh/:platform/:accountId → refresh expired token
 *
 * Supported platforms: facebook, instagram, twitter, linkedin, youtube
 */
const router = require('express').Router();
const axios  = require('axios');
const { supabase } = require('../utils/supabase');
const { encrypt }  = require('../utils/encrypt');
const { logger }   = require('../utils/logger');

// ── Constants ─────────────────────────────────────────────────
const MOBILE_SCHEME = 'autopostai://oauth-result';
const APP_URL       = process.env.APP_URL || 'http://localhost:5000';

// ── Platform config map ───────────────────────────────────────
function getPlatformConfig(platform) {
  const configs = {
    facebook: {
      authUrl:      'https://www.facebook.com/v18.0/dialog/oauth',
      clientId:     process.env.FACEBOOK_CLIENT_ID || process.env.FACEBOOK_APP_ID,
      clientSecret: process.env.FACEBOOK_CLIENT_SECRET || process.env.FACEBOOK_APP_SECRET,
      scope:        'pages_manage_posts,pages_read_engagement,pages_show_list',
      redirectUri:  `${APP_URL}/api/oauth/facebook/callback`,
    },
    instagram: {
      authUrl:      'https://www.facebook.com/v18.0/dialog/oauth',
      clientId:     process.env.FACEBOOK_CLIENT_ID || process.env.INSTAGRAM_APP_ID,
      clientSecret: process.env.FACEBOOK_CLIENT_SECRET || process.env.INSTAGRAM_APP_SECRET,
      scope:        'instagram_basic,instagram_content_publish,pages_show_list',
      redirectUri:  `${APP_URL}/api/oauth/instagram/callback`,
    },
    twitter: {
      authUrl:      'https://twitter.com/i/oauth2/authorize',
      clientId:     process.env.TWITTER_CLIENT_ID,
      clientSecret: process.env.TWITTER_CLIENT_SECRET,
      scope:        'tweet.read tweet.write users.read offline.access',
      redirectUri:  `${APP_URL}/api/oauth/twitter/callback`,
    },
    linkedin: {
      authUrl:      'https://www.linkedin.com/oauth/v2/authorization',
      clientId:     process.env.LINKEDIN_CLIENT_ID,
      clientSecret: process.env.LINKEDIN_CLIENT_SECRET,
      scope:        'r_liteprofile r_emailaddress w_member_social',
      redirectUri:  `${APP_URL}/api/oauth/linkedin/callback`,
    },
    youtube: {
      authUrl:      'https://accounts.google.com/o/oauth2/v2/auth',
      clientId:     process.env.YOUTUBE_CLIENT_ID || process.env.GOOGLE_CLIENT_ID,
      clientSecret: process.env.YOUTUBE_CLIENT_SECRET || process.env.GOOGLE_CLIENT_SECRET,
      scope:        'https://www.googleapis.com/auth/youtube.upload https://www.googleapis.com/auth/youtube.readonly',
      redirectUri:  `${APP_URL}/api/oauth/youtube/callback`,
    },
  };
  return configs[platform] || null;
}

// ── Helpers ───────────────────────────────────────────────────
function oauthError(res, msg) {
  logger.error(`OAuth error: ${msg}`);
  return res.redirect(
    `${MOBILE_SCHEME}?error=${encodeURIComponent(msg)}`
  );
}

function oauthSuccess(res, platform, username) {
  logger.info(`OAuth success: ${platform} (@${username})`);
  return res.redirect(
    `${MOBILE_SCHEME}?success=true&platform=${platform}&username=${encodeURIComponent(username)}`
  );
}

async function saveAccount(data) {
  const { data: account, error } = await supabase
    .from('social_accounts')
    .upsert(data, { onConflict: 'platform,platform_user_id' })
    .select()
    .single();

  if (error) throw new Error(error.message);

  // Confirm token saved
  logger.info(`Token saved: ${JSON.stringify({
    id:       account.id,
    platform: account.platform,
    username: account.username,
    status:   'connected',
  })}`);

  return account;
}

// ─────────────────────────────────────────────────────────────
// GET /api/oauth/:platform
// Redirects user to the provider's OAuth login page
// ─────────────────────────────────────────────────────────────
router.get('/:platform', (req, res) => {
  const { platform } = req.params;
  const config = getPlatformConfig(platform);

  if (!config) {
    return res.status(400).json({
      error: `Unsupported platform: ${platform}`,
      supported: ['facebook', 'instagram', 'twitter', 'linkedin', 'youtube'],
    });
  }

  if (!config.clientId) {
    return res.status(500).json({
      error: `${platform} credentials not configured. Set ${platform.toUpperCase()}_CLIENT_ID in .env`,
    });
  }

  logger.info(`OAuth init: ${platform}`);

  // Build provider-specific auth URL params
  let params;

  if (platform === 'twitter') {
    params = new URLSearchParams({
      response_type:         'code',
      client_id:             config.clientId,
      redirect_uri:          config.redirectUri,
      scope:                 config.scope,
      state:                 req.query.state || 'state',
      code_challenge:        'challenge',
      code_challenge_method: 'plain',
    });
  } else if (platform === 'youtube') {
    params = new URLSearchParams({
      client_id:     config.clientId,
      redirect_uri:  config.redirectUri,
      response_type: 'code',
      scope:         config.scope,
      access_type:   'offline',
      prompt:        'consent',
      state:         req.query.state || '',
    });
  } else {
    // Facebook, Instagram, LinkedIn
    params = new URLSearchParams({
      client_id:     config.clientId,
      redirect_uri:  config.redirectUri,
      scope:         config.scope,
      response_type: 'code',
      state:         req.query.state || '',
    });
  }

  res.redirect(`${config.authUrl}?${params}`);
});

// ─────────────────────────────────────────────────────────────
// GET /api/oauth/:platform/callback
// Receives auth code, exchanges for token, saves to DB
// ─────────────────────────────────────────────────────────────
router.get('/:platform/callback', async (req, res) => {
  const { platform } = req.params;
  const { code, error, error_description } = req.query;

  // User cancelled or provider returned error
  if (error) {
    return oauthError(res, error_description || error);
  }

  if (!code) {
    return oauthError(res, 'No authorization code received');
  }

  const config = getPlatformConfig(platform);
  if (!config) {
    return oauthError(res, `Unsupported platform: ${platform}`);
  }

  logger.info(`OAuth callback: ${platform}`);

  try {
    switch (platform) {
      case 'facebook':
      case 'instagram':
        return await handleMetaCallback(req, res, platform, config);
      case 'twitter':
        return await handleTwitterCallback(req, res, config);
      case 'linkedin':
        return await handleLinkedInCallback(req, res, config);
      case 'youtube':
        return await handleYouTubeCallback(req, res, config);
      default:
        return oauthError(res, `No callback handler for: ${platform}`);
    }
  } catch (err) {
    logger.error(`${platform} callback error: ${err.message}`);
    return oauthError(res, `${platform} connection failed. Please try again.`);
  }
});

// ── Meta (Facebook / Instagram) callback ─────────────────────
async function handleMetaCallback(req, res, platform, config) {
  const { code } = req.query;

  // Exchange code for token
  const tokenRes = await axios.get(
    'https://graph.facebook.com/v18.0/oauth/access_token',
    {
      params: {
        client_id:     config.clientId,
        client_secret: config.clientSecret,
        redirect_uri:  config.redirectUri,
        code,
      },
    }
  );

  const { access_token } = tokenRes.data;

  // Get user profile
  const meRes = await axios.get('https://graph.facebook.com/v18.0/me', {
    params: { fields: 'id,name,picture', access_token },
  });

  const userId      = meRes.data.id;
  const displayName = meRes.data.name;
  const avatarUrl   = meRes.data.picture?.data?.url;

  // Get managed pages (for posting)
  const pagesRes = await axios.get(
    `https://graph.facebook.com/v18.0/${userId}/accounts`,
    { params: { access_token } }
  );

  const page      = pagesRes.data.data?.[0];
  const pageId    = page?.id;
  const pageToken = page?.access_token || access_token;

  await saveAccount({
    platform,
    platform_user_id: userId,
    username:         displayName.toLowerCase().replace(/\s+/g, ''),
    display_name:     displayName,
    avatar_url:       avatarUrl,
    access_token:     encrypt(pageToken),
    page_id:          pageId,
    is_active:        true,
    token_expired:    false,
    status:           'connected',
  });

  return oauthSuccess(res, platform, displayName);
}

// ── Twitter callback ──────────────────────────────────────────
async function handleTwitterCallback(req, res, config) {
  const { code } = req.query;

  const tokenRes = await axios.post(
    'https://api.twitter.com/2/oauth2/token',
    new URLSearchParams({
      code,
      grant_type:    'authorization_code',
      client_id:     config.clientId,
      redirect_uri:  config.redirectUri,
      code_verifier: 'challenge',
    }),
    {
      auth: { username: config.clientId, password: config.clientSecret },
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    }
  );

  const { access_token, refresh_token } = tokenRes.data;

  const meRes = await axios.get('https://api.twitter.com/2/users/me', {
    headers: { Authorization: `Bearer ${access_token}` },
  });

  const { id, name, username } = meRes.data.data;

  await saveAccount({
    platform:         'twitter',
    platform_user_id: id,
    username,
    display_name:     name,
    access_token:     encrypt(access_token),
    refresh_token:    refresh_token ? encrypt(refresh_token) : null,
    is_active:        true,
    token_expired:    false,
    status:           'connected',
  });

  return oauthSuccess(res, 'twitter', username);
}

// ── LinkedIn callback ─────────────────────────────────────────
async function handleLinkedInCallback(req, res, config) {
  const { code } = req.query;

  const tokenRes = await axios.post(
    'https://www.linkedin.com/oauth/v2/accessToken',
    new URLSearchParams({
      grant_type:   'authorization_code',
      code,
      redirect_uri: config.redirectUri,
      client_id:    config.clientId,
      client_secret: config.clientSecret,
    }),
    { headers: { 'Content-Type': 'application/x-www-form-urlencoded' } }
  );

  const { access_token } = tokenRes.data;

  const meRes = await axios.get('https://api.linkedin.com/v2/me', {
    headers: { Authorization: `Bearer ${access_token}` },
  });

  const displayName = `${meRes.data.localizedFirstName} ${meRes.data.localizedLastName}`;

  await saveAccount({
    platform:         'linkedin',
    platform_user_id: meRes.data.id,
    username:         displayName.toLowerCase().replace(/\s+/g, '.'),
    display_name:     displayName,
    access_token:     encrypt(access_token),
    is_active:        true,
    token_expired:    false,
    status:           'connected',
  });

  return oauthSuccess(res, 'linkedin', displayName);
}

// ── YouTube callback ──────────────────────────────────────────
async function handleYouTubeCallback(req, res, config) {
  const { code } = req.query;

  const tokenRes = await axios.post('https://oauth2.googleapis.com/token', {
    code,
    client_id:     config.clientId,
    client_secret: config.clientSecret,
    redirect_uri:  config.redirectUri,
    grant_type:    'authorization_code',
  });

  const { access_token, refresh_token } = tokenRes.data;

  const channelRes = await axios.get(
    'https://www.googleapis.com/youtube/v3/channels',
    {
      params:  { part: 'snippet', mine: true },
      headers: { Authorization: `Bearer ${access_token}` },
    }
  );

  const channel      = channelRes.data.items?.[0];
  const channelId    = channel?.id;
  const channelTitle = channel?.snippet?.title || 'YouTube Channel';
  const avatarUrl    = channel?.snippet?.thumbnails?.default?.url;

  await saveAccount({
    platform:         'youtube',
    platform_user_id: channelId,
    username:         channelTitle.toLowerCase().replace(/\s+/g, ''),
    display_name:     channelTitle,
    avatar_url:       avatarUrl,
    access_token:     encrypt(access_token),
    refresh_token:    refresh_token ? encrypt(refresh_token) : null,
    is_active:        true,
    token_expired:    false,
    status:           'connected',
  });

  return oauthSuccess(res, 'youtube', channelTitle);
}

// ─────────────────────────────────────────────────────────────
// POST /api/oauth/refresh/:platform/:accountId
// Refresh an expired access token
// ─────────────────────────────────────────────────────────────
router.post('/refresh/:platform/:accountId', async (req, res) => {
  const { platform, accountId } = req.params;

  try {
    const { data: account } = await supabase
      .from('social_accounts')
      .select('refresh_token')
      .eq('id', accountId)
      .single();

    if (!account?.refresh_token) {
      return res.status(400).json({
        error: 'No refresh token — user must reconnect account',
        code:  'NO_REFRESH_TOKEN',
      });
    }

    const config = getPlatformConfig(platform);
    let newToken;

    if (platform === 'twitter') {
      const tokenRes = await axios.post(
        'https://api.twitter.com/2/oauth2/token',
        new URLSearchParams({
          grant_type:    'refresh_token',
          refresh_token: account.refresh_token,
          client_id:     config.clientId,
        }),
        { auth: { username: config.clientId, password: config.clientSecret } }
      );
      newToken = tokenRes.data.access_token;
    } else if (platform === 'youtube') {
      const tokenRes = await axios.post('https://oauth2.googleapis.com/token', {
        grant_type:    'refresh_token',
        refresh_token: account.refresh_token,
        client_id:     config.clientId,
        client_secret: config.clientSecret,
      });
      newToken = tokenRes.data.access_token;
    } else {
      return res.status(400).json({
        error: `Token refresh not supported for ${platform}`,
      });
    }

    await supabase.from('social_accounts')
      .update({
        access_token:  encrypt(newToken),
        token_expired: false,
        is_active:     true,
        status:        'connected',
      })
      .eq('id', accountId);

    logger.info(`Token refreshed: ${platform} / ${accountId}`);
    res.json({ success: true });

  } catch (err) {
    logger.error(`Token refresh error [${platform}]: ${err.message}`);
    await supabase.from('social_accounts')
      .update({ token_expired: true, is_active: false, status: 'expired' })
      .eq('id', accountId);
    res.status(500).json({
      error: 'Token refresh failed — user must reconnect',
      code:  'REFRESH_FAILED',
    });
  }
});

module.exports = router;

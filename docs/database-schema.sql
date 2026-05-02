-- ============================================================
-- AutoPost AI – PostgreSQL / Supabase Database Schema
-- Updated to match full OAuth + post publish + analytics flow
-- Run in Supabase SQL Editor: https://supabase.com/dashboard
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- USERS & AUTH
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email           TEXT UNIQUE NOT NULL,
  name            TEXT NOT NULL,
  avatar_url      TEXT,
  google_id       TEXT UNIQUE,
  password_hash   TEXT,                          -- null for Google-only users
  plan            TEXT NOT NULL DEFAULT 'free'
                    CHECK (plan IN ('free','basic','pro','premium')),
  trial_ends_at   TIMESTAMPTZ,
  is_disabled     BOOLEAN DEFAULT FALSE,
  referral_code   TEXT UNIQUE DEFAULT substr(md5(random()::text), 1, 8),
  referred_by     UUID REFERENCES users(id),
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- SUBSCRIPTIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS subscriptions (
  id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id              UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  plan                 TEXT NOT NULL CHECK (plan IN ('basic','pro','premium')),
  status               TEXT NOT NULL
                         CHECK (status IN ('active','cancelled','past_due','trialing')),
  stripe_sub_id        TEXT,
  razorpay_sub_id      TEXT,
  current_period_start TIMESTAMPTZ,
  current_period_end   TIMESTAMPTZ,
  cancel_at_period_end BOOLEAN DEFAULT FALSE,
  created_at           TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- SOCIAL ACCOUNTS (OAuth connected platforms)
-- ============================================================
CREATE TABLE IF NOT EXISTS social_accounts (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id          UUID REFERENCES users(id) ON DELETE CASCADE,  -- nullable for anonymous OAuth
  platform         TEXT NOT NULL
                     CHECK (platform IN ('instagram','facebook','twitter','linkedin','youtube')),
  platform_user_id TEXT NOT NULL,
  username         TEXT,
  display_name     TEXT,
  avatar_url       TEXT,
  access_token     TEXT NOT NULL,    -- AES-256 encrypted at app level
  refresh_token    TEXT,             -- AES-256 encrypted
  token_expires_at TIMESTAMPTZ,
  token_expired    BOOLEAN DEFAULT FALSE,
  page_id          TEXT,             -- Facebook/Instagram page ID
  is_active        BOOLEAN DEFAULT TRUE,
  status           TEXT NOT NULL DEFAULT 'connected'
                     CHECK (status IN ('connected','expired','disconnected')),
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(platform, platform_user_id)
);

-- ============================================================
-- POSTS
-- ============================================================
CREATE TABLE IF NOT EXISTS posts (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  caption          TEXT,
  hashtags         TEXT[],
  media_urls       TEXT[],           -- Supabase Storage / CDN URLs
  media_type       TEXT CHECK (media_type IN ('image','video','carousel','text')),
  platforms        TEXT[] NOT NULL,  -- ['instagram','twitter']
  status           TEXT NOT NULL DEFAULT 'draft'
                     CHECK (status IN ('draft','scheduled','publishing','published','partial','failed')),
  scheduled_at     TIMESTAMPTZ,
  published_at     TIMESTAMPTZ,
  is_repost        BOOLEAN DEFAULT FALSE,
  original_post_id UUID REFERENCES posts(id),
  ai_generated     BOOLEAN DEFAULT FALSE,
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- POST PLATFORM RESULTS (per-platform publish status)
-- ============================================================
CREATE TABLE IF NOT EXISTS post_results (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id           UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  social_account_id UUID REFERENCES social_accounts(id),
  platform          TEXT NOT NULL,
  platform_post_id  TEXT,           -- ID returned by platform API
  status            TEXT NOT NULL
                      CHECK (status IN ('pending','published','failed')),
  error_message     TEXT,
  published_at      TIMESTAMPTZ,
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(post_id, platform)         -- idempotency: one result per post per platform
);

-- ============================================================
-- POST ANALYTICS
-- ============================================================
CREATE TABLE IF NOT EXISTS post_analytics (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_result_id  UUID NOT NULL REFERENCES post_results(id) ON DELETE CASCADE,
  platform        TEXT NOT NULL,
  likes           INT DEFAULT 0,
  comments        INT DEFAULT 0,
  shares          INT DEFAULT 0,
  saves           INT DEFAULT 0,
  reach           INT DEFAULT 0,
  impressions     INT DEFAULT 0,
  clicks          INT DEFAULT 0,
  engagement_rate NUMERIC(5,2),
  fetched_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS account_analytics (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  social_account_id UUID NOT NULL REFERENCES social_accounts(id) ON DELETE CASCADE,
  followers         INT DEFAULT 0,
  following         INT DEFAULT 0,
  total_posts       INT DEFAULT 0,
  avg_engagement    NUMERIC(5,2),
  recorded_at       TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- AI GENERATIONS (audit + cache)
-- ============================================================
CREATE TABLE IF NOT EXISTS ai_generations (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type        TEXT NOT NULL
                CHECK (type IN ('caption','hashtags','hook','image','content_idea')),
  prompt      TEXT,
  result      TEXT,
  tokens_used INT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- AUTOMATION RULES
-- ============================================================
CREATE TABLE IF NOT EXISTS automation_rules (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name           TEXT NOT NULL,
  trigger        TEXT NOT NULL
                   CHECK (trigger IN ('new_blog','keyword_mention','schedule','engagement_threshold')),
  trigger_config JSONB,
  action         TEXT NOT NULL
                   CHECK (action IN ('auto_post','auto_reply','auto_dm','repost_top')),
  action_config  JSONB,
  is_active      BOOLEAN DEFAULT TRUE,
  last_run_at    TIMESTAMPTZ,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- AUTO REPLY TEMPLATES
-- ============================================================
CREATE TABLE IF NOT EXISTS auto_reply_templates (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform         TEXT NOT NULL,
  trigger_keywords TEXT[],
  reply_text       TEXT NOT NULL,
  is_ai_reply      BOOLEAN DEFAULT FALSE,
  is_active        BOOLEAN DEFAULT TRUE,
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- REFERRALS
-- ============================================================
CREATE TABLE IF NOT EXISTS referrals (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  referrer_id  UUID NOT NULL REFERENCES users(id),
  referred_id  UUID NOT NULL REFERENCES users(id),
  reward_given BOOLEAN DEFAULT FALSE,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_posts_user_status     ON posts(user_id, status);
CREATE INDEX IF NOT EXISTS idx_posts_scheduled_at    ON posts(scheduled_at) WHERE status = 'scheduled';
CREATE INDEX IF NOT EXISTS idx_post_results_post     ON post_results(post_id);
CREATE INDEX IF NOT EXISTS idx_analytics_result      ON post_analytics(post_result_id);
CREATE INDEX IF NOT EXISTS idx_social_accounts_user  ON social_accounts(user_id);
CREATE INDEX IF NOT EXISTS idx_social_accounts_plat  ON social_accounts(platform, platform_user_id);
CREATE INDEX IF NOT EXISTS idx_ai_gen_user           ON ai_generations(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_account_analytics     ON account_analytics(social_account_id, recorded_at);

-- ============================================================
-- ROW LEVEL SECURITY (Supabase)
-- Enable RLS so users can only access their own data
-- ============================================================
ALTER TABLE users              ENABLE ROW LEVEL SECURITY;
ALTER TABLE social_accounts    ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts               ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_results        ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_analytics      ENABLE ROW LEVEL SECURITY;
ALTER TABLE account_analytics   ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_generations      ENABLE ROW LEVEL SECURITY;
ALTER TABLE automation_rules    ENABLE ROW LEVEL SECURITY;
ALTER TABLE auto_reply_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions       ENABLE ROW LEVEL SECURITY;
ALTER TABLE referrals           ENABLE ROW LEVEL SECURITY;

-- Users can read/update their own profile
CREATE POLICY "users_own" ON users
  FOR ALL USING (auth.uid()::text = id::text);

-- Social accounts — user sees only their own
CREATE POLICY "social_accounts_own" ON social_accounts
  FOR ALL USING (auth.uid()::text = user_id::text);

-- Posts — user sees only their own
CREATE POLICY "posts_own" ON posts
  FOR ALL USING (auth.uid()::text = user_id::text);

-- Post results — via post ownership
CREATE POLICY "post_results_own" ON post_results
  FOR ALL USING (
    post_id IN (SELECT id FROM posts WHERE user_id::text = auth.uid()::text)
  );

-- Analytics — via post_results
CREATE POLICY "post_analytics_own" ON post_analytics
  FOR ALL USING (
    post_result_id IN (
      SELECT pr.id FROM post_results pr
      JOIN posts p ON p.id = pr.post_id
      WHERE p.user_id::text = auth.uid()::text
    )
  );

-- Account analytics
CREATE POLICY "account_analytics_own" ON account_analytics
  FOR ALL USING (
    social_account_id IN (
      SELECT id FROM social_accounts WHERE user_id::text = auth.uid()::text
    )
  );

-- AI generations
CREATE POLICY "ai_gen_own" ON ai_generations
  FOR ALL USING (auth.uid()::text = user_id::text);

-- Automation rules
CREATE POLICY "automation_own" ON automation_rules
  FOR ALL USING (auth.uid()::text = user_id::text);

-- Auto reply templates
CREATE POLICY "auto_reply_own" ON auto_reply_templates
  FOR ALL USING (auth.uid()::text = user_id::text);

-- Subscriptions
CREATE POLICY "subscriptions_own" ON subscriptions
  FOR ALL USING (auth.uid()::text = user_id::text);

-- ============================================================
-- UPDATED_AT TRIGGER
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER social_accounts_updated_at
  BEFORE UPDATE ON social_accounts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER posts_updated_at
  BEFORE UPDATE ON posts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

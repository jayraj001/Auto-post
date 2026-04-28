-- ============================================================
-- AutoPost AI – PostgreSQL Database Schema
-- ============================================================

-- EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- USERS & AUTH
-- ============================================================
CREATE TABLE users (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email         TEXT UNIQUE NOT NULL,
  name          TEXT NOT NULL,
  avatar_url    TEXT,
  google_id     TEXT UNIQUE,
  plan          TEXT NOT NULL DEFAULT 'free' CHECK (plan IN ('free','basic','pro','premium')),
  trial_ends_at TIMESTAMPTZ,
  referral_code TEXT UNIQUE DEFAULT substr(md5(random()::text), 1, 8),
  referred_by   UUID REFERENCES users(id),
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- SUBSCRIPTIONS
-- ============================================================
CREATE TABLE subscriptions (
  id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id              UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  plan                 TEXT NOT NULL CHECK (plan IN ('basic','pro','premium')),
  status               TEXT NOT NULL CHECK (status IN ('active','cancelled','past_due','trialing')),
  stripe_sub_id        TEXT,
  razorpay_sub_id      TEXT,
  current_period_start TIMESTAMPTZ,
  current_period_end   TIMESTAMPTZ,
  cancel_at_period_end BOOLEAN DEFAULT FALSE,
  created_at           TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- SOCIAL ACCOUNTS (connected platforms)
-- ============================================================
CREATE TABLE social_accounts (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform        TEXT NOT NULL CHECK (platform IN ('instagram','facebook','twitter','linkedin','youtube')),
  platform_user_id TEXT NOT NULL,
  username        TEXT,
  display_name    TEXT,
  avatar_url      TEXT,
  access_token    TEXT NOT NULL,   -- encrypted at app level
  refresh_token   TEXT,
  token_expires_at TIMESTAMPTZ,
  page_id         TEXT,            -- for Facebook pages
  is_active       BOOLEAN DEFAULT TRUE,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, platform, platform_user_id)
);

-- ============================================================
-- POSTS
-- ============================================================
CREATE TABLE posts (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  caption         TEXT,
  hashtags        TEXT[],
  media_urls      TEXT[],          -- Supabase Storage URLs
  media_type      TEXT CHECK (media_type IN ('image','video','carousel','text')),
  platforms       TEXT[] NOT NULL, -- ['instagram','twitter']
  status          TEXT NOT NULL DEFAULT 'draft'
                    CHECK (status IN ('draft','scheduled','publishing','published','failed')),
  scheduled_at    TIMESTAMPTZ,
  published_at    TIMESTAMPTZ,
  is_repost       BOOLEAN DEFAULT FALSE,
  original_post_id UUID REFERENCES posts(id),
  ai_generated    BOOLEAN DEFAULT FALSE,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- POST PLATFORM RESULTS (per-platform publish status)
-- ============================================================
CREATE TABLE post_results (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id          UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  social_account_id UUID NOT NULL REFERENCES social_accounts(id),
  platform         TEXT NOT NULL,
  platform_post_id TEXT,           -- ID returned by platform API
  status           TEXT NOT NULL CHECK (status IN ('pending','success','failed')),
  error_message    TEXT,
  published_at     TIMESTAMPTZ,
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- ANALYTICS
-- ============================================================
CREATE TABLE post_analytics (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_result_id   UUID NOT NULL REFERENCES post_results(id) ON DELETE CASCADE,
  platform         TEXT NOT NULL,
  likes            INT DEFAULT 0,
  comments         INT DEFAULT 0,
  shares           INT DEFAULT 0,
  saves            INT DEFAULT 0,
  reach            INT DEFAULT 0,
  impressions      INT DEFAULT 0,
  clicks           INT DEFAULT 0,
  engagement_rate  NUMERIC(5,2),
  fetched_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE account_analytics (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  social_account_id UUID NOT NULL REFERENCES social_accounts(id) ON DELETE CASCADE,
  followers        INT DEFAULT 0,
  following        INT DEFAULT 0,
  total_posts      INT DEFAULT 0,
  avg_engagement   NUMERIC(5,2),
  recorded_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- AI GENERATIONS (audit + cache)
-- ============================================================
CREATE TABLE ai_generations (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type        TEXT NOT NULL CHECK (type IN ('caption','hashtags','hook','image','content_idea')),
  prompt      TEXT,
  result      TEXT,
  tokens_used INT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- AUTOMATION RULES
-- ============================================================
CREATE TABLE automation_rules (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  trigger     TEXT NOT NULL CHECK (trigger IN ('new_blog','keyword_mention','schedule','engagement_threshold')),
  trigger_config JSONB,            -- e.g. {"url": "https://blog.com/feed", "keyword": "sale"}
  action      TEXT NOT NULL CHECK (action IN ('auto_post','auto_reply','auto_dm','repost_top')),
  action_config JSONB,
  is_active   BOOLEAN DEFAULT TRUE,
  last_run_at TIMESTAMPTZ,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- DM / COMMENT AUTO REPLIES
-- ============================================================
CREATE TABLE auto_reply_templates (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform    TEXT NOT NULL,
  trigger_keywords TEXT[],
  reply_text  TEXT NOT NULL,
  is_ai_reply BOOLEAN DEFAULT FALSE,
  is_active   BOOLEAN DEFAULT TRUE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- REFERRALS
-- ============================================================
CREATE TABLE referrals (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  referrer_id  UUID NOT NULL REFERENCES users(id),
  referred_id  UUID NOT NULL REFERENCES users(id),
  reward_given BOOLEAN DEFAULT FALSE,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX idx_posts_user_status    ON posts(user_id, status);
CREATE INDEX idx_posts_scheduled_at   ON posts(scheduled_at) WHERE status = 'scheduled';
CREATE INDEX idx_post_results_post    ON post_results(post_id);
CREATE INDEX idx_analytics_result     ON post_analytics(post_result_id);
CREATE INDEX idx_social_accounts_user ON social_accounts(user_id);
CREATE INDEX idx_ai_gen_user          ON ai_generations(user_id, created_at);

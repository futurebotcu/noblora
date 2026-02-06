-- ============================================================================
-- NOBLARA DATABASE SCHEMA
-- Supabase PostgreSQL with Row Level Security
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- ENUM TYPES
-- ============================================================================

CREATE TYPE app_mode AS ENUM ('dating', 'bff');
CREATE TYPE gender_type AS ENUM ('female', 'male', 'other');
CREATE TYPE verification_status AS ENUM ('pending', 'approved', 'rejected');
CREATE TYPE entry_status AS ENUM ('pending', 'approved', 'rejected');
CREATE TYPE score_status AS ENUM ('ok', 'limited', 'banned');
CREATE TYPE subscription_tier AS ENUM ('free', 'premium');
CREATE TYPE report_status AS ENUM ('pending', 'reviewed', 'actioned', 'dismissed');
CREATE TYPE meetup_event_type AS ENUM ('scheduled', 'checkin', 'completed', 'cancelled');

-- ============================================================================
-- PROFILES TABLE
-- Core user profile information
-- ============================================================================

CREATE TABLE profiles (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  mode app_mode NOT NULL DEFAULT 'dating',
  gender_claim gender_type NOT NULL,
  birth_year INTEGER NOT NULL CHECK (birth_year >= 1900 AND birth_year <= EXTRACT(YEAR FROM CURRENT_DATE) - 18),
  city TEXT,
  bio TEXT CHECK (char_length(bio) <= 500),
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_profiles_mode ON profiles(mode);
CREATE INDEX idx_profiles_gender ON profiles(gender_claim);
CREATE INDEX idx_profiles_location ON profiles(latitude, longitude) WHERE latitude IS NOT NULL;

-- ============================================================================
-- PHOTOS TABLE
-- User photos with AI verification results
-- ============================================================================

CREATE TABLE photos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  url TEXT NOT NULL,
  order_index INTEGER NOT NULL CHECK (order_index >= 0 AND order_index < 6),
  face_visible BOOLEAN DEFAULT FALSE,
  quality_score INTEGER DEFAULT 0 CHECK (quality_score >= 0 AND quality_score <= 100),
  approved BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, order_index)
);

CREATE INDEX idx_photos_user ON photos(user_id);
CREATE INDEX idx_photos_approved ON photos(user_id, approved);

-- ============================================================================
-- INSTAGRAM VERIFICATION TABLE
-- Instagram connection and verification (username NOT exposed to other users)
-- ============================================================================

CREATE TABLE instagram (
  user_id UUID PRIMARY KEY REFERENCES profiles(user_id) ON DELETE CASCADE,
  ig_username TEXT NOT NULL,
  ig_connected BOOLEAN DEFAULT FALSE,
  ig_connected_at TIMESTAMPTZ,
  ig_media_verified BOOLEAN DEFAULT FALSE,
  ig_verified_at TIMESTAMPTZ,
  oldest_face_media_ts TIMESTAMPTZ,
  -- OAuth tokens stored encrypted - NEVER expose
  access_token_encrypted TEXT,
  refresh_token_encrypted TEXT,
  token_expires_at TIMESTAMPTZ
);

-- ============================================================================
-- GENDER VERIFICATION TABLE
-- Separate verification step for gender claim
-- Does NOT use AI to infer gender - admin review only
-- ============================================================================

CREATE TABLE gender_verification (
  user_id UUID PRIMARY KEY REFERENCES profiles(user_id) ON DELETE CASCADE,
  status verification_status NOT NULL DEFAULT 'pending',
  reason TEXT,
  evidence_url TEXT, -- ID/selfie proof upload
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed_at TIMESTAMPTZ,
  reviewed_by UUID REFERENCES auth.users(id)
);

-- ============================================================================
-- VERIFICATIONS TABLE
-- Overall verification status (photos + IG + gender)
-- ============================================================================

CREATE TABLE verifications (
  user_id UUID PRIMARY KEY REFERENCES profiles(user_id) ON DELETE CASCADE,
  status verification_status NOT NULL DEFAULT 'pending',
  reason TEXT,
  photos_approved INTEGER DEFAULT 0,
  instagram_verified BOOLEAN DEFAULT FALSE,
  gender_verified BOOLEAN DEFAULT FALSE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- REFERRAL CODES TABLE
-- Referral codes for symmetric entry gate
-- ============================================================================

CREATE TABLE referral_codes (
  code TEXT PRIMARY KEY CHECK (char_length(code) >= 6 AND char_length(code) <= 20),
  created_by UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  inviter_gender gender_type NOT NULL,
  invitee_gender_required gender_type NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_active BOOLEAN DEFAULT TRUE,
  uses_remaining INTEGER DEFAULT 5
);

CREATE INDEX idx_referral_codes_creator ON referral_codes(created_by);
CREATE INDEX idx_referral_codes_active ON referral_codes(is_active, invitee_gender_required);

-- ============================================================================
-- REFERRALS TABLE
-- Tracks who referred whom
-- ============================================================================

CREATE TABLE referrals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  referrer UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  referred UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  code_used TEXT REFERENCES referral_codes(code),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  referred_verified_at TIMESTAMPTZ,
  UNIQUE(referred) -- Each user can only be referred once
);

CREATE INDEX idx_referrals_referrer ON referrals(referrer);
CREATE INDEX idx_referrals_referred ON referrals(referred);

-- ============================================================================
-- ENTRY STATUS TABLE
-- Entry gate status based on referral requirements
-- ============================================================================

CREATE TABLE entry_status (
  user_id UUID PRIMARY KEY REFERENCES profiles(user_id) ON DELETE CASCADE,
  status entry_status NOT NULL DEFAULT 'pending',
  required_opposite_gender INTEGER DEFAULT 1,
  verified_opposite_gender_count INTEGER DEFAULT 0,
  admin_override BOOLEAN DEFAULT FALSE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- LIKES TABLE
-- User likes (requires verified + entry approved)
-- ============================================================================

CREATE TABLE likes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  from_user UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  to_user UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  mode app_mode NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(from_user, to_user, mode)
);

CREATE INDEX idx_likes_from ON likes(from_user);
CREATE INDEX idx_likes_to ON likes(to_user);
CREATE INDEX idx_likes_match ON likes(to_user, from_user, mode);

-- ============================================================================
-- MATCHES TABLE
-- Mutual likes create matches
-- ============================================================================

CREATE TABLE matches (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_a UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  user_b UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  mode app_mode NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_a, user_b, mode),
  CHECK (user_a < user_b) -- Ensure consistent ordering
);

CREATE INDEX idx_matches_user_a ON matches(user_a);
CREATE INDEX idx_matches_user_b ON matches(user_b);

-- ============================================================================
-- MATCH STATE TABLE
-- Tracks match progression through flow
-- ============================================================================

CREATE TABLE match_state (
  match_id UUID PRIMARY KEY REFERENCES matches(id) ON DELETE CASCADE,
  schedule_deadline TIMESTAMPTZ NOT NULL, -- match_created + 12h
  call_required BOOLEAN DEFAULT TRUE,
  call_completed BOOLEAN DEFAULT FALSE,
  call_started_at TIMESTAMPTZ,
  call_ended_at TIMESTAMPTZ,
  call_duration_sec INTEGER,
  user_a_continue BOOLEAN, -- NULL = not decided
  user_b_continue BOOLEAN,
  chat_unlocked BOOLEAN DEFAULT FALSE,
  meetup_deadline TIMESTAMPTZ, -- call_ended + 5 days
  closed BOOLEAN DEFAULT FALSE,
  closed_reason TEXT
);

-- ============================================================================
-- CALL PROPOSALS TABLE
-- Women propose time slots first
-- ============================================================================

CREATE TABLE call_proposals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  proposer UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  slots JSONB NOT NULL, -- Array of {start, end} timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  accepted BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_call_proposals_match ON call_proposals(match_id);

-- ============================================================================
-- CALL BOOKINGS TABLE
-- Confirmed call schedules
-- ============================================================================

CREATE TABLE call_bookings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  proposal_id UUID REFERENCES call_proposals(id),
  scheduled_at TIMESTAMPTZ NOT NULL,
  duration_sec INTEGER DEFAULT 300,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(match_id) -- One booking per match
);

CREATE INDEX idx_call_bookings_scheduled ON call_bookings(scheduled_at);

-- ============================================================================
-- CALL RATINGS TABLE
-- Post-call ratings affect user scores
-- ============================================================================

CREATE TABLE call_ratings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  rater UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  flags JSONB, -- {inappropriate, no_show, fake_profile, rude, other}
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(match_id, rater)
);

CREATE INDEX idx_call_ratings_match ON call_ratings(match_id);

-- ============================================================================
-- MESSAGES TABLE
-- Chat messages (only after chat_unlocked)
-- ============================================================================

CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  from_user UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  body TEXT NOT NULL CHECK (char_length(body) <= 2000),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_messages_match ON messages(match_id, created_at DESC);

-- ============================================================================
-- BLOCKS TABLE
-- User blocks
-- ============================================================================

CREATE TABLE blocks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  blocker UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  blocked UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(blocker, blocked)
);

CREATE INDEX idx_blocks_blocker ON blocks(blocker);
CREATE INDEX idx_blocks_blocked ON blocks(blocked);

-- ============================================================================
-- REPORTS TABLE
-- User reports for safety review
-- ============================================================================

CREATE TABLE reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reporter UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  target UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  reason TEXT NOT NULL CHECK (char_length(reason) <= 500),
  evidence_urls TEXT[],
  status report_status DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed_at TIMESTAMPTZ,
  reviewed_by UUID REFERENCES auth.users(id),
  action_taken TEXT
);

CREATE INDEX idx_reports_target ON reports(target);
CREATE INDEX idx_reports_status ON reports(status);

-- ============================================================================
-- MEETUPS TABLE
-- Meetup scheduling (within 5 days of call)
-- ============================================================================

CREATE TABLE meetups (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  scheduled_at TIMESTAMPTZ NOT NULL,
  location_text TEXT CHECK (char_length(location_text) <= 200),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_meetups_match ON meetups(match_id);
CREATE INDEX idx_meetups_scheduled ON meetups(scheduled_at);

-- ============================================================================
-- QR CHECK-INS TABLE
-- Mutual QR scan at meetup
-- ============================================================================

CREATE TABLE qr_checkins (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  meetup_id UUID NOT NULL REFERENCES meetups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL,
  checked_in_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(meetup_id, user_id)
);

-- ============================================================================
-- MEETUP EVENTS TABLE
-- Audit trail for meetup flow
-- ============================================================================

CREATE TABLE meetup_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  meetup_id UUID NOT NULL REFERENCES meetups(id) ON DELETE CASCADE,
  event_type meetup_event_type NOT NULL,
  payload JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_meetup_events_meetup ON meetup_events(meetup_id);

-- ============================================================================
-- POSTS TABLE
-- Social micro-posts (1 per day, 150 chars)
-- ============================================================================

CREATE TABLE posts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  body VARCHAR(150) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  day_key DATE NOT NULL DEFAULT CURRENT_DATE,
  UNIQUE(user_id, day_key) -- Enforce 1 post per day
);

CREATE INDEX idx_posts_user ON posts(user_id);
CREATE INDEX idx_posts_date ON posts(day_key DESC, created_at DESC);

-- ============================================================================
-- POST REPORTS TABLE
-- ============================================================================

CREATE TABLE post_reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reporter UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  reason TEXT NOT NULL CHECK (char_length(reason) <= 500),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_post_reports_post ON post_reports(post_id);

-- ============================================================================
-- SUBSCRIPTIONS TABLE
-- Premium tier tracking (RevenueCat integration)
-- ============================================================================

CREATE TABLE subscriptions (
  user_id UUID PRIMARY KEY REFERENCES profiles(user_id) ON DELETE CASCADE,
  tier subscription_tier DEFAULT 'free',
  expires_at TIMESTAMPTZ,
  revenuecat_id TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- USER SCORES TABLE
-- Quality and reliability scores for matching algorithm
-- ============================================================================

CREATE TABLE user_scores (
  user_id UUID PRIMARY KEY REFERENCES profiles(user_id) ON DELETE CASCADE,
  quality_score DOUBLE PRECISION DEFAULT 3.0 CHECK (quality_score >= 0 AND quality_score <= 5),
  reliability_score DOUBLE PRECISION DEFAULT 3.0 CHECK (reliability_score >= 0 AND reliability_score <= 5),
  total_ratings INTEGER DEFAULT 0,
  total_reports_received INTEGER DEFAULT 0,
  total_blocks_received INTEGER DEFAULT 0,
  status score_status DEFAULT 'ok',
  ban_reason TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_user_scores_status ON user_scores(status);

-- ============================================================================
-- AUDIT LOG TABLE
-- All admin and system actions for accountability
-- ============================================================================

CREATE TABLE audit_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  actor UUID REFERENCES auth.users(id), -- NULL for system actions
  action TEXT NOT NULL,
  target_user UUID REFERENCES profiles(user_id),
  payload JSONB,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_log_actor ON audit_log(actor);
CREATE INDEX idx_audit_log_target ON audit_log(target_user);
CREATE INDEX idx_audit_log_action ON audit_log(action);
CREATE INDEX idx_audit_log_created ON audit_log(created_at DESC);

-- ============================================================================
-- CONFIG TABLE
-- System configuration (admin-editable)
-- ============================================================================

CREATE TABLE config (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  description TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by UUID REFERENCES auth.users(id)
);

-- Insert default config values
INSERT INTO config (key, value, description) VALUES
  ('bootstrap_mode_enabled', 'true', 'Allow users to bypass entry gate during bootstrap'),
  ('male_counter_proposal_enabled', 'false', 'Allow males to counter-propose call times'),
  ('video_call_required', 'true', 'Require video call before chat unlock'),
  ('photo_min_quality', '60', 'Minimum quality score for photo approval'),
  ('min_call_duration_sec', '180', 'Minimum call duration in seconds'),
  ('max_call_duration_sec', '300', 'Maximum call duration in seconds'),
  ('schedule_window_hours', '12', 'Hours for schedule-only window after match'),
  ('meetup_deadline_days', '5', 'Days to schedule meetup after call'),
  ('admin_users', '[]', 'List of admin user IDs');

-- ============================================================================
-- BACKGROUND JOBS TABLE
-- Queue abstraction for async processing
-- ============================================================================

CREATE TABLE jobs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  type TEXT NOT NULL,
  payload JSONB NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  priority INTEGER DEFAULT 0,
  attempts INTEGER DEFAULT 0,
  max_attempts INTEGER DEFAULT 3,
  error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  scheduled_for TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_jobs_status_priority ON jobs(status, priority DESC, scheduled_for);
CREATE INDEX idx_jobs_type ON jobs(type, status);

-- ============================================================================
-- RATE LIMITING TABLE
-- Track rate limits per user/action
-- ============================================================================

CREATE TABLE rate_limits (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
  action TEXT NOT NULL,
  ip_address INET,
  count INTEGER DEFAULT 1,
  window_start TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, action, window_start)
);

CREATE INDEX idx_rate_limits_user_action ON rate_limits(user_id, action, window_start DESC);

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Function to check if user is verified
CREATE OR REPLACE FUNCTION is_user_verified(uid UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM verifications
    WHERE user_id = uid AND status = 'approved'
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Function to check if user is entry approved
CREATE OR REPLACE FUNCTION is_user_entry_approved(uid UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM entry_status
    WHERE user_id = uid AND (status = 'approved' OR admin_override = TRUE)
  ) OR (
    -- Bootstrap mode check
    SELECT (value::text)::boolean FROM config WHERE key = 'bootstrap_mode_enabled'
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Function to check if users can interact (not blocked)
CREATE OR REPLACE FUNCTION can_users_interact(uid1 UUID, uid2 UUID)
RETURNS BOOLEAN AS $$
  SELECT NOT EXISTS (
    SELECT 1 FROM blocks
    WHERE (blocker = uid1 AND blocked = uid2)
       OR (blocker = uid2 AND blocked = uid1)
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Function to check if user can like (verified + entry approved + not banned)
CREATE OR REPLACE FUNCTION can_user_like(uid UUID)
RETURNS BOOLEAN AS $$
  SELECT is_user_verified(uid)
     AND is_user_entry_approved(uid)
     AND NOT EXISTS (
       SELECT 1 FROM user_scores
       WHERE user_id = uid AND status = 'banned'
     );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Function to check if chat is unlocked for a match
CREATE OR REPLACE FUNCTION is_chat_unlocked(mid UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM match_state
    WHERE match_id = mid
      AND chat_unlocked = TRUE
      AND closed = FALSE
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Function to check if user is match participant
CREATE OR REPLACE FUNCTION is_match_participant(mid UUID, uid UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM matches
    WHERE id = mid AND (user_a = uid OR user_b = uid)
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Function to get opposite gender
CREATE OR REPLACE FUNCTION get_opposite_gender(g gender_type)
RETURNS gender_type AS $$
  SELECT CASE
    WHEN g = 'male' THEN 'female'::gender_type
    WHEN g = 'female' THEN 'male'::gender_type
    ELSE 'other'::gender_type
  END;
$$ LANGUAGE sql IMMUTABLE;

-- Trigger to update verification status when components change
CREATE OR REPLACE FUNCTION update_verification_status()
RETURNS TRIGGER AS $$
DECLARE
  approved_photos INTEGER;
  ig_verified BOOLEAN;
  gender_verified BOOLEAN;
BEGIN
  -- Count approved photos
  SELECT COUNT(*) INTO approved_photos
  FROM photos
  WHERE user_id = NEW.user_id AND approved = TRUE AND face_visible = TRUE;

  -- Check IG verification
  SELECT ig_media_verified INTO ig_verified
  FROM instagram
  WHERE user_id = NEW.user_id;

  -- Check gender verification
  SELECT status = 'approved' INTO gender_verified
  FROM gender_verification
  WHERE user_id = NEW.user_id;

  -- Update verification status
  INSERT INTO verifications (user_id, status, photos_approved, instagram_verified, gender_verified, updated_at)
  VALUES (
    NEW.user_id,
    CASE
      WHEN approved_photos >= 3 AND COALESCE(ig_verified, FALSE) AND COALESCE(gender_verified, FALSE)
      THEN 'approved'
      ELSE 'pending'
    END,
    approved_photos,
    COALESCE(ig_verified, FALSE),
    COALESCE(gender_verified, FALSE),
    NOW()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    status = CASE
      WHEN EXCLUDED.photos_approved >= 3 AND EXCLUDED.instagram_verified AND EXCLUDED.gender_verified
      THEN 'approved'
      ELSE 'pending'
    END,
    photos_approved = EXCLUDED.photos_approved,
    instagram_verified = EXCLUDED.instagram_verified,
    gender_verified = EXCLUDED.gender_verified,
    updated_at = NOW();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to update entry status when referral is verified
CREATE OR REPLACE FUNCTION update_entry_status_on_referral()
RETURNS TRIGGER AS $$
DECLARE
  referrer_gender gender_type;
  referred_gender gender_type;
  opposite_verified INTEGER;
BEGIN
  -- Only process when referred becomes verified
  IF NEW.referred_verified_at IS NOT NULL AND OLD.referred_verified_at IS NULL THEN
    -- Get referrer's gender
    SELECT gender_claim INTO referrer_gender FROM profiles WHERE user_id = NEW.referrer;
    -- Get referred's gender
    SELECT gender_claim INTO referred_gender FROM profiles WHERE user_id = NEW.referred;

    -- If referred is opposite gender and now verified, increment count
    IF referred_gender = get_opposite_gender(referrer_gender) THEN
      UPDATE entry_status
      SET verified_opposite_gender_count = verified_opposite_gender_count + 1,
          status = CASE
            WHEN verified_opposite_gender_count + 1 >= required_opposite_gender THEN 'approved'
            ELSE status
          END,
          updated_at = NOW()
      WHERE user_id = NEW.referrer;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_update_entry_status
  AFTER UPDATE ON referrals
  FOR EACH ROW
  EXECUTE FUNCTION update_entry_status_on_referral();

-- Trigger to create match state when match is created
CREATE OR REPLACE FUNCTION create_match_state()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO match_state (match_id, schedule_deadline)
  VALUES (NEW.id, NEW.created_at + INTERVAL '12 hours');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_create_match_state
  AFTER INSERT ON matches
  FOR EACH ROW
  EXECUTE FUNCTION create_match_state();

-- Trigger to initialize user records
CREATE OR REPLACE FUNCTION initialize_user_records()
RETURNS TRIGGER AS $$
BEGIN
  -- Create entry_status record
  INSERT INTO entry_status (user_id) VALUES (NEW.user_id);

  -- Create user_scores record
  INSERT INTO user_scores (user_id) VALUES (NEW.user_id);

  -- Create verifications record
  INSERT INTO verifications (user_id) VALUES (NEW.user_id);

  -- Create subscription record
  INSERT INTO subscriptions (user_id) VALUES (NEW.user_id);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_initialize_user_records
  AFTER INSERT ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION initialize_user_records();

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_verifications_updated_at
  BEFORE UPDATE ON verifications
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_entry_status_updated_at
  BEFORE UPDATE ON entry_status
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_subscriptions_updated_at
  BEFORE UPDATE ON subscriptions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_user_scores_updated_at
  BEFORE UPDATE ON user_scores
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_config_updated_at
  BEFORE UPDATE ON config
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

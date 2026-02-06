# Noblara Row Level Security (RLS) Policies

This document describes all RLS policies enforced by Supabase PostgreSQL.

## Core Principles

1. **Server-side enforcement**: All access gates are enforced at the database level
2. **Least privilege**: Users can only access their own data and approved public data
3. **Audit trail**: All admin actions are logged
4. **No data leakage**: Instagram usernames and sensitive data are never exposed

---

## Policy Definitions

### profiles

```sql
-- Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Users can read their own profile
CREATE POLICY "Users can read own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = user_id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Users can insert their own profile (once)
CREATE POLICY "Users can insert own profile"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Verified & entry-approved users can read other verified & entry-approved users (for feed)
CREATE POLICY "Verified users can read other verified users"
  ON profiles FOR SELECT
  USING (
    -- Own profile always readable
    auth.uid() = user_id
    OR (
      -- Viewer must be verified and entry approved
      can_user_like(auth.uid())
      -- Target must be verified and entry approved
      AND can_user_like(user_id)
      -- Not blocked
      AND can_users_interact(auth.uid(), user_id)
      -- Not banned
      AND NOT EXISTS (
        SELECT 1 FROM user_scores WHERE user_scores.user_id = profiles.user_id AND status = 'banned'
      )
    )
  );
```

### photos

```sql
ALTER TABLE photos ENABLE ROW LEVEL SECURITY;

-- Users can manage their own photos
CREATE POLICY "Users can manage own photos"
  ON photos FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Verified & entry-approved users can read approved photos of other verified users
CREATE POLICY "Verified users can read approved photos"
  ON photos FOR SELECT
  USING (
    auth.uid() = user_id
    OR (
      approved = TRUE
      AND can_user_like(auth.uid())
      AND can_user_like(user_id)
      AND can_users_interact(auth.uid(), user_id)
    )
  );
```

### instagram

```sql
ALTER TABLE instagram ENABLE ROW LEVEL SECURITY;

-- Users can ONLY read their own Instagram data
-- Other users NEVER see ig_username - only a "verified" badge
CREATE POLICY "Users can read own instagram"
  ON instagram FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own instagram"
  ON instagram FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can insert own instagram"
  ON instagram FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- For feed display, use a separate view that only exposes ig_media_verified boolean
```

### gender_verification

```sql
ALTER TABLE gender_verification ENABLE ROW LEVEL SECURITY;

-- Users can read their own gender verification status
CREATE POLICY "Users can read own gender verification"
  ON gender_verification FOR SELECT
  USING (auth.uid() = user_id);

-- Users can submit their gender verification
CREATE POLICY "Users can submit gender verification"
  ON gender_verification FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Only admins can update (approve/reject)
-- Handled via service role in edge functions
```

### verifications

```sql
ALTER TABLE verifications ENABLE ROW LEVEL SECURITY;

-- Users can read their own verification status
CREATE POLICY "Users can read own verification"
  ON verifications FOR SELECT
  USING (auth.uid() = user_id);

-- System updates via triggers (no direct user update)
```

### referral_codes

```sql
ALTER TABLE referral_codes ENABLE ROW LEVEL SECURITY;

-- Users can read their own referral codes
CREATE POLICY "Users can read own referral codes"
  ON referral_codes FOR SELECT
  USING (auth.uid() = created_by);

-- Verified users can create referral codes
CREATE POLICY "Verified users can create referral codes"
  ON referral_codes FOR INSERT
  WITH CHECK (
    auth.uid() = created_by
    AND is_user_verified(auth.uid())
  );

-- Anyone can read active codes (for redemption lookup)
CREATE POLICY "Anyone can lookup active codes"
  ON referral_codes FOR SELECT
  USING (is_active = TRUE);
```

### referrals

```sql
ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;

-- Users can read referrals they made or received
CREATE POLICY "Users can read own referrals"
  ON referrals FOR SELECT
  USING (auth.uid() = referrer OR auth.uid() = referred);

-- Referrals are created via edge function with service role
```

### entry_status

```sql
ALTER TABLE entry_status ENABLE ROW LEVEL SECURITY;

-- Users can read their own entry status
CREATE POLICY "Users can read own entry status"
  ON entry_status FOR SELECT
  USING (auth.uid() = user_id);

-- System updates via triggers
```

### likes

```sql
ALTER TABLE likes ENABLE ROW LEVEL SECURITY;

-- Users can read likes they sent or received
CREATE POLICY "Users can read own likes"
  ON likes FOR SELECT
  USING (auth.uid() = from_user OR auth.uid() = to_user);

-- Only verified + entry-approved users can create likes to verified + entry-approved targets
CREATE POLICY "Verified users can like verified users"
  ON likes FOR INSERT
  WITH CHECK (
    auth.uid() = from_user
    AND can_user_like(auth.uid())
    AND can_user_like(to_user)
    AND can_users_interact(auth.uid(), to_user)
  );
```

### matches

```sql
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;

-- Users can only read matches they're part of
CREATE POLICY "Users can read own matches"
  ON matches FOR SELECT
  USING (auth.uid() = user_a OR auth.uid() = user_b);

-- Matches are created via trigger when mutual like detected
```

### match_state

```sql
ALTER TABLE match_state ENABLE ROW LEVEL SECURITY;

-- Users can read match state for their matches
CREATE POLICY "Users can read own match state"
  ON match_state FOR SELECT
  USING (is_match_participant(match_id, auth.uid()));
```

### call_proposals

```sql
ALTER TABLE call_proposals ENABLE ROW LEVEL SECURITY;

-- Match participants can read proposals
CREATE POLICY "Match participants can read proposals"
  ON call_proposals FOR SELECT
  USING (is_match_participant(match_id, auth.uid()));

-- WOMEN FIRST: Only female users can create initial proposals during schedule window
-- (unless config allows male counter-proposals)
CREATE POLICY "Women can propose first"
  ON call_proposals FOR INSERT
  WITH CHECK (
    auth.uid() = proposer
    AND is_match_participant(match_id, auth.uid())
    -- Check if in schedule window
    AND EXISTS (
      SELECT 1 FROM match_state ms
      WHERE ms.match_id = call_proposals.match_id
      AND NOW() < ms.schedule_deadline
    )
    -- Woman first rule
    AND (
      -- User is female
      (SELECT gender_claim FROM profiles WHERE user_id = auth.uid()) = 'female'
      OR
      -- Or male counter-proposal is enabled AND there's already a female proposal
      (
        (SELECT (value::text)::boolean FROM config WHERE key = 'male_counter_proposal_enabled')
        AND EXISTS (
          SELECT 1 FROM call_proposals cp
          JOIN profiles p ON p.user_id = cp.proposer
          WHERE cp.match_id = call_proposals.match_id
          AND p.gender_claim = 'female'
        )
      )
    )
  );
```

### call_bookings

```sql
ALTER TABLE call_bookings ENABLE ROW LEVEL SECURITY;

-- Match participants can read bookings
CREATE POLICY "Match participants can read bookings"
  ON call_bookings FOR SELECT
  USING (is_match_participant(match_id, auth.uid()));

-- Bookings created via edge function
```

### call_ratings

```sql
ALTER TABLE call_ratings ENABLE ROW LEVEL SECURITY;

-- Users can only read their own ratings (not see what others rated them)
CREATE POLICY "Users can read ratings they gave"
  ON call_ratings FOR SELECT
  USING (auth.uid() = rater);

-- Only match participants can rate after call completed
CREATE POLICY "Match participants can rate"
  ON call_ratings FOR INSERT
  WITH CHECK (
    auth.uid() = rater
    AND is_match_participant(match_id, auth.uid())
    AND EXISTS (
      SELECT 1 FROM match_state ms
      WHERE ms.match_id = call_ratings.match_id
      AND ms.call_completed = TRUE
    )
  );
```

### messages

```sql
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Only match participants can read messages if chat is unlocked
CREATE POLICY "Match participants can read messages"
  ON messages FOR SELECT
  USING (
    is_match_participant(match_id, auth.uid())
    AND is_chat_unlocked(match_id)
  );

-- Only match participants can send messages if chat is unlocked
CREATE POLICY "Match participants can send messages"
  ON messages FOR INSERT
  WITH CHECK (
    auth.uid() = from_user
    AND is_match_participant(match_id, auth.uid())
    AND is_chat_unlocked(match_id)
    AND can_users_interact(
      auth.uid(),
      (SELECT CASE WHEN user_a = auth.uid() THEN user_b ELSE user_a END FROM matches WHERE id = match_id)
    )
  );
```

### blocks

```sql
ALTER TABLE blocks ENABLE ROW LEVEL SECURITY;

-- Users can read blocks they created
CREATE POLICY "Users can read own blocks"
  ON blocks FOR SELECT
  USING (auth.uid() = blocker);

-- Users can create blocks
CREATE POLICY "Users can create blocks"
  ON blocks FOR INSERT
  WITH CHECK (auth.uid() = blocker);

-- Users can delete their own blocks
CREATE POLICY "Users can delete own blocks"
  ON blocks FOR DELETE
  USING (auth.uid() = blocker);
```

### reports

```sql
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

-- Users can read reports they submitted
CREATE POLICY "Users can read own reports"
  ON reports FOR SELECT
  USING (auth.uid() = reporter);

-- Verified users can create reports
CREATE POLICY "Verified users can create reports"
  ON reports FOR INSERT
  WITH CHECK (
    auth.uid() = reporter
    AND is_user_verified(auth.uid())
  );

-- Admins can read all reports via service role
```

### meetups

```sql
ALTER TABLE meetups ENABLE ROW LEVEL SECURITY;

-- Match participants can read meetups
CREATE POLICY "Match participants can read meetups"
  ON meetups FOR SELECT
  USING (is_match_participant(match_id, auth.uid()));

-- Match participants can create meetups if chat unlocked and within deadline
CREATE POLICY "Match participants can create meetups"
  ON meetups FOR INSERT
  WITH CHECK (
    is_match_participant(match_id, auth.uid())
    AND is_chat_unlocked(match_id)
    AND EXISTS (
      SELECT 1 FROM match_state ms
      WHERE ms.match_id = meetups.match_id
      AND (ms.meetup_deadline IS NULL OR NOW() < ms.meetup_deadline)
    )
  );
```

### qr_checkins

```sql
ALTER TABLE qr_checkins ENABLE ROW LEVEL SECURITY;

-- Users can read their own checkins
CREATE POLICY "Users can read own checkins"
  ON qr_checkins FOR SELECT
  USING (auth.uid() = user_id);

-- Checkins created via edge function with validation
```

### posts

```sql
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

-- Anyone can read posts from verified & entry-approved users
CREATE POLICY "Read posts from verified users"
  ON posts FOR SELECT
  USING (
    can_user_like(user_id)
    AND can_users_interact(auth.uid(), user_id)
  );

-- Verified & entry-approved users can create 1 post per day
CREATE POLICY "Verified users can post once per day"
  ON posts FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND can_user_like(auth.uid())
  );
  -- Unique constraint on (user_id, day_key) enforces 1/day

-- Users can delete their own posts
CREATE POLICY "Users can delete own posts"
  ON posts FOR DELETE
  USING (auth.uid() = user_id);
```

### post_reports

```sql
ALTER TABLE post_reports ENABLE ROW LEVEL SECURITY;

-- Users can read reports they submitted
CREATE POLICY "Users can read own post reports"
  ON post_reports FOR SELECT
  USING (auth.uid() = reporter);

-- Verified users can report posts
CREATE POLICY "Verified users can report posts"
  ON post_reports FOR INSERT
  WITH CHECK (
    auth.uid() = reporter
    AND is_user_verified(auth.uid())
  );
```

### subscriptions

```sql
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

-- Users can read their own subscription
CREATE POLICY "Users can read own subscription"
  ON subscriptions FOR SELECT
  USING (auth.uid() = user_id);

-- Updates via RevenueCat webhook (service role)
```

### user_scores

```sql
ALTER TABLE user_scores ENABLE ROW LEVEL SECURITY;

-- Users can read their own score
CREATE POLICY "Users can read own score"
  ON user_scores FOR SELECT
  USING (auth.uid() = user_id);

-- System updates only (service role)
```

### audit_log

```sql
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

-- Only admins can read audit logs (via service role)
-- No user access
```

### config

```sql
ALTER TABLE config ENABLE ROW LEVEL SECURITY;

-- Only admins can read/write config (via service role)
-- Public function exposes specific safe values
CREATE OR REPLACE FUNCTION get_public_config()
RETURNS JSONB AS $$
  SELECT jsonb_object_agg(key, value)
  FROM config
  WHERE key IN (
    'bootstrap_mode_enabled',
    'male_counter_proposal_enabled',
    'video_call_required',
    'min_call_duration_sec',
    'max_call_duration_sec',
    'schedule_window_hours',
    'meetup_deadline_days'
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;
```

### jobs

```sql
ALTER TABLE jobs ENABLE ROW LEVEL SECURITY;

-- No user access - service role only
```

---

## Admin Access

All admin operations use the **service role** key and bypass RLS. Admin actions MUST:

1. Check admin status via `config.admin_users` or auth role claim
2. Write to `audit_log` for every action
3. Never expose service role key to clients

```sql
-- Example admin check in edge function
CREATE OR REPLACE FUNCTION is_admin(uid UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM config
    WHERE key = 'admin_users'
    AND value ? uid::text
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;
```

---

## View for Public Profile Data

Used for feed display - never exposes IG username:

```sql
CREATE OR REPLACE VIEW public_profiles AS
SELECT
  p.user_id,
  p.mode,
  p.birth_year,
  p.city,
  p.bio,
  p.latitude,
  p.longitude,
  COALESCE(i.ig_media_verified, FALSE) as instagram_verified,
  (SELECT json_agg(json_build_object('url', ph.url, 'order_index', ph.order_index))
   FROM photos ph
   WHERE ph.user_id = p.user_id AND ph.approved = TRUE
   ORDER BY ph.order_index) as photos
FROM profiles p
LEFT JOIN instagram i ON i.user_id = p.user_id
WHERE can_user_like(p.user_id);
```

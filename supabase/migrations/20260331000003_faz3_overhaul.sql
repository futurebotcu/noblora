-- =============================================================================
-- FAZ 3: Major Overhaul Migration
-- - Usage limits system (tier-based daily/weekly/monthly)
-- - Signal system (replaces super_like concept)
-- - Note system (private notes on profiles/posts)
-- - Mini Intro system (post-connection intro messages)
-- - Check-in & Trust system
-- - Video call 3-5 min (replaces 10 min)
-- - Chat: no time limit (remove expiry enforcement)
-- - Match statuses: add pending_intro
-- Created: 2026-03-31
-- =============================================================================

-- ═══════════════════════════════════════════════════════════════════
-- 1. PROFILES: Add usage limits + trust_score columns
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE public.profiles
  -- Trust system (invisible to users, affects algorithmic visibility)
  ADD COLUMN IF NOT EXISTS trust_score          INT         NOT NULL DEFAULT 50,
  -- Daily usage counters
  ADD COLUMN IF NOT EXISTS daily_swipes_used    INT         NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS daily_swipes_reset   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS daily_connections    INT         NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS daily_connections_reset TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- Signal counters (daily/weekly/monthly depending on tier)
  ADD COLUMN IF NOT EXISTS daily_signals_used   INT         NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS daily_signals_reset  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS weekly_signals_used  INT         NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS weekly_signals_reset TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS monthly_signals_used INT         NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS monthly_signals_reset TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- Comment/Note counters
  ADD COLUMN IF NOT EXISTS daily_notes_used     INT         NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS daily_notes_reset    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS weekly_notes_used    INT         NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS weekly_notes_reset   TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- Trust score constraint
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_trust_score_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_trust_score_check
  CHECK (trust_score >= 0 AND trust_score <= 100);

-- ═══════════════════════════════════════════════════════════════════
-- 2. SIGNALS TABLE (replaces super_like as primary "strong interest")
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.signals (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id   UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  receiver_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(sender_id, receiver_id)
);

ALTER TABLE public.signals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "signals_select" ON public.signals
  FOR SELECT TO authenticated
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "signals_insert" ON public.signals
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "signals_delete" ON public.signals
  FOR DELETE TO authenticated
  USING (auth.uid() = sender_id);

CREATE INDEX IF NOT EXISTS signals_sender_idx ON public.signals(sender_id);
CREATE INDEX IF NOT EXISTS signals_receiver_idx ON public.signals(receiver_id);

-- ═══════════════════════════════════════════════════════════════════
-- 3. NOTES TABLE (private notes on profiles or posts)
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.notes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id   UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  receiver_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  target_type TEXT NOT NULL DEFAULT 'profile',
  target_id   UUID NOT NULL,                     -- profile user_id or post_id
  content     TEXT NOT NULL,
  is_read     BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT notes_target_type_check CHECK (target_type IN ('profile', 'post')),
  CONSTRAINT notes_content_length CHECK (char_length(content) BETWEEN 1 AND 280)
);

ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notes_select" ON public.notes
  FOR SELECT TO authenticated
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "notes_insert" ON public.notes
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "notes_update" ON public.notes
  FOR UPDATE TO authenticated
  USING (auth.uid() = receiver_id)   -- only receiver can mark as read
  WITH CHECK (auth.uid() = receiver_id);

CREATE INDEX IF NOT EXISTS notes_sender_idx ON public.notes(sender_id);
CREATE INDEX IF NOT EXISTS notes_receiver_idx ON public.notes(receiver_id);
CREATE INDEX IF NOT EXISTS notes_target_idx ON public.notes(target_type, target_id);

-- ═══════════════════════════════════════════════════════════════════
-- 4. MINI INTROS TABLE (post-connection intro messages)
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.mini_intros (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id   UUID REFERENCES public.matches(id) ON DELETE CASCADE NOT NULL,
  sender_id  UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  message    TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT mini_intros_message_length CHECK (char_length(message) BETWEEN 1 AND 280),
  UNIQUE(match_id, sender_id)
);

ALTER TABLE public.mini_intros ENABLE ROW LEVEL SECURITY;

-- Both users in the match can see intros
CREATE POLICY "mini_intros_select" ON public.mini_intros
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.matches m
      WHERE m.id = match_id
        AND (m.user1_id = auth.uid() OR m.user2_id = auth.uid())
    )
  );

CREATE POLICY "mini_intros_insert" ON public.mini_intros
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = sender_id);

CREATE INDEX IF NOT EXISTS mini_intros_match_idx ON public.mini_intros(match_id);

-- Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.mini_intros;

-- ═══════════════════════════════════════════════════════════════════
-- 5. CHECK-INS TABLE (post-meetup safety check)
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.check_ins (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_id  UUID REFERENCES public.real_meetings(id) ON DELETE CASCADE NOT NULL,
  user_id     UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  response    TEXT NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT check_ins_response_check CHECK (response IN ('great', 'okay', 'rather_not_say', 'report')),
  UNIQUE(meeting_id, user_id)
);

ALTER TABLE public.check_ins ENABLE ROW LEVEL SECURITY;

CREATE POLICY "check_ins_select" ON public.check_ins
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "check_ins_insert" ON public.check_ins
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS check_ins_meeting_idx ON public.check_ins(meeting_id);
CREATE INDEX IF NOT EXISTS check_ins_user_idx ON public.check_ins(user_id);

-- ═══════════════════════════════════════════════════════════════════
-- 6. MATCHES: Add pending_intro status, keep closed
-- ═══════════════════════════════════════════════════════════════════

-- Update the constraint to include pending_intro
ALTER TABLE public.matches DROP CONSTRAINT IF EXISTS matches_status_check;
ALTER TABLE public.matches ADD CONSTRAINT matches_status_check
  CHECK (status IN (
    'pending_intro',      -- NEW: after mutual swipe, before video scheduling
    'pending_video',      -- waiting for video schedule
    'video_scheduled',    -- video time accepted
    'video_completed',    -- video done, awaiting decisions
    'chatting',           -- chat open (NO expiry now)
    'meeting_scheduled',  -- in-person meetup planned
    'expired',
    'closed'
  ));

-- ═══════════════════════════════════════════════════════════════════
-- 7. VIDEO SESSIONS: Add call_duration_minutes column (3-5 min)
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE public.video_sessions
  ADD COLUMN IF NOT EXISTS call_duration_minutes INT NOT NULL DEFAULT 4;

ALTER TABLE public.video_sessions DROP CONSTRAINT IF EXISTS video_sessions_duration_check;
ALTER TABLE public.video_sessions ADD CONSTRAINT video_sessions_duration_check
  CHECK (call_duration_minutes BETWEEN 3 AND 5);

-- Update status constraint to include 'active'
ALTER TABLE public.video_sessions DROP CONSTRAINT IF EXISTS video_sessions_status_check;
ALTER TABLE public.video_sessions ADD CONSTRAINT video_sessions_status_check
  CHECK (status IN ('pending', 'counter_proposed', 'accepted', 'completed', 'expired', 'cancelled', 'active'));

-- ═══════════════════════════════════════════════════════════════════
-- 8. PROCESS_CALL_DECISION: Remove chat expiry (infinite chat)
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.process_call_decision(
  p_video_session_id UUID,
  p_user_id UUID,
  p_enjoyed BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_match     public.matches;
  v_session   public.video_sessions;
  v_conv_id   UUID;
  v_decisions INTEGER;
  v_yes_count INTEGER;
BEGIN
  SELECT * INTO v_session FROM public.video_sessions WHERE id = p_video_session_id;
  SELECT * INTO v_match FROM public.matches WHERE id = v_session.match_id;

  SELECT COUNT(*), COUNT(*) FILTER (WHERE enjoyed = TRUE)
  INTO v_decisions, v_yes_count
  FROM public.call_decisions
  WHERE video_session_id = p_video_session_id;

  IF v_decisions < 2 THEN
    RETURN jsonb_build_object('result', 'waiting');
  END IF;

  IF v_yes_count = 2 THEN
    -- Both "Keep Open" → chat opens with NO expiry
    INSERT INTO public.conversations (type, mode)
    VALUES ('alliance', v_match.mode)
    RETURNING id INTO v_conv_id;

    INSERT INTO public.conversation_participants (conversation_id, user_id)
    VALUES (v_conv_id, v_match.user1_id), (v_conv_id, v_match.user2_id);

    UPDATE public.matches
    SET status = 'chatting',
        conversation_id = v_conv_id,
        chat_expires_at = NULL     -- no expiry
    WHERE id = v_match.id;

    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES
      (v_match.user1_id, 'chat_opened', 'Chat is open!',
       'You both chose to keep it open. Start chatting!',
       jsonb_build_object('match_id', v_match.id, 'conversation_id', v_conv_id)),
      (v_match.user2_id, 'chat_opened', 'Chat is open!',
       'You both chose to keep it open. Start chatting!',
       jsonb_build_object('match_id', v_match.id, 'conversation_id', v_conv_id));

    RETURN jsonb_build_object('result', 'chat_opened', 'conversation_id', v_conv_id);
  ELSE
    -- At least one "Pass" → close silently
    UPDATE public.matches SET status = 'closed' WHERE id = v_match.id;

    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES
      (v_match.user1_id, 'connection_closed', 'Connection Ended',
       'This connection has come to a close. Keep exploring.',
       jsonb_build_object('match_id', v_match.id)),
      (v_match.user2_id, 'connection_closed', 'Connection Ended',
       'This connection has come to a close. Keep exploring.',
       jsonb_build_object('match_id', v_match.id));

    RETURN jsonb_build_object('result', 'closed');
  END IF;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════
-- 9. CHECK_AND_CREATE_MATCH: Create as pending_intro (not pending_video)
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.check_and_create_match(
  p_swiper UUID,
  p_target UUID,
  p_mode   TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_mutual BOOLEAN;
  v_match  public.matches;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM public.swipes
    WHERE swiper_id = p_target
      AND swiped_id = p_swiper
      AND direction IN ('right', 'super')
      AND mode = p_mode
  ) INTO v_mutual;

  IF NOT v_mutual THEN
    RETURN NULL;
  END IF;

  -- Check no existing match
  IF EXISTS (
    SELECT 1 FROM public.matches
    WHERE ((user1_id = p_swiper AND user2_id = p_target) OR
           (user1_id = p_target AND user2_id = p_swiper))
      AND mode = p_mode
      AND status NOT IN ('expired', 'closed')
  ) THEN
    RETURN NULL;
  END IF;

  -- Create match with pending_intro status (Mini Intro first)
  INSERT INTO public.matches (user1_id, user2_id, mode, status, video_deadline_at)
  VALUES (p_swiper, p_target, p_mode, 'pending_intro', NOW() + INTERVAL '24 hours')
  RETURNING * INTO v_match;

  -- Notify both users
  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES
    (p_swiper, 'new_match', 'New Connection!',
     'You have a new connection. Send a mini intro!',
     jsonb_build_object('match_id', v_match.id)),
    (p_target, 'new_match', 'New Connection!',
     'You have a new connection. Send a mini intro!',
     jsonb_build_object('match_id', v_match.id));

  RETURN to_jsonb(v_match);
END;
$$;

-- ═══════════════════════════════════════════════════════════════════
-- 10. USAGE LIMIT FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════

-- Check swipe limit per tier
CREATE OR REPLACE FUNCTION public.check_swipe_limit(p_user_id UUID)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tier   TEXT;
  v_used   INT;
  v_reset  TIMESTAMPTZ;
  v_limit  INT;
BEGIN
  SELECT nob_tier, daily_swipes_used, daily_swipes_reset
  INTO v_tier, v_used, v_reset
  FROM public.profiles WHERE id = p_user_id;

  IF v_tier IS NULL THEN RETURN FALSE; END IF;

  -- Reset if stale
  IF v_reset < NOW() - INTERVAL '1 day' THEN
    v_used := 0;
    UPDATE public.profiles SET daily_swipes_used = 0, daily_swipes_reset = NOW() WHERE id = p_user_id;
  END IF;

  -- Tier limits: observer=30, explorer=50, noble=100
  v_limit := CASE v_tier
    WHEN 'observer' THEN 30
    WHEN 'explorer' THEN 50
    WHEN 'noble'    THEN 100
    ELSE 30
  END;

  RETURN v_used < v_limit;
END;
$$;

-- Increment swipe counter
CREATE OR REPLACE FUNCTION public.increment_swipe_count(p_user_id UUID)
RETURNS VOID LANGUAGE sql SECURITY DEFINER AS $$
  UPDATE public.profiles SET daily_swipes_used = daily_swipes_used + 1 WHERE id = p_user_id;
$$;

-- Check connection (match) limit per tier
CREATE OR REPLACE FUNCTION public.check_connection_limit(p_user_id UUID)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tier   TEXT;
  v_used   INT;
  v_reset  TIMESTAMPTZ;
  v_limit  INT;
BEGIN
  SELECT nob_tier, daily_connections, daily_connections_reset
  INTO v_tier, v_used, v_reset
  FROM public.profiles WHERE id = p_user_id;

  IF v_tier IS NULL THEN RETURN FALSE; END IF;

  IF v_reset < NOW() - INTERVAL '1 day' THEN
    v_used := 0;
    UPDATE public.profiles SET daily_connections = 0, daily_connections_reset = NOW() WHERE id = p_user_id;
  END IF;

  v_limit := CASE v_tier
    WHEN 'observer' THEN 2
    WHEN 'explorer' THEN 4
    WHEN 'noble'    THEN 7
    ELSE 2
  END;

  RETURN v_used < v_limit;
END;
$$;

-- Check signal limit per tier
CREATE OR REPLACE FUNCTION public.check_signal_limit(p_user_id UUID)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tier           TEXT;
  v_daily          INT;
  v_weekly         INT;
  v_monthly        INT;
  v_daily_reset    TIMESTAMPTZ;
  v_weekly_reset   TIMESTAMPTZ;
  v_monthly_reset  TIMESTAMPTZ;
BEGIN
  SELECT nob_tier,
         daily_signals_used, daily_signals_reset,
         weekly_signals_used, weekly_signals_reset,
         monthly_signals_used, monthly_signals_reset
  INTO v_tier,
       v_daily, v_daily_reset,
       v_weekly, v_weekly_reset,
       v_monthly, v_monthly_reset
  FROM public.profiles WHERE id = p_user_id;

  IF v_tier IS NULL THEN RETURN FALSE; END IF;

  -- Reset stale counters
  IF v_daily_reset < NOW() - INTERVAL '1 day' THEN
    v_daily := 0;
    UPDATE public.profiles SET daily_signals_used = 0, daily_signals_reset = NOW() WHERE id = p_user_id;
  END IF;
  IF v_weekly_reset < NOW() - INTERVAL '7 days' THEN
    v_weekly := 0;
    UPDATE public.profiles SET weekly_signals_used = 0, weekly_signals_reset = NOW() WHERE id = p_user_id;
  END IF;
  IF v_monthly_reset < NOW() - INTERVAL '30 days' THEN
    v_monthly := 0;
    UPDATE public.profiles SET monthly_signals_used = 0, monthly_signals_reset = NOW() WHERE id = p_user_id;
  END IF;

  -- Observer: 1/month
  IF v_tier = 'observer' THEN RETURN v_monthly < 1; END IF;
  -- Explorer: 2/week
  IF v_tier = 'explorer' THEN RETURN v_weekly < 2; END IF;
  -- Noble: 1/day
  IF v_tier = 'noble' THEN RETURN v_daily < 1; END IF;

  RETURN FALSE;
END;
$$;

-- Increment signal counters
CREATE OR REPLACE FUNCTION public.increment_signal_count(p_user_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.profiles
  SET daily_signals_used   = daily_signals_used + 1,
      weekly_signals_used  = weekly_signals_used + 1,
      monthly_signals_used = monthly_signals_used + 1
  WHERE id = p_user_id;
END;
$$;

-- Check note limit per tier
CREATE OR REPLACE FUNCTION public.check_note_limit(p_user_id UUID)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tier         TEXT;
  v_daily        INT;
  v_weekly       INT;
  v_daily_reset  TIMESTAMPTZ;
  v_weekly_reset TIMESTAMPTZ;
BEGIN
  SELECT nob_tier, daily_notes_used, daily_notes_reset, weekly_notes_used, weekly_notes_reset
  INTO v_tier, v_daily, v_daily_reset, v_weekly, v_weekly_reset
  FROM public.profiles WHERE id = p_user_id;

  IF v_tier IS NULL THEN RETURN FALSE; END IF;

  IF v_daily_reset < NOW() - INTERVAL '1 day' THEN
    v_daily := 0;
    UPDATE public.profiles SET daily_notes_used = 0, daily_notes_reset = NOW() WHERE id = p_user_id;
  END IF;
  IF v_weekly_reset < NOW() - INTERVAL '7 days' THEN
    v_weekly := 0;
    UPDATE public.profiles SET weekly_notes_used = 0, weekly_notes_reset = NOW() WHERE id = p_user_id;
  END IF;

  -- Observer: 1/week (same as comments)
  IF v_tier = 'observer' THEN RETURN v_weekly < 1; END IF;
  -- Explorer: 3/week
  IF v_tier = 'explorer' THEN RETURN v_weekly < 3; END IF;
  -- Noble: 2/day
  IF v_tier = 'noble' THEN RETURN v_daily < 2; END IF;

  RETURN FALSE;
END;
$$;

-- Increment note counters
CREATE OR REPLACE FUNCTION public.increment_note_count(p_user_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.profiles
  SET daily_notes_used  = daily_notes_used + 1,
      weekly_notes_used = weekly_notes_used + 1
  WHERE id = p_user_id;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════
-- 11. TRUST SCORE FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.adjust_trust_score(p_user_id UUID, p_delta INT)
RETURNS VOID LANGUAGE sql SECURITY DEFINER AS $$
  UPDATE public.profiles
  SET trust_score = GREATEST(0, LEAST(100, trust_score + p_delta))
  WHERE id = p_user_id;
$$;

-- Process check-in and adjust trust
CREATE OR REPLACE FUNCTION public.process_check_in(
  p_meeting_id UUID,
  p_user_id UUID,
  p_response TEXT
)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_delta INT;
BEGIN
  -- Insert check-in
  INSERT INTO public.check_ins (meeting_id, user_id, response)
  VALUES (p_meeting_id, p_user_id, p_response)
  ON CONFLICT (meeting_id, user_id) DO UPDATE SET response = p_response;

  -- Adjust trust based on response
  v_delta := CASE p_response
    WHEN 'great'          THEN 5
    WHEN 'okay'           THEN 2
    WHEN 'rather_not_say' THEN 0
    WHEN 'report'         THEN -25
    ELSE 0
  END;

  -- Apply to the OTHER user (the person being reviewed)
  -- Find the other user from the meeting
  UPDATE public.profiles
  SET trust_score = GREATEST(0, LEAST(100, trust_score + v_delta))
  WHERE id = (
    SELECT CASE
      WHEN m.user1_id = p_user_id THEN m.user2_id
      ELSE m.user1_id
    END
    FROM public.matches m
    JOIN public.real_meetings rm ON rm.match_id = m.id
    WHERE rm.id = p_meeting_id
  );
END;
$$;

-- ═══════════════════════════════════════════════════════════════════
-- 12. CRON JOBS: Reset usage limits + remove chat expiry cron
-- ═══════════════════════════════════════════════════════════════════

-- Remove the chatting-matches expiry cron (chat is infinite now)
SELECT cron.unschedule('expire-chatting-matches');

-- Daily usage limit reset (midnight UTC)
SELECT cron.schedule('reset-daily-usage-limits', '0 0 * * *', $$
  UPDATE public.profiles SET
    daily_swipes_used    = 0, daily_swipes_reset    = NOW(),
    daily_connections    = 0, daily_connections_reset = NOW(),
    daily_signals_used   = 0, daily_signals_reset   = NOW(),
    daily_notes_used     = 0, daily_notes_reset     = NOW();
$$);

-- Weekly usage limit reset (Monday midnight UTC)
SELECT cron.schedule('reset-weekly-usage-limits', '0 0 * * 1', $$
  UPDATE public.profiles SET
    weekly_signals_used  = 0, weekly_signals_reset  = NOW(),
    weekly_notes_used    = 0, weekly_notes_reset    = NOW();
$$);

-- Monthly signal reset (1st of month midnight UTC)
SELECT cron.schedule('reset-monthly-signals', '0 0 1 * *', $$
  UPDATE public.profiles SET
    monthly_signals_used = 0, monthly_signals_reset = NOW();
$$);

-- Enable realtime on new tables
ALTER PUBLICATION supabase_realtime ADD TABLE public.signals;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notes;
ALTER PUBLICATION supabase_realtime ADD TABLE public.check_ins;

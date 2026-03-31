-- =============================================================================
-- NOBLARA — Complete Supabase PostgreSQL Schema v2
-- Run this in Supabase Dashboard → SQL Editor → New query → Run
-- IMPORTANT: Run this on a fresh project. For existing projects, use the
--            migration sections at the bottom.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_trgm; -- for text search

-- =============================================================================
-- profiles
-- =============================================================================
CREATE TABLE public.profiles (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
  display_name        TEXT NOT NULL DEFAULT '',
  bio                 TEXT,
  date_bio            TEXT,
  bff_bio             TEXT,
  social_bio          TEXT,

  -- Identity
  age                 INTEGER CHECK (age IS NULL OR (age >= 18 AND age <= 100)),
  gender              TEXT CHECK (gender IN ('male', 'female', 'other')),
  city                TEXT,
  nationality         TEXT,
  languages           TEXT[] DEFAULT '{}',

  -- Professional
  profession          TEXT,
  company             TEXT,
  education           TEXT,

  -- Mode & discovery
  mode                TEXT DEFAULT 'date' CHECK (mode IN ('date', 'bff', 'social')),
  location            GEOGRAPHY(POINT, 4326),

  -- Photos
  photos              TEXT[] DEFAULT '{}',
  date_avatar_url     TEXT,
  bff_avatar_url      TEXT,
  social_avatar_url   TEXT,

  -- Lifestyle
  smoking             TEXT CHECK (smoking IN ('never', 'socially', 'regularly')),
  drinking            TEXT CHECK (drinking IN ('never', 'socially', 'regularly')),
  sports              TEXT[] DEFAULT '{}',
  hobbies             TEXT[] DEFAULT '{}',
  travel_style        TEXT,
  relationship_goal   TEXT,

  -- Dating preferences
  pref_age_min        INTEGER DEFAULT 18,
  pref_age_max        INTEGER DEFAULT 60,
  pref_max_distance   INTEGER DEFAULT 50,

  -- Scoring & status
  noble_score         INTEGER DEFAULT 0 CHECK (noble_score >= 0 AND noble_score <= 100),
  is_verified         BOOLEAN DEFAULT FALSE,
  selfie_verified     BOOLEAN DEFAULT FALSE,
  photos_verified     BOOLEAN DEFAULT FALSE,
  is_onboarded        BOOLEAN DEFAULT FALSE,

  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_select" ON public.profiles
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "profiles_insert" ON public.profiles
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

CREATE POLICY "profiles_update" ON public.profiles
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- =============================================================================
-- gating_status
-- =============================================================================
CREATE TABLE public.gating_status (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
  is_verified           BOOLEAN DEFAULT FALSE,
  is_entry_approved     BOOLEAN DEFAULT FALSE,
  instagram_verified    BOOLEAN DEFAULT FALSE,
  verification_message  TEXT,
  entry_message         TEXT,
  created_at            TIMESTAMPTZ DEFAULT NOW(),
  updated_at            TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.gating_status ENABLE ROW LEVEL SECURITY;

CREATE POLICY "gating_select" ON public.gating_status
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "gating_insert" ON public.gating_status
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

CREATE POLICY "gating_update" ON public.gating_status
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- =============================================================================
-- photo_verifications  (Gemini AI verification)
-- =============================================================================
CREATE TABLE public.photo_verifications (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                  UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  photo_url                TEXT NOT NULL,
  photo_type               TEXT NOT NULL CHECK (photo_type IN ('profile', 'selfie')),
  status                   TEXT NOT NULL DEFAULT 'pending'
                           CHECK (status IN ('pending', 'approved', 'rejected')),
  gemini_response          JSONB,
  rejection_reason         TEXT,
  real_selfie_probability  FLOAT,
  gender_detected          TEXT,
  decision                 TEXT,
  ai_reason                TEXT,
  created_at               TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.photo_verifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "photo_verif_select" ON public.photo_verifications
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "photo_verif_insert" ON public.photo_verifications
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

-- Admins can update verification status (via service role key in edge function)

-- =============================================================================
-- gender_queue  (gender balance system)
-- =============================================================================
CREATE TABLE public.gender_queue (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
  gender      TEXT NOT NULL CHECK (gender IN ('male', 'female', 'other')),
  status      TEXT NOT NULL DEFAULT 'waiting'
              CHECK (status IN ('waiting', 'admitted', 'expired')),
  position    INTEGER,
  joined_at   TIMESTAMPTZ DEFAULT NOW(),
  admitted_at TIMESTAMPTZ
);

ALTER TABLE public.gender_queue ENABLE ROW LEVEL SECURITY;

CREATE POLICY "queue_select" ON public.gender_queue
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "queue_insert" ON public.gender_queue
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

-- =============================================================================
-- swipes
-- =============================================================================
CREATE TABLE public.swipes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  swiper_id   UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  target_id   UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  direction   TEXT NOT NULL CHECK (direction IN ('right', 'left', 'super')),
  mode        TEXT NOT NULL DEFAULT 'date' CHECK (mode IN ('date', 'bff', 'social')),
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(swiper_id, target_id, mode)
);

ALTER TABLE public.swipes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "swipes_select" ON public.swipes
  FOR SELECT TO authenticated USING (auth.uid() = swiper_id);

CREATE POLICY "swipes_insert" ON public.swipes
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = swiper_id);

-- =============================================================================
-- matches
-- =============================================================================
CREATE TABLE public.matches (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user1_id          UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  user2_id          UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  mode              TEXT NOT NULL DEFAULT 'date' CHECK (mode IN ('date', 'bff', 'social')),
  status            TEXT NOT NULL DEFAULT 'pending_video'
                    CHECK (status IN (
                      'pending_video',    -- matched, awaiting video schedule
                      'video_scheduled',  -- video call confirmed
                      'video_completed',  -- call done, awaiting decisions
                      'chatting',         -- both yes → chat open
                      'meeting_scheduled',-- real meeting booked
                      'expired'           -- time limit missed or someone said no
                    )),
  matched_at        TIMESTAMPTZ DEFAULT NOW(),
  video_deadline_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '12 hours',
  chat_expires_at   TIMESTAMPTZ,
  conversation_id   UUID,  -- populated after chatting begins
  CONSTRAINT no_self_match CHECK (user1_id <> user2_id),
  UNIQUE(user1_id, user2_id, mode)
);

ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;

-- Both users in the match can see it
CREATE POLICY "matches_select" ON public.matches
  FOR SELECT TO authenticated
  USING (auth.uid() = user1_id OR auth.uid() = user2_id);

CREATE POLICY "matches_insert" ON public.matches
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user1_id OR auth.uid() = user2_id);

CREATE POLICY "matches_update" ON public.matches
  FOR UPDATE TO authenticated
  USING (auth.uid() = user1_id OR auth.uid() = user2_id);

-- =============================================================================
-- video_sessions
-- =============================================================================
CREATE TABLE public.video_sessions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id        UUID REFERENCES public.matches(id) ON DELETE CASCADE NOT NULL,
  scheduled_at    TIMESTAMPTZ NOT NULL,
  status          TEXT NOT NULL DEFAULT 'proposed'
                  CHECK (status IN (
                    'proposed',   -- female proposed time
                    'confirmed',  -- male accepted
                    'counter',    -- male suggested another time
                    'active',     -- call in progress
                    'completed',  -- call ended normally
                    'cancelled',  -- cancelled
                    'expired'     -- 12hr window missed
                  )),
  proposed_by     UUID REFERENCES auth.users(id),
  confirmed_by    UUID REFERENCES auth.users(id),
  room_url        TEXT,
  started_at      TIMESTAMPTZ,
  ended_at        TIMESTAMPTZ,
  duration_seconds INTEGER,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.video_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "video_sessions_select" ON public.video_sessions
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.matches m
      WHERE m.id = video_sessions.match_id
        AND (m.user1_id = auth.uid() OR m.user2_id = auth.uid())
    )
  );

CREATE POLICY "video_sessions_insert" ON public.video_sessions
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = proposed_by);

CREATE POLICY "video_sessions_update" ON public.video_sessions
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.matches m
      WHERE m.id = video_sessions.match_id
        AND (m.user1_id = auth.uid() OR m.user2_id = auth.uid())
    )
  );

-- =============================================================================
-- call_decisions  (post-call feedback)
-- =============================================================================
CREATE TABLE public.call_decisions (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  video_session_id UUID REFERENCES public.video_sessions(id) ON DELETE CASCADE NOT NULL,
  user_id          UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  enjoyed          BOOLEAN NOT NULL,
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(video_session_id, user_id)
);

ALTER TABLE public.call_decisions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "call_decisions_select" ON public.call_decisions
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.video_sessions vs
      JOIN public.matches m ON m.id = vs.match_id
      WHERE vs.id = call_decisions.video_session_id
        AND (m.user1_id = auth.uid() OR m.user2_id = auth.uid())
    )
  );

CREATE POLICY "call_decisions_insert" ON public.call_decisions
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

-- =============================================================================
-- noble_tables  (Social mode — group events)
-- =============================================================================
CREATE TABLE public.noble_tables (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  host_id             UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  title               TEXT NOT NULL,
  table_goal          TEXT,
  event_tag           TEXT NOT NULL DEFAULT 'Dinner',
  event_emoji         TEXT DEFAULT '🍷',
  max_participants    INTEGER NOT NULL DEFAULT 4 CHECK (max_participants >= 2 AND max_participants <= 12),
  location_name       TEXT,
  location            GEOGRAPHY(POINT, 4326),
  discussion_topics   TEXT[] DEFAULT '{}',
  is_live             BOOLEAN DEFAULT TRUE,
  starts_at           TIMESTAMPTZ,
  created_at          TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.noble_tables ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tables_select" ON public.noble_tables
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "tables_insert" ON public.noble_tables
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = host_id);

CREATE POLICY "tables_update" ON public.noble_tables
  FOR UPDATE TO authenticated
  USING (auth.uid() = host_id) WITH CHECK (auth.uid() = host_id);

-- =============================================================================
-- table_participants
-- =============================================================================
CREATE TABLE public.table_participants (
  table_id    UUID REFERENCES public.noble_tables(id) ON DELETE CASCADE,
  user_id     UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at   TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (table_id, user_id)
);

ALTER TABLE public.table_participants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "table_participants_select" ON public.table_participants
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "table_participants_insert" ON public.table_participants
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

CREATE POLICY "table_participants_delete" ON public.table_participants
  FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- =============================================================================
-- conversations
-- =============================================================================
CREATE TABLE public.conversations (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type            TEXT NOT NULL CHECK (type IN ('alliance', 'circle')),
  mode            TEXT NOT NULL DEFAULT 'date' CHECK (mode IN ('date', 'bff', 'social')),
  table_id        UUID REFERENCES public.noble_tables(id) ON DELETE SET NULL,
  expires_at      TIMESTAMPTZ,  -- set for alliance chats (+5 days from creation)
  last_message_at TIMESTAMPTZ DEFAULT NOW(),
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "conversations_select" ON public.conversations
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.conversation_participants cp
      WHERE cp.conversation_id = conversations.id
        AND cp.user_id = auth.uid()
    )
  );

CREATE POLICY "conversations_insert" ON public.conversations
  FOR INSERT TO authenticated WITH CHECK (true);

-- =============================================================================
-- conversation_participants
-- =============================================================================
CREATE TABLE public.conversation_participants (
  conversation_id UUID REFERENCES public.conversations(id) ON DELETE CASCADE,
  user_id         UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at       TIMESTAMPTZ DEFAULT NOW(),
  last_read_at    TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (conversation_id, user_id)
);

ALTER TABLE public.conversation_participants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "conv_participants_select" ON public.conversation_participants
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.conversation_participants cp2
      WHERE cp2.conversation_id = conversation_participants.conversation_id
        AND cp2.user_id = auth.uid()
    )
  );

CREATE POLICY "conv_participants_insert" ON public.conversation_participants
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

CREATE POLICY "conv_participants_update" ON public.conversation_participants
  FOR UPDATE TO authenticated USING (auth.uid() = user_id);

-- =============================================================================
-- messages
-- =============================================================================
CREATE TABLE public.messages (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id      UUID REFERENCES public.conversations(id) ON DELETE CASCADE NOT NULL,
  sender_id            UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  sender_display_name  TEXT,
  content              TEXT NOT NULL CHECK (char_length(content) > 0),
  mode                 TEXT DEFAULT 'date' CHECK (mode IN ('date', 'bff', 'social')),
  is_system            BOOLEAN DEFAULT FALSE,
  created_at           TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "messages_select" ON public.messages
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.conversation_participants cp
      WHERE cp.conversation_id = messages.conversation_id
        AND cp.user_id = auth.uid()
    )
  );

CREATE POLICY "messages_insert" ON public.messages
  FOR INSERT TO authenticated
  WITH CHECK (
    (is_system = TRUE OR auth.uid() = sender_id) AND
    EXISTS (
      SELECT 1 FROM public.conversation_participants cp
      WHERE cp.conversation_id = messages.conversation_id
        AND cp.user_id = auth.uid()
    )
  );

-- =============================================================================
-- real_meetings  (in-person meetup scheduling)
-- =============================================================================
CREATE TABLE public.real_meetings (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id      UUID REFERENCES public.matches(id) ON DELETE CASCADE NOT NULL,
  proposed_by   UUID REFERENCES auth.users(id) NOT NULL,
  scheduled_at  TIMESTAMPTZ NOT NULL,
  location_text TEXT,
  status        TEXT NOT NULL DEFAULT 'proposed'
                CHECK (status IN ('proposed', 'confirmed', 'completed', 'cancelled')),
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.real_meetings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "real_meetings_select" ON public.real_meetings
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.matches m
      WHERE m.id = real_meetings.match_id
        AND (m.user1_id = auth.uid() OR m.user2_id = auth.uid())
    )
  );

CREATE POLICY "real_meetings_insert" ON public.real_meetings
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = proposed_by);

CREATE POLICY "real_meetings_update" ON public.real_meetings
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.matches m
      WHERE m.id = real_meetings.match_id
        AND (m.user1_id = auth.uid() OR m.user2_id = auth.uid())
    )
  );

-- =============================================================================
-- notifications
-- =============================================================================
CREATE TABLE public.notifications (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  type        TEXT NOT NULL,
  -- Types: new_match | video_proposed | video_confirmed | video_starting |
  --        call_decision_needed | chat_opened | chat_expiring_24h |
  --        meeting_proposed | meeting_confirmed | queue_admitted
  title       TEXT NOT NULL,
  body        TEXT NOT NULL,
  data        JSONB,
  read_at     TIMESTAMPTZ,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notifications_select" ON public.notifications
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "notifications_insert" ON public.notifications
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "notifications_update" ON public.notifications
  FOR UPDATE TO authenticated USING (auth.uid() = user_id);

-- =============================================================================
-- Realtime publications
-- =============================================================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.conversation_participants;
ALTER PUBLICATION supabase_realtime ADD TABLE public.matches;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.video_sessions;

-- =============================================================================
-- Indexes
-- =============================================================================
CREATE INDEX profiles_user_id_idx      ON public.profiles(user_id);
CREATE INDEX profiles_location_idx     ON public.profiles USING GIST(location);
CREATE INDEX profiles_mode_idx         ON public.profiles(mode);
CREATE INDEX profiles_gender_idx       ON public.profiles(gender);
CREATE INDEX swipes_swiper_idx         ON public.swipes(swiper_id);
CREATE INDEX swipes_target_idx         ON public.swipes(target_id);
CREATE INDEX swipes_direction_idx      ON public.swipes(direction);
CREATE INDEX matches_user1_idx         ON public.matches(user1_id);
CREATE INDEX matches_user2_idx         ON public.matches(user2_id);
CREATE INDEX matches_status_idx        ON public.matches(status);
CREATE INDEX video_sessions_match_idx  ON public.video_sessions(match_id);
CREATE INDEX video_sessions_sched_idx  ON public.video_sessions(scheduled_at);
CREATE INDEX messages_conv_id_idx      ON public.messages(conversation_id);
CREATE INDEX messages_created_at_idx   ON public.messages(created_at DESC);
CREATE INDEX noble_tables_host_idx     ON public.noble_tables(host_id);
CREATE INDEX noble_tables_live_idx     ON public.noble_tables(is_live) WHERE is_live = TRUE;
CREATE INDEX noble_tables_loc_idx      ON public.noble_tables USING GIST(location);
CREATE INDEX notifications_user_idx    ON public.notifications(user_id);
CREATE INDEX notifications_read_idx    ON public.notifications(read_at) WHERE read_at IS NULL;
CREATE INDEX photo_verif_user_idx      ON public.photo_verifications(user_id);
CREATE INDEX gender_queue_status_idx   ON public.gender_queue(status, gender);

-- =============================================================================
-- Triggers
-- =============================================================================

-- Trigger: new user → create profile + gating_status
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (user_id, display_name)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', ''))
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO public.gating_status (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Trigger: auto-set is_verified when both selfie_verified and photos_verified become true
CREATE OR REPLACE FUNCTION public.sync_is_verified()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.selfie_verified = TRUE AND NEW.photos_verified = TRUE THEN
    NEW.is_verified := TRUE;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER profiles_sync_is_verified
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.sync_is_verified();

-- Trigger: updated_at
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$;

CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER gating_updated_at
  BEFORE UPDATE ON public.gating_status
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Trigger: update conversations.last_message_at
CREATE OR REPLACE FUNCTION public.update_last_message_at()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.conversations SET last_message_at = NEW.created_at WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_new_message
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.update_last_message_at();

-- Function: detect mutual match after swipe
-- Returns the match record if both users liked each other, NULL otherwise
CREATE OR REPLACE FUNCTION public.check_and_create_match(
  p_swiper UUID,
  p_target UUID,
  p_mode   TEXT
)
RETURNS public.matches LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_match public.matches;
BEGIN
  -- Check if target already swiped right on swiper in same mode
  IF EXISTS (
    SELECT 1 FROM public.swipes
    WHERE swiper_id = p_target
      AND target_id = p_swiper
      AND direction IN ('right', 'super')
      AND mode = p_mode
  ) THEN
    -- Create match (smaller UUID first to enforce uniqueness)
    INSERT INTO public.matches (user1_id, user2_id, mode)
    VALUES (
      LEAST(p_swiper, p_target),
      GREATEST(p_swiper, p_target),
      p_mode
    )
    ON CONFLICT (user1_id, user2_id, mode) DO NOTHING
    RETURNING * INTO v_match;

    -- Notify both users
    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES
      (p_swiper, 'new_match', 'New Match!',
       'You have a new match. Schedule a video call within 12 hours.',
       jsonb_build_object('match_id', v_match.id, 'mode', p_mode)),
      (p_target, 'new_match', 'New Match!',
       'You have a new match. Schedule a video call within 12 hours.',
       jsonb_build_object('match_id', v_match.id, 'mode', p_mode));
  END IF;

  RETURN v_match;
END;
$$;

-- Function: open chat after both call decisions are positive
CREATE OR REPLACE FUNCTION public.process_call_decision(
  p_video_session_id UUID,
  p_user_id          UUID,
  p_enjoyed          BOOLEAN
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_match     public.matches;
  v_session   public.video_sessions;
  v_conv_id   UUID;
  v_decisions INTEGER;
  v_yes_count INTEGER;
BEGIN
  -- Get session + match
  SELECT vs.*, m.* INTO v_session
  FROM public.video_sessions vs
  JOIN public.matches m ON m.id = vs.match_id
  WHERE vs.id = p_video_session_id;

  SELECT * INTO v_match FROM public.matches WHERE id = v_session.match_id;

  -- Count total decisions for this session
  SELECT COUNT(*), COUNT(*) FILTER (WHERE enjoyed = TRUE)
  INTO v_decisions, v_yes_count
  FROM public.call_decisions
  WHERE video_session_id = p_video_session_id;

  -- Add current decision (+1 because we just inserted before calling this)
  v_decisions := v_decisions + 1;
  IF p_enjoyed THEN v_yes_count := v_yes_count + 1; END IF;

  -- Both decisions received
  IF v_decisions >= 2 THEN
    IF v_yes_count = 2 THEN
      -- Both said yes → open chat
      INSERT INTO public.conversations (type, mode, expires_at)
      VALUES (
        'alliance',
        v_match.mode,
        NOW() + INTERVAL '5 days'
      )
      RETURNING id INTO v_conv_id;

      INSERT INTO public.conversation_participants (conversation_id, user_id)
      VALUES (v_conv_id, v_match.user1_id), (v_conv_id, v_match.user2_id);

      UPDATE public.matches
      SET status = 'chatting',
          chat_expires_at = NOW() + INTERVAL '5 days',
          conversation_id = v_conv_id
      WHERE id = v_match.id;

      -- Notify both
      INSERT INTO public.notifications (user_id, type, title, body, data)
      VALUES
        (v_match.user1_id, 'chat_opened', 'Chat is open!',
         'You both enjoyed the call. Start chatting — you have 5 days.',
         jsonb_build_object('match_id', v_match.id, 'conversation_id', v_conv_id)),
        (v_match.user2_id, 'chat_opened', 'Chat is open!',
         'You both enjoyed the call. Start chatting — you have 5 days.',
         jsonb_build_object('match_id', v_match.id, 'conversation_id', v_conv_id));

      RETURN jsonb_build_object('result', 'chat_opened', 'conversation_id', v_conv_id);
    ELSE
      -- At least one said no → expire match
      UPDATE public.matches SET status = 'expired' WHERE id = v_match.id;
      RETURN jsonb_build_object('result', 'expired');
    END IF;
  END IF;

  RETURN jsonb_build_object('result', 'waiting');
END;
$$;

-- =============================================================================
-- Storage buckets
-- =============================================================================
INSERT INTO storage.buckets (id, name, public)
VALUES
  ('avatars',       'avatars',       true),
  ('galleries',     'galleries',     true),
  ('selfies',       'selfies',       false),  -- private, only for verification
  ('verifications', 'verifications', false)   -- private, only for admin review
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "avatars_public_read" ON storage.objects
  FOR SELECT TO public USING (bucket_id = 'avatars');

CREATE POLICY "avatars_auth_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "avatars_auth_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "galleries_public_read" ON storage.objects
  FOR SELECT TO public USING (bucket_id = 'galleries');

CREATE POLICY "galleries_auth_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'galleries' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "selfies_auth_read" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'selfies' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "selfies_auth_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'selfies' AND auth.uid()::text = (storage.foldername(name))[1]);

-- =============================================================================
-- Seed: gender queue balance function
-- =============================================================================
CREATE OR REPLACE FUNCTION public.admit_from_queue()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_male_count   INTEGER;
  v_female_count INTEGER;
  v_admit_count  INTEGER;
  v_user         RECORD;
BEGIN
  SELECT COUNT(*) INTO v_male_count
  FROM public.gating_status
  JOIN public.profiles p ON p.user_id = gating_status.user_id
  WHERE is_entry_approved = TRUE AND p.gender = 'male';

  SELECT COUNT(*) INTO v_female_count
  FROM public.gating_status
  JOIN public.profiles p ON p.user_id = gating_status.user_id
  WHERE is_entry_approved = TRUE AND p.gender = 'female';

  -- Admit waiting users of the minority gender (up to 5 at a time)
  IF v_male_count < v_female_count THEN
    FOR v_user IN
      SELECT user_id FROM public.gender_queue
      WHERE gender = 'male' AND status = 'waiting'
      ORDER BY joined_at LIMIT 5
    LOOP
      UPDATE public.gender_queue
      SET status = 'admitted', admitted_at = NOW()
      WHERE user_id = v_user.user_id;

      UPDATE public.gating_status
      SET is_entry_approved = TRUE
      WHERE user_id = v_user.user_id;

      INSERT INTO public.notifications (user_id, type, title, body)
      VALUES (v_user.user_id, 'queue_admitted', 'You''re in!',
              'Your access has been approved. Welcome to Noblara.');
    END LOOP;
  ELSIF v_female_count < v_male_count THEN
    FOR v_user IN
      SELECT user_id FROM public.gender_queue
      WHERE gender = 'female' AND status = 'waiting'
      ORDER BY joined_at LIMIT 5
    LOOP
      UPDATE public.gender_queue
      SET status = 'admitted', admitted_at = NOW()
      WHERE user_id = v_user.user_id;

      UPDATE public.gating_status
      SET is_entry_approved = TRUE
      WHERE user_id = v_user.user_id;

      INSERT INTO public.notifications (user_id, type, title, body)
      VALUES (v_user.user_id, 'queue_admitted', 'You''re in!',
              'Your access has been approved. Welcome to Noblara.');
    END LOOP;
  END IF;
END;
$$;

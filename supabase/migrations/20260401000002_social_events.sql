-- =============================================================================
-- SOCIAL MODE: Events system with chat, flagging, attendance, purge
-- Created: 2026-04-01
-- =============================================================================

-- ═══════════════════════════════════════════════════════════════════
-- 1. EVENTS TABLE
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.events (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  host_id           UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  title             TEXT NOT NULL,
  description       TEXT,
  cover_image_url   TEXT,
  event_date        TIMESTAMPTZ NOT NULL,
  location_text     TEXT,
  location_lat      DOUBLE PRECISION,
  location_lng      DOUBLE PRECISION,
  max_attendees     INT NOT NULL DEFAULT 10,
  plus3_enabled     BOOLEAN NOT NULL DEFAULT FALSE,
  companion_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  status            TEXT NOT NULL DEFAULT 'active',
  quality_score     INT NOT NULL DEFAULT 50,
  attendee_count    INT NOT NULL DEFAULT 0,
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT events_status_check CHECK (status IN ('draft', 'active', 'locked', 'deleted')),
  CONSTRAINT events_max_attendees_check CHECK (max_attendees BETWEEN 2 AND 50),
  CONSTRAINT events_quality_check CHECK (quality_score BETWEEN 0 AND 100)
);

ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "events_select" ON public.events
    FOR SELECT TO authenticated
    USING (status IN ('active', 'locked'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "events_insert" ON public.events
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = host_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "events_update" ON public.events
    FOR UPDATE TO authenticated
    USING (auth.uid() = host_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS events_host_idx ON public.events(host_id);
CREATE INDEX IF NOT EXISTS events_date_idx ON public.events(event_date);
CREATE INDEX IF NOT EXISTS events_status_idx ON public.events(status);

-- ═══════════════════════════════════════════════════════════════════
-- 2. EVENT_PARTICIPANTS TABLE
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.event_participants (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id          UUID REFERENCES public.events(id) ON DELETE CASCADE NOT NULL,
  user_id           UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  attendance_status TEXT NOT NULL DEFAULT 'going',
  companion_count   INT NOT NULL DEFAULT 0,
  joined_at         TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT ep_status_check CHECK (attendance_status IN ('going', 'maybe', 'out', 'on_my_way', 'arrived')),
  CONSTRAINT ep_companion_check CHECK (companion_count BETWEEN 0 AND 3),
  UNIQUE(event_id, user_id)
);

ALTER TABLE public.event_participants ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "ep_select" ON public.event_participants
    FOR SELECT TO authenticated USING (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "ep_insert" ON public.event_participants
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "ep_update" ON public.event_participants
    FOR UPDATE TO authenticated
    USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "ep_delete" ON public.event_participants
    FOR DELETE TO authenticated
    USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS ep_event_idx ON public.event_participants(event_id);
CREATE INDEX IF NOT EXISTS ep_user_idx ON public.event_participants(user_id);

-- ═══════════════════════════════════════════════════════════════════
-- 3. EVENT_MESSAGES TABLE
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.event_messages (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id        UUID REFERENCES public.events(id) ON DELETE CASCADE NOT NULL,
  sender_id       UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  content         TEXT NOT NULL,
  gold_flagged    BOOLEAN NOT NULL DEFAULT FALSE,
  blue_flagged    BOOLEAN NOT NULL DEFAULT FALSE,
  blue_flagged_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.event_messages ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "em_select" ON public.event_messages
    FOR SELECT TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.event_participants ep
        WHERE ep.event_id = event_messages.event_id AND ep.user_id = auth.uid()
      ) OR EXISTS (
        SELECT 1 FROM public.events e
        WHERE e.id = event_messages.event_id AND e.host_id = auth.uid()
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "em_insert" ON public.event_messages
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = sender_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS em_event_idx ON public.event_messages(event_id);
CREATE INDEX IF NOT EXISTS em_created_idx ON public.event_messages(created_at);

-- ═══════════════════════════════════════════════════════════════════
-- 4. EVENT_CHECKINS TABLE
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.event_checkins (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id        UUID REFERENCES public.events(id) ON DELETE CASCADE NOT NULL,
  user_id         UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  event_was_real  BOOLEAN,
  host_rating     BOOLEAN,
  noshow_reported BOOLEAN,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(event_id, user_id)
);

ALTER TABLE public.event_checkins ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "ec_insert" ON public.event_checkins
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "ec_select" ON public.event_checkins
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 5. RPC: Join event
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.join_event(p_event_id UUID, p_companion_count INT DEFAULT 0)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_event public.events;
  v_current INT;
BEGIN
  SELECT * INTO v_event FROM public.events WHERE id = p_event_id;
  IF v_event IS NULL OR v_event.status != 'active' THEN
    RETURN jsonb_build_object('error', 'event_not_available');
  END IF;

  SELECT COUNT(*) INTO v_current FROM public.event_participants WHERE event_id = p_event_id AND attendance_status != 'out';
  IF v_current >= v_event.max_attendees THEN
    RETURN jsonb_build_object('error', 'event_full');
  END IF;

  INSERT INTO public.event_participants (event_id, user_id, attendance_status, companion_count)
  VALUES (p_event_id, auth.uid(), 'going', p_companion_count)
  ON CONFLICT (event_id, user_id) DO UPDATE SET attendance_status = 'going', companion_count = p_companion_count;

  UPDATE public.events SET attendee_count = (
    SELECT COUNT(*) FROM public.event_participants WHERE event_id = p_event_id AND attendance_status != 'out'
  ) WHERE id = p_event_id;

  RETURN jsonb_build_object('result', 'joined');
END;
$$;

-- ═══════════════════════════════════════════════════════════════════
-- 6. RPC: Leave event
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.leave_event(p_event_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.event_participants SET attendance_status = 'out'
  WHERE event_id = p_event_id AND user_id = auth.uid();

  UPDATE public.events SET attendee_count = (
    SELECT COUNT(*) FROM public.event_participants WHERE event_id = p_event_id AND attendance_status != 'out'
  ) WHERE id = p_event_id;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════
-- 7. RPC: Flag message gold (host only)
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.flag_message_gold(p_message_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_msg public.event_messages;
BEGIN
  SELECT * INTO v_msg FROM public.event_messages WHERE id = p_message_id;
  IF NOT EXISTS (SELECT 1 FROM public.events WHERE id = v_msg.event_id AND host_id = auth.uid()) THEN
    RAISE EXCEPTION 'Only host can gold-flag';
  END IF;

  IF (SELECT COUNT(*) FROM public.event_messages WHERE event_id = v_msg.event_id AND gold_flagged = TRUE) >= 3 THEN
    RAISE EXCEPTION 'Max 3 pinned messages';
  END IF;

  UPDATE public.event_messages SET gold_flagged = TRUE WHERE id = p_message_id;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════
-- 8. RPC: Flag message blue (any attendee)
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.flag_message_blue(p_message_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.event_messages SET blue_flagged = TRUE, blue_flagged_by = auth.uid()
  WHERE id = p_message_id;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════
-- 9. RPC: Submit post-event checkin
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.submit_event_checkin(
  p_event_id UUID, p_was_real BOOLEAN, p_host_rating BOOLEAN, p_noshow BOOLEAN
)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_host UUID;
  v_delta INT;
BEGIN
  INSERT INTO public.event_checkins (event_id, user_id, event_was_real, host_rating, noshow_reported)
  VALUES (p_event_id, auth.uid(), p_was_real, p_host_rating, p_noshow)
  ON CONFLICT (event_id, user_id) DO UPDATE
  SET event_was_real = p_was_real, host_rating = p_host_rating, noshow_reported = p_noshow;

  SELECT host_id INTO v_host FROM public.events WHERE id = p_event_id;

  -- Adjust host trust
  v_delta := 0;
  IF p_was_real AND p_host_rating THEN v_delta := v_delta + 10; END IF;
  IF NOT p_was_real THEN v_delta := v_delta - 30; END IF;
  IF p_host_rating = FALSE THEN v_delta := v_delta - 5; END IF;

  IF v_delta != 0 THEN
    UPDATE public.profiles SET trust_score = GREATEST(0, LEAST(100, trust_score + v_delta))
    WHERE id = v_host;
  END IF;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════
-- 10. CRON: Lock ended events + Purge old messages
-- ═══════════════════════════════════════════════════════════════════

DO $$ BEGIN PERFORM cron.unschedule('lock-ended-events'); EXCEPTION WHEN OTHERS THEN NULL; END $$;
SELECT cron.schedule('lock-ended-events', '*/15 * * * *', $$
  UPDATE public.events SET status = 'locked'
  WHERE status = 'active' AND event_date + INTERVAL '3 hours' < NOW();
$$);

DO $$ BEGIN PERFORM cron.unschedule('purge-old-event-messages'); EXCEPTION WHEN OTHERS THEN NULL; END $$;
SELECT cron.schedule('purge-old-event-messages', '*/15 * * * *', $$
  DELETE FROM public.event_messages
  WHERE event_id IN (
    SELECT id FROM public.events WHERE event_date + INTERVAL '4 hours 10 minutes' < NOW()
  );
  UPDATE public.events SET status = 'deleted'
  WHERE status = 'locked' AND event_date + INTERVAL '4 hours 10 minutes' < NOW();
$$);

-- ═══════════════════════════════════════════════════════════════════
-- 11. Realtime
-- ═══════════════════════════════════════════════════════════════════

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'events') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.events;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'event_participants') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.event_participants;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'event_messages') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.event_messages;
  END IF;
END $$;

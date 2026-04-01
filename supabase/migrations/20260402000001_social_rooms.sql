-- ============================================================
-- Social Rooms — proximity-ranked ephemeral topic rooms
-- ============================================================

-- ── Tables ──────────────────────────────────────────────────

CREATE TABLE public.rooms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  host_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title text NOT NULL CHECK (char_length(title) BETWEEN 1 AND 60),
  description text CHECK (char_length(description) <= 100),
  room_type text NOT NULL DEFAULT 'text' CHECK (room_type IN ('text','voice','mixed')),
  topic_tags text[] DEFAULT '{}',
  max_participants int NOT NULL DEFAULT 10 CHECK (max_participants BETWEEN 5 AND 20),
  participant_count int NOT NULL DEFAULT 0,
  host_lat double precision,
  host_lng double precision,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','locked','deleted')),
  quality_score int NOT NULL DEFAULT 0,
  last_activity_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.room_participants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id uuid NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  joined_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(room_id, user_id)
);

CREATE TABLE public.room_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id uuid NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES public.profiles(id),
  content text NOT NULL,
  gold_flagged bool NOT NULL DEFAULT false,
  blue_flagged bool NOT NULL DEFAULT false,
  blue_flagged_by uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX idx_rooms_status ON public.rooms(status);
CREATE INDEX idx_rooms_host ON public.rooms(host_id);
CREATE INDEX idx_rooms_last_activity ON public.rooms(last_activity_at);
CREATE INDEX idx_room_participants_room ON public.room_participants(room_id);
CREATE INDEX idx_room_participants_user ON public.room_participants(user_id);
CREATE INDEX idx_room_messages_room ON public.room_messages(room_id);
CREATE INDEX idx_room_messages_created ON public.room_messages(created_at);

-- ── RLS ─────────────────────────────────────────────────────

ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_messages ENABLE ROW LEVEL SECURITY;

-- rooms: anyone authenticated can read active rooms and create
CREATE POLICY rooms_select ON public.rooms FOR SELECT TO authenticated
  USING (status = 'active');

CREATE POLICY rooms_insert ON public.rooms FOR INSERT TO authenticated
  WITH CHECK (host_id = auth.uid());

CREATE POLICY rooms_update ON public.rooms FOR UPDATE TO authenticated
  USING (host_id = auth.uid());

CREATE POLICY rooms_delete ON public.rooms FOR DELETE TO authenticated
  USING (host_id = auth.uid());

-- room_participants: authenticated users can see participants of active rooms,
-- insert/delete own participation
CREATE POLICY room_participants_select ON public.room_participants FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.rooms WHERE id = room_id AND status = 'active'));

CREATE POLICY room_participants_insert ON public.room_participants FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY room_participants_delete ON public.room_participants FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- room_messages: participants can read and insert messages
CREATE POLICY room_messages_select ON public.room_messages FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.room_participants
    WHERE room_id = room_messages.room_id AND user_id = auth.uid()
  ));

CREATE POLICY room_messages_insert ON public.room_messages FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.room_participants
      WHERE room_id = room_messages.room_id AND user_id = auth.uid()
    )
  );

-- ── RPC Functions ───────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.join_room(p_room_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_status text;
  v_count int;
  v_max int;
BEGIN
  SELECT status, participant_count, max_participants
    INTO v_status, v_count, v_max
    FROM public.rooms WHERE id = p_room_id FOR UPDATE;

  IF v_status IS NULL THEN RETURN 'room_not_found'; END IF;
  IF v_status <> 'active' THEN RETURN 'room_closed'; END IF;
  IF v_count >= v_max THEN RETURN 'room_full'; END IF;

  INSERT INTO public.room_participants (room_id, user_id)
    VALUES (p_room_id, auth.uid())
    ON CONFLICT (room_id, user_id) DO NOTHING;

  RETURN 'joined';
END;
$$;

CREATE OR REPLACE FUNCTION public.leave_room(p_room_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_host uuid;
  v_remaining int;
BEGIN
  DELETE FROM public.room_participants
    WHERE room_id = p_room_id AND user_id = auth.uid();

  SELECT host_id INTO v_host FROM public.rooms WHERE id = p_room_id;

  SELECT COUNT(*) INTO v_remaining
    FROM public.room_participants WHERE room_id = p_room_id;

  -- If host left and nobody remains, lock the room
  IF auth.uid() = v_host AND v_remaining = 0 THEN
    UPDATE public.rooms SET status = 'locked' WHERE id = p_room_id;
  END IF;

  RETURN 'left';
END;
$$;

CREATE OR REPLACE FUNCTION public.flag_room_message_gold(p_message_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_room_id uuid;
  v_host_id uuid;
  v_gold_count int;
BEGIN
  SELECT room_id INTO v_room_id FROM public.room_messages WHERE id = p_message_id;
  IF v_room_id IS NULL THEN RETURN 'message_not_found'; END IF;

  SELECT host_id INTO v_host_id FROM public.rooms WHERE id = v_room_id;
  IF v_host_id <> auth.uid() THEN RETURN 'not_host'; END IF;

  SELECT COUNT(*) INTO v_gold_count
    FROM public.room_messages WHERE room_id = v_room_id AND gold_flagged = true;
  IF v_gold_count >= 3 THEN RETURN 'max_gold_reached'; END IF;

  UPDATE public.room_messages SET gold_flagged = true WHERE id = p_message_id;
  RETURN 'flagged';
END;
$$;

CREATE OR REPLACE FUNCTION public.flag_room_message_blue(p_message_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.room_messages
    SET blue_flagged = true, blue_flagged_by = auth.uid()
    WHERE id = p_message_id;
  RETURN 'flagged';
END;
$$;

CREATE OR REPLACE FUNCTION public.close_inactive_rooms()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- Lock rooms inactive for 24h
  UPDATE public.rooms
    SET status = 'locked'
    WHERE status = 'active'
      AND last_activity_at < now() - interval '24 hours';

  -- Delete messages from locked rooms older than 25h
  DELETE FROM public.room_messages
    WHERE room_id IN (
      SELECT id FROM public.rooms
      WHERE status = 'locked'
        AND last_activity_at < now() - interval '25 hours'
    );

  -- Mark old locked rooms as deleted
  UPDATE public.rooms
    SET status = 'deleted'
    WHERE status = 'locked'
      AND last_activity_at < now() - interval '25 hours';
END;
$$;

-- ── Triggers ────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.trg_room_participant_insert()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.rooms SET participant_count = participant_count + 1
    WHERE id = NEW.room_id;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_room_participant_delete()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.rooms SET participant_count = GREATEST(participant_count - 1, 0)
    WHERE id = OLD.room_id;
  RETURN OLD;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_room_message_insert()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.rooms SET last_activity_at = now()
    WHERE id = NEW.room_id;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_room_participant_insert
  AFTER INSERT ON public.room_participants
  FOR EACH ROW EXECUTE FUNCTION public.trg_room_participant_insert();

CREATE TRIGGER on_room_participant_delete
  AFTER DELETE ON public.room_participants
  FOR EACH ROW EXECUTE FUNCTION public.trg_room_participant_delete();

CREATE TRIGGER on_room_message_insert
  AFTER INSERT ON public.room_messages
  FOR EACH ROW EXECUTE FUNCTION public.trg_room_message_insert();

-- ── Cron (requires pg_cron extension) ───────────────────────
-- Run close_inactive_rooms every hour
SELECT cron.schedule(
  'close-inactive-rooms',
  '0 * * * *',
  $$SELECT public.close_inactive_rooms()$$
);

-- ── Realtime ────────────────────────────────────────────────
ALTER PUBLICATION supabase_realtime ADD TABLE public.room_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.room_participants;

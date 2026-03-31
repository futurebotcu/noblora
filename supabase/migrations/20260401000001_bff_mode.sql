-- =============================================================================
-- BFF MODE: AI Suggestions, Reach Outs, Plan system
-- Created: 2026-04-01
-- =============================================================================

-- ═══════════════════════════════════════════════════════════════════
-- 1. BFF_SUGGESTIONS TABLE
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.bff_suggestions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_a_id     UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  user_b_id     UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  common_ground JSONB NOT NULL DEFAULT '[]'::jsonb,
  status        TEXT NOT NULL DEFAULT 'pending',
  user_a_action TEXT,
  user_b_action TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  expires_at    TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '48 hours'),
  CONSTRAINT bff_suggestions_status_check CHECK (status IN ('pending', 'connected', 'passed', 'expired')),
  CONSTRAINT bff_suggestions_action_check CHECK (
    (user_a_action IS NULL OR user_a_action IN ('connect', 'pass')) AND
    (user_b_action IS NULL OR user_b_action IN ('connect', 'pass'))
  ),
  UNIQUE(user_a_id, user_b_id)
);

ALTER TABLE public.bff_suggestions ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "bff_suggestions_select" ON public.bff_suggestions
    FOR SELECT TO authenticated
    USING (auth.uid() = user_a_id OR auth.uid() = user_b_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "bff_suggestions_update" ON public.bff_suggestions
    FOR UPDATE TO authenticated
    USING (auth.uid() = user_a_id OR auth.uid() = user_b_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS bff_suggestions_user_a_idx ON public.bff_suggestions(user_a_id);
CREATE INDEX IF NOT EXISTS bff_suggestions_user_b_idx ON public.bff_suggestions(user_b_id);
CREATE INDEX IF NOT EXISTS bff_suggestions_status_idx ON public.bff_suggestions(status);

-- ═══════════════════════════════════════════════════════════════════
-- 2. REACH_OUTS TABLE
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.reach_outs (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id   UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  receiver_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  mode        TEXT NOT NULL DEFAULT 'bff',
  status      TEXT NOT NULL DEFAULT 'pending',
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT reach_outs_status_check CHECK (status IN ('pending', 'connected', 'ignored', 'expired')),
  UNIQUE(sender_id, receiver_id, mode)
);

ALTER TABLE public.reach_outs ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "reach_outs_select" ON public.reach_outs
    FOR SELECT TO authenticated
    USING (auth.uid() = sender_id OR auth.uid() = receiver_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "reach_outs_insert" ON public.reach_outs
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = sender_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "reach_outs_update" ON public.reach_outs
    FOR UPDATE TO authenticated
    USING (auth.uid() = receiver_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS reach_outs_sender_idx ON public.reach_outs(sender_id);
CREATE INDEX IF NOT EXISTS reach_outs_receiver_idx ON public.reach_outs(receiver_id);

-- ═══════════════════════════════════════════════════════════════════
-- 3. BFF_PLANS TABLE
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.bff_plans (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID REFERENCES public.conversations(id) ON DELETE CASCADE NOT NULL,
  created_by      UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  plan_type       TEXT NOT NULL,
  location        TEXT,
  scheduled_at    TIMESTAMPTZ NOT NULL,
  status          TEXT NOT NULL DEFAULT 'proposed',
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT bff_plans_type_check CHECK (plan_type IN ('coffee', 'walk', 'cowork', 'culture', 'city')),
  CONSTRAINT bff_plans_status_check CHECK (status IN ('proposed', 'accepted', 'declined', 'completed', 'cancelled'))
);

ALTER TABLE public.bff_plans ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "bff_plans_select" ON public.bff_plans
    FOR SELECT TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.conversation_participants cp
        WHERE cp.conversation_id = bff_plans.conversation_id
          AND cp.user_id = auth.uid()
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "bff_plans_insert" ON public.bff_plans
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = created_by);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "bff_plans_update" ON public.bff_plans
    FOR UPDATE TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.conversation_participants cp
        WHERE cp.conversation_id = bff_plans.conversation_id
          AND cp.user_id = auth.uid()
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS bff_plans_conv_idx ON public.bff_plans(conversation_id);

-- ═══════════════════════════════════════════════════════════════════
-- 4. PROFILES: Add BFF usage limit columns
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS daily_bff_suggestions_used INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS daily_bff_suggestions_reset TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS weekly_reach_outs_used INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS weekly_reach_outs_reset TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS daily_reach_outs_used INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS daily_reach_outs_reset TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- ═══════════════════════════════════════════════════════════════════
-- 5. RPC: Check BFF suggestion limit
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.check_bff_suggestion_limit(p_user_id UUID)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tier  TEXT;
  v_used  INT;
  v_reset TIMESTAMPTZ;
  v_limit INT;
BEGIN
  SELECT nob_tier, daily_bff_suggestions_used, daily_bff_suggestions_reset
  INTO v_tier, v_used, v_reset
  FROM public.profiles WHERE id = p_user_id;

  IF v_tier IS NULL THEN RETURN FALSE; END IF;

  IF v_reset < NOW() - INTERVAL '1 day' THEN
    v_used := 0;
    UPDATE public.profiles SET daily_bff_suggestions_used = 0, daily_bff_suggestions_reset = NOW() WHERE id = p_user_id;
  END IF;

  v_limit := CASE v_tier
    WHEN 'observer' THEN 1
    WHEN 'explorer' THEN 3
    WHEN 'noble'    THEN 5
    ELSE 1
  END;

  RETURN v_used < v_limit;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════
-- 6. RPC: Check Reach Out limit
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.check_reach_out_limit(p_user_id UUID)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tier         TEXT;
  v_weekly       INT;
  v_daily        INT;
  v_weekly_reset TIMESTAMPTZ;
  v_daily_reset  TIMESTAMPTZ;
BEGIN
  SELECT nob_tier, weekly_reach_outs_used, weekly_reach_outs_reset,
         daily_reach_outs_used, daily_reach_outs_reset
  INTO v_tier, v_weekly, v_weekly_reset, v_daily, v_daily_reset
  FROM public.profiles WHERE id = p_user_id;

  IF v_tier IS NULL THEN RETURN FALSE; END IF;

  IF v_weekly_reset < NOW() - INTERVAL '7 days' THEN
    v_weekly := 0;
    UPDATE public.profiles SET weekly_reach_outs_used = 0, weekly_reach_outs_reset = NOW() WHERE id = p_user_id;
  END IF;
  IF v_daily_reset < NOW() - INTERVAL '1 day' THEN
    v_daily := 0;
    UPDATE public.profiles SET daily_reach_outs_used = 0, daily_reach_outs_reset = NOW() WHERE id = p_user_id;
  END IF;

  IF v_tier = 'observer' THEN RETURN v_weekly < 1; END IF;
  IF v_tier = 'explorer' THEN RETURN v_weekly < 3; END IF;
  IF v_tier = 'noble' THEN RETURN v_daily < 1; END IF;

  RETURN FALSE;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════
-- 7. RPC: Process BFF suggestion action
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.process_bff_action(
  p_suggestion_id UUID,
  p_user_id UUID,
  p_action TEXT  -- 'connect' or 'pass'
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_sug   public.bff_suggestions;
  v_other UUID;
  v_conv  UUID;
BEGIN
  SELECT * INTO v_sug FROM public.bff_suggestions WHERE id = p_suggestion_id;
  IF v_sug IS NULL THEN RETURN jsonb_build_object('error', 'not_found'); END IF;

  -- Update the correct user's action
  IF p_user_id = v_sug.user_a_id THEN
    UPDATE public.bff_suggestions SET user_a_action = p_action WHERE id = p_suggestion_id;
    v_sug.user_a_action := p_action;
  ELSIF p_user_id = v_sug.user_b_id THEN
    UPDATE public.bff_suggestions SET user_b_action = p_action WHERE id = p_suggestion_id;
    v_sug.user_b_action := p_action;
  ELSE
    RETURN jsonb_build_object('error', 'unauthorized');
  END IF;

  -- If either passes → close
  IF p_action = 'pass' THEN
    UPDATE public.bff_suggestions SET status = 'passed' WHERE id = p_suggestion_id;
    RETURN jsonb_build_object('result', 'passed');
  END IF;

  -- If both connected → open chat
  IF v_sug.user_a_action = 'connect' AND v_sug.user_b_action = 'connect' THEN
    INSERT INTO public.conversations (type, mode)
    VALUES ('alliance', 'bff')
    RETURNING id INTO v_conv;

    INSERT INTO public.conversation_participants (conversation_id, user_id)
    VALUES (v_conv, v_sug.user_a_id), (v_conv, v_sug.user_b_id);

    INSERT INTO public.matches (user1_id, user2_id, mode, status, conversation_id)
    VALUES (v_sug.user_a_id, v_sug.user_b_id, 'bff', 'chatting', v_conv);

    UPDATE public.bff_suggestions SET status = 'connected' WHERE id = p_suggestion_id;

    v_other := CASE WHEN p_user_id = v_sug.user_a_id THEN v_sug.user_b_id ELSE v_sug.user_a_id END;

    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES
      (v_sug.user_a_id, 'bff_connected', 'New BFF Connection!',
       'You both chose to connect. Start chatting!',
       jsonb_build_object('conversation_id', v_conv)),
      (v_sug.user_b_id, 'bff_connected', 'New BFF Connection!',
       'You both chose to connect. Start chatting!',
       jsonb_build_object('conversation_id', v_conv));

    RETURN jsonb_build_object('result', 'connected', 'conversation_id', v_conv);
  END IF;

  RETURN jsonb_build_object('result', 'waiting');
END;
$$;

-- ═══════════════════════════════════════════════════════════════════
-- 8. Expire stale BFF suggestions (cron)
-- ═══════════════════════════════════════════════════════════════════

DO $$ BEGIN
  PERFORM cron.unschedule('expire-bff-suggestions');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

SELECT cron.schedule('expire-bff-suggestions', '0 */6 * * *', $$
  UPDATE public.bff_suggestions
  SET status = 'expired'
  WHERE status = 'pending' AND expires_at < NOW();
$$);

-- ═══════════════════════════════════════════════════════════════════
-- 9. Realtime
-- ═══════════════════════════════════════════════════════════════════

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'bff_suggestions') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.bff_suggestions;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'reach_outs') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.reach_outs;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'bff_plans') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.bff_plans;
  END IF;
END $$;

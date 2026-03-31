-- =============================================================================
-- PRODUCTION HARDENING: Lifestyle columns, filter support, settings, cleanup
-- =============================================================================

-- ═══════════════════════════════════════════════════════════════════
-- 1. PROFILES: Lifestyle columns for filter matching
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS drinks          TEXT,
  ADD COLUMN IF NOT EXISTS smokes          TEXT,
  ADD COLUMN IF NOT EXISTS nightlife       TEXT,
  ADD COLUMN IF NOT EXISTS social_energy   TEXT,
  ADD COLUMN IF NOT EXISTS routine         TEXT,
  ADD COLUMN IF NOT EXISTS faith_sensitivity TEXT,
  ADD COLUMN IF NOT EXISTS looking_for     TEXT,
  ADD COLUMN IF NOT EXISTS bff_looking_for TEXT,
  ADD COLUMN IF NOT EXISTS hobbies         TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS prompts_answered INT NOT NULL DEFAULT 0;

-- ═══════════════════════════════════════════════════════════════════
-- 2. PROFILES: Settings columns
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_paused          BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS dating_active      BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS dating_visible     BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS bff_active         BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS bff_visible        BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS social_active      BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS social_visible     BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS incognito_mode     BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS calm_mode          BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS show_city_only     BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS hide_exact_distance BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS reach_permission   TEXT NOT NULL DEFAULT 'everyone',
  ADD COLUMN IF NOT EXISTS signal_permission  TEXT NOT NULL DEFAULT 'everyone',
  ADD COLUMN IF NOT EXISTS note_permission    TEXT NOT NULL DEFAULT 'everyone',
  ADD COLUMN IF NOT EXISTS show_last_active   BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS show_status_badge  BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS travel_mode        BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS travel_city        TEXT,
  ADD COLUMN IF NOT EXISTS message_preview    BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS auto_save_media    BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS leave_event_chat_auto BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS ai_writing_help    JSONB NOT NULL DEFAULT '{"nob_cleanup":true,"bio_cleanup":true,"event_cleanup":true,"message_softening":true}'::jsonb,
  ADD COLUMN IF NOT EXISTS ai_suggestions     JSONB NOT NULL DEFAULT '{"bff_explanations":true,"event_recommendations":true,"profile_resonance":true,"filter_suggestions":true}'::jsonb,
  ADD COLUMN IF NOT EXISTS ai_insights        JSONB NOT NULL DEFAULT '{"show_resonance":true,"show_standout":true,"show_performance":true}'::jsonb;

-- ═══════════════════════════════════════════════════════════════════
-- 3. RPC: Count profiles matching filters (for oracle counter)
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.count_filtered_profiles(
  p_user_id UUID,
  p_mode TEXT,
  p_age_min INT DEFAULT 18,
  p_age_max INT DEFAULT 65,
  p_verified_only BOOLEAN DEFAULT FALSE,
  p_complete_only BOOLEAN DEFAULT FALSE,
  p_tier_filter TEXT DEFAULT NULL
)
RETURNS INT LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_count INT;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM public.profiles p
  JOIN public.gating_status g ON g.user_id = p.id
  WHERE p.id != p_user_id
    AND g.is_entry_approved = TRUE
    AND p.is_verified = TRUE
    AND p.active_modes @> ARRAY[p_mode]
    AND (p.age IS NULL OR (p.age >= p_age_min AND p.age <= p_age_max))
    AND (NOT p_verified_only OR p.is_verified = TRUE)
    AND (NOT p_complete_only OR p.is_onboarded = TRUE)
    AND (p_tier_filter IS NULL OR p.nob_tier = p_tier_filter);

  RETURN v_count;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════
-- 4. RPC: Generate BFF suggestions (real, not mock)
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.generate_bff_suggestions(p_user_id UUID)
RETURNS INT LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_profile public.profiles;
  v_candidate RECORD;
  v_count INT := 0;
  v_limit INT;
  v_tier TEXT;
BEGIN
  SELECT * INTO v_profile FROM public.profiles WHERE id = p_user_id;
  IF v_profile IS NULL THEN RETURN 0; END IF;

  v_tier := COALESCE(v_profile.nob_tier, 'observer');
  v_limit := CASE v_tier WHEN 'observer' THEN 1 WHEN 'explorer' THEN 3 WHEN 'noble' THEN 5 ELSE 1 END;

  -- Check daily limit
  IF v_profile.daily_bff_suggestions_used >= v_limit THEN RETURN 0; END IF;

  -- Find compatible users not already suggested
  FOR v_candidate IN
    SELECT p.id, p.city, p.bio, p.social_energy, p.routine
    FROM public.profiles p
    JOIN public.gating_status g ON g.user_id = p.id
    WHERE p.id != p_user_id
      AND g.is_entry_approved = TRUE
      AND p.is_verified = TRUE
      AND p.active_modes @> ARRAY['bff']
      AND p.is_paused = FALSE
      AND NOT EXISTS (
        SELECT 1 FROM public.bff_suggestions bs
        WHERE (bs.user_a_id = p_user_id AND bs.user_b_id = p.id)
           OR (bs.user_a_id = p.id AND bs.user_b_id = p_user_id)
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.matches m
        WHERE ((m.user1_id = p_user_id AND m.user2_id = p.id)
            OR (m.user1_id = p.id AND m.user2_id = p_user_id))
          AND m.mode = 'bff'
          AND m.status NOT IN ('expired', 'closed')
      )
    ORDER BY
      -- Same city first
      (CASE WHEN p.city = v_profile.city THEN 0 ELSE 1 END),
      p.maturity_score DESC
    LIMIT (v_limit - v_profile.daily_bff_suggestions_used)
  LOOP
    INSERT INTO public.bff_suggestions (user_a_id, user_b_id, common_ground)
    VALUES (p_user_id, v_candidate.id, '["You might get along"]'::jsonb)
    ON CONFLICT (user_a_id, user_b_id) DO NOTHING;

    v_count := v_count + 1;
  END LOOP;

  UPDATE public.profiles
  SET daily_bff_suggestions_used = daily_bff_suggestions_used + v_count
  WHERE id = p_user_id;

  RETURN v_count;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════
-- 5. Indexes for filter queries
-- ═══════════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS profiles_age_idx ON public.profiles(age);
CREATE INDEX IF NOT EXISTS profiles_nob_tier_idx ON public.profiles(nob_tier);
CREATE INDEX IF NOT EXISTS profiles_maturity_idx ON public.profiles(maturity_score DESC);
CREATE INDEX IF NOT EXISTS profiles_is_paused_idx ON public.profiles(is_paused);

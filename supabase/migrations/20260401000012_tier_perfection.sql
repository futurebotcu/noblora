-- =============================================================================
-- TIER PERFECTION: Fix promotion notification bug, add bonus, fix decay
-- =============================================================================

-- ═══════════════════════════════════════════════════════════════════
-- 1. FIX recalculate_tiers: notify BEFORE updating tier
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.recalculate_tiers()
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_total INT;
  v_noble_cutoff INT;
  v_explorer_cutoff INT;
  v_rec RECORD;
BEGIN
  -- Recalculate all maturity scores first
  FOR v_rec IN SELECT id FROM public.profiles LOOP
    PERFORM public.calculate_maturity_score(v_rec.id);
  END LOOP;

  SELECT COUNT(*) INTO v_total FROM public.profiles;
  IF v_total = 0 THEN RETURN; END IF;

  v_noble_cutoff := GREATEST(1, CEIL(v_total * 0.10));
  v_explorer_cutoff := GREATEST(1, CEIL(v_total * 0.50));

  -- Compute new tiers
  WITH ranked AS (
    SELECT id, maturity_score,
           ROW_NUMBER() OVER (ORDER BY maturity_score DESC, vitality_score DESC, random()) AS rank
    FROM public.profiles
  ),
  new_tiers AS (
    SELECT id,
      CASE
        WHEN rank <= v_noble_cutoff THEN 'noble'
        WHEN rank <= v_explorer_cutoff THEN 'explorer'
        ELSE 'observer'
      END AS new_tier
    FROM ranked
  )
  -- Send notifications BEFORE updating (so IS DISTINCT FROM works)
  INSERT INTO public.notifications (user_id, type, title, body, data)
  SELECT nt.id, 'tier_promoted',
    CASE nt.new_tier
      WHEN 'noble' THEN 'Welcome to Noble'
      WHEN 'explorer' THEN 'You''ve reached Explorer!'
      ELSE 'Tier update'
    END,
    CASE nt.new_tier
      WHEN 'noble' THEN 'You''re in the top 10% of Noblara. Your consistency speaks for itself.'
      WHEN 'explorer' THEN 'Your profile is growing. Keep engaging to reach Noble.'
      ELSE 'Your activity has slowed. Keep engaging to maintain your tier.'
    END,
    jsonb_build_object('new_tier', nt.new_tier, 'old_tier', p.nob_tier)
  FROM new_tiers nt
  JOIN public.profiles p ON p.id = nt.id
  WHERE p.nob_tier IS DISTINCT FROM nt.new_tier
    AND (nt.new_tier IN ('noble', 'explorer') OR
         (p.nob_tier IN ('noble', 'explorer') AND nt.new_tier = 'observer'));

  -- NOW update tiers
  WITH ranked AS (
    SELECT id, maturity_score,
           ROW_NUMBER() OVER (ORDER BY maturity_score DESC, vitality_score DESC, random()) AS rank
    FROM public.profiles
  ),
  new_tiers AS (
    SELECT id,
      CASE
        WHEN rank <= v_noble_cutoff THEN 'noble'
        WHEN rank <= v_explorer_cutoff THEN 'explorer'
        ELSE 'observer'
      END AS new_tier
    FROM ranked
  )
  UPDATE public.profiles p
  SET nob_tier = nt.new_tier
  FROM new_tiers nt
  WHERE p.id = nt.id AND p.nob_tier IS DISTINCT FROM nt.new_tier;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════
-- 2. FIX calculate_maturity_score: add bonus computation
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.calculate_maturity_score(p_user_id UUID)
RETURNS DOUBLE PRECISION LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_p DOUBLE PRECISION := 0;
  v_c DOUBLE PRECISION := 0;
  v_d DOUBLE PRECISION := 0;
  v_t DOUBLE PRECISION := 0;
  v_f DOUBLE PRECISION := 50;
  v_v DOUBLE PRECISION := 0;
  v_bonus DOUBLE PRECISION := 0;
  v_profile public.profiles;
  v_tmp INT;
  v_tmp2 INT;
  v_score DOUBLE PRECISION;
BEGIN
  SELECT * INTO v_profile FROM public.profiles WHERE id = p_user_id;
  IF v_profile IS NULL THEN RETURN 0; END IF;

  -- P: Profile completeness
  IF v_profile.date_avatar_url IS NOT NULL OR v_profile.bff_avatar_url IS NOT NULL THEN v_p := v_p + 20; END IF;
  IF v_profile.bio IS NOT NULL AND char_length(v_profile.bio) > 10 THEN v_p := v_p + 20; END IF;
  IF v_profile.photos IS NOT NULL AND array_length(v_profile.photos, 1) >= 2 THEN v_p := v_p + 20; END IF;
  IF v_profile.prompts_answered >= 2 THEN v_p := v_p + 20; END IF;
  IF EXISTS (SELECT 1 FROM public.posts WHERE user_id = p_user_id AND is_pinned = TRUE) THEN v_p := v_p + 20; END IF;

  -- C: Community
  SELECT COUNT(*) INTO v_tmp FROM public.posts WHERE user_id = p_user_id AND is_draft = FALSE;
  v_c := v_c + LEAST(v_tmp, 20) * 3;
  SELECT COUNT(*) INTO v_tmp FROM public.notes WHERE sender_id = p_user_id;
  v_c := v_c + LEAST(v_tmp, 5) * 5;
  SELECT COUNT(*) INTO v_tmp FROM public.matches WHERE (user1_id = p_user_id OR user2_id = p_user_id) AND mode = 'bff' AND status = 'chatting';
  v_c := v_c + LEAST(v_tmp, 5) * 4;
  SELECT COUNT(*) INTO v_tmp FROM public.event_participants ep JOIN public.event_checkins ec ON ec.event_id = ep.event_id AND ec.user_id = ep.user_id WHERE ep.user_id = p_user_id;
  v_c := v_c + LEAST(v_tmp, 5) * 5;
  v_c := LEAST(v_c, 100);

  -- D: Depth
  SELECT COUNT(*) INTO v_tmp FROM public.conversations c
    JOIN public.conversation_participants cp ON cp.conversation_id = c.id
    WHERE cp.user_id = p_user_id
    AND (SELECT COUNT(*) FROM public.messages m WHERE m.conversation_id = c.id) > 10;
  v_d := v_d + LEAST(v_tmp, 10) * 10;
  SELECT COUNT(*) INTO v_tmp FROM public.video_sessions vs
    JOIN public.matches m ON m.id = vs.match_id
    WHERE (m.user1_id = p_user_id OR m.user2_id = p_user_id) AND vs.status = 'completed';
  v_d := v_d + LEAST(v_tmp, 8) * 8;
  SELECT COUNT(*) INTO v_tmp FROM public.real_meetings rm
    JOIN public.matches m ON m.id = rm.match_id
    WHERE (m.user1_id = p_user_id OR m.user2_id = p_user_id) AND rm.status = 'confirmed';
  v_d := v_d + LEAST(v_tmp, 5) * 15;
  v_d := LEAST(v_d, 100);

  -- T: Trust
  v_t := v_profile.trust_score;

  -- F: Follow-through
  SELECT COUNT(*) INTO v_tmp FROM public.event_participants WHERE user_id = p_user_id AND attendance_status IN ('going', 'arrived');
  SELECT COUNT(*) INTO v_tmp2 FROM public.event_checkins WHERE user_id = p_user_id;
  IF v_tmp > 0 THEN
    v_f := (v_tmp2::DOUBLE PRECISION / v_tmp * 100);
  END IF;
  v_f := GREATEST(0, LEAST(100, v_f));

  -- V: Vitality
  v_v := CASE
    WHEN v_profile.last_active_at > NOW() - INTERVAL '24 hours' THEN 100
    WHEN v_profile.last_active_at > NOW() - INTERVAL '48 hours' THEN 80
    WHEN v_profile.last_active_at > NOW() - INTERVAL '7 days' THEN 50
    WHEN v_profile.last_active_at > NOW() - INTERVAL '30 days' THEN 20
    ELSE 0
  END;

  -- Bonus (max +5)
  -- Recent Nob in last 15 min
  IF EXISTS (SELECT 1 FROM public.posts WHERE user_id = p_user_id AND published_at > NOW() - INTERVAL '15 minutes') THEN
    v_bonus := v_bonus + 0.5;
  END IF;
  -- Balanced signal send/receive
  SELECT COUNT(*) INTO v_tmp FROM public.signals WHERE sender_id = p_user_id;
  SELECT COUNT(*) INTO v_tmp2 FROM public.signals WHERE receiver_id = p_user_id;
  IF v_tmp > 0 AND v_tmp2 > 0 AND ABS(v_tmp - v_tmp2) <= GREATEST(v_tmp, v_tmp2) * 0.5 THEN
    v_bonus := v_bonus + 0.2;
  END IF;
  v_bonus := LEAST(v_bonus, 5);

  -- Final score
  v_score := (v_p * 0.20) + (v_c * 0.15) + (v_d * 0.15) + (v_t * 0.20) + (v_f * 0.20) + (v_v * 0.10);
  v_score := LEAST(v_score + v_bonus, 100);

  -- Cache all component scores
  UPDATE public.profiles SET
    maturity_score = v_score,
    profile_completeness_score = v_p::INT,
    community_score = v_c::INT,
    depth_score = v_d::INT,
    follow_through_score = v_f::INT,
    vitality_score = v_v
  WHERE id = p_user_id;

  RETURN v_score;
END;
$$;

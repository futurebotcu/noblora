-- ---------------------------------------------------------------------------
-- Dalga 11 — ROLLBACK: generate_bff_suggestions eski body
-- ---------------------------------------------------------------------------
-- Apply this if Dalga 11 migration causes issues (incognito filter
-- yanlis filterliyor, BFF onerileri sifira dustu, vs.).
--
-- Bu rollback 'is_discoverable' satirini kaldirir, geri kalan body
-- production_hardening.sql:88-147 ile birebir ayni (Dalga 7 search_path
-- korunur).
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.generate_bff_suggestions(p_user_id UUID)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, auth, pg_temp
AS $$
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

  IF v_profile.daily_bff_suggestions_used >= v_limit THEN RETURN 0; END IF;

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

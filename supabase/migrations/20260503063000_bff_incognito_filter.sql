-- ---------------------------------------------------------------------------
-- Dalga 11 — R8: generate_bff_suggestions incognito filter
-- ---------------------------------------------------------------------------
-- Privacy bug: Incognito user'lar BFF onerilerinde gorunuyor.
-- Mevcut filter is_paused/is_verified/active_modes kontrol ediyor
-- ama incognito_mode YOK.
--
-- Fix: AND public.is_discoverable(p.id, 'bff', p_user_id)
-- DEFINER->DEFINER call (Dalga 6 pattern ile ayni).
--
-- is_discoverable kontrolleri (settings_completion.sql:23-57):
--   1. is_paused -> FALSE (mevcut filter ile redundant, harmless)
--   2. mode_visible (bff_visible) -> FALSE ise reddet (BONUS sikilastirma)
--   3. incognito_mode -> matches'ta (target, requester) bagi yoksa reddet
--      (asil fix)
--
-- search_path: Dalga 7 baseline 'public, extensions, auth, pg_temp'
-- korunuyor (advisor function_search_path_mutable 0 -> 0 beklenir).
--
-- Performance: candidate FOR loop LIMIT 5 (max nob_tier='noble').
-- Per-row is_discoverable cagrisi = 5 max. Index lookup matches
-- tablosunda hizli. Subquery alternatifi gereksiz.
--
-- Out of scope (ayri dalga):
--   - hide_exact_distance enforce (mesafe altyapisi yok)
--   - calm_mode ek enforce yerleri
--   - notification_preferences (push trigger eksik)
--   - show_city_only (phantom setting, DB granularity yok)
--
-- ---------------------------------------------------------------------------
-- ROLLBACK SQL (run if anything breaks after apply):
-- ---------------------------------------------------------------------------
-- See .claude/dalga-11-rollback.sql for emergency rollback (eski body).
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
      AND public.is_discoverable(p.id, 'bff', p_user_id)  -- Dalga 11 R8 fix
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

-- Post-apply verification:
--   1. SELECT prosrc FROM pg_proc WHERE proname = 'generate_bff_suggestions';
--      Body 'is_discoverable' string'i icermeli.
--   2. BEGIN;
--        UPDATE profiles SET incognito_mode=true WHERE id='<bff-user-A>';
--        SELECT generate_bff_suggestions('<bff-user-B>');
--        SELECT * FROM bff_suggestions WHERE user_a_id='<bff-user-B>'
--          AND user_b_id='<bff-user-A>';  -- 0 satir beklenir
--      ROLLBACK;
--   3. Advisor: function_search_path_mutable = 0 (korundu),
--      total = 115 (degismedi), security_definer = 110 (degismedi).

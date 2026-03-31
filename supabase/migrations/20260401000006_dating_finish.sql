-- =============================================================================
-- DATING FINISH: Remaining swipe count RPC
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_remaining_swipes(p_user_id UUID)
RETURNS INT LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tier TEXT;
  v_used INT;
  v_reset TIMESTAMPTZ;
  v_limit INT;
BEGIN
  SELECT nob_tier, daily_swipes_used, daily_swipes_reset
  INTO v_tier, v_used, v_reset
  FROM public.profiles WHERE id = p_user_id;

  IF v_tier IS NULL THEN RETURN 0; END IF;

  IF v_reset < NOW() - INTERVAL '1 day' THEN
    v_used := 0;
  END IF;

  v_limit := CASE v_tier
    WHEN 'observer' THEN 30
    WHEN 'explorer' THEN 50
    WHEN 'noble'    THEN 100
    ELSE 30
  END;

  RETURN GREATEST(0, v_limit - v_used);
END;
$$;

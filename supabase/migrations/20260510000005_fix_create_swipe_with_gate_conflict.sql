-- ─────────────────────────────────────────────────────────────────────────────
-- R13 fix — create_swipe_with_gate ON CONFLICT must match the actual unique
-- constraint on `public.swipes`, which is 3-column:
--   UNIQUE (swiper_id, swiped_id, mode)
--
-- The original migration (20260510000004) used `ON CONFLICT (swiper_id,
-- swiped_id)` and failed at runtime with "no unique or exclusion constraint
-- matching the ON CONFLICT specification" (PG error 42P10) when the gate
-- passed and the INSERT was attempted. Smoke senaryo 2 caught this before
-- any production user hit it.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.create_swipe_with_gate(
  p_swiper_id UUID,
  p_target_id UUID,
  p_direction TEXT,
  p_mode      TEXT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_country         TEXT;
  v_travel_mode     BOOLEAN;
  v_travel_country  TEXT;
  v_can_interact    BOOLEAN;
BEGIN
  SELECT country, travel_mode, travel_country
    INTO v_country, v_travel_mode, v_travel_country
  FROM public.profiles
  WHERE id = p_swiper_id;

  v_can_interact := (
    v_country IN ('TH', 'VN', 'PH')
    OR (COALESCE(v_travel_mode, FALSE) AND v_travel_country IN ('TH', 'VN', 'PH'))
  );

  IF NOT v_can_interact AND p_direction = 'right' THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error',   'travel_mode_required',
      'message', 'Activate travel mode in Thailand, Vietnam, or Philippines to like profiles'
    );
  END IF;

  -- Match the actual unique constraint: (swiper_id, swiped_id, mode).
  INSERT INTO public.swipes (swiper_id, swiped_id, direction, mode)
  VALUES (p_swiper_id, p_target_id, p_direction, p_mode)
  ON CONFLICT (swiper_id, swiped_id, mode) DO UPDATE SET direction = EXCLUDED.direction;

  RETURN jsonb_build_object('success', TRUE);
END;
$$;

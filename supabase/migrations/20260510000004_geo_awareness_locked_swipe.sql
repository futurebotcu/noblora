-- ─────────────────────────────────────────────────────────────────────────────
-- Dalga R13 — Geo-Awareness + Locked Swipe (V1 launch path)
--
-- Adds:
--   • profiles.country         (text, NULL ok = outside TH/VN/PH)
--   • profiles.travel_country  (text)
--   • profiles.place_id        (text, Google Places place_id of home city)
--   • profiles.travel_place_id (text, Google Places place_id of travel city)
--   • create_swipe_with_gate(swiper, target, direction, mode) RPC
--
-- Country gate logic (right-swipe only):
--   user.country IN ('TH','VN','PH')
--   OR (user.travel_mode = TRUE AND user.travel_country IN ('TH','VN','PH'))
--
-- Existing infra KEPT (PostGIS location, ST_Distance, mesafe slider,
-- Geolocator, geocoding pkgs). This migration is additive only.
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. New columns ─────────────────────────────────────────────────────────────
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS country          TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS travel_country   TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS place_id         TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS travel_place_id  TEXT;

-- 2. Country gate RPC ────────────────────────────────────────────────────────
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
  -- Read swiper geo state
  SELECT country, travel_mode, travel_country
    INTO v_country, v_travel_mode, v_travel_country
  FROM public.profiles
  WHERE id = p_swiper_id;

  -- Country gate (only enforced on right-swipe; left passes through)
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

  -- Insert swipe (idempotent for re-swipe / direction flip)
  INSERT INTO public.swipes (swiper_id, swiped_id, direction, mode)
  VALUES (p_swiper_id, p_target_id, p_direction, p_mode)
  ON CONFLICT (swiper_id, swiped_id) DO UPDATE SET direction = EXCLUDED.direction;

  RETURN jsonb_build_object('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_swipe_with_gate(UUID, UUID, TEXT, TEXT) TO authenticated;

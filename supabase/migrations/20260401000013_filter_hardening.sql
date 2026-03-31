-- =============================================================================
-- FILTER HARDENING: Geo distance RPC, photo count, pinned nob flag
-- =============================================================================

-- ═══════════════════════════════════════════════════════════════════
-- 1. Cached photo_count column for efficient filtering
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS photo_count INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS has_pinned_nob BOOLEAN NOT NULL DEFAULT FALSE;

-- Backfill photo_count from photos array
UPDATE public.profiles SET photo_count = COALESCE(array_length(photos, 1), 0) WHERE photos IS NOT NULL;

-- ═══════════════════════════════════════════════════════════════════
-- 2. RPC: Geo-filtered profile discovery
-- Uses PostGIS ST_DWithin on geography column for real km filtering
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fetch_nearby_profiles(
  p_user_id UUID,
  p_mode TEXT,
  p_max_distance_km DOUBLE PRECISION DEFAULT 100,
  p_same_city_only BOOLEAN DEFAULT FALSE
)
RETURNS TABLE(profile_id UUID, distance_km DOUBLE PRECISION) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_loc geography;
  v_user_city TEXT;
BEGIN
  SELECT location, city INTO v_user_loc, v_user_city
  FROM public.profiles WHERE id = p_user_id;

  -- If user has no location, fall back to city match
  IF v_user_loc IS NULL THEN
    RETURN QUERY
    SELECT p.id AS profile_id, 0::DOUBLE PRECISION AS distance_km
    FROM public.profiles p
    WHERE p.id != p_user_id
      AND p.is_paused = FALSE
      AND (NOT p_same_city_only OR p.city = v_user_city);
    RETURN;
  END IF;

  RETURN QUERY
  SELECT p.id AS profile_id,
    ST_Distance(p.location, v_user_loc) / 1000.0 AS distance_km
  FROM public.profiles p
  WHERE p.id != p_user_id
    AND p.is_paused = FALSE
    AND p.location IS NOT NULL
    AND ST_DWithin(p.location, v_user_loc, p_max_distance_km * 1000)
    AND (NOT p_same_city_only OR p.city = v_user_city);
END;
$$;

-- ═══════════════════════════════════════════════════════════════════
-- 3. Trigger: Update photo_count when photos array changes
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.update_photo_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.photo_count := COALESCE(array_length(NEW.photos, 1), 0);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_photo_count ON public.profiles;
CREATE TRIGGER profiles_photo_count
  BEFORE INSERT OR UPDATE OF photos ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_photo_count();

-- ═══════════════════════════════════════════════════════════════════
-- 4. Trigger: Update has_pinned_nob when posts change
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.update_has_pinned_nob()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  UPDATE public.profiles SET has_pinned_nob = EXISTS (
    SELECT 1 FROM public.posts WHERE user_id = COALESCE(NEW.user_id, OLD.user_id) AND is_pinned = TRUE
  ) WHERE id = COALESCE(NEW.user_id, OLD.user_id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS posts_pinned_nob ON public.posts;
CREATE TRIGGER posts_pinned_nob
  AFTER INSERT OR UPDATE OF is_pinned OR DELETE ON public.posts
  FOR EACH ROW EXECUTE FUNCTION public.update_has_pinned_nob();

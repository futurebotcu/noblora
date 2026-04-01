-- =============================================================================
-- INTERACTION GATING: photo count + verified photo checks
-- =============================================================================

-- Ensure columns exist
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS verified_profile_photo BOOLEAN NOT NULL DEFAULT FALSE;

-- Update verified_profile_photo from existing verification state
UPDATE public.profiles SET verified_profile_photo = TRUE WHERE selfie_verified = TRUE OR photos_verified = TRUE;

-- ═══════════════════════════════════════════════════════════════════
-- RPC: Check if user can interact in a given mode
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.can_user_interact(p_user_id UUID, p_mode TEXT)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_photo_count INT;
  v_verified BOOLEAN;
BEGIN
  SELECT photo_count, verified_profile_photo
  INTO v_photo_count, v_verified
  FROM public.profiles WHERE id = p_user_id;

  IF v_photo_count IS NULL THEN RETURN FALSE; END IF;

  -- Dating & BFF: 3+ photos AND verified profile photo
  IF p_mode IN ('date', 'bff') THEN
    RETURN v_photo_count >= 3 AND v_verified;
  END IF;

  -- Social: verified profile photo only
  IF p_mode = 'social' THEN
    RETURN v_verified;
  END IF;

  RETURN FALSE;
END;
$$;

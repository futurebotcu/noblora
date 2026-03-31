-- =============================================================================
-- Migration: profiles — ensure verification/onboarding columns exist + trigger
-- =============================================================================
-- Columns were added to schema.sql but may be missing from existing DBs.
-- selfie_verified and photos_verified were manually added earlier; the rest
-- are added here safely with IF NOT EXISTS.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_verified   BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS is_onboarded  BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS photos        TEXT[]  DEFAULT '{}';

-- Backfill: any row that already has both flags set should have is_verified = true
UPDATE public.profiles
SET is_verified = TRUE
WHERE selfie_verified = TRUE AND photos_verified = TRUE AND is_verified = FALSE;

-- Trigger function: keep is_verified in sync whenever selfie/photo flags are updated
CREATE OR REPLACE FUNCTION public.sync_is_verified()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.selfie_verified = TRUE AND NEW.photos_verified = TRUE THEN
    NEW.is_verified := TRUE;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_sync_is_verified ON public.profiles;
CREATE TRIGGER profiles_sync_is_verified
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.sync_is_verified();

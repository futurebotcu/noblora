-- Migration: Tighten profiles_select RLS policy
-- Why: Previous policy used USING(true) which exposed all profiles including
--      incomplete, paused, and test accounts to any authenticated user.
-- What: Now only shows:
--   1. User's own profile (always accessible)
--   2. Completed (is_onboarded=true) and active (is_paused=false) profiles
-- Impact: Prevents scraping of incomplete/inactive/paused profiles while
--         maintaining full discovery functionality for the dating app.

DROP POLICY IF EXISTS "profiles_select" ON public.profiles;

CREATE POLICY "profiles_select" ON public.profiles
  FOR SELECT TO authenticated
  USING (
    auth.uid() = id
    OR (is_onboarded = true AND COALESCE(is_paused, false) = false)
  );

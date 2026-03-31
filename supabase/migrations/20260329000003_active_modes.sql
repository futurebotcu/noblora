-- =============================================================================
-- Active Modes — users opt into which modes they participate in
-- =============================================================================

-- 1. Add active_modes column to profiles
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS active_modes TEXT[] NOT NULL DEFAULT '{}';

-- 2. Backfill: seed existing rows with their current_mode as the default active mode
UPDATE public.profiles
  SET active_modes = ARRAY[current_mode]
  WHERE current_mode IS NOT NULL
    AND (active_modes IS NULL OR active_modes = '{}');

-- 3. RLS policy: users can update their own active_modes
-- (profiles table must already have RLS enabled)
CREATE POLICY "profiles_update_active_modes" ON public.profiles
  FOR UPDATE TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

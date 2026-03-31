-- =============================================================================
-- APPEARANCE SETTINGS: theme_mode + accent_color on profiles
-- =============================================================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS theme_mode   TEXT NOT NULL DEFAULT 'dark',
  ADD COLUMN IF NOT EXISTS accent_color TEXT NOT NULL DEFAULT 'gold';

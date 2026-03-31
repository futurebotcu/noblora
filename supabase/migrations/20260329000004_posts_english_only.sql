-- =============================================================================
-- Enforce English-only (ASCII) content in posts
-- =============================================================================

ALTER TABLE public.posts
  DROP CONSTRAINT IF EXISTS posts_content_ascii;

ALTER TABLE public.posts
  ADD CONSTRAINT posts_content_ascii
    CHECK (content ~ '^[[:ascii:]]+$');

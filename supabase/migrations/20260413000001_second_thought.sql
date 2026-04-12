-- THE SECOND THOUGHT: revision history, future nobs, comment edits
-- See apply_migration for full deployed SQL.
-- This file tracks the local copy for version control.

CREATE TABLE IF NOT EXISTS public.post_revisions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id         UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  revision_type   TEXT NOT NULL CHECK (revision_type IN ('minor_edit', 'second_thought')),
  previous_content TEXT NOT NULL,
  previous_caption TEXT,
  new_content     TEXT NOT NULL,
  new_caption     TEXT,
  reason          TEXT CHECK (reason IS NULL OR char_length(reason) <= 200),
  revision_number INT NOT NULL DEFAULT 1,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS edit_count          INT         NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS has_second_thought  BOOLEAN     NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS last_edited_at      TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS second_thought_reason TEXT,
  ADD COLUMN IF NOT EXISTS original_content    TEXT,
  ADD COLUMN IF NOT EXISTS original_caption    TEXT,
  ADD COLUMN IF NOT EXISTS is_future_nob       BOOLEAN     NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS revisit_at          TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS future_nob_status   TEXT;

ALTER TABLE public.post_comments
  ADD COLUMN IF NOT EXISTS is_edited        BOOLEAN     NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS edit_count       INT         NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS original_content TEXT,
  ADD COLUMN IF NOT EXISTS last_edited_at   TIMESTAMPTZ;

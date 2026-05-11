-- ─────────────────────────────────────────────────────────────────────────────
-- R16 — Flip the DB-level default for profiles.accent_color from 'gold' to
-- 'emerald'. R15 already changed the client-side default in
-- lib/providers/appearance_provider.dart, but the DB default fires on:
--   • new profile rows where `accent_color` is not explicitly set, and
--   • `syncFromSupabase()` after signup when the DB has the column set to
--     its default.
--
-- Existing rows are intentionally NOT rewritten — users who have already
-- chosen 'gold' (or any other accent) keep their preference. This migration
-- only changes what NEW signups default to.
--
-- Evidence: R16_ROOT_CAUSE_AUDIT_REPORT.md "Root cause #3" — DB
-- `information_schema.columns` shows `column_default = "'gold'::text"` even
-- after R15 client-side fix.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.profiles
  ALTER COLUMN accent_color SET DEFAULT 'emerald';

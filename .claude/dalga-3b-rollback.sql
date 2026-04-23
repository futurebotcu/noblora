-- ---------------------------------------------------------------------------
-- Dalga 3b ROLLBACK — emergency restore for migration:
--   20260423105809_drop_r5b_dead_policies.sql
-- ---------------------------------------------------------------------------
-- Use case: nothing should break after Dalga 3b apply, because the 5
-- dropped policies were behaviorally dead (Dalga 3 pre-smoke kanıtı:
-- her biri RLS tarafından reddedildi). Rollback is gereksiz beklenir.
--
-- However, if something unexpected surfaces (e.g. an undocumented client
-- code path was secretly relying on one of these dead policies via a
-- different role context that pre-smoke didn't cover), this restores the
-- 5 original PERMISSIVE INSERT policies to their pre-Dalga-3b state.
--
-- Run as service_role / postgres in Supabase SQL editor or via
-- mcp__supabase__execute_sql. Do NOT commit this file's SQL into a new
-- migration unless you intend to permanently revert the cleanup.
-- ---------------------------------------------------------------------------

-- Restore the 5 dropped permissive policies to their original state.
CREATE POLICY "matches_insert_system" ON public.matches
  FOR INSERT TO public WITH CHECK (true);

CREATE POLICY "cp_insert_own" ON public.conversation_participants
  FOR INSERT TO public WITH CHECK (true);

CREATE POLICY "conv_insert_own" ON public.conversations
  FOR INSERT TO public WITH CHECK (true);

CREATE POLICY "rm_insert_own" ON public.real_meetings
  FOR INSERT TO public WITH CHECK (true);

CREATE POLICY "video_insert_own" ON public.video_sessions
  FOR INSERT TO public WITH CHECK (true);

-- Verification after rollback: advisor `rls_policy_always_true` should
-- show the 5 original cache_keys back (total count back to 6 including
-- video_update_own).

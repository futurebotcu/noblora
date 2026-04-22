-- ---------------------------------------------------------------------------
-- Dalga 3 ROLLBACK — emergency restore for migration:
--   20260422081824_rls_harden_notifications_and_gating.sql
-- ---------------------------------------------------------------------------
-- Use case: post-apply smoke test fails (e.g. signup flow breaks because
-- handle_new_user_gating cannot bypass RLS as expected, or app code does
-- direct gating_status writes that get blocked).
--
-- Run as service_role / postgres in Supabase SQL editor or via
-- mcp__supabase__execute_sql. Do NOT commit this file's SQL into a new
-- migration unless you intend to permanently revert the hardening.
-- ---------------------------------------------------------------------------

-- Restore the 3 dropped permissive policies to their original state.
CREATE POLICY "notifications_insert_system" ON public.notifications
  FOR INSERT TO public WITH CHECK (true);

CREATE POLICY "gating_insert_system" ON public.gating_status
  FOR INSERT TO public WITH CHECK (true);

CREATE POLICY "gating_update_system" ON public.gating_status
  FOR UPDATE TO public USING (true) WITH CHECK (true);

-- Remove the new restrictive replacements added by the migration.
DROP POLICY IF EXISTS "gating_insert_own" ON public.gating_status;
DROP POLICY IF EXISTS "gating_update_own" ON public.gating_status;

-- Verification after rollback: advisor `rls_policy_always_true` should
-- show the 3 original cache_keys back, and direct authenticated UPDATE
-- on gating_status (pre-smoke test 4 pattern) should succeed again.

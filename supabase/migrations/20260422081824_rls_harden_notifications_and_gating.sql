-- ---------------------------------------------------------------------------
-- Dalga 3 — R5: Drop cosmetic permissive + harden gating_status
-- ---------------------------------------------------------------------------
-- Scope (3 policy changes, all atomic in one transaction):
-- 1. notifications_insert_system: DROP only (DEAD policy, advisor cosmetic).
--    polroles={0} quirk made it effectively non-applicable for any role.
-- 2. gating_status.gating_insert_system: DROP + replace with restrictive
--    gating_insert_own (auth.uid() = user_id, TO authenticated).
--    AKTIF bypass — pre-smoke test 3: elena could INSERT for arbitrary
--    user_id (RLS passed, FK denied = proof RLS was reached and let through).
-- 3. gating_status.gating_update_system: DROP + replace with restrictive
--    gating_update_own (USING + WITH CHECK auth.uid() = user_id).
--    AKTIF bypass — pre-smoke test 4: elena UPDATEd trultruva's
--    is_verified flag (RETURNING confirmed, transaction rolled back).
--
-- Remaining 5 cosmetic dead policies → R5b (Dalga 3b, separate PR).
-- See .claude/known_regressions.md R5b for full list.
--
-- ---------------------------------------------------------------------------
-- SECURITY DEFINER compatibility (verified pre-write):
-- ---------------------------------------------------------------------------
--   handle_new_user_gating: DEFINER → bypasses RLS, signup INSERT ok
--   dev_auto_verify:        DEFINER → bypasses RLS, dev tool ok
--   sync_is_verified:       INVOKER, but trigger on profiles
--                           (selfie_verified+photos_verified → is_verified),
--                           does NOT touch gating_status → not affected
--
-- ---------------------------------------------------------------------------
-- ROLLBACK SQL (run if smoke test fails after apply):
-- ---------------------------------------------------------------------------
--   CREATE POLICY "notifications_insert_system" ON public.notifications
--     FOR INSERT TO public WITH CHECK (true);
--   CREATE POLICY "gating_insert_system" ON public.gating_status
--     FOR INSERT TO public WITH CHECK (true);
--   CREATE POLICY "gating_update_system" ON public.gating_status
--     FOR UPDATE TO public USING (true) WITH CHECK (true);
--   DROP POLICY IF EXISTS "gating_insert_own" ON public.gating_status;
--   DROP POLICY IF EXISTS "gating_update_own" ON public.gating_status;
--
-- (Also stored standalone at .claude/dalga-3-rollback.sql for emergencies.)
-- ---------------------------------------------------------------------------

-- Step 1 — Create new restrictive policies FIRST (overlap-safe).
-- Old permissive policies still grant true during this window; coexistence
-- is fine because PERMISSIVE policies OR-combine.
CREATE POLICY "gating_insert_own" ON public.gating_status
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "gating_update_own" ON public.gating_status
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Step 2 — Drop old permissive policies. Now safe: new restrictive policies
-- govern authenticated callers; SECURITY DEFINER functions bypass RLS.
DROP POLICY IF EXISTS "notifications_insert_system" ON public.notifications;
DROP POLICY IF EXISTS "gating_insert_system"        ON public.gating_status;
DROP POLICY IF EXISTS "gating_update_system"        ON public.gating_status;

-- Post-apply verification targets (advisor cache_keys that should disappear):
--   rls_policy_always_true_public_notifications_notifications_insert_system
--   rls_policy_always_true_public_gating_status_gating_insert_system
--   rls_policy_always_true_public_gating_status_gating_update_system

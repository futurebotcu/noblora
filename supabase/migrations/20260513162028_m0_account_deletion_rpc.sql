-- =============================================================================
-- M0 follow-up — Account deletion RPC
-- =============================================================================
-- Why:
--   The Settings "Delete Account" handler at
--   lib/features/settings/settings_screen.dart:418-424 directly UPDATEs
--   profiles with two columns:
--     { is_paused: true, verification_status: 'deletion_requested' }
--   After M0 the trust-lockdown trigger trg_profiles_block_sensitive_writes
--   blocks any client-side change to verification_status (it is on the
--   protected list). The entire UPDATE rolls back, is_paused also never sets,
--   and the Delete Account button is functionally broken.
--
-- Fix:
--   A SECURITY DEFINER RPC that the client calls instead of the direct
--   UPDATE. The function:
--     - Reads auth.uid() — caller cannot target any other user.
--     - Sets the M0 bypass marker (app.bypass_lockdown=true, transaction-
--       local) so its own UPDATE passes the trust-lockdown trigger.
--     - Whitelists exactly two columns: is_paused=TRUE and
--       verification_status='deletion_requested'. No other write is
--       performed, no other parameter accepted.
--
-- Security characteristics:
--   - No p_user_id parameter → impossible to delete someone else's account.
--   - Bypass marker scope is set_config(..., true) — transaction-local;
--     it does not leak to subsequent statements on the same connection.
--   - REVOKE PUBLIC + anon EXECUTE; GRANT to authenticated only.
--   - The function does not REVOKE anything broader than its own
--     namespace, does not touch other tables, does not call other SECDEF
--     functions, and has no SQL injection surface (no dynamic SQL).
--
-- What it does NOT do:
--   - Does not delete data immediately. The deletion is a *request*; the
--     existing hard_delete_expired_accounts cron handles the 30-day grace
--     period elsewhere (already revoked from anon + public in R21).
--   - Does not cascade to other tables (matches, messages, photo_verifications).
--     Those are handled by FK ON DELETE CASCADE when the auth.users row is
--     finally removed.
--   - Does not sign the user out. The Flutter handler does that
--     immediately after the RPC succeeds (existing behaviour).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.request_account_deletion()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid;
BEGIN
  v_uid := auth.uid();

  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required to request account deletion';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_uid) THEN
    RAISE EXCEPTION 'Profile not found for the calling user';
  END IF;

  -- Whitelist the controlled write so the M0 trust-lockdown trigger passes.
  PERFORM set_config('app.bypass_lockdown', 'true', true);

  UPDATE public.profiles
     SET is_paused           = TRUE,
         verification_status = 'deletion_requested'
   WHERE id = v_uid;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.request_account_deletion() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.request_account_deletion() FROM anon;
GRANT  EXECUTE ON FUNCTION public.request_account_deletion() TO authenticated;

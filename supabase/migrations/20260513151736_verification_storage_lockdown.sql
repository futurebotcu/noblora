-- =============================================================================
-- Verification Storage Lockdown — P0-2 fix
-- =============================================================================
-- Issue:
--   Storage policy "authenticated users can read verification photos" granted
--   SELECT on the entire `verification-photos` bucket to any authenticated
--   user, with NO folder check (USING (bucket_id = 'verification-photos')).
--   Any holder of a Supabase JWT could list and download every user's
--   verification selfie via:
--     GET /storage/v1/object/verification-photos/<other_user_id>/selfie_*.jpg
--   This is an explicit identity-document privacy leak.
--
-- Audit reference:
--   VERIFICATION_FLOW_AUDIT_REPORT.md §8 P0-2 (2026-05-13).
--   Live query (pre-fix) confirmed: storage.objects policy with
--   `using_expr = (bucket_id = 'verification-photos'::text)`.
--
-- Strategy (containment, not full rebuild):
--   1. DROP the bucket-wide read policy.
--   2. CREATE an owner-scoped read policy: a user can only read objects
--      whose folder path starts with their own auth.uid().
--   3. service_role bypasses RLS by default and needs no explicit policy.
--      A future SECURITY DEFINER RPC (Path B in the audit) is the correct
--      future admin-read path; out of R-containment scope.
--
-- Effect on existing flows:
--   - Owner upload / read / update / delete of own verification photos:
--     UNAFFECTED. The folder-scoped INSERT/UPDATE/DELETE policies for
--     `verification-photos` already exist and remain in place; the new
--     SELECT policy mirrors the same folder scope.
--   - Admin panel: the legacy Verifications-tab thumbnail rendering will
--     now fail to fetch other users' selfies (admin's auth.uid() ≠ target's
--     folder). This is acceptable: the admin approve write path was already
--     broken (P0-3 in the audit), so we are not making anything that used
--     to work stop working.
--   - service_role / Edge Functions: unaffected.
--
-- Rollback:
--   REVOKE the new policy and recreate the unsafe bucket-wide policy. Not
--   recommended; if rollback is ever needed it should be paired with a real
--   admin-read path (SECURITY DEFINER RPC).
-- =============================================================================

DROP POLICY IF EXISTS "authenticated users can read verification photos"
  ON storage.objects;

CREATE POLICY "users can read own verification photos"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'verification-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

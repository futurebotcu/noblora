-- Dalga 9 ROLLBACK - restore the 2 dead SELECT policies dropped by
-- 20260502083216_drop_dead_listing_policies.sql.
--
-- Use ONLY if a future feature adds .list() / auth'ed .download() calls
-- on galleries / profile-photos buckets and breaks because the policies
-- are missing. Restoring re-opens public_bucket_allows_listing advisor
-- WARN (2 lint hits) - that is the trade-off.
--
-- Standalone (NOT under supabase/migrations/) so it does not auto-apply.
-- Run via mcp__supabase__execute_sql or psql.

CREATE POLICY "anyone can read gallery photos"
  ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'galleries');

CREATE POLICY "authenticated users can read profile photos"
  ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'profile-photos');

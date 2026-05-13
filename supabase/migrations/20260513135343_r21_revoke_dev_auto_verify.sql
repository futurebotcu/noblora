-- =============================================================================
-- R21 — Revoke + DROP dev_auto_verify (P0 security fix)
-- =============================================================================
-- Issue:
--   public.dev_auto_verify() is a SECURITY DEFINER function that flips all
--   verification flags for the calling user. Flutter only invokes it from
--   lib/providers/auth_provider.dart:214 inside an `if (isDevMode)` guard, so
--   production app builds never call it. However the RPC itself was missed by
--   the previous two REVOKE passes (20260429135255_revoke_definer_executable.sql
--   and 20260502075743_revoke_definer_executable_public.sql), and `pg_proc`
--   confirms grantees = {PUBLIC, postgres, anon, authenticated, service_role}.
--   Any holder of a valid Supabase JWT can therefore POST to
--   /rest/v1/rpc/dev_auto_verify and self-verify, bypassing photo verification
--   and entry gate.
--
-- Audit references:
--   - NOBLORA_CURRENT_STATE_AUDIT.md §7 P0-1 (2026-05-13)
--   - mcp__supabase__get_advisors(type=security) baseline: 108 findings, two of
--     which are anon/authenticated SECDEF executability for this function.
--
-- Strategy:
--   1. REVOKE ALL EXECUTE first (defense in depth, in case DROP is blocked).
--   2. DROP FUNCTION IF EXISTS to remove the attack surface entirely.
--   Function body is not version-controlled (no CREATE FUNCTION in migrations
--   or supabase_schema.sql); local developers who need the shortcut back can
--   re-create it via a local seed file outside of production migrations.
--
-- Rollback:
--   None. If needed, restore via pg_dump of pre-migration state or recreate
--   from a local seed.
-- =============================================================================

REVOKE ALL ON FUNCTION public.dev_auto_verify() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.dev_auto_verify() FROM anon;
REVOKE ALL ON FUNCTION public.dev_auto_verify() FROM authenticated;
REVOKE ALL ON FUNCTION public.dev_auto_verify() FROM service_role;

DROP FUNCTION IF EXISTS public.dev_auto_verify();

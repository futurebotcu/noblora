-- ---------------------------------------------------------------------------
-- Dalga 3b — R5b: Drop 5 cosmetic dead permissive policies
-- ---------------------------------------------------------------------------
-- Context:
--   5 PERMISSIVE INSERT policies with WITH CHECK (true) but polroles={0}
--   PostgreSQL quirk made them behaviorally inert. pre-smoke test
--   (2026-04-22, Dalga 3) proved each rejected cross-user INSERT under
--   authenticated caller — RLS denied, FK never reached.
--
-- Scope (5 DROPs, no CREATE — replacements not needed because policies
-- are already dead; nothing depends on them):
--   1. matches.matches_insert_system       (INSERT, with_check=true)
--   2. conversation_participants.cp_insert_own (INSERT, with_check=true)
--   3. conversations.conv_insert_own       (INSERT, with_check=true)
--   4. real_meetings.rm_insert_own         (INSERT, with_check=true)
--   5. video_sessions.video_insert_own     (INSERT, with_check=true)
--
-- Out of scope (intentional, R5b kayıt notunda kanıtlı):
--   - video_sessions.video_update_own (UPDATE) — intra-match design;
--     SELECT policy match-bound, dış user erişemez. Kalır.
--
-- Evidence ref:
--   - .claude/known_regressions.md R5b
--   - Dalga 3 pre-smoke (session_notes 2026-04-22 ADIM 2.5/2.6 tablosu)
--
-- ---------------------------------------------------------------------------
-- SECURITY DEFINER compatibility: not relevant.
-- ---------------------------------------------------------------------------
--   These policies are dead — no SECURITY DEFINER function depends on them
--   bypassing or being constrained by them. INSERT paths in the codebase
--   either use SECURITY DEFINER RPCs (check_and_create_match,
--   safe_advance_to_video, etc.) which bypass RLS entirely, or use other
--   restrictive policies that already exist on each table. Removing these
--   5 cosmetic rows changes no behavior.
--
-- ---------------------------------------------------------------------------
-- ROLLBACK SQL (run if anything unexpectedly breaks after apply):
-- ---------------------------------------------------------------------------
--   CREATE POLICY "matches_insert_system" ON public.matches
--     FOR INSERT TO public WITH CHECK (true);
--   CREATE POLICY "cp_insert_own" ON public.conversation_participants
--     FOR INSERT TO public WITH CHECK (true);
--   CREATE POLICY "conv_insert_own" ON public.conversations
--     FOR INSERT TO public WITH CHECK (true);
--   CREATE POLICY "rm_insert_own" ON public.real_meetings
--     FOR INSERT TO public WITH CHECK (true);
--   CREATE POLICY "video_insert_own" ON public.video_sessions
--     FOR INSERT TO public WITH CHECK (true);
--
-- (Also stored standalone at .claude/dalga-3b-rollback.sql for emergencies.)
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS "cp_insert_own"         ON public.conversation_participants;
DROP POLICY IF EXISTS "conv_insert_own"       ON public.conversations;
DROP POLICY IF EXISTS "matches_insert_system" ON public.matches;
DROP POLICY IF EXISTS "rm_insert_own"         ON public.real_meetings;
DROP POLICY IF EXISTS "video_insert_own"      ON public.video_sessions;

-- Post-apply verification targets (advisor cache_keys that should disappear):
--   rls_policy_always_true_public_conversation_participants_cp_insert_own
--   rls_policy_always_true_public_conversations_conv_insert_own
--   rls_policy_always_true_public_matches_matches_insert_system
--   rls_policy_always_true_public_real_meetings_rm_insert_own
--   rls_policy_always_true_public_video_sessions_video_insert_own
--
-- Expected post-apply advisor count for rls_policy_always_true:
--   6 → 1 (only video_sessions.video_update_own remains, intentional).

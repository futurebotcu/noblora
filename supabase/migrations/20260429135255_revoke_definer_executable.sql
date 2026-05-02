-- Dalga 8: security_definer_function_executable batch REVOKE (KISMEN)
--
-- Advisor BEFORE: 150 lint hits across two categories
--   - anon_security_definer_function_executable: 75
--   - authenticated_security_definer_function_executable: 75
--
-- Strategy: REVOKE EXECUTE for 20 SECURITY DEFINER functions that have
-- ZERO Flutter callers. Frontend RPCs (52 sigs) keep their grants —
-- revoking those would crash production.
--
-- Selection criteria:
--   1. Trigger functions (returns trigger) — invoked by table-level
--      events, role permissions on the function itself are irrelevant.
--   2. Cron / scheduled-job functions — run as the postgres role via
--      Supabase cron, never invoked by clients.
--   3. Internal helpers called only from other DEFINER functions
--      (e.g. is_discoverable, called by filter_discoverable_ids) —
--      DEFINER→DEFINER calls execute under the outer function's owner,
--      not the client role.
--
-- Behaviour change: NONE. No Flutter call site, trigger, or cron
-- depends on anon/authenticated executing these functions.
--
-- Expected lint reduction: 150 → 110 (-40, i.e. 20 functions × 2 roles).
-- 100% zero is intentionally NOT pursued in this wave: 52 frontend RPCs
-- still need anon/authenticated execute. Tightening that further (e.g.
-- per-fn anon revoke) is a follow-up scope.
--
-- Rollback: .claude/dalga-8-rollback.sql (GRANT EXECUTE).

-- ───────────────────────────────────────────────────────────────────
-- Trigger functions (13) — table-event invoked, role grants irrelevant
-- ───────────────────────────────────────────────────────────────────

REVOKE EXECUTE ON FUNCTION public.feed_event_comment_added()
  FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.feed_event_echo_changed()
  FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.feed_event_post_published()
  FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.feed_event_reaction_changed()
  FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_new_user_gating()
  FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_new_user_profile()
  FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.notify_on_echo()
  FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.notify_on_reaction()
  FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.notify_on_reply()
  FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_room_message_insert()
  FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_room_participant_delete()
  FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_room_participant_insert()
  FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trigger_push_notification()
  FROM anon, authenticated;

-- ───────────────────────────────────────────────────────────────────
-- Cron / internal helper (7) — no Flutter caller; postgres or
-- DEFINER→DEFINER invocation only
-- ───────────────────────────────────────────────────────────────────

REVOKE EXECUTE ON FUNCTION public.adjust_trust_score(uuid, integer)
  FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.close_inactive_rooms()
  FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_remaining_swipes(uuid)
  FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.hard_delete_expired_accounts()
  FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.is_discoverable(uuid, text, uuid)
  FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.recalculate_tiers()
  FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.update_vitality_decay()
  FROM anon, authenticated;

-- Dalga 8b ROLLBACK - restore EXECUTE grants for the 20 SECURITY
-- DEFINER functions revoked by 20260502075743_revoke_definer_executable_public.
--
-- Use ONLY if post-apply smoke test fails on a path that depends on
-- PUBLIC/anon/authenticated executing one of these functions.
-- Restoring grants re-opens the security_definer_function_executable
-- lint hits - that is the trade-off vs. broken behaviour.
--
-- Standalone (NOT under supabase/migrations/) so it does not auto-apply.
-- Run via mcp__supabase__execute_sql or psql.

-- Trigger functions (13)

GRANT EXECUTE ON FUNCTION public.feed_event_comment_added()
  TO PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.feed_event_echo_changed()
  TO PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.feed_event_post_published()
  TO PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.feed_event_reaction_changed()
  TO PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user_gating()
  TO PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user_profile()
  TO PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.notify_on_echo()
  TO PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.notify_on_reaction()
  TO PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.notify_on_reply()
  TO PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.trg_room_message_insert()
  TO PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.trg_room_participant_delete()
  TO PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.trg_room_participant_insert()
  TO PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.trigger_push_notification()
  TO PUBLIC, anon, authenticated;

-- Cron / internal helper (7)

GRANT EXECUTE ON FUNCTION public.adjust_trust_score(uuid, integer)
  TO PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.close_inactive_rooms()
  TO PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_remaining_swipes(uuid)
  TO PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.hard_delete_expired_accounts()
  TO PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_discoverable(uuid, text, uuid)
  TO PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.recalculate_tiers()
  TO PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.update_vitality_decay()
  TO PUBLIC, anon, authenticated;

-- Dalga 8 ROLLBACK — restore EXECUTE grants for the 20 SECURITY
-- DEFINER functions revoked by 20260429135255_revoke_definer_executable.
--
-- Use ONLY if post-apply smoke test fails on a path that depends on
-- one of these grants (unexpected dependency). Restoring grants
-- re-opens the security_definer_function_executable lint hits — that
-- is the trade-off vs. broken behaviour.
--
-- Standalone (NOT under supabase/migrations/) so it does not auto-apply.
-- Run via mcp__supabase__execute_sql or psql.

-- ───────────────────────────────────────────────────────────────────
-- Trigger functions (13)
-- ───────────────────────────────────────────────────────────────────

GRANT EXECUTE ON FUNCTION public.feed_event_comment_added()
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.feed_event_echo_changed()
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.feed_event_post_published()
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.feed_event_reaction_changed()
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user_gating()
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user_profile()
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.notify_on_echo()
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.notify_on_reaction()
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.notify_on_reply()
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.trg_room_message_insert()
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.trg_room_participant_delete()
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.trg_room_participant_insert()
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.trigger_push_notification()
  TO anon, authenticated;

-- ───────────────────────────────────────────────────────────────────
-- Cron / internal helper (7)
-- ───────────────────────────────────────────────────────────────────

GRANT EXECUTE ON FUNCTION public.adjust_trust_score(uuid, integer)
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.close_inactive_rooms()
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_remaining_swipes(uuid)
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.hard_delete_expired_accounts()
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_discoverable(uuid, text, uuid)
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.recalculate_tiers()
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.update_vitality_decay()
  TO anon, authenticated;

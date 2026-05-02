-- Dalga 8b: Dalga 8'in PUBLIC inheritance fix'i
--
-- Dalga 8 (20260429135255_revoke_definer_executable.sql) apply edildi
-- ama PostgreSQL'de PUBLIC role default grant'i nedeniyle no-op kaldi.
-- anon/authenticated direct grant yok, PUBLIC'ten miras aliyor.
--
-- Kanit (apply sonrasi pg_proc dump):
--   proacl: {=X/postgres, postgres=X/postgres, service_role=X/postgres}
--   "=X" = PUBLIC role has EXECUTE granted by postgres
--   has_function_privilege(anon|authenticated, fn, 'EXECUTE') = TRUE
--   (PUBLIC inheritance, REVOKE no-op)
--
-- Dogru komut: REVOKE EXECUTE ... FROM PUBLIC, anon, authenticated
--
-- service_role + postgres direct grant'li (proacl son iki entry):
--   postgres=X/postgres, service_role=X/postgres
-- Trigger'lar bu role'ler ile calisir, REVOKE FROM PUBLIC etkilemez.
-- Davranis degismez.
--
-- Beklenen advisor: 150 -> 110 (-40)
-- SQL dogrulama: has_function_privilege(anon|auth, fn, 'EXECUTE') = FALSE x 40
--
-- Selection criteria, fonksiyon listesi, davranis analizi: Dalga 8 ile
-- AYNI (envanter tekrari yok). Tek fark: REVOKE komutu syntactically
-- effective olacak sekilde (PUBLIC dahil).
--
-- Rollback: .claude/dalga-8b-rollback.sql (GRANT EXECUTE TO PUBLIC, anon, authenticated)

-- Trigger functions (13) - table-event invoked, role grants irrelevant

REVOKE EXECUTE ON FUNCTION public.feed_event_comment_added()
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.feed_event_echo_changed()
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.feed_event_post_published()
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.feed_event_reaction_changed()
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_new_user_gating()
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_new_user_profile()
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.notify_on_echo()
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.notify_on_reaction()
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.notify_on_reply()
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_room_message_insert()
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_room_participant_delete()
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_room_participant_insert()
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trigger_push_notification()
  FROM PUBLIC, anon, authenticated;

-- Cron / internal helper (7) - no Flutter caller; postgres or
-- DEFINER->DEFINER invocation only

REVOKE EXECUTE ON FUNCTION public.adjust_trust_score(uuid, integer)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.close_inactive_rooms()
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_remaining_swipes(uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.hard_delete_expired_accounts()
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.is_discoverable(uuid, text, uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.recalculate_tiers()
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.update_vitality_decay()
  FROM PUBLIC, anon, authenticated;

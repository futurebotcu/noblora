-- Dalga 7: function_search_path_mutable batch fix
--
-- Advisor BEFORE: 60 lint findings (function_search_path_mutable)
--   - 51 SECURITY DEFINER + 9 SECURITY INVOKER
--   - 59 unique function names + 1 fetch_nob_feed overload
--
-- Strategy: explicit SET search_path = public, extensions, auth, pg_temp
--   - public: app schema (tables, types)
--   - extensions: PostGIS et al. (some app fns reference unqualified geom helpers)
--   - auth: auth.uid(), auth.users (qualified or unqualified resolves)
--   - pg_temp: last → blocks temp-table injection vector
--
-- Behaviour change: NONE. ALTER FUNCTION ... SET ... is idempotent and
-- only adds a config; function bodies are untouched. Supabase docs
-- recommended remediation for this lint.
--
-- Rollback: .claude/dalga-7-rollback.sql (RESET search_path).

ALTER FUNCTION public.accept_reach_out(uuid)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.adjust_trust_score(uuid, integer)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.calculate_maturity_score(uuid)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.can_reach_user(uuid, uuid, text)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.can_user_interact(uuid, text)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.check_and_create_match(uuid, uuid, text)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.check_bff_suggestion_limit(uuid)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.check_connection_limit(uuid)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.check_nob_limit(uuid, text)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.check_note_limit(uuid)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.check_reach_out_limit(uuid)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.check_signal_limit(uuid)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.check_swipe_limit(uuid)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.close_inactive_rooms()
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.count_filtered_profiles(uuid, text, integer, integer, boolean, boolean, text)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.decrement_rewinds(uuid)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.decrement_super_likes(uuid)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.dev_auto_verify()
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.discover_mood_lanes(integer)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.fetch_nearby_profiles(uuid, text, double precision, boolean)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.fetch_nob_feed(uuid, text, text, text, boolean, boolean, integer)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.fetch_nob_feed(uuid, text, text, text, boolean, boolean, integer, integer)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.flag_message_blue(uuid)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.flag_message_gold(uuid)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.flag_room_message_blue(uuid)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.flag_room_message_gold(uuid)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.generate_bff_suggestions(uuid)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.get_own_reaction_counts(uuid, uuid)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.get_own_reaction_counts_batch(uuid[], uuid)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.get_remaining_swipes(uuid)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.handle_new_user_gating()
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.handle_new_user_profile()
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.hard_delete_expired_accounts()
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.increment_nob_count()
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.increment_note_count(uuid)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.increment_profile_views(uuid)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.increment_signal_count(uuid)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.increment_swipe_count(uuid)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.is_discoverable(uuid, text, uuid)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.join_event(uuid, integer)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.join_room(uuid)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.leave_event(uuid)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.leave_room(uuid)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.process_bff_action(uuid, uuid, text)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.process_call_decision(uuid, uuid, boolean)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.process_check_in(uuid, uuid, text)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.recalculate_tiers()
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.safe_advance_to_video(uuid, uuid)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.set_updated_at()
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.set_video_session_expiry()
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.submit_event_checkin(uuid, boolean, boolean, boolean)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.sync_is_verified()
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.trg_room_message_insert()
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.trg_room_participant_delete()
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.trg_room_participant_insert()
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.trigger_push_notification()
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.update_has_pinned_nob()
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.update_last_active(uuid)
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.update_photo_count()
  SET search_path = public, extensions, auth, pg_temp;
ALTER FUNCTION public.update_vitality_decay()
  SET search_path = public, extensions, auth, pg_temp;

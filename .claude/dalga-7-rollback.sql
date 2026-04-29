-- Dalga 7 ROLLBACK — function_search_path_mutable batch fix reversal.
--
-- Use ONLY in emergency. Restoring mutable search_path re-opens the
-- security warning surface (Supabase advisor will flag 60 functions
-- again). All ALTER ... SET search_path values are removed by RESET,
-- returning to PostgreSQL default (caller-controlled search_path).
--
-- This file is standalone (NOT under supabase/migrations/) so it does
-- not auto-apply. Run manually via mcp__supabase__execute_sql or psql.

ALTER FUNCTION public.accept_reach_out(uuid) RESET search_path;
ALTER FUNCTION public.adjust_trust_score(uuid, integer) RESET search_path;
ALTER FUNCTION public.calculate_maturity_score(uuid) RESET search_path;
ALTER FUNCTION public.can_reach_user(uuid, uuid, text) RESET search_path;
ALTER FUNCTION public.can_user_interact(uuid, text) RESET search_path;
ALTER FUNCTION public.check_and_create_match(uuid, uuid, text) RESET search_path;
ALTER FUNCTION public.check_bff_suggestion_limit(uuid) RESET search_path;
ALTER FUNCTION public.check_connection_limit(uuid) RESET search_path;
ALTER FUNCTION public.check_nob_limit(uuid, text) RESET search_path;
ALTER FUNCTION public.check_note_limit(uuid) RESET search_path;
ALTER FUNCTION public.check_reach_out_limit(uuid) RESET search_path;
ALTER FUNCTION public.check_signal_limit(uuid) RESET search_path;
ALTER FUNCTION public.check_swipe_limit(uuid) RESET search_path;
ALTER FUNCTION public.close_inactive_rooms() RESET search_path;
ALTER FUNCTION public.count_filtered_profiles(uuid, text, integer, integer, boolean, boolean, text) RESET search_path;
ALTER FUNCTION public.decrement_rewinds(uuid) RESET search_path;
ALTER FUNCTION public.decrement_super_likes(uuid) RESET search_path;
ALTER FUNCTION public.dev_auto_verify() RESET search_path;
ALTER FUNCTION public.discover_mood_lanes(integer) RESET search_path;
ALTER FUNCTION public.fetch_nearby_profiles(uuid, text, double precision, boolean) RESET search_path;
ALTER FUNCTION public.fetch_nob_feed(uuid, text, text, text, boolean, boolean, integer) RESET search_path;
ALTER FUNCTION public.fetch_nob_feed(uuid, text, text, text, boolean, boolean, integer, integer) RESET search_path;
ALTER FUNCTION public.flag_message_blue(uuid) RESET search_path;
ALTER FUNCTION public.flag_message_gold(uuid) RESET search_path;
ALTER FUNCTION public.flag_room_message_blue(uuid) RESET search_path;
ALTER FUNCTION public.flag_room_message_gold(uuid) RESET search_path;
ALTER FUNCTION public.generate_bff_suggestions(uuid) RESET search_path;
ALTER FUNCTION public.get_own_reaction_counts(uuid, uuid) RESET search_path;
ALTER FUNCTION public.get_own_reaction_counts_batch(uuid[], uuid) RESET search_path;
ALTER FUNCTION public.get_remaining_swipes(uuid) RESET search_path;
ALTER FUNCTION public.handle_new_user_gating() RESET search_path;
ALTER FUNCTION public.handle_new_user_profile() RESET search_path;
ALTER FUNCTION public.hard_delete_expired_accounts() RESET search_path;
ALTER FUNCTION public.increment_nob_count() RESET search_path;
ALTER FUNCTION public.increment_note_count(uuid) RESET search_path;
ALTER FUNCTION public.increment_profile_views(uuid) RESET search_path;
ALTER FUNCTION public.increment_signal_count(uuid) RESET search_path;
ALTER FUNCTION public.increment_swipe_count(uuid) RESET search_path;
ALTER FUNCTION public.is_discoverable(uuid, text, uuid) RESET search_path;
ALTER FUNCTION public.join_event(uuid, integer) RESET search_path;
ALTER FUNCTION public.join_room(uuid) RESET search_path;
ALTER FUNCTION public.leave_event(uuid) RESET search_path;
ALTER FUNCTION public.leave_room(uuid) RESET search_path;
ALTER FUNCTION public.process_bff_action(uuid, uuid, text) RESET search_path;
ALTER FUNCTION public.process_call_decision(uuid, uuid, boolean) RESET search_path;
ALTER FUNCTION public.process_check_in(uuid, uuid, text) RESET search_path;
ALTER FUNCTION public.recalculate_tiers() RESET search_path;
ALTER FUNCTION public.safe_advance_to_video(uuid, uuid) RESET search_path;
ALTER FUNCTION public.set_updated_at() RESET search_path;
ALTER FUNCTION public.set_video_session_expiry() RESET search_path;
ALTER FUNCTION public.submit_event_checkin(uuid, boolean, boolean, boolean) RESET search_path;
ALTER FUNCTION public.sync_is_verified() RESET search_path;
ALTER FUNCTION public.trg_room_message_insert() RESET search_path;
ALTER FUNCTION public.trg_room_participant_delete() RESET search_path;
ALTER FUNCTION public.trg_room_participant_insert() RESET search_path;
ALTER FUNCTION public.trigger_push_notification() RESET search_path;
ALTER FUNCTION public.update_has_pinned_nob() RESET search_path;
ALTER FUNCTION public.update_last_active(uuid) RESET search_path;
ALTER FUNCTION public.update_photo_count() RESET search_path;
ALTER FUNCTION public.update_vitality_decay() RESET search_path;

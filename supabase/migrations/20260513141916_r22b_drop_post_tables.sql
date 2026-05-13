-- =============================================================================
-- R22B — Drop posts + post_reactions + post_comments tables
-- =============================================================================
-- Pre-conditions:
--   - R22A landed on main (commits 01c1118 + c8cf370). Flutter has zero
--     runtime references to these tables or their trigger functions.
--   - Direct grep over lib/ and test/ confirms: no `from('posts')`,
--     no `from('post_reactions')`, no `from('post_comments')`, no RPC
--     calls to fetch_nob_feed / fetch_post_by_id / fetch_comment_counts /
--     fetch_reaction_counts / get_own_reaction_counts / edit_comment /
--     perform_minor_edit / perform_second_thought / fetch_noblara_unread_count.
--
-- What this migration removes:
--   1. Three tables (CASCADE handles attached policies, indexes, triggers):
--        - public.post_reactions  (created 20260329000002)
--        - public.post_comments   (created 20260331000001)
--        - public.posts           (created 20260329000002, rewritten 20260331000002)
--   2. Eight trigger functions that become orphan after CASCADE
--      (each verified to have ZERO other trigger consumers via pg_trigger join):
--        - public.feed_event_comment_added()
--        - public.feed_event_post_published()
--        - public.feed_event_reaction_changed()
--        - public.notify_on_reply()
--        - public.notify_on_reaction()
--        - public.increment_nob_count()
--        - public.update_has_pinned_nob()
--        - public.set_updated_at()
--      Trigger functions return type `trigger` so they cannot be PostgREST RPCs;
--      no public RPC exposure is being closed here. set_updated_at() is named
--      generically but the DB confirms it had only the posts trigger as a
--      consumer (no other table uses it; Noblara appears to use other
--      touch-fn patterns elsewhere).
--
-- What this migration deliberately does NOT touch:
--   - feed_events table — kept intentionally (activity log, used by other
--     features). After this migration it simply receives no new
--     post-related event rows.
--   - Latent RPC orphans whose bodies reference posts but which Flutter
--     never calls: fetch_post_by_id, fetch_nob_feed, fetch_nob_lane,
--     fetch_comment_counts_batch, fetch_reaction_counts_batch,
--     get_own_reaction_counts, get_own_reaction_counts_batch,
--     edit_comment, perform_minor_edit, perform_second_thought,
--     fetch_noblara_unread_count, mark_noblara_notifications_read,
--     fetch_country_insight_data, fetch_country_mood_detail,
--     fetch_country_moods, check_nob_limit, fetch_echo_counts_batch.
--     These remain in pg_proc and will 42P01 if invoked, but are
--     unreachable from the V1 client. Cleanup belongs to R22C.
--
-- FK safety:
--   - Inbound FK check over pg_constraint: zero rows. No KEPT table
--     references public.posts / post_reactions / post_comments,
--     so CASCADE is fully contained to the three target tables.
--
-- Rollback:
--   - None. The CREATE TABLE statements for these tables are not in any
--     versioned migration file (they predate the chronological migration
--     set) and recovery would require pg_dump from a pre-migration
--     snapshot. Risk accepted because the audit, R22A grep, and direct
--     pg_constraint inspection all agree: nothing depends on these objects.
-- =============================================================================

DROP TABLE IF EXISTS public.post_reactions CASCADE;
DROP TABLE IF EXISTS public.post_comments CASCADE;
DROP TABLE IF EXISTS public.posts CASCADE;

DROP FUNCTION IF EXISTS public.feed_event_comment_added();
DROP FUNCTION IF EXISTS public.feed_event_post_published();
DROP FUNCTION IF EXISTS public.feed_event_reaction_changed();
DROP FUNCTION IF EXISTS public.notify_on_reply();
DROP FUNCTION IF EXISTS public.notify_on_reaction();
DROP FUNCTION IF EXISTS public.increment_nob_count();
DROP FUNCTION IF EXISTS public.update_has_pinned_nob();
DROP FUNCTION IF EXISTS public.set_updated_at();

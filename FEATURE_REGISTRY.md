# Noblara Feature Registry
> Source of truth for feature status. Updated: 2026-04-01

## Status Definitions
- **ACTIVE**: Reachable in app, wired end-to-end, changes real state
- **PASSIVE**: Exists in code but not active in user flow
- **UI_ONLY**: Visible but does not affect backend
- **BACKEND_ONLY**: Schema/RPC exists but Flutter never uses it
- **LOCKED**: Intentionally disabled / out of scope
- **DEAD**: Removed in cleanup pass

---

## FILTERS

| Feature | Status | End-to-end? | Files |
|---------|--------|-------------|-------|
| Age range | ACTIVE | Yes - DB `.gte`/`.lte` on `age` | filter_bottom_sheet, feed_repository |
| Max distance | UI_ONLY | No - needs PostGIS | filter_bottom_sheet (slider exists) |
| Trust Shield | ACTIVE | Yes - `is_onboarded` + `nob_tier` filter | feed_repository:50-54 |
| Drinks/Smokes/Nightlife/Routine/Faith | ACTIVE (strict only) | Yes when long-pressed (strict). Preference = no DB effect | feed_repository:68-85 |
| Looking For (dating/bff) | ACTIVE (strict only) | Same as above | feed_repository:87-94 |
| Verified only | ACTIVE | Yes - redundant with base filter | feed_repository:57 |
| Complete only | ACTIVE | Yes - `is_onboarded` | feed_repository:58 |
| Has Nobs | ACTIVE | Yes - `daily_nob_count > 0` | feed_repository:98-99 |
| Has Prompts | ACTIVE | Yes - `prompts_answered >= 2` | feed_repository:103-104 |
| Six+ Photos | UI_ONLY | No - no photo count in profile | filter_bottom_sheet |
| Languages | PASSIVE | Client-side sort only | feed_repository:158-160 |
| Vibes | UI_ONLY | No query effect | filter_bottom_sheet |
| Interests | PASSIVE | Client-side sort only | feed_repository:162-164 |
| Status Badge | ACTIVE | Yes - `nob_tier` filter | feed_repository:60-65 |
| Strict mode (long press) | ACTIVE | Yes - toggles hard vs preference | filter_state.dart |
| Presets | ACTIVE | Yes - applies filter fields | filter_state.dart |
| Oracle counter | ACTIVE | Yes - RPC `count_filtered_profiles` | filter_bottom_sheet |
| Filter persistence | ACTIVE | Yes - SharedPreferences | filter_provider.dart |

## SETTINGS

| Feature | Status | Saved to DB? | Read back? |
|---------|--------|-------------|------------|
| Mode toggles (6x) | ACTIVE | Yes | Not checked in feed queries |
| Incognito mode | UI_ONLY | Yes (written) | Never read |
| Calm mode | UI_ONLY | Yes (written) | Never read |
| Show city only | UI_ONLY | Yes (written) | Never read |
| Hide exact distance | UI_ONLY | Yes (written) | Never read |
| Show last active | UI_ONLY | Yes (written) | Never read |
| Show status badge | UI_ONLY | Yes (written) | Never read |
| Notification prefs | UI_ONLY | Yes (written) | No push system |
| Message preview | UI_ONLY | Yes (written) | Never read |
| Pause account | ACTIVE | Yes - `is_paused=true` | feed_repository filters it |
| Delete account | UI_ONLY | Signs out only | No actual deletion |

## DATING MODE

| Feature | Status | Files |
|---------|--------|-------|
| Swipe (right/left) | ACTIVE | feed_screen, swipe_repository |
| Swipe limit (30/50/100) | ACTIVE | swipe_repository calls `check_swipe_limit` |
| Connection limit (2/4/7) | ACTIVE | swipe_repository calls `check_connection_limit` |
| Signal | ACTIVE | signal_repository |
| Rewind | ACTIVE | feed_provider, super_like_repository |
| Match found | ACTIVE | feed_screen → MatchFoundScreen |
| Mini Intro | ACTIVE | mini_intro_screen |
| Short Intro Rules | ACTIVE | short_intro_rules_screen |
| Video Scheduling | ACTIVE | video_scheduling_screen |
| Video Call | ACTIVE | video_call_screen |
| Post-Call Decision | ACTIVE | post_call_decision_screen |
| Individual Chat | ACTIVE | individual_chat_screen |
| Real Meeting | ACTIVE | real_meeting_screen |
| Check-in | ACTIVE | check_in_screen |

## BFF MODE

| Feature | Status | Files |
|---------|--------|-------|
| AI Suggestions | ACTIVE | bff_screen, bff_provider, RPC `generate_bff_suggestions` |
| Connect/Pass | ACTIVE | RPC `process_bff_action` |
| Reach Out (send) | ACTIVE | bff_suggestion_repository |
| Reach Out (receive) | ACTIVE | bff_screen Reach Outs tab |
| Plan Create | ACTIVE | bff_plan_screen (via chat icon) |
| Plan View | PASSIVE | fetchPlans exists but no list screen |
| Common Ground | ACTIVE (mock/AI) | bff_suggestion_card |

## SOCIAL / EVENTS

| Feature | Status | Files |
|---------|--------|-------|
| Event Feed | ACTIVE | social_events_screen, event_repository |
| Event Create | ACTIVE | create_event_screen (+ AI quality check) |
| Event Join | ACTIVE | RPC `join_event` |
| Event Leave | BACKEND_ONLY | Provider method exists, no UI button |
| Event Detail | ACTIVE | event_detail_screen |
| Event Chat | ACTIVE (realtime) | event_chat_screen + Supabase channel |
| Gold Flag (pin) | ACTIVE | RPC `flag_message_gold` |
| Blue Flag | ACTIVE | RPC `flag_message_blue` |
| Attendance States | ACTIVE | event_participant model |
| Purge Cron | ACTIVE (server) | Migration cron job |
| Event Check-in | ACTIVE | event_checkin_screen → trust_score |

## TIER / MATURITY / TRUST

| Feature | Status | Files |
|---------|--------|-------|
| NobTier (observer/explorer/noble) | ACTIVE | profile.dart, feed_repository, tier_badge |
| Tier Badge | ACTIVE | tier_badge.dart, profile_screen |
| Maturity Score | ACTIVE | profile.dart, auth triggers RPC |
| Profile Strength | ACTIVE | profile_screen (real data) |
| Tier Promotion Screen | ACTIVE | tier_promotion_screen, notification handler |
| Trust Score | PASSIVE | In model, used in tips logic only |

## LOCKED FEATURES (intentionally disabled)
- QR check-in
- Geofence verification
- Real-world forced validation

## REMOVED IN CLEANUP (2026-04-01)
- `filter_options.dart` (superseded by filter_state.dart)
- `social_screen.dart` (placeholder)
- `table_card.dart`, `table_card_widget.dart`, `table_provider.dart`, `group_chat_screen.dart` (old Tables system)
- `usage_limits.dart` (never imported)
- `event_checkin.dart` (never imported, raw params used instead)
- `mode_selection_screen.dart` (never in navigation)
- `_DiagBadge` in app_router.dart (dev artifact)
- `_SocialFeed`, `_TableStack`, `_TableFullSheet` in feed_screen.dart (dead code)

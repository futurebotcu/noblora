# V1 — Remove Meeting / Scheduling Feature Report

**Date:** 2026-05-11
**Branch:** `dalga-v1-remove-meeting-scheduling` (cut from `main` at `f92aee4`)
**Commit:** `b2130c6`

---

## Executive Summary

Pulled the date-meeting / real-meeting / post-meeting-check-in flow entirely from V1. After this change the romantic flow is: **Match → first message → chat.** No meeting CTA, no scheduling UI, no calendar, no post-meeting check-in survey. Generic "if you decide to meet someone, choose a public place and tell a friend" safety copy in Help Center stays (Cleanup PR #50 already removed the feature-flavored "schedule a video call before meeting" language).

BFF "Make a plan" (`bff_plan_screen.dart`) is **kept** — BFF plans are a distinct flow (friendship activities, not romantic meetings) and remain scoped for V1. The shared `SchedulingConfig` time-snap helper stays because BFF reads it.

Backend tables (`public.real_meetings`, `public.check_ins`) are **NOT dropped** — the client surface for them is now zero, so they're safe to leave. Logged below for a V1.x deferred cleanup migration.

**Net code change:** 12 files touched, **−1410 lines** (1427 removed, 17 added — mostly explanatory comments).
**Smoke:** `flutter analyze --fatal-infos` green, `flutter test` 286/286 pass.

---

## Removed UI / Routes

### Files deleted (8 files, 1325 lines)

| File | Lines | Role |
|---|---|---|
| `lib/features/match/real_meeting_screen.dart` | 758 | Date-meeting scheduling UI: date/time picker, location prompt, propose/accept flow |
| `lib/features/match/check_in_screen.dart` | 194 | Post-meeting check-in survey: "Did you meet?", "Was it safe?" prompts |
| `lib/data/models/real_meeting.dart` | 34 | RealMeeting model |
| `lib/data/models/check_in.dart` | 29 | CheckIn model |
| `lib/data/repositories/real_meeting_repository.dart` | 72 | Supabase reads/writes for real_meetings table |
| `lib/data/repositories/check_in_repository.dart` | 69 | Supabase reads/writes for check_ins table |
| `lib/providers/real_meeting_provider.dart` | 136 | Riverpod state for current meeting + pending list |
| `lib/providers/check_in_provider.dart` | 63 | Riverpod state for pending check-ins |

No route definitions to remove — these screens were pushed directly via `Navigator.push` from chat / matches; no named-route table.

### CTAs / entry points removed

| Location | Before | After |
|---|---|---|
| `individual_chat_screen.dart` AppBar (line ~785) | Date: `Plan Meeting` IconButton (handshake icon) routing to `RealMeetingScreen`; BFF: `Make a plan` routing to `BffPlanScreen` (shared widget) | BFF-only: `Make a plan` IconButton gated to `_isBff`; date matches have no scheduling CTA in the AppBar |
| `matches_screen.dart` top of list (line ~372-428) | Pending check-in banner ("You have a pending check-in" → `CheckInScreen`) | Removed entirely; matches list now jumps from header straight to filter chips |
| `match_detail_screen.dart` `_StatusCard._label` (line ~210) | `case 'meeting_scheduled': return 'Meeting Scheduled'` | Removed; legacy status (if it ever surfaces) falls through to default which renders the raw status string |
| `data/models/match.dart` (line ~79) | `bool get hasMeeting => status == 'meeting_scheduled'` | Removed; the getter had zero callers anyway |

---

## Removed Providers / Services / Widgets

- `real_meetingProvider`, `pendingRealMeetingsProvider`, `meetingNotifierProvider` (`lib/providers/real_meeting_provider.dart`) — all 3 Riverpod providers gone with the file
- `checkInProvider`, `pendingCheckInsProvider` (`lib/providers/check_in_provider.dart`) — both gone with the file
- `RealMeetingRepository` + `CheckInRepository` — gone with their files
- No remaining widgets refer to RealMeeting / CheckIn / their providers (verified post-delete via `flutter analyze --fatal-infos` → No issues found! 7.6s)

---

## Removed Text / Localization

Localization layer: this app ships English-only for V1 (per the `project_v1_english_only` memory) — no ARB / l10n files exist, so there are no `.arb` strings to clean up.

Removed in-code copy:

| Source | Text removed |
|---|---|
| `individual_chat_screen.dart` tooltip | "Plan Meeting" |
| `matches_screen.dart` banner | "You have a pending check-in" |
| `match_detail_screen.dart` label | "Meeting Scheduled" |
| `real_meeting_screen.dart` (entire file deleted) | All scheduling-related copy: time pickers, "Propose a Meeting", "Suggested time", "Confirm the time", "Cancel meeting", "Reschedule", etc. |
| `check_in_screen.dart` (entire file deleted) | "Did you meet?", "Was it safe?", "Rate your experience", "Skip" / "Submit", etc. |

---

## Help Center Cleanup

Help Center was already cleaned up by **Cleanup PR #50** (commit `40e957c`) — the historical "schedule a video call" and "video calls and meetings" feature-flavored language was rewritten to the current `match → first message → chat → meet in person` flow. After today's V1 removal, the remaining mentions in `help_center_screen.dart` are:

- `'Likes, matches, chat, and meeting in person'` (Matching & Conversations subtitle, line 398) — generic; "meeting in person" reads as the user's real-life act, not as an app-scheduling feature
- `'• Meet in public places for first meetings.'` (Safety tips, line 539) — generic safety advice
- `'• Tell a friend where you\'re going and who you\'re meeting.'` (line 540) — generic safety advice
- `'• Take time to chat before meeting in person — get a feel for the other person first.'` (line 542) — generic safety advice

These are not feature promises; they're V1-appropriate generic safety copy. **Left in place.** No further Help Center change needed.

---

## Backend Leftovers (deferred cleanup)

The following Supabase artifacts are no longer touched by the client. **NOT dropped in this sprint** per the safety rule:

| Artifact | Type | Reason kept |
|---|---|---|
| `public.real_meetings` | table | Holds historical scheduling rows; no client reader |
| `public.check_ins` | table | Holds historical post-meeting survey rows; no client reader |
| (associated triggers / RPCs from original meeting migrations) | depends | Not enumerated this sprint |

Verified via `information_schema.tables`:
```sql
SELECT table_name FROM information_schema.tables
WHERE table_schema='public' AND table_name IN ('real_meetings', 'check_ins');
-- → both present
```

**Recommended follow-up** (V1.x, separate sprint):

1. `DROP TABLE IF EXISTS public.check_ins CASCADE;` — drops any FKs from associated triggers
2. `DROP TABLE IF EXISTS public.real_meetings CASCADE;` — same
3. Audit any orphan `notification_kind` enum values referencing meeting/check_in pushes (search migrations 20260413000002 + 20260330000003 + 20260401000006); drop unused enum members if any.

Write as a single dated migration `2026XXXX000000_drop_meeting_scheduling_v1_leftover.sql` after V1 has shipped and is stable in production. Do **not** combine with any other schema change.

---

## Tests Updated

No test file references `RealMeeting`, `CheckIn`, `real_meeting`, `check_in`, or `pendingCheckIns` — verified via `grep -rn` across `test/`. Zero test updates needed; the existing 286-test suite continues to pass unchanged.

This is consistent with the dead-code agent finding in `APP_UNDERSTANDING_REPORT.md`: the meeting / check-in features had no UI test coverage, only integration through the deleted screens.

---

## Analyze / Test Results

```
$ flutter analyze --fatal-infos
Analyzing noblara...
No issues found! (ran in 7.6s)

$ flutter test
00:03 +286: All tests passed!
```

Both green post-delete. No broken imports, no unused providers, no failing widget tests.

---

## APK / AAB Build

Both built post-removal:

### APK

| Field | Value |
|---|---|
| Path | `build/app/outputs/flutter-apk/app-release.apk` |
| Size | 57.6MB binary unit (60,445,577 bytes / 60.4MB decimal) |
| Date | 2026-05-11 19:45 |
| Version | `1.0.0+1` |
| Source HEAD | `b2130c6` |
| Build duration | 144.0s (`Gradle task 'assembleRelease'`) |

### AAB

| Field | Value |
|---|---|
| Path | `build/app/outputs/bundle/release/app-release.aab` |
| Size | 45.3MB binary unit (47,531,547 bytes / 47.5MB decimal) |
| Date | 2026-05-11 19:45 |
| Version | `1.0.0+1` |
| Source HEAD | `b2130c6` |
| Build duration | 171.6s (`Gradle task 'bundleRelease'`) |

**Size delta vs pre-removal:**
- APK: 60.6MB → 60.4MB (−131KB, ~−0.2%)
- AAB: 47.6MB → 47.5MB (−76KB, ~−0.2%)

Modest binary win — most of the deleted code was Dart logic + UI widgets, and Flutter's AOT compiler already tree-shakes unreferenced exports. The bigger wins are non-functional: 1325 fewer Dart lines for V1.x audit / maintenance and zero dead provider connections in the Riverpod graph.

Pre-removal artifacts kept as `.bak`:
- `app-release-pre-meeting-removal.apk.bak`
- `app-release-pre-meeting-removal.aab.bak`

---

## Remaining Safe Follow-up

1. **Backend cleanup migration** (V1.x post-launch): drop `real_meetings` + `check_ins` tables + any orphan enum members. See "Backend Leftovers" above for the script.
2. **Verify `notification_kind` enum** has no meeting/check_in members still mapped — if any push triggers reference them, the trigger will silently no-op (sender side) but the enum value will linger.
3. **Search `lib/features/status/status_screen.dart`** for the `'Intros waiting'` stat (line 283) — confirm `pending` count is still meaningful post-removal. The Stat icon (`Icons.schedule_rounded`) is generic Material and stays; only verify the underlying count source isn't computed from a now-absent meeting query.
4. **R16 PR + R14/R15 PR + this PR ordering**: each branch is independent on top of `main` at `f92aee4`. If R16 lands first, this branch needs a clean `git pull --rebase origin main` — no semantic conflict expected, the touched files don't overlap.

---

## Branch state

- Branch: `dalga-v1-remove-meeting-scheduling`
- HEAD: `b2130c6`
- Working tree: clean (gitignored screenshots only)
- Push: pending — push after AAB/APK builds complete

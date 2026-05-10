# Play Store Prep Cleanup Report

**Date:** 2026-05-10
**Branch:** `dalga-cleanup-playstore-prep` (cut from `main` at `db65536`)
**Scope:** User-visible UI honesty cleanup. No new features, no migrations, no redesigns.

---

## What was removed / rewritten

### 1. Settings — placeholder & phantom rows (commit `fe8e478`)

**File:** `lib/features/settings/settings_screen.dart` (-104 lines net)

Rows removed (all were noop or static-modal placeholders):

| Removed row | Why |
|---|---|
| **ID Verification** ("Not yet available", disabled) | Visual placeholder; no implementation date |
| **Safety Tips** (static modal, hardcoded copy) | Same content lives in Help Center "Safety Tips" item |
| **Community Rules** (static modal) | Duplicate of Help Center "Community Guidelines" |
| **Contact Support** (static "email us at..." modal) | Help Center has searchable contact info |
| **Report a Bug** (text input → clipboard copy noop) | Not connected to a real intake — clipboard ≠ submission |
| **Request My Data** (static GDPR/KVKK modal) | Help Center "Can I request my data?" item covers this |
| **Community Guidelines** (static modal) | Already linked from Privacy Policy + Help Center |

Phantom notification toggles trimmed to those whose preference key is enforced server-side in `supabase/functions/send-push/index.ts:216-222 mapTypeToPrefKey()`:

| Toggle | Server map | Action |
|---|---|---|
| **Connections** (`new_match`) | ✓ `new_match` | KEPT |
| **BFF Suggestions** (`bff_connected`) | ✓ `bff_suggestion` | KEPT |
| Messages (`new_message`) | ✗ no map | REMOVED |
| Signals (`signals`) | ✗ no map | REMOVED |
| Notes (`notes`) | ✗ no map | REMOVED |
| Verification (`verification`) | ✗ no map | REMOVED |
| Safety Alerts (`safety`) | ✗ no map | REMOVED |
| Product Updates (`updates`) | ✗ no map | REMOVED |

Server skipped the preference check entirely for unmapped types (line 42-65), so the six removed toggles were lying — user thought they opted out but pushes still arrived. When a new notification type ships, extend the server map first, then add the toggle.

Section rename: "Support" → "Help & Legal" (Help Center + Privacy Policy in one card).

Side cleanup:
- Dropped unused `_showContent` + `_showBugReport` helper methods
- Dropped `_Row.disabled` constructor param (no remaining callers after ID Verification removal)
- Restored `flutter/services.dart` import (HapticFeedback in `_SheetOption`)

---

### 2. Help Center — current flow rewrite (commit `40e957c`)

**File:** `lib/features/settings/help_center_screen.dart` (+15 / -16 lines)

R10 (PR #45) and R11 (migration `20260510000001`) removed the video call system. Help Center still described the deleted flow at six locations, telling users about features that no longer exist.

| Before (stale) | After (current) |
|---|---|
| "mutual like → mini intro → video call → real meeting" | "mutual like → first message → chat → meet in person" |
| "limited window to schedule a video call. After the call, both sides decide whether to continue" | Describes the Bumble-style first-message gate (R11): "match opens with 'send first message' state — once you (or they) send the opener, the chat unlocks for both sides" |
| "Likes, matches, chat, and video calls" (subtitle) | "Likes, matches, chat, and meeting in person" |
| "If neither side schedules a video call within the deadline, the conversation expires" | Replaced with "Why do I have to send the first message?" — explains the actual R11 gate |
| "moving from text to real interaction (video calls and meetings)" | Folded into the new first-message-gate explanation |
| "Use the in-app video call before meeting in person" (Safety tips) | "Take time to chat before meeting in person" |

Also dropped the Noblara Feed step from the "Getting Started → What should I do first?" path list (Feed is gated behind `kSocialEnabled=false`, not user-reachable).

Kept the standalone "Noblara Feed" Help category for now — invisible in nav, harmless if a user is curious. Can be removed in a future pass once the Feed product decision is final.

---

### 3. "Explore Nob Feed" empty-state button (commit `ecfa69c`)

**File:** `lib/features/feed/feed_screen.dart` (-30 lines)

The empty-state button labeled "Explore Nob Feed" actually routed to `MainTabNavigator.switchTab(1)` — the Chats tab, not the Noblara Feed. The Feed itself is gated behind `kSocialEnabled=false` and not surfaced anywhere in the main shell.

Double misleading: wrong label AND wrong destination.

Removed the button entirely. The empty-state copy ("All caught up — Check back soon — new people join every day") stands on its own without an action prompt; pushing users into Chats from a discovery dead-end was unjustified.

Side cleanup: dropped the now-unused `main_tab_navigator` import.

---

### 4. AI output guard (commit `2d5ee2f`)

**File:** `lib/services/gemini_service.dart` (+43 / -2 lines)

Two minimal defensive layers in `analyzeText()`:

**a) Client-side blocklist** (`_outputBlocklist` + `_containsBlockedContent`)

A short list of obvious slurs / profanity terms. Word-boundary regex avoids false positives like "scunthorpe". When a Gemini response trips the filter, `analyzeText()` returns `{'text': ''}` and the caller falls through to its static fallback string.

This is **not** a moderation system. The goal is "never surface a clearly toxic suggestion to the user" as a last-line defense in front of Gemini's own safety filters. Server-side policy is the proper home for richer moderation rules.

**b) Silent error swallowing**

Previously `analyzeText()` threw `Exception('AI service error: $e')` on network/parse/edge-function failures, which sometimes leaked to UI as raw scary text. Now we `debugPrint` and return `{'text': ''}`; every existing caller already has a polite static fallback (e.g. `'Hey $otherName, nice to connect!'`), so the user sees graceful generic copy instead of a stack trace.

No new dependencies, no API surface change. Existing caller try/catch blocks still cover their local `jsonDecode` throws.

---

## Files changed

| File | Lines (+ / -) | Commit |
|---|---|---|
| `lib/features/settings/settings_screen.dart` | +16 / -104 | `fe8e478` |
| `lib/features/settings/help_center_screen.dart` | +15 / -16 | `40e957c` |
| `lib/features/feed/feed_screen.dart` | +0 / -30 | `ecfa69c` |
| `lib/services/gemini_service.dart` | +43 / -2 | `2d5ee2f` |
| **Total** | **+74 / -152** | 4 commits |

Net: **-78 lines** of user-visible misleading or noop UI.

---

## Smoke

| Check | Result |
|---|---|
| `flutter analyze --fatal-infos` | **No issues found! (ran in 20.7s)** ✓ |
| `flutter test` | **286/286 pass** ✓ |
| Settings file (focused) | No issues found! (1.4s) ✓ |
| Help Center file (focused) | No issues found! (1.2s) ✓ |
| Feed file (focused) | No issues found! (1.6s) ✓ |
| Gemini service file (focused) | No issues found! (1.1s) ✓ |

---

## AAB rebuild

| Field | Value |
|---|---|
| Path | `build/app/outputs/bundle/release/app-release.aab` |
| Size | 47.6MB (47,614,972 bytes; Gradle reported 45.4MB binary unit) |
| Date | 2026-05-10 17:38 |
| Version | `1.0.0+1` (`pubspec.yaml`) |
| Build duration | 88.1s (`Gradle task 'bundleRelease'`) |
| Signing | release `signingConfig` from `android/key.properties` → `upload-keystore.jks` (gitignored) |

**Backup chain** (kept for diff/rollback):
- `app-release-pre-R14.aab.bak` — 47.6MB, 2026-05-10 10:40 (pre-R13 merge)
- `app-release-pre-cleanup.aab.bak` — 47.6MB, 2026-05-10 17:14 (post-R14, pre-cleanup)
- `app-release.aab` — 47.6MB, 2026-05-10 17:38 (post-cleanup, current)

Net AAB delta from cleanup: −8KB (negligible — most weight is assets/binaries, not the UI strings we cut).

---

## Branch state

- Branch: `dalga-cleanup-playstore-prep`
- HEAD: `2d5ee2f` (after this report commit becomes HEAD)
- Commits ahead of `main`: 4 (one per concern, split per `feedback_one_pr_one_concern` memory)
- Push status: pending (this report will be the 5th commit on the branch)

---

## Not in scope for this sprint

These were called out in `APP_UNDERSTANDING_REPORT.md` but explicitly deferred:
- Read-receipt UI display verification (chat bubble visualization)
- gemini-text deployed/source drift reconciliation (V1.x note)
- R8/ProGuard hardening (V1.x post-launch)
- Large-file refactor (1000+ line screens — V1.x post-launch tech debt)
- Verification Hub UX polish
- Discover empty-state illustration polish
- Onboarding InfoStep richer copy

These remain blockers-of-polish, not blockers-of-launch.

---

## Next steps (manual, user)

1. Review the 4 cleanup commits + this report
2. Push branch + open PR (`https://github.com/futurebotcu/noblora/pull/new/dalga-cleanup-playstore-prep`)
3. Self-merge
4. Re-build AAB on `main` post-merge (or use the current AAB if HEAD will match after merge)
5. Upload to Play Console Internal Test track
6. Complete the R14 + cleanup smoke checklist on physical device:
   - Sign in works (R14 validation)
   - Settings shows: Account · Privacy & Visibility · Notifications (2 toggles only) · Safety & Verification · Chats · AI Preferences · Help & Legal · Danger Zone
   - Help Center "Getting Started → What is Noblara?" mentions "first message → chat → meet in person" (no video calls)
   - Discover empty state has no "Explore Nob Feed" button
7. On green: promote to Production track

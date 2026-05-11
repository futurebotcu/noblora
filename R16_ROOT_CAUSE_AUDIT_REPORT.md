# R16 Root Cause Audit Report

**Date:** 2026-05-11
**Branch:** `dalga-r16-root-cause-audit` (cut from `main` at `f92aee4`)
**Scope:** Forensic. Read-only. No code changes. No fix applied yet.

---

## Executive Summary

The user's device-level smoke surfaced what *looked* like four loosely related blockers (GPS, manual city, "stuck on You're all set", "restarts onboarding from the top"). R13–R15 patched the symptoms one at a time. R16 audits the state machine end-to-end and finds **two independent root causes** that together explain every observed symptom:

1. **`onboarding_flow_screen._complete()` writes to non-existent DB columns** (`location_lat`, `location_lng`). The `profiles` table has never had these columns — they only ever existed on the dropped `social_events` table. **Every onboarding save where GPS or manual-city-with-coords succeeded has been failing with Supabase 400 since the very first commit of this file.** R15 made the failure *visible* (throw + toast) but didn't fix the payload. Smoking-gun proof: today's api logs show `PATCH /profiles` × 2 at status 400 from device `fe35aa23` (fatihkartal75), 1 second apart — exactly the R15 retry loop fingerprint.

2. **`fatihkartal75@gmail.com` has `display_name = ""`** (NOT NULL DEFAULT `''` from the schema) **and `is_onboarded = true`**. Router asks `!hasProfile || !hasGender` (profile_provider.dart:25-30); `hasProfile` requires `displayName.trim().isNotEmpty`. Result: every time Fatih signs in, the router sends him to `OnboardingFlowScreen` — not because the app is "starting from scratch," but because the profile row exists in a half-finished state that the router treats as incomplete. The user perceives this as "the app keeps restarting onboarding on me."

Combined effect: Fatih signs in → router sends him to onboarding (cause #2) → he fills it out → tries to save → save fails (cause #1) → toast → he can't escape.

A third, smaller issue: **`profiles.accent_color` has DB-level default `'gold'`** even after R15 client-side default flipped to `'emerald'`. Old rows (testfeed1) still read `'gold'` and surface in fresh installs once `syncFromSupabase()` runs.

**No fix has been applied in this branch.** This report names the minimum change set that would close all three.

---

## Actual Router State Machine

**File:** `lib/navigation/app_router.dart:140-181`

Top-to-bottom decision flow (every state change re-evaluates):

| # | Condition | Destination |
|---|---|---|
| 1 | `!auth.isInitialized` | `_splash('initializing…')` |
| 2 | `!auth.isAuthenticated` | `WelcomeScreen` |
| 3 | `_bootstrappedUserId != auth.userId` (bootstrap pending) | `_splash('loading…')` |
| 4 | `verif.isLoading` | `_splash('loading verifications…')` |
| 5 | `!profile.hasProfile \|\| !profile.hasGender` | **`OnboardingFlowScreen`** |
| 6 | (default — all clear) | `MainTabNavigator` |

**Completeness contract** (`lib/providers/profile_provider.dart:25-30`):

```dart
bool get hasProfile =>
    profile != null && profile!.displayName.trim().isNotEmpty;

bool get hasGender =>
    profile?.gender != null && profile!.gender!.isNotEmpty;
```

Two fields drive the entire onboarding-vs-main-app decision: `display_name` (non-empty after trim) and `gender` (non-null + non-empty). **Nothing else gates this route** — not `is_onboarded`, not `city`, not `country`, not `age`, not photos.

**Mapped against the user reports:**

| Auth state | profile row | `display_name` | `gender` | Router goes to | Matches user complaint? |
|---|---|---|---|---|---|
| null | n/a | n/a | n/a | WelcomeScreen | n/a |
| signed in | null (no row) | n/a | n/a | OnboardingFlow | "first install onboarding" — expected |
| signed in | present | `""` (empty) | `'male'` | **OnboardingFlow** | **fatihkartal75 — "app keeps restarting onboarding"** |
| signed in | present | `'eagleyetrader'` | null | OnboardingFlow | latent — would also restart if user signs in |
| signed in | present | `'FeedTest 1'` | `'male'` | MainTabNavigator | testfeed1 — works |
| signed in | present | `'trultruva'` | `'female'` | MainTabNavigator | trultruva — works |

---

## Profile Completion Requirements

Per the code, **only two fields are required to leave onboarding**: `display_name` and `gender`. Everything else is collected during onboarding but not enforced by the router. Specifically:

| Field | Required by router? | Required by `_validateCompletion()`? | Required by `_complete()` save? | Required by DB schema? |
|---|---|---|---|---|
| `display_name` | **yes** | yes (line 82: `nameCtrl.text.trim().isEmpty`) | sent unconditionally | NOT NULL DEFAULT `''` |
| `gender` | **yes** | implicit (default `'female'`) | sent unconditionally | NULLABLE |
| `age` | no | implicit via `_BasicsPage._canContinue ≥ 18` | sent unconditionally | NULLABLE |
| `looking_for` | no | no | hardcoded `'Serious relationship'` | NULLABLE |
| `city` | no | no | sent only if `_city.isNotEmpty` (R15 change) | NULLABLE |
| `country` | no | no | sent only if `_country.isNotEmpty` | NULLABLE |
| `from_country` | no | no | not sent in `_complete` (Profile Edit only) | NULLABLE |
| `location_lat` | no | no | **sent if `_locationLat != null` — DOES NOT EXIST IN DB** | column missing |
| `location_lng` | no | no | **sent if `_locationLng != null` — DOES NOT EXIST IN DB** | column missing |
| `place_id` | no | no | not sent in `_complete` (Travel mode only) | NULLABLE |
| `travel_mode` | no | no | not sent in `_complete` | NOT NULL DEFAULT `false` |
| `date_avatar_url` | no | photo OR avatar required (line 83) | sent (nullable) | NULLABLE |
| `avatar_id` | no | same as above | sent if non-null | NULLABLE |
| `is_onboarded` | **NOT consulted** | n/a | hardcoded `true` | NULL DEFAULT `false` |
| privacy step toggles (incognito, calm, show_last_active, …) | no | no | hardcoded defaults | NOT NULL with defaults |

**Critical observation:** `is_onboarded` is a column in the DB and gets set to `true` at the end of onboarding, **but the router never reads it.** Both the router and the existing user check rely on `display_name` + `gender`. If either is empty/null, the user re-enters onboarding regardless of `is_onboarded`.

---

## Existing User DB State (live, 2026-05-11)

Pulled from `auth.users JOIN profiles`:

| email | last_sign_in | `display_name` | `gender` | `age` | `city` | `country` | `is_onboarded` | `accent_color` | router goes to |
|---|---|---|---|---|---|---|---|---|---|
| **`fatihkartal75@gmail.com`** | **2026-05-11 15:34:49** | **`""`** | `'male'` | null | null | null | `true` | `'emerald'` | **OnboardingFlow** |
| `testfeed1@test.noblara.com` | 2026-05-10 12:11 | `'FeedTest 1'` | `'male'` | 21 | null | null | `true` | `'gold'` ⚠ | MainTabNavigator |
| `trultruva@gmail.com` | 2026-05-06 12:32 | `'trultruva'` | `'female'` | null | null | null | `true` | `'emerald'` | MainTabNavigator |
| `eagleyetrader@gmail.com` | 2026-05-05 15:46 | `'eagleyetrader'` | **null** | null | null | null | `true` | `'gold'` ⚠ | OnboardingFlow (latent) |

**Why fatihkartal75 restarts onboarding:** `display_name = ""` (the schema default; never overwritten with a real name) → `profile.displayName.trim().isEmpty` → `hasProfile = false` → router takes branch #5.

**Why testfeed1 still shows gold accent:** the DB default for `accent_color` is `'gold'`, set when the row was seeded; R15 client-side default flip doesn't rewrite existing rows. `syncFromSupabase()` reads `'gold'` back and applies it.

---

## Why Existing User Restarts Onboarding

The "first onboarding screen showing for an existing user" symptom from R15 is **not a bug** — it's the router doing exactly what its contract says. The bug is **upstream**: the `fatihkartal75` profile row was created at signup-time with `display_name = ''` (DB default) and never got a real name written to it, because **every subsequent `_complete()` save attempt has failed at the Supabase 400 step** (cause #1 below). The user enters onboarding → completes it → hits Save → fails → starts over next session.

**Evidence chain:**

1. `auth.users.created_at` for fatihkartal75: **2026-03-28 20:13:46** (~6 weeks ago)
2. `profiles.updated_at` for fatihkartal75: **2026-03-28 20:13:46** (same instant — the row was seeded by signup but never successfully updated by user-driven flow)
3. `display_name = ""` matches the schema default `''` — the user never made it through `_complete()`
4. `gender = 'male'` was set later — likely by a previous code path that wrote `gender` independently (the `profileProvider.notifier.updateGender()` call in `_complete` line 181, which runs after the save retry; it still hit because `updateGender()` only writes `gender` + `is_onboarded`, neither requires `location_lat`)
5. The current API logs show the same 400 failures happening today at 15:35:38 — the save has been broken *consistently* for the entire 6-week period

---

## Manual City Flow

**File:** `lib/shared/widgets/city_search_screen.dart`

| Step | What happens |
|---|---|
| User types in search field | `_onSearchChanged` → 350ms debounce → `locationRepositoryProvider.searchPlaces(query)` (places-proxy autocomplete) |
| User taps a prediction | `_selectPlace(prediction)` |
| Inside `_selectPlace` | calls `locationRepositoryProvider.fetchPlaceDetails(prediction.placeId)` (places-proxy details) |
| Place details response | extracts `lat`, `lng` from `geometry.location`; extracts `country` long_name; extracts R13-enriched `countryCode` short_name |
| Callback fired | `widget.onSelected(mainText, country, lat, lng, countryCode, placeId)` |
| Onboarding receives | `_LocationPage` `onLocationSet(city, country, lat, lng)` → sets `_city/_country/_locationLat/_locationLng`; **separately** `onCountryCodeSet(countryCode)` |

**Fallback path** (details call fails — `places-proxy` 401/timeout/etc.) at `city_search_screen.dart:130-138`:

```dart
widget.onSelected(
  prediction.mainText,
  prediction.secondaryText,   // ← used as country (not really country, just sub-label)
  null,                       // ← lat null
  null,                       // ← lng null
  null,                       // ← countryCode null
  prediction.placeId,
);
```

**Key observation:** when fetchPlaceDetails *succeeds*, `_locationLat` and `_locationLng` are set non-null → `_complete` includes `location_lat`/`location_lng` in the payload → **save fails 400.** When fetchPlaceDetails *fails*, lat/lng are null → `_complete` *omits* them via the `if (_locationLat != null)` guard → save would have a chance to succeed.

This is why the user can't tell where the bug lives. The same UI behavior (pick city, tap continue) sometimes "almost works" and sometimes fails immediately, depending on whether places-proxy details succeeded or not.

**Continue button condition** (`_LocationPage` line 773): `hasLocation = widget.city.isNotEmpty` — only checks `_city`, doesn't care about lat/lng. So manual city is "valid" from the onboarding UI's point of view even when lat/lng are missing.

---

## Complete Page Save Flow

`_CompletePage` "Enter Noblara" button (`onboarding_flow_screen.dart:1090-1119`, post-R15):

1. `setState(_loading = true)`
2. `await widget.onComplete().timeout(Duration(seconds: 15))` — `widget.onComplete` = `_OnboardingFlowState._complete`
3. **On success:** `setState(_loading = false)` (R15 added this defensively)
4. **On exception:** `setState(_loading = false)` + toast branched by `e is TimeoutException`

`_complete()` body (post-R15, `onboarding_flow_screen.dart:87-194`):

| Step | Result on fatihkartal75 today |
|---|---|
| `_validateCompletion()` (name+photo) | ✓ user filled in both |
| `ref.read(authProvider).userId` non-null check | ✓ signed in as `fe35aa23-...` |
| Photo upload via `storageRepositoryProvider` | ✓ succeeded earlier (`has_avatar=true`) |
| `profileRepositoryProvider.updateProfile(uid, payload)` (retry 1) | **✗ 400** — proven by api logs 15:35:38.376 |
| Retry 2 (200ms later) | **✗ 400** — proven by api logs 15:35:39.067 |
| R15-added `throw Exception('Profile save failed: $lastError')` | ✓ thrown |
| Caller (`_CompletePage`) catch block | toast "We couldn't save your profile…" |
| `_loading = false` defensively | ✓ |
| `createProfile` + `updateGender` never reached (R15: above throw aborts) | ✓ |

**The save fails because the payload contains `location_lat: <number>` and `location_lng: <number>`.** Supabase rejects unknown columns at 400. The retry doesn't help — same payload, same column-not-found.

What R15 actually did: previously this failure was silent and the cascade continued. Post-R15 it's a user-visible toast with a working retry button. **The retry will keep failing as long as the payload is wrong**, but at least the user knows.

---

## Suspected Root Cause With Evidence

### Root cause #1 — non-existent columns in onboarding save payload

| Evidence | Source |
|---|---|
| `profiles` table column inventory (no `location_lat`, no `location_lng`) | `information_schema.columns` query — only `location` (USER-DEFINED, likely PostGIS), `device_platform`, etc. |
| Only place `location_lat`/`location_lng` columns exist in migrations | `grep -rn "location_lat\|location_lng" supabase/migrations/` → only `20260401000002_social_events.sql:18-19` (events table, dropped 2026-05-04) |
| Onboarding still sends these fields | `lib/features/onboarding/onboarding_flow_screen.dart:163-164` |
| Live PATCH failure | api logs `2026-05-11 15:35:38.376` + `15:35:39.067` — both `PATCH /profiles?id=eq.fe35aa23-…` → 400, Dart/3.9 user-agent, 691ms apart (R15 retry fingerprint) |
| Profile model does not declare these fields | `grep -nE "locationLat\|locationLng\|location_lat\|location_lng" lib/data/models/profile.dart lib/features/profile/edit/profile_draft.dart` → 0 hits |

**Verdict:** the two lines have been broken since they were written. R10/R11/R12/R13/R14/R15 never touched them. Removing them is the entire fix.

### Root cause #2 — `fatihkartal75` row in zombie state

| Evidence | Source |
|---|---|
| `display_name = ""` (schema default) | DB query result above |
| `updated_at = 2026-03-28 20:13:46` (same as `created_at`) | Same row |
| Router contract requires `display_name.trim().isNotEmpty` for `hasProfile` | `lib/providers/profile_provider.dart:25-26` |
| Failed PATCH today shows `_complete()` still can't write | api logs (above) |

**Verdict:** Fatih has been in this loop for 6 weeks; every signup-era `_complete()` failed at the same payload bug. After cause #1 is fixed, his row can finally take a real `display_name` write. **Or** the row can be one-off DB-fixed today (set `display_name='Fatih'` or similar) to unblock his testing while the code fix ships.

### Root cause #3 — `accent_color` DB default still `'gold'` (post-R15)

| Evidence | Source |
|---|---|
| `column_default = "'gold'::text"` for `accent_color` | `information_schema.columns` query |
| `testfeed1.accent_color = 'gold'` (DB) | DB query above |
| Client-side `AppearanceState.accentId = 'emerald'` (post-R15) | `lib/providers/appearance_provider.dart:17` |
| `syncFromSupabase()` overwrites client default with server value | `lib/providers/appearance_provider.dart:55-71` |

**Verdict:** R15 only handles the case where Supabase has no preference yet (sync fallback at line 64). Existing rows or new signups (where DB default fires) keep getting `'gold'`. A 1-line ALTER TABLE migration would clean this.

---

## Fix Options

I'm not applying any of these — listing them so we can pick.

### Option A — Code-only minimal fix (recommended)

| File | Change |
|---|---|
| `lib/features/onboarding/onboarding_flow_screen.dart` | Delete lines 163-164 (`location_lat` + `location_lng` payload entries). The local `_locationLat` / `_locationLng` state vars can stay; they're harmless and useful if the columns are ever added. |

That's the entire code fix. Six characters of `if` clauses + comma vanish; save starts succeeding for every user who reached the location step.

### Option B — DB cleanup for fatihkartal75 (one-off, optional)

```sql
UPDATE profiles SET display_name = 'Fatih' WHERE id = 'fe35aa23-f2b5-4150-852e-b94db5739848';
```

Frees the test account immediately without waiting for the code fix to ship. Pure data cleanup; no schema change.

### Option C — DB default flip for `accent_color` (optional, follow-up)

```sql
ALTER TABLE profiles ALTER COLUMN accent_color SET DEFAULT 'emerald';
```

One-line migration. Existing rows keep their current `accent_color` (no UPDATE), but new signups + manual NULL inserts now land on `'emerald'`. Pairs with R15's client-side fix.

### Option D — Schema extension (NOT recommended in this sprint)

Adding `location_lat double precision, location_lng double precision` to `profiles` is the *only* path that preserves the lat/lng data the user provides. The cost is a new migration + a model field + a fromJson/toJson + a draft mapping + a Profile.copyWith — all the R1 4-tuple discipline. Distance-based discovery currently uses `fetch_nearby_profiles` RPC; needs review of whether that RPC already reads these from somewhere else (e.g. `location` PostGIS column) before this is justified. **Out of R16 scope.**

### Option E — Onboarding contract revisit (NOT recommended)

Making the router consult `is_onboarded` in addition to `display_name + gender` would change route semantics for *every* user, including testfeed1. High blast radius for a non-bug; the current contract is fine.

---

## Recommended Minimal Fix

**Option A + Option B + Option C, in that order, in three separate commits.**

- **A** unblocks every new signup permanently (six-character code change).
- **B** unblocks Fatih's existing test account right now without a code re-deploy (one DB UPDATE; safe to apply because no other user has this row).
- **C** stops new gold installs (one ALTER TABLE; matches the R15 spirit at the DB layer).

After A+B+C ship, the symptoms reported in R15 ("first onboarding screen shows even for existing user," "save fail toast," "stuck on you're all set") all stop reproducing.

**Estimated effort:** 5 minutes of edits, 1 minute of SQL, 1 minute of migration write. The R15 throw/toast/spinner-reset work stays in place — A doesn't undo it, just removes the underlying cause.

---

## What NOT To Patch

- ❌ Don't add `location_lat`/`location_lng` to the `profiles` table (Option D) just to "make the payload valid." Discovery distance is already served by `fetch_nearby_profiles` RPC and the legacy `location` USER-DEFINED column; we don't know yet whether duplicating into plain doubles helps. Defer this until R-distance-RPC audit.
- ❌ Don't change the router contract (Option E). `display_name + gender` is the right minimal completeness signal; the current bug is that signups can't *write* a `display_name`, not that the router is reading the wrong field.
- ❌ Don't apply R15-style "throw + toast" again. R15 was correct — make the failure visible. R16 is about removing the underlying failure.
- ❌ Don't add diagnostic `[NOB_R16_TRACE]` logs. The API logs already show the 400 PATCH. We have the smoking gun without a custom trace build.
- ❌ Don't bump version to 1.0.0+2 yet. Hold off; ship A+B+C in a single PR (R16), bump versionCode there.

---

## Cross-check: secondary anomalies observed

Surfaced during the audit, **not blockers** for the V1 smoke but worth noting:

1. **`filter_discoverable_ids` RPC → 400** (api logs today 15:34:53 + 2026-05-10). Used by R13 batch filter. May be tied to country gating; verify post-R16.
2. **`calculate_maturity_score` RPC → 404** (2026-05-10 16:44). Function may have been dropped or renamed; AuthNotifier.initialize() calls `recalculateMaturityScore` fire-and-forget so the 404 is silently swallowed. Worth a follow-up.
3. **`profiles.location` USER-DEFINED column** exists (PostGIS geometry, likely the actual home for coordinates) but nothing in lib/ writes to it. The `fetch_nearby_profiles` RPC likely reads from it. If we ever resurrect lat/lng persistence, route through this column, not new plain doubles.

These are flagged for a post-V1 audit, not part of R16.

---

## Branch state

- Branch: `dalga-r16-root-cause-audit`
- HEAD: `f92aee4` (no commits added beyond this report)
- Working tree: one new untracked file (`R16_ROOT_CAUSE_AUDIT_REPORT.md`)
- **No code changed. No migration written. No fix applied.**

Waiting on user direction:
- Apply A only (minimal)
- Apply A + B (minimal + Fatih test-account unblock)
- Apply A + B + C (full recommended)
- Different decision

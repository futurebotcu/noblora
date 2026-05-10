# R15 Release Smoke Bugfix Report

**Date:** 2026-05-10
**Branch:** `dalga-r15-release-smoke-bugfix` (cut from `main` at `dcf2c14`)
**Trigger:** Physical-device Internal Test smoke surfaced four blockers preventing onboarding completion.
**Scope:** Bug fixes only — no new features, no migrations, no schema changes.

---

## Executive Summary

The user installed the post-cleanup release AAB on a physical device and ran through onboarding. Five user-visible blockers appeared:

1. The OS location permission popup never showed
2. "Where are you based?" felt non-functional
3. The "You're all set, Fatih" screen froze with the spinner
4. A "Profile save failed" toast surfaced with no recovery path
5. Several screens leaked Bumble-style yellow buttons

R15 fixes all five with **four small commits** (no UI redesign, no schema change). The combined fix + post-merge build is in `app-release.aab` (47.6MB, v1.0.0+1, 2026-05-10 18:35) and is ready for re-upload to Play Console Internal Test.

`flutter analyze --fatal-infos` and `flutter test` are both green post-fix.

---

## Bugs Reproduced / Root Cause

### Bug 1 — "Yellow leftovers" everywhere (highest visibility)

**Root cause:** `lib/providers/appearance_provider.dart` had three default-fallback constants all set to `'gold'` — even though `AppColors.accents` lists `emerald` with `isDefault: true`.

| Site | Effect |
|---|---|
| `AppearanceState` constructor (line 17) | First-paint-before-load default |
| `_loadLocal()` SharedPreferences fallback (line 50) | Fresh install / cleared cache default |
| `syncFromSupabase()` server-null fallback (line 64) | New user with no `accent_color` row |

Result: every fresh install rendered the entire UI in Bumble-yellow (Sign In button, primary CTAs, GPS button, success accents). The gold accent is meant as an opt-in premium choice, not the V1 default. **All three changed to `'emerald'`.** The runtime `isGold` getter was preserved (`accentId == 'gold'`).

### Bug 2 — Permission popup never showed

**Root cause:** `LocationService.getCurrentPosition()` collapsed every failure path to `null` (service disabled, denied, deniedForever, position unavailable, geocoding error). The caller (`_LocationPage._useGPS`) could only show one generic message — **the user had no idea whether the popup was suppressed because permission was already denied-permanent, OS location services were off, or something else.**

`AndroidManifest.xml` was already correct (ACCESS_FINE_LOCATION + ACCESS_COARSE_LOCATION declared). The plugin wiring was fine; the UX was the problem.

### Bug 3 — "Where are you based?" felt broken

**Root cause:** Same as Bug 2 — when GPS failed, the only visible feedback was `_error = 'Could not detect location. Try searching manually.'`. No retry hint, no Settings shortcut, no service-toggle hint. Manual fallback (`_openSearch`) was already wired, but the user had no clear cue that it was the path forward.

### Bug 4 — "You're all set, Fatih" frozen spinner

**Two cascading bugs:**

1. **`_complete()` swallowed save failures.** The DB save loop caught both retry attempts and only toasted on the second failure, but **continued execution** to call `createProfile()` + `updateGender()` — which also failed (no row to refresh from), again silently. Net effect: every error path looked identical to the caller, AppRouter never observed a profile state change, and the button stayed disabled with the spinner running.

2. **`_CompletePage.onPressed` only reset `_loading=false` in the catch block.** On *success* the screen relied on AppRouter to unmount it before the user noticed. If the router rebuild was delayed (or — per Bug 4.1 — prevented by silent cascade), the spinner kept spinning forever.

### Bug 5 — "Profile save failed" with no recovery

**Root cause:** The save retry loop produced a generic toast and then continued the cascade described in Bug 4.1. The user had no actionable next step — was their connection bad? Was their location wrong? Should they retry? The toast didn't say.

### Bug 6 — "First onboarding screen not showing" (NOT REPRODUCED)

The user reported "ilk ekranda beklenen onboarding görünmüyor." Code-level audit:
- `AppRouter` already routes to `OnboardingFlowScreen` whenever `!profile.hasProfile || !profile.hasGender` (`app_router.dart:171`)
- `SignUpScreen` after successful signup pops to root (`Navigator.popUntil(isFirst)`), which triggers `AppRouter.build()` re-evaluation; new sign-ups should land on `_WelcomePage` (step 0)
- No SharedPreferences key gates the onboarding entrance — every `!hasProfile || !hasGender` user re-enters at step 0

We could not reproduce this from code alone. Possible scenarios (need user clarification): (a) the device was already signed in as `fatihkartal75` with `hasProfile=true && hasGender=true` (would route directly to Discover; not technically a bug), (b) the user expected a Welcome screen variant that doesn't exist, (c) a transient state during smoke. **No code change for now** — left as a follow-up if the device retest still hits it after the four fixes ship.

---

## Location Permission Fix

**File: `lib/core/services/location_service.dart`** — rewritten with explicit status reporting.

```dart
enum LocationStatus {
  success,
  denied,                  // first-time prompt declined or "Deny" tapped
  deniedForever,           // "Don't ask again" — must visit App Settings
  serviceDisabled,         // OS-level GPS toggle off
  positionUnavailable,     // permission OK but read failed (timeout / no fix)
}

class LocationResult { /* status + city/country/coords */ }
```

- New `getLocationFromGPS()` returns `LocationResult` (was `Map<String,dynamic>`)
- `getCurrentPosition()` Position fix wrapped in 12s timeout (avoid hung GPS)
- Two new helpers: `openAppSettingsPage()`, `openLocationSettings()`

**File: `lib/features/onboarding/onboarding_flow_screen.dart` `_LocationPage`** — UX rewritten as a status switch:

| Status | Message | Extra action |
|---|---|---|
| `success` | (no error) | proceed to next step |
| `denied` | "Permission denied. Tap 'Use my location' again to retry, or pick your city below." | retry by tapping again |
| `deniedForever` | "Location access is blocked for Noblara. Open Settings to allow it, or pick your city manually below." | **Open Settings** button |
| `serviceDisabled` | "Location services are turned off. Turn them on in your device Settings, or pick your city manually below." | **Open Settings** button |
| `positionUnavailable` | "Couldn't read your location right now. Try again or pick your city manually below." | retry |

**Manual city search remains the always-available fallback.** The user can never get locked at this step regardless of permission state.

---

## Profile Save Fix

**File: `lib/features/onboarding/onboarding_flow_screen.dart` `_complete()`** — error propagation rewritten.

Before: save fail → silent toast → cascade to `createProfile/updateGender` → profile state never updated → CompletePage stuck.

After: any failure throws with a real exception attached:
- Missing required fields → `Exception(error)`
- No auth uid → `Exception('Not signed in...')`
- Both DB save retries exhausted → `Exception('Profile save failed: $lastError')`
- `createProfile`/`updateGender` errors propagate naturally (try/catch removed)

Also: `_city` is now sent only when non-empty (`if (_city.isNotEmpty) 'city': _city`). Previously `''` was always sent — fine on a TEXT NULL column but persists empty strings for users who skipped the GPS step.

---

## "You Are All Set" Navigation Fix

**File: `lib/features/onboarding/onboarding_flow_screen.dart` `_CompletePage` button onPressed** — both paths now reset `_loading`:

```dart
try {
  await widget.onComplete().timeout(const Duration(seconds: 15));
  // Success: AppRouter listens to profileProvider and will unmount this
  // screen on the next frame. Reset _loading defensively in case the
  // router rebuild is delayed.
  if (!mounted) return;
  setState(() => _loading = false);
} catch (e) {
  if (!context.mounted) return;
  setState(() => _loading = false);
  final msg = e is TimeoutException
      ? 'This is taking longer than expected. Please check your connection and try again.'
      : "We couldn't save your profile. Please check your location or try again.";
  ToastService.show(context, message: msg, type: ToastType.error);
}
```

Error messages are now actionable:
- `TimeoutException` → connection hint
- All other errors → save / location hint
- Replaces the old generic "Something went wrong"

`mounted` check switched to `context.mounted` to satisfy `use_build_context_synchronously` lint.

---

## Onboarding Entry Fix

**Code-level audit confirmed:** `AppRouter` already routes `!hasProfile || !hasGender` users to `OnboardingFlowScreen`. No code change applied.

The reported symptom ("ilk ekranda beklenen onboarding görünmüyor") could not be reproduced from source. Most likely the device was already signed in as a user whose profile was complete enough to bypass onboarding — needs a user-side retest with a fresh sign-up to confirm.

If the symptom persists post-R15, candidates for follow-up:
- Whether the test sign-up email got auto-confirmed, returning a session before the profile row was created
- Whether `SignUpScreen` "Check your email" flow leaves the user in an in-between state where Welcome no longer renders

---

## Yellow Color Cleanup

| Location | Before | After |
|---|---|---|
| `appearance_provider.dart` (3 sites) | default accent `'gold'` | default accent `'emerald'` |
| `travel_mode_section.dart:162` (warning icon) | `Colors.orange` (raw Material) | `AppColors.warning` (theme token) |

The `AppColors.gold` usages in `interaction_gate_provider.dart` and `widgets/locked_swipe_banner.dart` are **intentional** (premium-tier indicator for noble-tier locked features) and left in place per "no big redesign" sprint scope.

`grep -rn "Colors.yellow\|Colors.amber\|Colors.orange" lib/` returns **zero matches** post-fix.

---

## Tests

No new widget/unit tests added — every fix is wired to existing flows (`profileProvider`, AppRouter, LocationService, AppearanceState) that don't have UI test coverage in this sprint scope. Adding scenarios for permission-state branching + save-fail retry would be a V1.x test-coverage sprint item.

| Check | Result |
|---|---|
| `flutter analyze --fatal-infos` (full project) | **No issues found! (ran in 5.8s)** ✓ |
| `flutter test` (full suite) | **286/286 pass** ✓ |
| Per-file analyze | All 4 changed files green ✓ |

---

## AAB Build

| Field | Value |
|---|---|
| Path | `build/app/outputs/bundle/release/app-release.aab` |
| Size | 47.6MB (47,607,706 bytes; Gradle reported 45.4MB binary unit) |
| Date | 2026-05-10 18:35 |
| Version | `1.0.0+1` (`pubspec.yaml`) |
| Build duration | 100.8s (`Gradle task 'bundleRelease'`) |
| Signing | release `signingConfig` from `android/key.properties` → `upload-keystore.jks` (gitignored) |

**Backup chain** (all kept for rollback / diff):
- `app-release-pre-R14.aab.bak` — 2026-05-10 10:40 (pre-R13/R14)
- `app-release-pre-cleanup.aab.bak` — 2026-05-10 17:14 (post-R14, pre-cleanup branch)
- `app-release-pre-cleanup-merge.aab.bak` — 2026-05-10 17:38 (post-cleanup branch, pre-PR #50 merge)
- `app-release-pre-R15-location-onboarding-fix.aab.bak` — 2026-05-10 17:51 (post-cleanup-merge, pre-R15)
- `app-release.aab` — 2026-05-10 18:35 (post-R15, current)

Net AAB delta from R15: −7KB (negligible — fixes are surgical).

---

## Remaining Risks

1. **"First onboarding screen not showing"** — could not reproduce from source. Requires user retest with a fresh sign-up email after this AAB ships. If the symptom persists, investigation moves to `SignUpScreen` email-confirmation flow.
2. **Read-receipt UI** — flagged in `APP_UNDERSTANDING_REPORT.md` as "DB ready, UI unclear." Not touched in this sprint; out of R15 scope.
3. **AI moderation** — basic blocklist already shipped in cleanup PR #50. No richer policy in R15.
4. **R8/ProGuard** — still disabled. Sign-in works in release without R8 (R14 verified at the source level), but enabling minification post-V1 will need Supabase reflection rules.
5. **AppearanceProvider Supabase sync** — if a user previously persisted `accent_color: 'gold'` to their profile, the `syncFromSupabase` path will restore gold even after this fix. The default-fallback fix only helps **new** rows / null `accent_color` columns. Existing user accounts (testfeed1, fatihkartal75, etc.) keep their old preference. This is acceptable: the user can change accent from Settings; we're only fixing the V1 first-paint default.
6. **`_city.isNotEmpty` send** — if a downstream feature reads `profiles.city` and assumes non-null, it could see `null` for users who skipped GPS in onboarding. Not currently observed; flagged for V1.x audit.

---

## Physical Device Retest Checklist

Re-upload `app-release.aab` (2026-05-10 18:35) to Play Console Internal Test track, install on the physical device, then verify:

**Default accent / yellow leftovers:**
- [ ] Welcome screen "Sign In" button is **emerald green**, not yellow
- [ ] "Create Account" outline button border is emerald
- [ ] Onboarding "Begin" button is emerald
- [ ] All primary CTAs across screens are emerald

**Onboarding entry:**
- [ ] Fresh sign-up email → after submit, lands on Welcome step (1/8 progress, "Begin" button)
- [ ] (If "first screen missing" reproduces, capture which screen actually appeared first and report back)

**Location permission flow ("Where are you based?"):**
- [ ] Tap "Use my location" → OS permission popup appears
- [ ] Tap "Allow" → city/country resolves and shows in the result card
- [ ] Tap "Don't allow" → in-app message: "Permission denied. Tap 'Use my location' again to retry, or pick your city below."
- [ ] If permission was denied permanently in a previous run → "Open Settings" button appears
- [ ] If location services off at OS level → "Turn them on..." message + "Open Settings" button
- [ ] Manual "Or search manually" link always works → opens city search
- [ ] After picking any city → "Continue" button enables

**Profile save:**
- [ ] "You're all set, Fatih" screen shows after Privacy step
- [ ] Tap "Enter Noblara" → spinner, then transition to Discover (or onboarding completes successfully)
- [ ] If save fails → toast: "We couldn't save your profile. Please check your location or try again." + button re-enabled (no infinite spinner)
- [ ] If timeout → toast: "This is taking longer than expected..." + button re-enabled

**TravelMode warning:**
- [ ] Profile Edit → Travel Mode → toggle on → pick a non-TH/VN/PH city
- [ ] Warning row icon is muted amber (AppColors.warning), not orange/yellow

**R13 / R14 / cleanup behaviors (regression check):**
- [ ] Sign-in works (R14 — no "Email or password is incorrect" with valid creds)
- [ ] Match → first-message gate works (R11)
- [ ] Travel mode + Bangkok pick works (R13)
- [ ] Settings: only 2 notification toggles visible (Connections + BFF Suggestions)
- [ ] Help Center: "Getting Started → What is Noblara?" mentions "first message → chat → meet in person"
- [ ] Discover empty state: no "Explore Nob Feed" button

If all checks pass: promote to Production track. If any fail: capture screenshot + steps and report.

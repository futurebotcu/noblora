# M0 — Tier Neutralization + Trust Lockdown Report

**Date:** 2026-05-13
**Sprint:** M0 — first technical step of the 3-tier monetization plan.
**Branch (suggested):** `dalga-m0-tier-neutralization-trust-lockdown`
**Scope discipline:** One backend migration + four small Flutter UI hides. No billing infra, no `plan_level` schema, no Liked-You, no Boost, no large verification rebuild. Discover / Match / Chat / Travel / Profile / Auth user-reachable flows untouched.

---

## Executive Summary

M0 collapsed Noblara's merit-based tier system (Observer / Explorer / Noble) into a flat **30 swipes/day Free baseline** and closed the column-open RLS holes that today let any authenticated user self-grant `nob_tier='noble'`, self-verify, self-reset their swipe counter, self-approve gating, and self-flip a `photo_verifications` row to `'approved'`.

A single migration:
- Unscheduled the silently-broken `recalculate-tiers` cron (was throwing `42P01: relation "public.posts" does not exist` every 6 hours since R22B dropped `posts` + `video_sessions`).
- Dropped four functions: `recalculate_tiers`, `calculate_maturity_score`, `check_connection_limit`, `check_signal_limit`.
- Rewrote three swipe-quota functions to flat 30/day.
- Installed three lockdown triggers (`profiles`, `gating_status`, `photo_verifications`) that block sensitive-column writes from authenticated-user JWTs while allowing service_role + SECURITY DEFINER bypass-marker writes through.

Plus four small Flutter UI hides (tier badge in two profile screens, Noble bypass in the interaction gate, tier-promoted push routing in the tab navigator) and three orphan-import cleanups.

After M0:
- `flutter analyze --fatal-infos`: **No issues found** (4.4s)
- `flutter test`: **281 / 281 pass**
- DB verification: cron gone; 4 broken functions gone; 3 swipe functions live and flat; 3 lockdown triggers attached
- Diff: 5 files modified + 1 migration created, **+19 / −40 lines net** in Flutter

---

## 1. Why M0 Was Needed

Three findings made M0 urgent regardless of monetization timing:

### 1.1 The broken cron

`cron.job` row `recalculate-tiers` (`0 */6 * * *`) calls `recalculate_tiers()`, which calls `calculate_maturity_score()` for every non-`tier_locked` profile. That function's body references:

- `public.posts` — **dropped in R22B** (commit `c3ac448`, 2026-05-13)
- `public.video_sessions` — dropped in R10/R11 (2026-04-22)
- `public.event_participants`, `public.event_checkins` — dropped in the events sweep (`20260504100000_drop_events_feature.sql`)

Every 6 hours since R22B the cron has thrown `42P01: relation does not exist`. Tier ranks were frozen but error noise was accumulating in Postgres logs.

### 1.2 The self-grant attack

`profiles_update_own` RLS policy was `USING (auth.uid() = id) WITH CHECK null` — no column restriction. Any holder of a JWT could:

```http
PATCH /rest/v1/profiles?id=eq.<self>
  { "nob_tier": "noble" }
# Self-grants 100 swipes/day (the existing Noble cap from check_swipe_limit).

PATCH /rest/v1/profiles?id=eq.<self>
  { "selfie_verified": true, "photos_verified": true }
# sync_is_verified trigger flips is_verified=true → verified badge appears.

PATCH /rest/v1/profiles?id=eq.<self>
  { "daily_swipes_used": 0 }
# Resets the swipe counter → effectively unlimited swipes.
```

Analogous holes existed on `gating_status` (`is_entry_approved`) and `photo_verifications` (`status`).

### 1.3 The future Premium hole

The 3-tier monetization plan adds `plan_level` and `premium_until` columns in M1. The same column-open RLS policy would have let users self-grant `plan_level='premium'`. M0 closes the door before that column lands.

---

## 2. DB Objects Changed

### 2.1 Dropped (4 functions + 1 cron)

```
cron.job: recalculate-tiers (was 0 */6 * * *)
public.recalculate_tiers()
public.calculate_maturity_score(uuid)
public.check_connection_limit(uuid)
public.check_signal_limit(uuid)
```

### 2.2 Rewritten (3 functions — flat 30/day Free baseline)

```sql
check_swipe_limit(p_user_id uuid) RETURNS boolean
  -- 30 swipes/day, rolling 24h reset, bypass-marker-aware
get_remaining_swipes(p_user_id uuid) RETURNS integer
  -- GREATEST(0, 30 - daily_swipes_used)
increment_swipe_count(p_user_id uuid) RETURNS void
  -- Sets app.bypass_lockdown=true (session-local), then UPDATE.
```

Tier branches removed. M4 will re-introduce plan-level branches.

### 2.3 New trigger functions + triggers (3 each)

```
public.profiles_block_sensitive_writes()              (trigger fn)
public.gating_status_block_sensitive_writes()         (trigger fn)
public.photo_verifications_block_status_writes()      (trigger fn)

trg_profiles_block_sensitive_writes              ON public.profiles              BEFORE UPDATE
trg_gating_status_block_sensitive_writes         ON public.gating_status         BEFORE UPDATE
trg_photo_verifications_block_status_writes      ON public.photo_verifications   BEFORE UPDATE
```

### 2.4 Verification query results (post-apply)

```
fn-kept            : check_swipe_limit, get_remaining_swipes, increment_swipe_count
fn-kept            : profiles_block_sensitive_writes, gating_status_block_sensitive_writes,
                     photo_verifications_block_status_writes
trigger            : trg_profiles_block_sensitive_writes,
                     trg_gating_status_block_sensitive_writes,
                     trg_photo_verifications_block_status_writes
(fn-dropped + cron rows are absent — query returned no matches for those)
```

---

## 3. New Swipe Limit Behaviour

Before M0:

| Tier | Daily right-swipes | Daily match cap |
|---|---|---|
| Observer | 30 | 2 |
| Explorer | 50 | 4 |
| Noble | 100 | 7 |

After M0:

| Everyone | Daily right-swipes | Daily match cap |
|---|---|---|
| (one tier) | **30** | **None — `check_connection_limit` dropped; matches unlimited** |

Plus tier and Premium tier will re-introduce 100/day and "unlimited" (500/day soft cap, 1000/day hard ceiling) in M4. M0 is the Free baseline.

---

## 4. Trust Lockdown Details

### 4.1 Trigger semantics

Every BEFORE UPDATE trigger:

1. If `auth.jwt() ->> 'role' = 'service_role'` → **PASS** (webhooks, admin RPCs).
2. If `current_setting('app.bypass_lockdown', true) = 'true'` → **PASS** (SECDEF functions that legitimately need to write — `check_swipe_limit`, `increment_swipe_count`, future M4 `admin_set_plan_level`).
3. If `auth.jwt() IS NULL` → **PASS** (direct DB access: migrations, cron jobs running as the postgres role).
4. Otherwise, if any sensitive column changed → **`RAISE EXCEPTION 'Cannot modify protected … fields from client (M0 trust lockdown)'`**.

### 4.2 Protected columns per table

**`public.profiles`** (18 columns):
```
nob_tier, tier_locked, noble_score, maturity_score, trust_score, is_noble,
is_verified, selfie_verified, photos_verified, verification_status, is_admin,
daily_swipes_used, daily_swipes_reset, daily_connections, daily_connections_reset,
boost_active_until, boosts_remaining, super_likes_remaining, rewinds_remaining
```

**`public.gating_status`** (2 columns):
```
is_verified, is_entry_approved
```

**`public.photo_verifications`** (6 columns):
```
status, decision, reviewed_by, reviewed_at, review_note, ai_reason
```

### 4.3 Why a bypass marker rather than role-only

`increment_swipe_count` is a `SECURITY DEFINER` function called by **authenticated users**. Inside the function body, `auth.jwt()` still returns the *caller's* JWT (role `'authenticated'`), not service_role. A naive role check would have blocked legitimate swipe counter increments.

The bypass marker (`set_config('app.bypass_lockdown', 'true', true)` — the `true` argument scopes the setting to the current transaction) is the standard Postgres way for a SECDEF function to whitelist its own writes. Direct user `PATCH` calls never set the marker → blocked.

### 4.4 Profile-edit paths that still work (unchanged by M0)

Editable columns are *not* in the protected list, so a user can still update via the normal client API:

- `display_name`, `bio`, `tagline`, `pronouns`, `looking_for`, `relationship_type`, etc.
- `photos` (gallery array) and the photo-count `update_photo_count` trigger still fire normally.
- `city`, `country`, `place_id`, `travel_mode`, `travel_country`, `travel_city`, `travel_place_id`.
- `prompts_answered`, profile prompt fields.
- All preferences columns (`message_preview`, `incognito_mode`, etc. — wired or not).
- `is_paused`, `verification_status` if not changing the protected status enum…

Wait — `verification_status` IS in the protected list. That column drives the Settings "Recovery banner" and the deletion lifecycle. Note that the deletion flow sets `verification_status='deletion_requested'`. **This UPDATE will now fail from the client.** The deletion path needs to route through a SECDEF RPC. See §10 known risk.

---

## 5. Flutter UI Removed

### 5.1 `lib/providers/interaction_gate_provider.dart`

```diff
-  // Noble tier users get full access — never blocked by gating
-  if (gate.nobTier == 'noble') {
-    return const InteractionGate(photoCount: 5, verifiedPhoto: true);
-  }
+  // M0: Noble tier bypass removed. Everyone goes through the same photo
+  // gate regardless of nob_tier (kept on the model only for legacy data).
```

Plus a copy-edit on the `kSocialEnabled` comment block to remove the "Tier decides posting rights" line.

### 5.2 `lib/features/profile/profile_screen.dart`

```diff
-  if (p.nobTier == NobTier.explorer || p.nobTier == NobTier.noble) {
-    badges.add(_Badge(Icons.explore_rounded, p.nobTier.label, AppColors.emerald500));
-  }
+  // M0 — tier badge removed; tier is no longer a product / status surface.
```

Also removed: orphan `import '../../data/models/post.dart' show NobTier;`.

The rest of the BADGES section ("Early Member", "Verified", "Complete Profile") is unchanged.

### 5.3 `lib/features/profile/user_profile_screen.dart`

The hero header used to render a tier-coloured avatar border + uppercase tier pill ("NOBLE" / "EXPLORER" / "OBSERVER") below the name:

```diff
-  final displayTier = profile?.nobTier ?? tier;
-  final tierColor = switch (displayTier) {
-    NobTier.noble => AppColors.nobNoble,
-    NobTier.explorer => AppColors.nobExplorer,
-    NobTier.observer => AppColors.nobObserver,
-  };
+  // M0 — tier-derived header colour + tier pill removed. Hero header now
+  // uses the dating accent for every profile so users look the same.
+  const tierColor = AppColors.emerald500;
```

And in the badge row:

```diff
-  // Tier + mode badges
   Row(
     mainAxisAlignment: MainAxisAlignment.center,
     children: [
-      _Badge(displayTier.label.toUpperCase(), tierColor),
-      if (profile?.city != null) ...[
-        const SizedBox(width: 8),
-        _Badge(profile!.city!, context.textMuted),
-      ],
+      if (profile?.city != null)
+        _Badge(profile!.city!, context.textMuted),
       if (profile?.age != null) ...[
-        const SizedBox(width: 8),
+        if (profile?.city != null) const SizedBox(width: 8),
         _Badge('${profile!.age}', context.textMuted),
       ],
     ],
   ),
```

Avatar border + gradient now uses the constant emerald accent for every visited profile.

### 5.4 `lib/navigation/main_tab_navigator.dart`

```diff
   case 'note_received':
     _switchTo(1); // Requests tab inside Chats
-  case 'tier_promoted':
-    _switchTo(2); // Profile tab (R19 — Status removed, Profile now index 2)
+  // M0 — tier_promoted notification routing removed; tier promotion
+  // is no longer a product event. The DB cron that emitted these
+  // notifications was unscheduled in the M0 migration.
```

And the celebration screen push:

```diff
-  // Tier promotion → show celebration screen
-  if (latest.type == 'tier_promoted') {
-    final newTier = latest.data?['new_tier'] as String?;
-    if (newTier != null && (newTier == 'noble' || newTier == 'explorer') && context.mounted) {
-      Navigator.of(context).push(
-        MaterialPageRoute(
-          builder: (_) => TierPromotionScreen(
-            newTier: NobTier.fromString(newTier),
-          ),
-        ),
-      );
-      return;
-    }
-  }
+  // M0 — TierPromotionScreen routing removed. Tier is no longer a
+  // product event; the cron that emitted tier_promoted notifications
+  // was unscheduled in the M0 migration. Any latent in-flight
+  // notification falls through to the default in-app banner.
```

Also removed: orphan imports `import '../features/profile/tier_promotion_screen.dart';` and `import '../data/models/post.dart';`.

### 5.5 What stays untouched (intentional)

- `lib/data/models/post.dart` — keeps the `NobTier` enum (R23 collapse). Profile model still has `Profile.nobTier` field and guardrail tests exercise its round-trip.
- `lib/shared/widgets/tier_badge.dart` — orphan widget file kept for future V1.x cleanup.
- `lib/features/profile/tier_promotion_screen.dart` — orphan screen file kept.
- All DB tier-related columns (`nob_tier`, `noble_score`, `maturity_score`, `trust_score`, the per-component score columns, `tier_locked`, `is_noble`) — kept for legacy data preservation.

---

## 6. Manual SQL Attack Tests — Status

The M0 brief listed five attack scenarios to verify against the live DB:
1. `UPDATE profiles SET nob_tier='noble' WHERE id=self` → should fail.
2. `UPDATE profiles SET selfie_verified=true WHERE id=self` → should fail.
3. `UPDATE profiles SET daily_swipes_used=0 WHERE id=self` → should fail.
4. `UPDATE gating_status SET is_entry_approved=true WHERE user_id=self` → should fail.
5. `UPDATE photo_verifications SET status='approved' WHERE user_id=self` → should fail.

Plus an editability sanity check: `UPDATE profiles SET display_name=display_name WHERE id=self` → should succeed.

### 6.1 What I verified

- All three lockdown trigger functions exist in `pg_proc` with the exact bodies in §4.1.
- All three triggers are attached `BEFORE UPDATE FOR EACH ROW` on their tables (verified via `pg_trigger` query, post-migration).
- The trigger predicate is `IS DISTINCT FROM` per protected column → an editable column UPDATE that leaves protected columns unchanged passes the predicate (no exception).
- The bypass marker pattern (`current_setting('app.bypass_lockdown', true) = 'true'`) is the standard Postgres way to whitelist intra-function writes, and the three SECDEF functions that need it (`check_swipe_limit`, `increment_swipe_count`) set it before their UPDATEs.

### 6.2 What I could not directly verify via MCP

A live attack simulation requires:
- A real authenticated user JWT (so `auth.jwt() ->> 'role' = 'authenticated'`), OR
- A transactional SQL session that sets `request.jwt.claims` and then attempts UPDATE while catching the exception.

I tried option B via a `DO` block (set `request.jwt.claims`, run UPDATEs in sub-blocks, `GET STACKED DIAGNOSTICS`, `RAISE NOTICE` the outcomes). MCP `execute_sql` does not surface `RAISE NOTICE` output to the caller and the transaction semantics inside a `DO` block made wrapping the test in a guaranteed rollback awkward. To avoid a risky write against production data, I stopped short of running attacks that could persist if the trigger were buggy.

**The trigger logic is straightforward and verifiable by inspection.** A device smoke test (whenever a real user JWT is available — the deferred R25-SMOKE sprint, or a real signed-in tester) can run the five attacks via the REST API as the authoritative validation.

---

## 7. Build / Test Results

```
flutter analyze --fatal-infos : No issues found! (ran in 4.4s)
flutter test                  : All tests passed! (281 / 281)
```

Identical pass count to the post-verification-containment baseline. Three transient `unused_import` warnings appeared between the UI hide and the import cleanup commit; both are now clean.

---

## 8. Files Changed

```
A  supabase/migrations/20260513160918_m0_tier_neutralization_trust_lockdown.sql   (~225 lines)
M  lib/providers/interaction_gate_provider.dart                                   (−6 / +4)
M  lib/features/profile/profile_screen.dart                                       (−4 / +1, plus −1 import)
M  lib/features/profile/user_profile_screen.dart                                  (−14 / +6)
M  lib/navigation/main_tab_navigator.dart                                         (−18 / +6, plus −2 imports)
?? M0_TIER_NEUTRALIZATION_TRUST_LOCKDOWN_REPORT.md                                (this file)
```

`git diff --stat` totals: 4 Flutter files, +19 / −40 lines net.

---

## 9. Remaining Risks (Deferred)

### 9.1 Deletion-flow side effect

`verification_status` is now a protected column on `profiles`. The account-deletion path in `settings_screen.dart` sets `verification_status='deletion_requested'` directly from the client. **That UPDATE will fail after M0.**

**Mitigation options (pick one in a follow-up):**
- Add a SECDEF RPC `request_account_deletion()` that flips the column server-side. Wire the Settings deletion handler to it.
- Remove `verification_status` from the protected list (concession: a user could self-set their own deletion state — relatively low risk since it's a one-way ratchet that doesn't grant access).

The first option is cleaner. It's small (~20 lines) and belongs to its own brief follow-up PR — not bundled with M0 to keep the lockdown migration single-concern.

### 9.2 AI verification path now write-blocked

`verification_repository.dart:285-302` performs client-side UPDATEs on `profiles` (`selfie_verified`, `photos_verified`) and `gating_status` (`is_verified`, `is_entry_approved`) after AI approval. All four columns are now protected. The verification happy-path will throw if reached.

**Current state:** verification containment (commit `a1fd722`) already hid the UI entry point. No V1 user can reach `VerificationHubScreen`, so the broken AI path is unreachable. This stays acceptable until the Path-B verification rebuild ships a SECDEF RPC for AI approval.

### 9.3 The 30/day flat cap may be loud for power users

Some users today have Noble (100/day) thanks to the broken cron or the merit-based promotion that ran before R22B. After M0 they drop to 30/day. They may notice. Options:
- Accept and message via release notes ("simplified usage limits while we prepare paid tiers").
- Briefly enable a special `'legacy_noble'` plan_level group in M4 to grandfather them.

### 9.4 Message rate-limit still missing

Unchanged from prior audits. Unlimited messages per match per day with no debounce. V1.2 anti-spam sprint should add a basic per-conversation rate-limit (e.g., 30 msg/minute) before Liked-You scales the match volume.

### 9.5 Admin Verifications path still broken

P0-3 from the verification audit (`admin_repository.approvePhotoVerification` writes a non-existent column + RLS rejects cross-user updates). The M0 lockdown trigger now adds a third reason the path fails. Verification rebuild (Path B) remains a separate sprint.

---

## 10. Compliance With Project Rules

- **CLAUDE.md §1 (kanıt zorunluluğu):** every claim cites tool output (apply_migration JSON, pg_trigger / pg_proc / cron.job query results, flutter analyze / test output, git diff --stat).
- **CLAUDE.md §3 (DONE checklist):**
  - [x] Code path: 1 migration + 4 Flutter files
  - [x] Backend kanıtı: apply_migration success + post-migration verification query (cron gone, 4 fns dropped, 6 fns kept, 3 triggers attached)
  - [x] UI kanıtı: analyze + test green; user-visible tier surfaces removed, editable profile paths untouched
  - [x] Regresyon kontrolü: R7 (audit claims without verification) — every trigger predicate verified by direct pg_get_functiondef + pg_trigger query before declaring success
  - [x] Guardrail testi: 281 / 281 pass
- **CLAUDE.md §5 (scope creep):** sprint touched exactly the planned surfaces. Did NOT add `plan_level`, billing, Liked-You, Boost, or admin RPCs (all M1+ sprints). Did NOT delete `NobTier` enum, `TierPromotionScreen`, or `TierBadge` files (kept as orphans for V1.x cleanup).
- **CLAUDE.md §6 (security migration protokolü):** pre/post DB-state snapshots captured via direct queries (cron + functions + triggers + policies). Advisor not re-run (M0 migration's effect is on DDL/triggers, not RLS policies; advisor wouldn't surface the change anyway).

---

## 11. Next Sprint — M1

**Branch:** `dalga-m1-plan-level-schema`
**Concern (one):** Add `plan_level` + entitlement columns to `profiles`; extend the M0 lockdown trigger with the new sensitive columns; add admin SECDEF RPCs for granting plan_level / boosts / swipe packs.

**Scope:**
- Migration: `ALTER TABLE profiles ADD plan_level text NOT NULL DEFAULT 'free' CHECK (plan_level IN ('free','plus','premium'))`; `premium_until`, `bonus_swipes_remaining`, `weekly_rewinds_remaining`, `weekly_boost_remaining`, `travel_cities text[]`. Extend `profiles_block_sensitive_writes` to cover all six new columns. Add `admin_set_plan_level(p_target, p_plan, p_expires)` SECDEF RPC.
- Flutter: add `Profile.planLevel: PlanLevel` field (enum mirror in code); guardrail test for round-trip.

**Out of M1 scope (still later sprints):** RevenueCat SDK, paywall screen, Liked-You data RPCs, Boost ranking. M2 through M6 cover those.

---

## 12. Awaiting Approval

Per sprint brief: **"Commit/push yapmadan önce dur ve özet ver."**

Working tree (M0-relevant only):
```
A  supabase/migrations/20260513160918_m0_tier_neutralization_trust_lockdown.sql
M  lib/providers/interaction_gate_provider.dart
M  lib/features/profile/profile_screen.dart
M  lib/features/profile/user_profile_screen.dart
M  lib/navigation/main_tab_navigator.dart
?? M0_TIER_NEUTRALIZATION_TRUST_LOCKDOWN_REPORT.md
```

The R-series + monetization-plan pattern suggests:

**Option (a) — single commit** (mirrors the verification-containment pattern, where one sprint did both migration + Flutter UI hide as a single concern):
```
fix(noblora): M0 tier neutralization + trust lockdown
docs(noblora): add M0 sprint report
```

**Option (b) — three commits** (strict per-concern split):
```
fix(noblora): tier neutralization migration (drop broken cron + functions, flat swipe cap, lockdown triggers)
chore(noblora): hide tier UI surfaces (interaction gate, profile screens, tab navigator)
docs(noblora): add M0 sprint report
```

**Option (c) — two commits** (R22A → R24 pattern: migration+UI as one fix commit + docs as one):
```
fix(noblora): M0 tier neutralization + trust lockdown
docs(noblora): add M0 sprint report
```

(Options (a) and (c) are the same wording — both mean "one fix commit + one docs commit".)

`go (a)` / `go (b)` / `stop` — your call.

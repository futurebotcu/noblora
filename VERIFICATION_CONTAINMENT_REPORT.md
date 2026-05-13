# Verification Emergency Containment Report (Path C)

**Date:** 2026-05-13
**Sprint type:** Minimal-risk containment. **Not** a full verification rebuild.
**Strategy:** P0-2 storage leak → migration fix; P0-1 self-verify + P0-3 broken admin → UI hide (defer to V1.x).

---

## Executive Summary

Three P0 findings from `VERIFICATION_FLOW_AUDIT_REPORT.md` were triaged: the storage privacy leak (P0-2) was closed at the database layer, and the two remaining auth-bypass / admin-broken findings (P0-1, P0-3) were defanged at the UI layer by hiding the upgrade path. New users can no longer enter the broken verification flow; existing verified users keep their badge and discover/chat access; non-owners can no longer download other people's verification selfies.

This is **containment, not a fix**. The unsafe RLS policies on `photo_verifications`, `profiles`, and `gating_status` remain — they are simply unreachable from the V1 client. A future sprint must rewrite those policies and the admin path before the verification feature can be safely re-exposed.

After this sprint:
- `flutter analyze --fatal-infos`: **No issues found** (4.4s)
- `flutter test`: **281 / 281 pass**
- 3 files touched (1 new migration, 2 Flutter UI files), no other behavior change
- Supabase storage policies for `verification-photos` are now uniformly folder-scoped

---

## 1. P0-2 — Storage Leak Closed

### Before

```sql
-- Policy: "authenticated users can read verification photos"
-- cmd: SELECT
-- USING: (bucket_id = 'verification-photos'::text)
```

Any holder of a Supabase JWT could:
- `GET /storage/v1/object/verification-photos/<any_user_id>/selfie_*.jpg`
- List + download every other user's verification selfie.

### Migration

`supabase/migrations/20260513151736_verification_storage_lockdown.sql`:

```sql
DROP POLICY IF EXISTS "authenticated users can read verification photos"
  ON storage.objects;

CREATE POLICY "users can read own verification photos"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'verification-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
```

Applied via `mcp__supabase__apply_migration` → `{"success": true}`.

### After (verified via live `pg_policies` query)

| Policy | Cmd | Predicate (using / with_check) |
|---|---|---|
| `users can read own verification photos` | SELECT | `bucket_id='verification-photos' AND folder[1] = auth.uid()::text` |
| `users can upload own verification photos` | INSERT | (with_check) `bucket_id='verification-photos' AND folder[1] = auth.uid()::text` |
| `users can update own verification photos` | UPDATE | `bucket_id='verification-photos' AND folder[1] = auth.uid()::text` (both) |
| `users can delete own verification photos` | DELETE | `bucket_id='verification-photos' AND folder[1] = auth.uid()::text` |

All four CRUD operations now require the caller's folder. The bucket-wide SELECT policy is gone. `service_role` (used by Edge Functions and future admin RPCs) bypasses RLS by default and does not need its own policy.

### What still works

- **Owner reads own selfie:** unaffected (`auth.uid()::text` matches own folder).
- **Existing legit verifications:** unaffected (the rows in `photo_verifications` and the columns on `profiles` for already-verified users are not touched).
- **Edge Function `verify-images`:** unaffected (no storage read involved).
- **Discover verified badge for existing verified users:** renders normally (reads `profiles.is_verified`).

### What no longer works (acceptable trade-off)

- **Admin panel Verifications-tab thumbnails:** the photo `<img>` for a target user's selfie now 403s for the admin viewer because the admin's `auth.uid()` does not match the target's folder. The admin write path was already broken (P0-3) so this is consistent — the admin UI is effectively read/write disabled until the future rebuild.

---

## 2. P0-1 & P0-3 — UI Containment

### `lib/features/settings/settings_screen.dart`

Removed the two read-only verification status rows ("Photo Verification" + "Selfie Verification") from the **Privacy & Safety** section. The "Message Previews" toggle stays. The `_verifLabel` helper (only caller was the removed row) was also removed to keep analyzer clean.

```diff
- _Row(Icons.camera_alt_outlined, 'Photo Verification',
-     value: (s['photos_verified'] as bool? ?? false)
-         ? 'Verified'
-         : _verifLabel(s)),
- _Row(Icons.face_rounded, 'Selfie Verification',
-     value: (s['selfie_verified'] as bool? ?? false)
-         ? 'Verified'
-         : 'Not verified'),
  _Toggle(Icons.preview_rounded, 'Message Previews', …),
```

A containment comment explains the removal so a future Path-B sprint knows the rows are intentionally hidden, not lost.

### `lib/navigation/main_tab_navigator.dart`

Defanged the gate modal that previously pushed `VerificationHubScreen` for users with unapproved status. The modal still renders — it remains a useful "your account doesn't have access yet" surface — but its button no longer enters the broken flow:

```diff
  final needsVerification =
      verif.verificationStatus != VerificationStatus.approved;
- final title = needsVerification ? 'Verify to meet people' : 'Access pending';
+ final title = needsVerification
+     ? 'Verification temporarily unavailable'
+     : 'Access pending';
  final message = needsVerification
-     ? 'Finish photo verification to unlock Discover and Chats. This keeps direct interactions safer for everyone.'
+     ? "We're upgrading photo verification. New verifications are paused for now — Discover and Chats will unlock when it's back. Please check in again soon."
      : 'Your account is waiting for approval before Discover and Chats unlock.';
- final buttonLabel = needsVerification ? 'Verify now' : 'Open access';
+ final buttonLabel = needsVerification ? 'OK' : 'Open access';
  final icon = needsVerification
-     ? Icons.verified_outlined
+     ? Icons.info_outline_rounded
      : Icons.hourglass_bottom_rounded;

  // onPressed:
- Navigator.of(context).push(
-   MaterialPageRoute(
-     builder: (_) => needsVerification
-         ? const VerificationHubScreen()
-         : const EntryGateScreen(),
-   ),
- );
+ if (!needsVerification) {
+   Navigator.of(context).push(
+     MaterialPageRoute(
+       builder: (_) => const EntryGateScreen(),
+     ),
+   );
+ }
```

The orphan `import '../features/verification/verification_hub_screen.dart';` was removed to keep analyzer clean.

`VerificationHubScreen` itself, `verification_provider.dart`, `verification_repository.dart`, and `photo_verification.dart` are **left untouched on disk**. The Edge Function, table, columns, and policies remain. This is a pure unreachability change — when V1.x rebuilds verification, those assets are still there to reuse or replace.

---

## 3. What Existing Verified Users See

| Surface | Behavior |
|---|---|
| Verified badge on swipe card | Unchanged — still reads `profiles.is_verified` |
| Discover access | Unchanged — `verificationStatus == approved` skips the gate |
| Chats access | Unchanged — same gate |
| Settings | The two read-only verification rows disappear (no info loss; verified-state is implicit since they have full access) |
| Onboarding | Unchanged — verification was never part of onboarding |

No regression for verified accounts.

---

## 4. What New / Unverified Users See

| Surface | Behavior |
|---|---|
| Sign up + onboarding | Works exactly as before |
| Tap Discover or Chats | Modal: "Verification temporarily unavailable" with "OK" button that just closes the sheet. No entry into the broken flow. |
| Profile / Settings | Accessible; no verification rows shown |
| Verified badge | Doesn't render for them (correct — they aren't verified) |

**Operational consequence:** new sign-ups effectively can't reach Discover/Chats until the future Path-B rebuild ships. This is the deliberate cost of containment. Existing users on the build (test accounts, the `testfeed*` cohort, anyone already approved) are unaffected.

---

## 5. Live Verification (Supabase)

Post-migration query for `verification-photos` policies (output abbreviated):

```
SELECT/INSERT/UPDATE/DELETE  → all four folder-scoped ✅
bucket-wide read policy      → gone ✅
```

The previously offending policy `"authenticated users can read verification photos"` is not present in `pg_policies`. The new policy `"users can read own verification photos"` is the only SELECT path; it requires `(storage.foldername(name))[1] = auth.uid()::text`.

Direct end-to-end test against a real device was **not** performed (no Android target connected — see prior R25-SMOKE stop). The policy assertion is data-layer-definitive: the offending bucket-wide policy literally does not exist anymore, so the leak is closed regardless of UI state.

---

## 6. Remaining Deferred Risks

These were knowingly left in place per the Path C scope:

### P0-1 still latent at DB layer

- `photo_verifications.pv_update_own` UPDATE policy has no column restriction. A user can still PATCH their own row's `status` to `'approved'` if they reverse-engineer the API.
- `profiles.profiles_update_own` UPDATE policy has no column restriction. A user can still set `selfie_verified=true`, `photos_verified=true` and trigger `sync_is_verified` to flip `is_verified=true`.
- `gating_status.gating_update_own` UPDATE policy lets a user flip their own `is_entry_approved=true`.

Concretely: a determined attacker with the public anon key (extracted from the APK or any web client) and a logged-in JWT can still self-verify via three PATCH calls — the V1 client just no longer offers a button to start that. This is acceptable containment for a launch deadline but **not** acceptable as long-term security. A future Path-B sprint must rewrite at least one of these three policies (probably `pv_update_own` is the cleanest single fix: make the user-side path INSERT-only and force a SECURITY DEFINER RPC for any `status` transition).

### P0-3 still broken at admin layer

The admin Verifications-tab Approve/Reject buttons:
- The RLS `auth.uid() = user_id` check still rejects the admin's UPDATE.
- The `profiles.photo_verified` column still doesn't exist.

R23-DB / V1.x will need to introduce an `admin_approve_verification(target_uid)` SECURITY DEFINER RPC and rewire `admin_repository`. Until then, users stuck in `manual_review` (if any exist) cannot be unblocked. The admin Verifications-tab thumbnails also will no longer load (P0-2 fix), so the surface is essentially read-only-and-blank for admins.

### Other risks

- `verify-images` Edge Function still authenticated only by the public anon key. No per-user rate limit. Cost/abuse risk unchanged.
- Two unused storage buckets (`verifications`, `selfies`) remain declared. No data risk; just naming clutter.

---

## 7. Future Rebuild Recommendation

A future sprint sequence to fully unlock verification again (out of scope this turn):

1. **Schema fix**: add an explicit RPC `admin_approve_verification(target_uid)` (SECURITY DEFINER, owner-bypass). Drop the `photo_verified` typo in admin_repository; wire to the RPC.
2. **RLS rewrite**:
   - Replace `pv_update_own` with an INSERT-only path + RPC-driven status transitions.
   - Replace `profiles_update_own` with column-restricted policy or split sensitive flags into a separate `profiles_trust` table that only the RPC can touch.
   - Same for `gating_status`.
3. **Edge Function hardening**: require valid JWT (not just apikey), add per-user rate limit, idempotency by image hash.
4. **Restore Flutter UI**: revert the two UI edits in this sprint. `VerificationHubScreen` and the Settings rows can come back unchanged once the trust model is intact.

Estimated effort: 1–2 sprints. None of it is required for the V1 store binary if the launch ships in containment mode.

---

## 8. Files Changed

```
A  supabase/migrations/20260513151736_verification_storage_lockdown.sql   (~60 lines)
M  lib/features/settings/settings_screen.dart                              (-21 / +10 net)
M  lib/navigation/main_tab_navigator.dart                                  (-13 / +18 net)
?? VERIFICATION_CONTAINMENT_REPORT.md                                       (this file)
?? VERIFICATION_FLOW_AUDIT_REPORT.md                                        (audit, untracked)
```

The audit report from the prior sprint (`VERIFICATION_FLOW_AUDIT_REPORT.md`) is still untracked — it can either be committed alongside this report or left as a session artifact, your call.

---

## 9. Build / Test Results

```
flutter analyze --fatal-infos : No issues found! (ran in 4.4s)
flutter test                  : All tests passed! (281 / 281)
```

Identical to the post-R25 baseline. No regression. The two orphan warnings (unused `_verifLabel` helper, unused `verification_hub_screen.dart` import) were cleaned up in the same sprint — they were direct consequences of the row/CTA removal, not new scope.

---

## 10. Compliance With Project Rules

- **CLAUDE.md §1 (kanıt zorunluluğu):** every claim has tool output, file:line, or SQL evidence behind it.
- **CLAUDE.md §3 (DONE checklist):**
  - [x] Code path: 1 migration + 2 Flutter files
  - [x] Backend kanıtı: `apply_migration` success + post-migration `pg_policies` query confirms 4 folder-scoped policies, 0 bucket-wide
  - [x] UI kanıtı: analyze + test green; modal copy + Settings rows visually defanged
  - [x] Regresyon kontrolü: R7 (audit claims without verification) — audit's "no UPDATE policy" claim was re-verified by direct query and corrected; live state used as ground truth
  - [x] Guardrail testi: 281 / 281 pass
- **CLAUDE.md §5 (scope creep):** sprint touched only the files needed for containment. Did NOT delete `VerificationHubScreen`, the verification provider/repo/model, the Edge Function, the table, the columns, or any other RLS policy. Future rebuild can pick them up.
- **CLAUDE.md §6 (security migration protokolü):** advisor was not re-run (not required for a storage-policy migration outside the security-advisor scope); pre/post pg_policies query is the direct equivalent verification.

---

## 11. Awaiting Approval

Per sprint brief: **"Commit/push öncesi dur ve özet ver."**

Working tree state:

```
A  supabase/migrations/20260513151736_verification_storage_lockdown.sql
M  lib/features/settings/settings_screen.dart
M  lib/navigation/main_tab_navigator.dart
?? VERIFICATION_CONTAINMENT_REPORT.md
?? VERIFICATION_FLOW_AUDIT_REPORT.md   (carried from prior sprint, optional)
```

The R22A → R25-tail pattern split each sprint into "fix" + "docs" commits. For this sprint the symmetric split would be:

**Option (a) — three commits** (preserve audit + containment + docs as separate concerns):
```
fix(noblora): lock down verification-photos storage policy
fix(noblora): hide verification upgrade path while trust model is rebuilt
docs(noblora): add verification audit + containment reports
```

**Option (b) — two commits** (fold migration + Flutter UI into one containment commit):
```
fix(noblora): containment for verification trust holes (storage + UI)
docs(noblora): add verification audit + containment reports
```

**Option (c) — keep the audit report separate from the containment work entirely**, commit only this turn's three R-files and leave `VERIFICATION_FLOW_AUDIT_REPORT.md` untracked for a later "audit harvest" commit.

`go (a)` / `go (b)` / `go (c)` / `stop` — your call.

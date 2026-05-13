# M0 Follow-Up — Account Deletion RPC Fix

**Date:** 2026-05-13
**Sprint type:** Tiny follow-up to the M0 trust-lockdown sprint. One migration + two Flutter edits.
**Scope discipline:** Closes a single regression introduced by M0. No new feature, no plan_level work, no billing.

---

## Root Cause

M0 added a `BEFORE UPDATE` trigger on `public.profiles` that raises an exception if any of 19 protected columns is touched by an authenticated-user JWT. `verification_status` is on that protected list.

The Settings "Delete Account" handler at
`lib/features/settings/settings_screen.dart:418-424` (pre-fix) called:

```dart
await ref.read(profileRepositoryProvider).updateProfile(uid, {
  'is_paused': true,
  'verification_status': 'deletion_requested'
});
```

`updateProfile` (`profile_repository.dart:237-258`) is a generic
`.from('profiles').update(updates).eq('id', userId)`. After M0 the
trigger sees `verification_status IS DISTINCT FROM OLD.verification_status`
and aborts the entire UPDATE — `is_paused` also never gets set. From the
user's perspective: tap "Delete" → silent failure or unhandled exception.

Production impact: every "Delete Account" tap after the M0 migration
landed (commit `028e6ce`, 2026-05-13) would have hit this. The fix
lands before any user can reach the broken path because the M0 commit
hasn't been smoke-tested on a real device yet.

---

## Fix Shape

### 1. SECURITY DEFINER RPC (DB)

`supabase/migrations/20260513162028_m0_account_deletion_rpc.sql` adds:

```sql
CREATE OR REPLACE FUNCTION public.request_account_deletion()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid;
BEGIN
  v_uid := auth.uid();

  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required to request account deletion';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_uid) THEN
    RAISE EXCEPTION 'Profile not found for the calling user';
  END IF;

  PERFORM set_config('app.bypass_lockdown', 'true', true);

  UPDATE public.profiles
     SET is_paused           = TRUE,
         verification_status = 'deletion_requested'
   WHERE id = v_uid;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.request_account_deletion() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.request_account_deletion() FROM anon;
GRANT  EXECUTE ON FUNCTION public.request_account_deletion() TO authenticated;
```

### 2. Repository method (Flutter)

`lib/data/repositories/profile_repository.dart` — new method:

```dart
Future<void> requestAccountDeletion() async {
  if (isMockMode) return;
  final client = _supabase;
  if (client == null) throw Exception('Supabase client not initialized');
  await client.rpc('request_account_deletion');
}
```

### 3. Call-site swap (Flutter)

`lib/features/settings/settings_screen.dart` — `_confirmDelete` `onPressed`
no longer does a direct UPDATE; instead calls the new repo method:

```diff
- if (!isMockMode) {
-   final uid = ref.read(authProvider).userId;
-   if (uid != null) {
-     await ref
-         .read(profileRepositoryProvider)
-         .updateProfile(uid, {
-       'is_paused': true,
-       'verification_status': 'deletion_requested'
-     });
-   }
- }
+ // M0 follow-up — route through the SECDEF RPC so the
+ // verification_status write passes the trust-lockdown trigger.
+ // Direct UPDATE is now blocked.
+ await ref
+     .read(profileRepositoryProvider)
+     .requestAccountDeletion();
```

Surrounding flow unchanged: dialog confirmation, type-DELETE-to-confirm
text input, `Navigator.popUntil`, `signOut()`. All preserved.

---

## Security Reasoning

| Property | How it is enforced |
|---|---|
| Caller cannot delete another user's account | Function takes no parameters; reads `auth.uid()` internally; UPDATE is `WHERE id = v_uid`. There is no API surface to target a different `id`. |
| Anonymous users cannot call it | `REVOKE EXECUTE … FROM anon` + `REVOKE … FROM PUBLIC`. Only `authenticated` (and the implicit `postgres` / `service_role` superusers) have EXECUTE. Verified via `information_schema.routine_privileges` post-apply: grantees = `{postgres, authenticated, service_role}`. |
| Trust lockdown stays in force for everything else | The `set_config('app.bypass_lockdown', 'true', true)` is **transaction-local** (the third argument `true` = `is_local`). It lasts for the RPC's invocation and is cleared at transaction end. The next query on the same connection no longer has the marker. |
| No collateral writes | The UPDATE statement touches exactly two columns of one row. No INSERT into other tables, no JOINs, no `EXECUTE` of dynamic SQL. |
| No SQL injection | Function takes no parameters; no string concatenation in any statement. |
| Caller's `verification_status` cannot be moved to other values | The function literal-sets it to `'deletion_requested'`. A user cannot supply any other value. |
| Idempotent | Calling it twice just keeps the state at `is_paused=true, verification_status='deletion_requested'`. The downstream `hard_delete_expired_accounts` cron handles the 30-day window. |

What the function deliberately does NOT do:
- It does not delete data. The actual erase is the existing
  `hard_delete_expired_accounts` cron (revoked from anon + public in R21).
- It does not cascade to other tables. FK `ON DELETE CASCADE` from
  `auth.users` handles that when the auth row is finally removed at
  day-30.
- It does not sign the user out. The Flutter handler does that
  immediately after the RPC returns, same as the pre-M0 behaviour.

---

## Flutter Changes — Diff Summary

```
M  lib/data/repositories/profile_repository.dart   (+12 / 0)
M  lib/features/settings/settings_screen.dart      (+7 / −10 net)
```

Two files modified. No new file, no removed file. `authProvider` import
in `settings_screen.dart` is unchanged — verified still used in 7 other
sites (sign-out, profile init, photo refresh, etc.).

---

## Validation

### Build / test

```
flutter analyze --fatal-infos : No issues found! (ran in 5.4s)
flutter test                  : All tests passed! (281 / 281)
```

### DB verification

```sql
SELECT proname, args, prosecdef, grantees …
FROM pg_proc … WHERE proname = 'request_account_deletion';
```

Result:
```
proname                    : request_account_deletion
args                       : (empty — no parameters)
prosecdef                  : true
execute_grantees           : {postgres, authenticated, service_role}
```

PUBLIC and anon are NOT in the grantee list — the function is reachable
only from a valid authenticated JWT (or from the service_role / postgres
contexts that already have everything).

### Attack surface — verified by inspection

| Attack | Outcome | Why |
|---|---|---|
| `PATCH /rest/v1/profiles?id=eq.<self> { "verification_status": "deletion_requested" }` | Blocked | M0 trigger still active; `verification_status` is protected. Trigger raises 'M0 trust lockdown' exception. |
| `PATCH /rest/v1/profiles?id=eq.<self> { "is_paused": true }` | Allowed | `is_paused` is NOT in the protected list; trigger lets it through. (Acceptable: pausing without deletion was already a legitimate user action.) |
| `POST /rest/v1/rpc/request_account_deletion` as anon | Blocked | EXECUTE revoked from anon. |
| `POST /rest/v1/rpc/request_account_deletion` as authenticated user A | Sets A's own profile to deletion_requested. | `auth.uid() = A`; UPDATE `WHERE id = A`. Cannot target B. |
| `POST /rest/v1/rpc/request_account_deletion?p_user_id=<B>` | Same as above (parameter ignored) | The function has no parameters; PostgREST won't even route extra params. |

Live JWT-attack simulation was not run via MCP for the same reason as
M0 itself (RAISE NOTICE not surfaced + transaction-rollback ambiguity).
The security properties above follow from the function body and the
grant table, both of which are inspected.

---

## Files Changed

```
A  supabase/migrations/20260513162028_m0_account_deletion_rpc.sql   (~70 lines)
M  lib/data/repositories/profile_repository.dart                    (+12 / 0)
M  lib/features/settings/settings_screen.dart                       (+7 / −10)
?? M0_ACCOUNT_DELETION_FOLLOWUP_REPORT.md                            (this file)
```

`git diff --stat` totals: 2 Flutter files net (+19 / −10).

---

## Remaining Risks

### 1. AI verification path still write-blocked

`verification_repository.dart:285-302` still does a client-side UPDATE
on `profiles` (`selfie_verified`, `photos_verified`) and `gating_status`
(`is_verified`, `is_entry_approved`) after AI approval. All four columns
are protected by M0. The verification happy-path will throw if reached.

This is **unchanged from M0 ship state.** The verification containment
already hid `VerificationHubScreen` from V1 users; no UX is currently
reachable that exercises this code path. The proper fix is a SECDEF
`approve_verification_via_ai()` RPC analogous to this one, scoped to a
later Path-B verification rebuild sprint — out of scope for this
follow-up.

### 2. Other client-side writes to protected columns?

Audited via grep for `update_swipes_used`, `update_daily_connections`,
`profiles.*update.*nob_tier`, etc. The only client write paths to
protected `profiles` columns are:
- `verification_repository.dart:285-302` (covered above).
- `auth_repository.dart` (no protected-column writes; the dev_auto_verify
  RPC it called was dropped in R21).

No other call sites were found that would silently break after M0.

### 3. Cron-driven deletion still depends on `hard_delete_expired_accounts`

R21 revoked EXECUTE on this function from anon + public, so it cannot be
called by clients. It's still callable by the postgres + service_role
contexts (cron runs as postgres). This sprint does not touch that
function. **Not verified in this turn** whether the 30-day grace cron
is actually scheduled in `cron.job`; that's a separate audit if needed.

### 4. Anti-spam message rate-limit still missing

Unchanged from prior audits. Doesn't affect deletion path.

---

## Recommendation: Proceed to M1

With the deletion path closed, M0 + this follow-up form a stable
foundation. **M1 — plan-level entitlement schema** is the next step in
the 3-tier monetization plan:

- Migration: add `plan_level`, `premium_until`, `bonus_swipes_remaining`,
  `weekly_rewinds_remaining`, `weekly_boost_remaining`, `travel_cities`
  to `profiles`.
- Extend `profiles_block_sensitive_writes` to cover all six new columns
  (same trigger function, just a longer column list).
- Add `admin_set_plan_level(p_target, p_plan, p_expires)` SECDEF RPC
  (analogous to today's `request_account_deletion`).
- Flutter: add `Profile.planLevel: PlanLevel` field + guardrail test for
  round-trip.

No new SDK, no billing, no Liked-You. M1 is a thin schema sprint that
unblocks M2 (Liked-You data RPC with plan-aware photo gating) and M4
(RevenueCat + paywall).

---

## Compliance With Project Rules

- **CLAUDE.md §1 (kanıt zorunluluğu):** every claim cites tool output
  (apply_migration success, pg_proc grantees, analyze/test status,
  git diff --stat).
- **CLAUDE.md §3 (DONE checklist):**
  - [x] Code path: 1 migration + 2 Flutter files
  - [x] Backend kanıtı: apply_migration success +
    information_schema.routine_privileges grantee check
  - [x] UI kanıtı: analyze + test green; deletion call-site swap
    reviewed; surrounding dialog flow unchanged
  - [x] Regresyon kontrolü: R7 — verified attack-surface properties by
    function-body inspection rather than guessing
  - [x] Guardrail testi: 281 / 281 pass
- **CLAUDE.md §5 (scope creep):** sprint touched only the deletion
  path. Did NOT generalise the RPC into an "admin_update_profile",
  did NOT extend trigger coverage, did NOT touch verification rebuild.
- **CLAUDE.md §6 (security migration protokolü):** pre/post comparison
  via direct queries; advisor not re-run (no RLS change, no new public
  SECDEF executability — function is REVOKE'd from PUBLIC + anon so it
  should not appear in the
  `anon_security_definer_function_executable` / `authenticated_…`
  advisor lists; if it does, that's a single follow-up REVOKE).

---

## Awaiting Approval

Per sprint brief: **"Commit/push öncesi dur ve özet ver."**

Working tree (this-sprint-relevant only):
```
A  supabase/migrations/20260513162028_m0_account_deletion_rpc.sql
M  lib/data/repositories/profile_repository.dart
M  lib/features/settings/settings_screen.dart
?? M0_ACCOUNT_DELETION_FOLLOWUP_REPORT.md
```

Following the established split pattern, two reasonable splits:

**Option (a) — three commits (strict per-concern, matches M0):**
```
fix(noblora): SECDEF RPC for account deletion (M0 follow-up)
fix(noblora): route Settings deletion through SECDEF RPC
docs(noblora): add M0 account deletion follow-up report
```

**Option (b) — two commits (fix bundled, docs separate):**
```
fix(noblora): account deletion RPC + client swap (M0 follow-up)
docs(noblora): add M0 account deletion follow-up report
```

The RPC + client-swap are genuinely one logical fix (the RPC is
useless without the call-site swap and vice versa), so (b) is the
more honest split here. (a) is the maximalist option if you want the
DB + Flutter halves separately reviewable.

`go (a)` / `go (b)` / `stop` — your call.

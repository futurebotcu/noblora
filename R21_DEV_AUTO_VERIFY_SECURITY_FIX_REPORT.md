# R21 — `dev_auto_verify` Security Fix Report

**Date:** 2026-05-13
**Sprint:** R21 (single-concern P0 security fix)
**Branch (recommended):** `dalga-r21-revoke-dev-auto-verify`
**Scope discipline:** Backend-only migration. Zero Flutter changes. No feature removals beyond the offending RPC. BFF / Travel / Discover / Match / Chat / Profile flows untouched per the sprint brief.

---

## TL;DR

Single P0 release-blocker identified in the audit (`NOBLORA_CURRENT_STATE_AUDIT.md` §7) is **closed**. The SECURITY DEFINER function `public.dev_auto_verify()` is dropped from the database. Supabase security advisor confirms the targeted two findings disappeared (108 → 106). Flutter analyze + test green (281/281, identical to pre-fix baseline). No regression.

---

## 1. Issue Recap

| Field | Value |
|---|---|
| RPC | `public.dev_auto_verify()` |
| Type | `SECURITY DEFINER`, language `plpgsql`, volatile, 0 args |
| Pre-fix grantees | `PUBLIC, postgres, anon, authenticated, service_role` |
| Attack | Any holder of a Supabase JWT → `POST /rest/v1/rpc/dev_auto_verify` → self-verify, bypass photo review + entry gate |
| Flutter call site | `lib/data/repositories/auth_repository.dart:50` invoked from `lib/providers/auth_provider.dart:214` inside `if (isDevMode) { try {…} catch (e) { debugPrint(…) } }` |
| Why missed earlier | `20260429135255_revoke_definer_executable.sql` and `20260502075743_revoke_definer_executable_public.sql` listed 20 SECDEF functions each — `dev_auto_verify` was not among them. |

---

## 2. Files Changed

```
A  supabase/migrations/20260513135343_r21_revoke_dev_auto_verify.sql   (35 lines)
A  R21_DEV_AUTO_VERIFY_SECURITY_FIX_REPORT.md                          (this file)
```

**No Flutter code changed.** The dead call site in `auth_provider.dart:214` is left in place because:
- It is gated by `isDevMode` (false in release builds), so production never invokes it.
- It is wrapped in `try { … } catch (e) { debugPrint('[auth] dev auto-verify failed: $e'); }` — a missing RPC simply logs a warning on localhost dev signups.
- Removing the call belongs to a tidy-up PR; the sprint brief explicitly forbade Flutter edits.

---

## 3. Migration Content

`supabase/migrations/20260513135343_r21_revoke_dev_auto_verify.sql`:

```sql
REVOKE ALL ON FUNCTION public.dev_auto_verify() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.dev_auto_verify() FROM anon;
REVOKE ALL ON FUNCTION public.dev_auto_verify() FROM authenticated;
REVOKE ALL ON FUNCTION public.dev_auto_verify() FROM service_role;

DROP FUNCTION IF EXISTS public.dev_auto_verify();
```

**Rationale for DROP rather than REVOKE-only:**
- The function body is **not version-controlled** — no `CREATE FUNCTION` exists in the migration set or `supabase_schema.sql`. It lives only on the remote DB as a pre-migration seed.
- `REVOKE ALL` precedes `DROP IF EXISTS` as defense in depth (in case a future re-create accidentally re-grants).
- `DROP` removes the attack surface entirely. Even a misconfigured future `GRANT EXECUTE` cannot re-expose a function that does not exist.
- Local developers who want the auto-verify shortcut can re-create the function in a local seed outside of production migrations.

**Signatures covered:** Only one — `public.dev_auto_verify()` with no parameters. Verified via `pg_proc` pre-migration (single row, args=''); no overloads exist.

---

## 4. Apply Command (Used)

Applied via Supabase MCP `apply_migration` against the production project:

```
project_id : xgkkslbeuydbbcvlhsli  (noblara, ap-northeast-1)
name       : r21_revoke_dev_auto_verify
result     : {"success": true}
```

Equivalent CLI command for traceability:

```bash
supabase db push --linked
# or, for one-off application:
psql "$SUPABASE_DB_URL" -f supabase/migrations/20260513135343_r21_revoke_dev_auto_verify.sql
```

(Secrets never logged. `$SUPABASE_DB_URL` resolved from environment, not from CLAUDE.md or the report.)

---

## 5. Verification Evidence

### 5.1 `pg_proc` lookup

**Before:**
```sql
SELECT proname, pg_get_function_identity_arguments(oid), prosecdef, ...
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname='dev_auto_verify';
```
Result:
```
[{"function_name":"dev_auto_verify","args":"","security_definer":true,
  "volatility":"VOLATILE",
  "execute_grantees":["PUBLIC","postgres","anon","authenticated","service_role"]}]
```

**After:** `[]` — empty. Function gone, no orphan signatures, no lingering grants.

### 5.2 Supabase advisor diff

| Metric | Pre | Post | Δ |
|---|---|---|---|
| Total findings | 108 | 106 | **−2** |
| ERROR | 1 | 1 | 0 |
| WARN | 106 | 104 | −2 |
| INFO | 1 | 1 | 0 |
| `anon_security_definer_function_executable` | 52 | 51 | −1 |
| `authenticated_security_definer_function_executable` | 52 | 51 | −1 |
| `dev_auto_verify` mentions | 2 | **0** | −2 |

CLAUDE.md §6 step 5 "fixed" criterion (targeted rows absent in post-output, no new rows introduced) — **met.**

### 5.3 Flutter regression check

```
flutter analyze --fatal-infos : No issues found! (ran in 4.1s)
flutter test                  : All tests passed! (281 / 281)
```

Identical to the pre-R21 baseline captured in the audit report.

---

## 6. Residual Risk

**For the closed P0:** None. The function does not exist. A re-introduction would require a future migration explicitly re-creating it; if that ever happens, advisor will surface it again as a fresh finding.

**Adjacent items that R21 deliberately did NOT touch** (out of sprint scope, called out for the next iteration):

1. **104 of 106 remaining advisor findings** are still SECDEF functions executable by `anon` / `authenticated`. The vast majority are legitimate RPCs that Flutter genuinely calls (`fetch_nearby_profiles`, `filter_discoverable_ids`, `check_and_create_match`, …) and need that grant to function. They are advisor noise rather than active vulnerabilities — but the list also contains **R18/R19 orphans** (`check_bff_suggestion_limit`, `generate_bff_suggestions`, `process_bff_action`, `process_check_in`) that match feature-removal cleanup candidates. These belong to a later sweep, not R21.

2. **Flutter dead call site** at `auth_provider.dart:214` (and the wrapper at `auth_repository.dart:48-51`) is now a guaranteed-no-op on every localhost build. Removing the two methods is a one-line cleanup for the same PR that drops the Signal feature (see §8).

3. **Function body lost.** Because `dev_auto_verify` was never in version control, recovering its localhost-only behavior requires recreating it from memory/session notes (`session_notes.md` line 3063 documents intent). Acceptable trade-off for the security win.

4. **`hard_delete_expired_accounts()`** function body still not reviewed in audit. Independent of R21.

---

## 7. Compliance With Project Rules

- **CLAUDE.md §1 (kanıt zorunluluğu):** every claim above has either a tool output, advisor count, or file:line citation.
- **CLAUDE.md §3 (DONE checklist):**
  - [x] Code path: `supabase/migrations/20260513135343_r21_revoke_dev_auto_verify.sql`
  - [x] Backend kanıtı: advisor 108→106, pg_proc `[]`, apply_migration `success:true`
  - [x] UI kanıtı: not applicable (no UI change; analyze+test green confirms no client regression)
  - [x] Regresyon kontrolü: known_regressions.md — R5 (bypass-disguised-as-fix) checked: this drops the function entirely rather than layering a new policy over an old one, so the R5 pattern does not apply
  - [x] Guardrail testi: 281 pass / 0 fail
- **CLAUDE.md §5 (scope creep):** sprint touched exactly two files (one migration, one report). No drift.
- **CLAUDE.md §6 (güvenlik migration protokolü):** baseline advisor → migration → post-migration advisor → side-by-side → fixed criterion. All five steps executed and documented in §5.2.

---

## 8. Recommended Next PR — R22

**Branch:** `dalga-r22-drop-post-tables`
**Concern (one):** Drop the orphan `posts` + `post_reactions` (+ leftover `post_comments` shadow) tables that survived the social-feature removal sweep.

**Why R22 next:**
- Same flavor as R21 (single-concern backend cleanup with clear advisor signal).
- Closes the P1 attack surface flagged in `NOBLORA_CURRENT_STATE_AUDIT.md` §4 item 5: `post_reactions.reactions_select` policy is still `USING (true)`, allowing any authenticated user to enumerate the table if data exists.
- Tables have **zero Flutter references** in `lib/` — only the legacy `noblora feed/` parked directory mentions them (and that directory is itself slated for purge in R24).
- Migration is `DROP TABLE … CASCADE` for `posts`, `post_reactions`. `post_comments` was already CASCADE-dropped by `20260331000002`; just confirm no orphan stays.
- Advisor delta target: the `posts_*` and `post_reactions_*` SECDEF rows (typically 4–6 of them in the current 104-count baseline) should disappear.

After R22, the next two recommended PRs (R23 Signal dead-code cleanup, R24 `noblora feed/` legacy purge) become trivially small Flutter-side housekeeping changes that can either bundle or stay split per `feedback_one_pr_one_concern.md` — likely split, given the user's stated preference.

---

## 9. Commit & Push Checklist (when ready)

Per `feedback_commit_discipline.md`, this fix must end in a commit. Recommended commit set, **two separate commits** per `feedback_one_pr_one_concern.md`:

```
git checkout -b dalga-r21-revoke-dev-auto-verify
git add supabase/migrations/20260513135343_r21_revoke_dev_auto_verify.sql
git commit -m "fix(R21): drop dev_auto_verify — close P0 SECDEF executable to authenticated"

git add R21_DEV_AUTO_VERIFY_SECURITY_FIX_REPORT.md
git commit -m "docs(R21): security fix report — advisor 108→106, dev_auto_verify dropped"
```

Awaiting your `go` before running the above. (User-authorized destructive/visible actions only.)

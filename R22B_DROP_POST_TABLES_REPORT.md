# R22B — Drop `posts` + `post_reactions` + `post_comments` Tables Report

**Date:** 2026-05-13
**Sprint:** R22B (backend table drop — single-concern)
**Branch (suggested):** `dalga-r22b-drop-post-tables`
**Pre-conditions:** R22A landed on `main` (commits `01c1118` fix + `c8cf370` docs). Flutter has zero runtime references.
**Scope discipline:** Backend migration only. Zero Flutter changes. Discover / Match / Chat / Travel / Profile / Auth / BFF flows untouched. No UI changes. No new features.

---

## Executive Summary

Three orphan tables and eight attached trigger functions removed in a single migration. **30 DB objects deleted** in one `apply_migration` call: 3 tables, 11 policies, 8 triggers, 8 trigger functions (the 8 triggers and their indexes are removed via the table CASCADE; the 8 functions are dropped explicitly because trigger CASCADE doesn't follow up to function bodies). No regression. Advisor count 106 → 102. Flutter analyze + test green at 281/281.

R22B closes the original P1 from the audit (`NOBLORA_CURRENT_STATE_AUDIT.md` §4 item 5 + §7 P1-1). The `post_reactions.reactions_select USING(true)` policy that allowed any authenticated user to enumerate reactions is gone, along with the table it protected.

---

## 1. Why R22B Was Needed

| Concern | Source | Resolution |
|---|---|---|
| `post_reactions.reactions_select USING(true)` — open enumeration of reaction data for any JWT holder | audit §7 P1-1; `20260329000002:79` | Policy CASCADE-removed with table |
| `posts` table CRUD live despite removed-from-client status | audit §4 item 5 | Table dropped |
| Eight trigger functions that only fired on the dropped tables, still in `pg_proc` as orphan SECDEF code | dependency map (this report §3) | Dropped explicitly |
| Two of those eight (`notify_on_reaction`, `notify_on_reply`) flagged by advisor as anon/authenticated SECDEF executable | advisor baseline | Removed from advisor (−4 findings) |

---

## 2. Runtime Reference Verification

### 2.1 Flutter direct grep (lib/ + test/)

Patterns searched:

```
from\(['"]posts['"]\)
from\(['"]post_reactions['"]\)
from\(['"]post_comments['"]\)
fetchRecentPosts
postsToday
reaction_type
PostReaction
class Post\b
```

Result: **0 matches** in `lib/` and `test/`. The R22A cleanup held.

### 2.2 Flutter RPC call check

Also grepped `lib/` for any `rpc('...')` invocation of the latent post-related RPCs that still live in `pg_proc`:

```
fetch_post_by_id, fetch_nob_feed, fetch_nob_lane,
fetch_comment_counts_batch, fetch_reaction_counts_batch,
get_own_reaction_counts, get_own_reaction_counts_batch,
edit_comment, perform_minor_edit, perform_second_thought,
fetch_noblara_unread_count, mark_noblara_notifications_read
```

Result: **0 matches.** No client-side call site → these are unreachable from V1 (but still latent if anyone wires them up later; see §9).

### 2.3 DB FK inbound check

```sql
SELECT … FROM pg_constraint
WHERE contype='f'
  AND confrelid IN ('public.posts','public.post_reactions','public.post_comments')
  AND conrelid NOT IN ('public.posts','public.post_reactions','public.post_comments');
```

Result: **0 rows.** No KEPT table FKs into the three targets, so `CASCADE` is fully contained.

---

## 3. DB Objects Removed

### Tables (3)

| Table | Created in | Last touched |
|---|---|---|
| `public.posts` | `20260329000002_noblara_social_posts.sql` | `20260413000002_posts_ai_error.sql` |
| `public.post_reactions` | `20260329000002_noblara_social_posts.sql` | (no later changes) |
| `public.post_comments` | `20260331000001_post_comments.sql` | `20260413000001_second_thought.sql` |

### Policies (11) — CASCADE'd with their owning table

```
posts:           posts_delete, posts_insert, posts_select_owner_only, posts_update
post_reactions:  reactions_delete, reactions_insert, reactions_select_own
post_comments:   delete_own_comment, insert_own_comment, update_own_comment, view_comments
```

### Indexes (~19) — CASCADE'd with their owning table

```
posts:           posts_pkey, posts_user_idx, posts_created_idx,
                 posts_ai_status_failed_idx, idx_posts_analyzed,
                 idx_posts_anonymous, idx_posts_city_cluster,
                 idx_posts_country_code, idx_posts_primary_mood
post_reactions:  post_reactions_pkey, post_reactions_post_id_user_id_key,
                 reactions_post_idx, reactions_user_idx
post_comments:   post_comments_pkey, idx_post_comments_post_id,
                 idx_post_comments_user_id, idx_post_comments_parent,
                 idx_post_comments_chain
```

### Triggers (8) — CASCADE'd with their owning table

```
posts:           feed_event_post_published_trg, posts_nob_count,
                 posts_pinned_nob, posts_updated_at
post_reactions:  feed_event_reaction_changed_trg, notify_on_reaction_trg
post_comments:   feed_event_comment_added_trg, notify_on_reply_trg
```

### Trigger functions (8) — dropped explicitly

These don't get CASCADE'd when their owning trigger is dropped (Postgres only removes the trigger record, not the function body). All 8 verified to have **zero other trigger consumers** via `pg_trigger` join before drop:

```
public.feed_event_post_published()      -- only on posts
public.feed_event_reaction_changed()    -- only on post_reactions
public.feed_event_comment_added()       -- only on post_comments
public.notify_on_reaction()             -- only on post_reactions
public.notify_on_reply()                -- only on post_comments
public.increment_nob_count()            -- only on posts
public.update_has_pinned_nob()          -- only on posts
public.set_updated_at()                 -- only on posts (verified — Noblara uses other touch-fn patterns elsewhere)
```

### Post-migration verification query

```sql
SELECT 'table' AS kind, table_name AS name
  FROM information_schema.tables
 WHERE table_schema='public' AND table_name IN ('posts','post_reactions','post_comments')
UNION ALL
SELECT 'policy', policyname || ' on ' || tablename
  FROM pg_policies WHERE schemaname='public' AND tablename IN (...)
UNION ALL
SELECT 'trigger', t.tgname || ' on ' || c.relname FROM pg_trigger t JOIN pg_class c ...
UNION ALL
SELECT 'function', p.proname FROM pg_proc p ...
   WHERE proname IN (the 8 trigger fns);
```

**Result: `[]` (empty).** All 30 objects gone.

---

## 4. Migration File

```
supabase/migrations/20260513141916_r22b_drop_post_tables.sql   (74 lines)
```

Body summary:

```sql
DROP TABLE IF EXISTS public.post_reactions CASCADE;
DROP TABLE IF EXISTS public.post_comments  CASCADE;
DROP TABLE IF EXISTS public.posts          CASCADE;

DROP FUNCTION IF EXISTS public.feed_event_comment_added();
DROP FUNCTION IF EXISTS public.feed_event_post_published();
DROP FUNCTION IF EXISTS public.feed_event_reaction_changed();
DROP FUNCTION IF EXISTS public.notify_on_reply();
DROP FUNCTION IF EXISTS public.notify_on_reaction();
DROP FUNCTION IF EXISTS public.increment_nob_count();
DROP FUNCTION IF EXISTS public.update_has_pinned_nob();
DROP FUNCTION IF EXISTS public.set_updated_at();
```

Ordering rationale: `post_reactions` and `post_comments` both FK into `posts`, so they drop first (or via CASCADE either way). `IF EXISTS` and `CASCADE` keep the migration idempotent and self-contained against any partial prior cleanup.

The header comment documents pre-conditions, FK safety analysis, the explicit scope boundary (15 latent RPC orphans left for R22C), and rollback notes.

---

## 5. Apply Command

Applied via Supabase MCP `apply_migration` against the production project:

```
project_id : xgkkslbeuydbbcvlhsli  (noblara, ap-northeast-1)
name       : r22b_drop_post_tables
result     : {"success": true}
```

Equivalent CLI:

```bash
supabase db push --linked
# or
psql "$SUPABASE_DB_URL" -f supabase/migrations/20260513141916_r22b_drop_post_tables.sql
```

Secrets/keys not logged.

---

## 6. Advisor Before / After (CLAUDE.md §6 protocol)

| Metric | Pre-R22B | Post-R22B | Δ |
|---|---|---|---|
| Total findings | 106 | **102** | **−4** |
| ERROR | 1 | 1 | 0 |
| WARN | 104 | 100 | −4 |
| INFO | 1 | 1 | 0 |
| `anon_security_definer_function_executable` | 51 | 49 | −2 |
| `authenticated_security_definer_function_executable` | 51 | 49 | −2 |
| `rls_disabled_in_public` (spatial_ref_sys, PostGIS) | 1 | 1 | 0 |
| `rls_enabled_no_policy` (_internal_config) | 1 | 1 | 0 |
| `extension_in_public` (postgis) | 1 | 1 | 0 |
| `auth_leaked_password_protection` | 1 | 1 | 0 |

**The −4 corresponds to `notify_on_reaction` + `notify_on_reply`** — the only two functions in our drop list that the advisor saw as anon/authenticated-executable SECDEF. The other 6 trigger functions return `trigger` type and weren't in the advisor list to begin with.

**Functions that R22B did NOT drop and that still show in advisor with `posts`-content coupling** (latent RPC orphans, see §9):

```
edit_comment                       fetch_comment_counts_batch
fetch_country_insight_data         fetch_country_mood_detail
fetch_country_moods                fetch_echo_counts_batch
fetch_nob_lane                     fetch_noblara_unread_count
fetch_post_by_id                   fetch_reaction_counts_batch
get_own_reaction_counts            get_own_reaction_counts_batch
mark_noblara_notifications_read    perform_minor_edit
perform_second_thought
```

That's 15 functions × 2 roles = 30 findings still on the books. None reachable from Flutter (§2.2).

CLAUDE.md §6 step 5 "fixed" criterion — *targeted rows absent in post-output, no other rows introduced*: **met.**

---

## 7. Flutter Analyze / Test

```
flutter analyze --fatal-infos : No issues found! (ran in 115.9s — fresh pub get cache cold)
flutter test                  : All tests passed! (281 / 281)
```

Identical to post-R21 / post-R22A baseline. Zero regression. The backend drop has no compile-time effect because Flutter never referenced the dropped objects.

---

## 8. Risk Assessment

**Functional risk: zero (verified).**
- Flutter never called these tables, RPCs, or triggers (R22A grep + this report §2.1, §2.2).
- No KEPT table FK'd into the dropped set (§2.3) — CASCADE is fully contained.
- All 8 trigger functions had zero other consumers (DB-verified).
- `feed_events` table preserved per intent (it's used by other systems; this migration only stops new rows from being written by the now-deleted post triggers, which is the desired outcome since posts no longer exist).

**Operational risk: low.**
- If a future client release wires up a stale RPC like `fetch_post_by_id`, it will throw `42883: function public.fetch_post_by_id(...) does not exist` only after the latent RPC orphans are themselves dropped in R22C. Today they still exist but throw `42P01` if called (no table). Either way, V1 client cannot reach them.

**Migration safety: idempotent.**
- All statements use `IF EXISTS` so a re-run is a no-op.

**Schema reproducibility risk: moderate.**
- The original `CREATE TABLE` statements for these three tables are in chronological migrations (`20260329000002`, `20260331000001`), so re-creating them is technically possible via reverting + re-applying those old migrations — but doing so would also resurrect their open `USING(true)` policies. **A re-introduction of these features should redesign the schema, not replay the old migrations.**

---

## 9. Rollback Notes

R22B is a destructive migration. Conventional rollback paths:

1. **Pre-migration snapshot:** Supabase project has automated daily backups. Restoring to a backup taken before `2026-05-13T14:19:16Z` recovers all 30 objects byte-for-byte.
2. **Forward replay:** Apply the original migration files (`20260329000002`, `20260331000001`, `20260331000002`, `20260413000001`, `20260413000002`) in chronological order to recreate the schema. **Not recommended** — they include the original permissive policies (`USING(true)` etc.) that this sprint was partly designed to remove.

In practice: if the post/feed feature ever comes back as a Noblara feature, it should be designed fresh against the V1.x security baseline, not by un-dropping these tables.

---

## 10. Remaining Legacy Cleanup Candidates

The audit identified more legacy DB tendrils than R22B addresses by design. Snapshot of what remains:

### Latent RPC orphans referencing now-deleted tables (R22C candidate)

15 SECURITY DEFINER functions whose bodies reference `posts` / `post_comments` / `post_reactions` content and will throw `42P01` if called. None are invoked by Flutter:

```
edit_comment, fetch_comment_counts_batch, fetch_country_insight_data,
fetch_country_mood_detail, fetch_country_moods, fetch_echo_counts_batch,
fetch_nob_lane, fetch_noblara_unread_count, fetch_post_by_id,
fetch_reaction_counts_batch, get_own_reaction_counts,
get_own_reaction_counts_batch, mark_noblara_notifications_read,
perform_minor_edit, perform_second_thought
```

Advisor delta achievable by R22C: **up to −30 findings** (15 functions × 2 roles each).

### Other audit-flagged cleanups (separate sprints)

- **R23**: Signal dead code (Flutter `signal_repository.dart` + `signal.dart` + dead notification handler branch). Pure Flutter PR.
- **R24**: `noblora feed/` legacy directory at repo root.
- **R25**: AAB rebuild after R21 / R22A / R22B / R23 stack.
- **R26 (V1.x)**: Orphan profile columns (`show_status_badge`, `show_last_active`, `calm_mode`, `incognito_mode`, `bff_visible`, `bff_bio`, `bff_avatar_url`) + `bff_suggestions` / `bff_plans` / `check_ins` tables.

---

## 11. Recommended Next Sprint — R23

**Branch (suggested):** `dalga-r23-signal-dead-code`
**Concern (one):** Strip the orphan Signal feature from Flutter.

**Scope:**
- Delete `lib/data/repositories/signal_repository.dart`
- Delete `lib/data/models/signal.dart`
- Remove `signalRepositoryProvider` registration in `lib/providers/feed_provider.dart` (lines 9, 17–20)
- Strip the dead `'signal_received'` branch from notification handler in `lib/navigation/main_tab_navigator.dart:73`
- Confirm no other imports

**Out of scope:**
- DB-side: `signals` table and SECURITY DEFINER functions (`check_signal_limit`, `increment_signal_count`, `can_user_interact`, etc.) — leave for a later V1.x signal sweep.

**Why R23 next:**
- Pure Flutter cleanup, contained blast radius (mirror image of R22A pattern).
- Closes the audit §4 item 2 finding.
- Sets up a future signal-DB sweep with the same Flutter-first / backend-second pattern that worked for R22.

---

## 12. Compliance With Project Rules

- **CLAUDE.md §1 (kanıt zorunluluğu):** every claim above has SQL output, advisor count, grep result, or apply_migration response cited.
- **CLAUDE.md §3 (DONE checklist):**
  - [x] Code path: `supabase/migrations/20260513141916_r22b_drop_post_tables.sql`
  - [x] Backend kanıtı: post-migration verification query empty; advisor 106→102; apply_migration `success:true`
  - [x] UI kanıtı: N/A (no UI change); analyze+test green proves no client regression
  - [x] Regresyon kontrolü: R5 (bypass-disguised-as-fix) — N/A; this is a clean DROP, not a policy layer-over. R7 (audit claims without verification) — every "Flutter has zero refs" claim re-verified by direct grep before action.
  - [x] Guardrail testi: 281 / 281 pass
- **CLAUDE.md §5 (scope creep):** sprint touched exactly two files (one migration, one report) + applied one DB migration. Did NOT also drop the 15 latent RPC orphans even though they were tempting (explicitly outside R22B scope; flagged for R22C).
- **CLAUDE.md §6 (güvenlik migration protokolü):** baseline → migration → verify → side-by-side advisor → fixed criterion. All 5 steps executed; §6 of this report captures the deltas.

---

## 13. Awaiting Approval

Per sprint brief: **"Commit/push yapmadan önce dur ve özet ver."**

Working tree state:

```
?? supabase/migrations/20260513141916_r22b_drop_post_tables.sql
?? R22B_DROP_POST_TABLES_REPORT.md
```

Nothing staged. No commit attempted. Awaiting your `go` to commit/push, with the same R21/R22A split pattern as the default:

**Option (a) — single commit:**
```
fix(noblora): R22B drop post tables (backend cleanup)
```

**Option (b) — split commits (matching R22A):**
```
fix(noblora): drop posts post_reactions post_comments tables
docs(noblora): add R22B drop post tables report
```

Say `go (a)` or `go (b)` and I will execute. Or `stop` to leave as untracked working files.

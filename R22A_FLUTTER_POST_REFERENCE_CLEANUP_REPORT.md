# R22A — Flutter `posts` Reference Cleanup Report

**Date:** 2026-05-13
**Sprint:** R22A (Flutter-side prep before backend table drop)
**Branch (suggested):** `dalga-r22a-flutter-post-cleanup`
**Scope discipline:** Flutter-only. **Zero Supabase migrations** written or applied. No DB tables touched. No new features. No UI redesign. Discover / Match / Chat / Travel / Profile / Auth / BFF (already gone) flows untouched. Only the still-wired posts plumbing in admin + the orphan model + a few help-center sentences.

---

## Executive Summary

The audit-driven plan to drop `posts` + `post_reactions` tables (R22) hit a stop: Flutter still ran a `db.from('posts').select('id')` query on every admin dashboard open via `fetchAdminStats()`. The audit sub-agent's "zero references" claim was incorrect; direct grep showed an active runtime reference. R22A closes that gap by removing the only runtime path, deleting the orphan model classes (keeping the `NobTier` enum that 6 unrelated UI files depend on), and updating user-facing copy that still mentioned posts/reactions.

After R22A:
- `git grep -nE "from\(['\"]posts['\"]\)|fetchRecentPosts|postsToday|reaction_type|PostReaction|class Post\b"` in `lib/` → **0 matches**
- One comment leftover in `feed_repository.dart:141` (descriptive only, no DB call) — explicitly permitted by sprint brief
- `flutter analyze --fatal-infos`: **No issues found** (5.9s)
- `flutter test`: **281 / 281 pass** (unchanged from baseline)
- Diff: **4 files, +7 / −334 lines** (net −327)

R22B (the backend `DROP TABLE` migration) is now safe to apply.

---

## 1. Why R22A Was Needed

R22's intent was a single backend `DROP TABLE … CASCADE` for `posts` + `post_reactions`. The R22 brief told me to stop if Flutter active references existed. Direct grep found:

| Reference | Wired? | Risk under R22 backend drop |
|---|---|---|
| `admin_repository.dart:34` — `db.from('posts').select('id').gte(...)` | **YES** — called from `_adminStatsProvider` whenever an admin opens the Admin tab | `42P01: relation "public.posts" does not exist` → admin stats `FutureProvider` errors → "Error: …" banner in admin Overview |
| `admin_repository.dart:117` — `db.from('posts').select(...)` inside `fetchRecentPosts()` | **No** — method has zero call sites in `lib/` | Latent risk only; would surface if any future code invoked it |
| `data/models/post.dart` — `Post` class + `PostReaction` class | **No** for the classes themselves; **YES** for the `NobTier` enum in the same file | Classes are dead; enum is critical (used by tier_badge, profile.dart, tier_promotion_screen, user_profile_screen, main_tab_navigator, profile_screen) |
| `help_center_screen.dart` — 4 user-visible strings mentioning posts/reactions/Noblara Feed | **YES** (rendered) | Cosmetic — confusing copy once the feature is gone |

Without R22A, R22B would break the admin Overview tab for admin-flagged users. With R22A, R22B's `DROP TABLE` runs against a table that Flutter no longer references.

---

## 2. Flutter Reference Scan Results

### 2.1 Before R22A

```
lib/data/repositories/admin_repository.dart:34   db.from('posts')...
lib/data/repositories/admin_repository.dart:117  db.from('posts')...
lib/data/repositories/admin_repository.dart:108  Future fetchRecentPosts(...)
lib/data/repositories/admin_repository.dart:18   int postsToday,
lib/data/repositories/admin_repository.dart:25   postsToday: 0,
lib/data/repositories/admin_repository.dart:44   postsToday: (results[3] as List).length,
lib/features/admin/admin_screen.dart:34          final int postsToday;
lib/features/admin/admin_screen.dart:40          this.postsToday = 0,
lib/features/admin/admin_screen.dart:54          postsToday: 8,
lib/features/admin/admin_screen.dart:62          postsToday: stats.postsToday,
lib/features/admin/admin_screen.dart:208         label: 'Posts Today',
lib/features/admin/admin_screen.dart:209         value: stats.postsToday,
lib/data/models/post.dart                        Post + PostReaction + NobTier (all 3)
lib/features/settings/help_center_screen.dart:484  "Your conversations, matches, and posts remain intact"
lib/features/settings/help_center_screen.dart:492  "...matches, posts, and all associated files"
lib/features/settings/help_center_screen.dart:507  "• All posts and reactions"
lib/features/settings/help_center_screen.dart:641–669  "I. NOBLARA FEED" entire category (3 _HelpItem)
```

### 2.2 After R22A

```
lib/data/repositories/admin_repository.dart  → no `posts` references
lib/features/admin/admin_screen.dart         → no `posts` references
lib/data/models/post.dart                    → contains ONLY `NobTier` enum (22 lines)
lib/features/settings/help_center_screen.dart  → posts/Noblara Feed copy gone
```

Final repo-wide grep (`from\(['"]posts['"]\)|from\(['"]post_reactions['"]\)|fetchRecentPosts|postsToday|Posts Today|reaction_type|PostReaction|class Post\b`) over `lib/` and `test/`: **0 runtime matches**.

Only remaining mention of the word "posts" in `lib/`:

```
lib/data/repositories/feed_repository.dart:141:      // Has Nob posts (weekly — survives UTC daily reset)
```

This is a comment inside an unrelated tier-vitality calculation. The line above it does NOT call any posts table — it's commentary. Sprint brief explicitly permitted comment leftovers ("yorum satırları … hariç tutulabilir").

The `noblara feed/` legacy directory at repo root still has its own copies of post.dart / post_repository.dart / posts_provider.dart, but that directory is not in `pubspec.yaml`, not part of the build, and was already flagged as a separate cleanup target (R24) in the audit. Out of R22A scope.

---

## 3. Files Modified

| File | +ins | -del | What changed |
|---|---|---|---|
| `lib/data/models/post.dart` | 0 | 243 | Replaced with NobTier-only file (22 lines). Removed `Post` class, `PostReaction` class, `package:flutter/foundation.dart` import. |
| `lib/data/repositories/admin_repository.dart` | 3 | 55 | `fetchStats()` record type: 4-field → 3-field (dropped `postsToday`). Removed posts query from `Future.wait`. Deleted entire `fetchRecentPosts()` method (lines 105–140). Updated doc comment. |
| `lib/features/admin/admin_screen.dart` | 0 | 9 | Dropped `postsToday` field from `_AdminStats`. Dropped `postsToday: 8` from mock + `postsToday: stats.postsToday` from real path. Removed "Posts Today" `_StatCard` widget (4 lines + trailing comma adjustment). |
| `lib/features/settings/help_center_screen.dart` | 4 | 27 | Rephrased pause/delete bodies (dropped "and posts", "posts," fragments). Removed "All posts and reactions" bullet. Deleted entire "I. NOBLARA FEED" `_HelpCategory` (3 items, ~28 lines). |
| **Total** | **7** | **334** | net −327 lines |

No new files. No file renames. No `pubspec.yaml` change (no deps added/removed).

---

## 4. Build / Test Results

```
flutter analyze --fatal-infos : No issues found! (ran in 5.9s)
flutter test                  : All tests passed! (281 / 281)
```

Identical to the post-R21 baseline. Zero regression.

The `Profile toJson -> fromJson roundtrip` guardrail suite is unaffected because `profile.dart` only imported `post.dart` for `NobTier`, which is still exported.

---

## 5. Why R22B Is Now Safe

The single hard blocker for `DROP TABLE public.posts CASCADE` was the admin stat query. That query is gone:

```dart
// admin_repository.dart, before R22A (line 34):
db.from('posts').select('id').gte('created_at', ...)
// admin_repository.dart, after R22A:
// (query removed; Future.wait now has 3 parallel reads, not 4)
```

DB-side dependencies that R22B will need to deal with (recap from prior dependency discovery, not changed by R22A):

```
indexes (will CASCADE):  idx_posts_*, posts_*_idx, post_reactions_*_idx, post_comments_*_idx (~14)
policies (will CASCADE): posts_*, reactions_*, *_comment (~9)
triggers (will CASCADE): feed_event_post_published_trg, feed_event_reaction_changed_trg,
                         feed_event_comment_added_trg, notify_on_reaction_trg,
                         notify_on_reply_trg, posts_nob_count, posts_pinned_nob,
                         posts_updated_at  (~8)
post_comments table also linked via FK to posts → would CASCADE-drop too
```

No outbound FK from any KEPT table points at `posts` or `post_reactions`, so CASCADE is contained. R22B's `DROP TABLE IF EXISTS public.post_reactions CASCADE; DROP TABLE IF EXISTS public.posts CASCADE;` will additionally remove `post_comments` (since it FKs into `posts`). The user's R22 scope listed posts + post_reactions; whether `post_comments` should also be explicit-dropped in R22B is a small decision for the next sprint — CASCADE will take it anyway.

Advisor delta projection for R22B (informational, not measured this sprint): each of these 3 tables and their `posts_*` / `reactions_*` SECDEF function rows in the advisor's `anon_security_definer_function_executable` / `authenticated_security_definer_function_executable` categories should disappear. Estimated −4 to −8 advisor findings on top of R21's 106. To be measured in the actual R22B sprint.

---

## 6. Risk Assessment

**Functional risk: low.**

- Admin Overview tab: stat card count drops from 4 to 3 ("Posts Today" removed). All other admin functionality intact (verifications tab unchanged, approve/reject paths unchanged).
- Profile, Discover, Match, Chat, Travel, Auth, Settings (non-help-center), Onboarding: untouched.
- `NobTier` enum users (6 files): unaffected — same enum, same imports.
- Help Center: 4 small copy edits + one whole category removed. Users see slightly shorter help index. No broken links, no orphan navigation.

**Build risk: zero.** Analyze and test both green.

**Behavioral surprise:** An admin user who refreshed the Overview tab during V1 would have seen a "Posts Today" tile auto-populate with whatever count the DB held. After R22A they see 3 tiles instead of 4. Acceptable since posts feature is removed and admins receive a tighter UI.

**Migration coupling risk:** None — R22A makes no DB change. If R22B is ever skipped or rolled back, R22A still stands as valid cleanup.

---

## 7. Rollback Notes

R22A is a pure Flutter code change. Rollback is `git revert <r22a-commit>` on the branch. No data migration, no schema state, no API contract change.

If specifically the help-center copy edits should be kept while reverting admin/post changes, the commits can be split (currently planned as a single commit per sprint brief — call out if a split is preferred).

---

## 8. Compliance With Project Rules

- **CLAUDE.md §1 (kanıt zorunluluğu):** every claim has a tool output reference (analyze, test, grep, git diff --stat).
- **CLAUDE.md §3 (DONE checklist):**
  - [x] Code path: 4 files listed in §3 with line counts
  - [x] Backend kanıtı: N/A this sprint — no DB change; R22B will carry that responsibility
  - [x] UI kanıtı: analyze + test green; admin stat card visual change documented; help-center category removal documented
  - [x] Regresyon kontrolü: known_regressions.md — R1 (Profile copyWith drift) checked: profile.dart only imports `NobTier`, untouched. R3 (`_substantive()` filter): N/A. R7 (audit claims without verification): this sprint's own report sub-agent claim was the trigger to STOP and re-verify by direct grep — followed §9.
  - [x] Guardrail testi: 281 / 281 pass
- **CLAUDE.md §5 (scope creep):** 4 file changes — all four in the prompt's explicit YAPILACAKLAR list. No bonus refactors.
- **CLAUDE.md §6 (security migration protokolü):** N/A — no migration this sprint.

---

## 9. Recommended Next Sprint — R22B

**Branch (suggested):** `dalga-r22b-drop-post-tables`
**Concern (one):** Backend `DROP TABLE` for `posts` + `post_reactions` (+ implicit `post_comments` via CASCADE).
**Pre-conditions now met:** R22A landed; `git grep` confirms zero runtime references in `lib/`.

Proposed migration shell:

```sql
-- supabase/migrations/<ts>_r22b_drop_post_tables.sql
-- (advisor baseline → apply → re-check; CLAUDE.md §6 protocol)

DROP TABLE IF EXISTS public.post_reactions CASCADE;
DROP TABLE IF EXISTS public.posts CASCADE;
-- post_comments removed implicitly via FK CASCADE; if it survives, drop explicit:
DROP TABLE IF EXISTS public.post_comments CASCADE;
```

Verification:
- `information_schema.tables` rows for the three names should be empty.
- `pg_policies` rows referencing those tables should be empty.
- `pg_trigger` rows for `feed_event_post_published_trg`, `notify_on_reaction_trg` and the rest should be gone.
- Advisor `posts_*` / `reactions_*` / `post_comments_*` SECDEF function-executable findings should drop out.
- `flutter analyze` / `flutter test` should stay 281/281 with no change (Flutter no longer touches these tables).

---

## 10. Awaiting Approval

Per sprint brief: **"Commit/push yapmadan önce dur ve özet ver."**

Working tree currently has 4 modified files (above) + this report. Nothing staged. No commit attempted. Awaiting your `go` to:

1. Stage the 4 Flutter files + this report.
2. Single commit, message proposed: `fix(noblara): R22A — remove flutter posts references`
3. Push `origin main` (matching R21 push pattern).

Say the word and I'll execute. Or split the commit (Flutter cleanup vs. doc) if you prefer the strict one-PR-one-concern shape.

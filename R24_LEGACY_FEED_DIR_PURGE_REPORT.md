# R24 — Legacy `noblora feed/` Directory Purge Report

**Date:** 2026-05-13
**Sprint:** R24 (repo hygiene)
**Branch (suggested):** `dalga-r24-noblora-feed-purge`
**Scope:** Repo cleanup. No Flutter runtime behavior change. No Supabase migration. No DB touch. Discover / Match / Chat / Travel / Profile / Auth flows untouched.

---

## Executive Summary

The `noblora feed/` directory at repo root has been purged. It was a 706 KB / 35-file mini-project mirror containing an old Noblara social-feed implementation (lib/features/social, providers, supabase/functions, tests) that pre-dated the R18 BFF removal and R19 Status removal. It was excluded from the Flutter analyzer (`analysis_options.yaml`), absent from `pubspec.yaml`, not imported by any active source file, and not referenced by Android/gradle or any CI script — but it kept appearing in audit grep results and confused two sub-agents during R22 and R23, leading to incorrect "Flutter has these references" claims that had to be re-verified.

After R24:
- 35 files deleted (−12 138 lines)
- 2 small config/doc edits (+3 / −7 lines)
- `flutter analyze --fatal-infos`: **No issues found**
- `flutter test`: **281 / 281 pass**
- Repo-wide grep for `noblora feed` now returns only historical reports + one explanatory comment I added in this sprint

---

## 1. Why R24 Was Needed

Two concrete pains it caused:

1. **R22 sub-agent false positive.** The Supabase contract audit agent reported "Flutter has zero references to posts" — incorrect because admin_repository did call `db.from('posts')`. When I cross-checked, the only other code referencing `posts` was inside `noblora feed/lib/data/repositories/post_repository.dart`. That made the cross-check noisier than it should have been: the agent had been pattern-matching against a directory that was not in the build.
2. **R22B/R23 manual grep noise.** Every "is this still referenced?" check during R22/R23 had to manually filter out `noblora feed/` hits. The `analysis_options.yaml:14` exclude (`- "noblora feed/**"`) silenced the analyzer but not grep tools or explorer agents.

Both pains are eliminated by simply removing the directory. There is no upside to keeping it around — the post/social/circles work it contained was either redesigned (R22A/R22B) or removed (R18 BFF, R19 Status). If a future feature ever revives a Noblara social layer, it should be designed fresh against the V1.x architecture, not resurrected from this parked snapshot.

---

## 2. Inventory of the Deleted Directory

```
noblora feed/
├── assets/         (some legacy asset files)
├── lib/
│   ├── data/
│   │   ├── models/         (post.dart, etc.)
│   │   └── repositories/   (post_repository.dart, etc.)
│   ├── features/social/    (room_card_widget, room_chat_screen, rooms_tab)
│   └── providers/          (posts_provider, mood_map_provider,
│                            noblara_notification_provider, room_provider,
│                            comment_provider, …)
├── supabase/
│   └── functions/
│       ├── nob-ai-edit/             (115 lines)
│       ├── nob-country-insight/     (169 lines)
│       └── nob-quality-check/       (386 lines)
└── test/
    ├── nob_compose_turkish_test.dart
    ├── post_masking_test.dart
    └── posts_optimistic_react_test.dart
```

Total: 35 files, 706 KB on disk, ~12 138 lines of code deleted by `git rm -r`.

Largest individual files (per `git diff --cached --stat`):
- `lib/features/social/room_chat_screen.dart` — 618 lines
- `lib/providers/posts_provider.dart` — 660 lines
- `supabase/functions/nob-quality-check/index.ts` — 386 lines
- `lib/features/social/room_card_widget.dart` — 278 lines
- `lib/providers/room_provider.dart` — 273 lines

---

## 3. Proof It Was Not Used By Runtime / Build

### 3.1 `pubspec.yaml`
- No `assets:` entry referencing `noblora feed/`.
- No `dependencies` path-resolved into it.
- Confirmed by `grep -n "noblora feed" pubspec.yaml`: no matches.

### 3.2 Analyzer
- `analysis_options.yaml:13–14` explicitly excluded it:
  ```yaml
  analyzer:
    exclude:
      - "noblora feed/**"
  ```
  Removed in this sprint as part of the cleanup (now that the dir doesn't exist, the exclude is meaningless).

### 3.3 Import paths
- `grep` across `lib/` and `test/` for `noblora feed`, `noblora_feed`, `noblora/feed`, `noblora\\feed`: **zero matches in active code**, except one doc-comment in `lib/core/utils/mock_mode.dart:18` (now updated; see §4).

### 3.4 Android / iOS / CI
- `android/build.gradle.kts`, `android/app/`, `gradle.properties`: no references.
- No `.github/`, no `scripts/`, no root-level CI config touches it.

### 3.5 Other tooling
- No `Makefile`, no `justfile`, no `taskfile.yaml` at repo root.
- Firebase config and `.env` neither bundle nor reference the dir.

Verdict: the directory was orphan in every sense — present on disk and in git history, but invisible to every build/runtime/test toolchain.

---

## 4. Files Changed Beyond the Deletion

Two tiny edits to clean up the now-stale references:

### 4.1 `lib/core/utils/mock_mode.dart`

The `kSocialEnabled` feature-flag doc-comment used to point at the legacy dir:

```diff
- /// Events were removed in Dalga 13. Rooms/circles code lives in
- /// noblora feed/lib/features/social/ and related providers, but is inert at runtime.
- /// Flip to true to re-enable.
+ /// Events were removed in Dalga 13. The rooms/circles code that used to
+ /// live in the legacy `noblora feed/` directory was purged in R24; flipping
+ /// this flag to true would now require a fresh implementation.
  const bool kSocialEnabled = false;
```

Comment-only edit. `kSocialEnabled` constant value unchanged (`false`). Zero runtime behavior change.

### 4.2 `analysis_options.yaml`

```diff
- analyzer:
-   exclude:
-     - "noblora feed/**"
- 
  linter:
```

Removed the analyzer exclude block (the entire `analyzer:` section, since the exclude was its only contents). Excluding a non-existent path is a no-op; removing it tidies the config.

---

## 5. Repo-Wide Verification

`Grep -r "noblora feed"` over the whole repo, post-purge:

```
APP_UNDERSTANDING_REPORT.md            (historical audit doc, untracked at repo root)
AUDIT_REPORT.md                        (historical audit doc, untracked at repo root)
NOBLORA_CURRENT_STATE_AUDIT.md         (R-series audit, untracked at repo root)
R21_DEV_AUTO_VERIFY_SECURITY_FIX_REPORT.md  (committed report — mentions "slated for purge in R24")
R22B_DROP_POST_TABLES_REPORT.md        (committed report — mentions R24 as a candidate)
R23_SIGNAL_UNREACHABLE_BRANCH_CLEANUP_REPORT.md  (committed report)
.claude/known_regressions.md            (historical session memory)
lib/core/utils/mock_mode.dart:18        (the R24 explanatory comment added in §4.1)
```

**Zero active import / asset / build references remain.** All 8 hits are either historical artifacts (left intentionally) or the new explanatory comment that points at the purge itself.

---

## 6. Build / Test Results

```
flutter analyze --fatal-infos : No issues found! (ran in 4.0s)
flutter test                  : All tests passed! (281 / 281)
```

Identical to the post-R23 baseline. Removing `analysis_options.yaml` exclude block did not surface new lint issues — the dir is now gone, so there was nothing to exclude anyway.

---

## 7. Risk Assessment

**Functional risk: zero.** No code in `noblora feed/` was reachable from any active path — analyzer excluded it, no imports targeted it, no build script bundled it.

**Build risk: zero.** Analyze + test green. Removing the analyzer exclude is the cleanest possible config delta — fewer lines, same effective behavior.

**Documentation risk: low.** Historical reports (R21, R22B, R23, NOBLORA_CURRENT_STATE_AUDIT, APP_UNDERSTANDING_REPORT, AUDIT_REPORT) still reference `noblora feed/` as a then-existing directory. This is intentional — reports are frozen artifacts and the references are correct in context. The `known_regressions.md` mentions are similarly historical-record entries.

**Recovery risk: low.** If the directory ever needs to be inspected (e.g., to mine an old post/social implementation for V1.x revival), it lives in git history at every commit on `main` from May 8 through this sprint. `git show <pre-r24-sha>:"noblora feed/lib/providers/posts_provider.dart"` retrieves any specific file.

**Reproducibility risk: zero.** Re-running `pubspec.yaml`-based builds yields identical output. No tests change.

---

## 8. Remaining Cleanup Candidates

The audit's recap of orphan/legacy items, with R24 status appended:

| Item | Status | Owner sprint |
|---|---|---|
| Legacy `noblora feed/` directory | **DONE (R24)** | — |
| 15 latent post-RPC orphans in `pg_proc` | Pending | R22C |
| DB-side Signal objects (`signals` table + 4 SECDEF RPCs) | Pending | R23-DB |
| Orphan profile columns (`show_status_badge`, `show_last_active`, `calm_mode`, `incognito_mode`, `bff_*`) | Pending | R26 (V1.x) |
| `bff_suggestions` / `bff_plans` / `check_ins` tables | Pending | R26 (V1.x) |
| `ToastType.signal` enum value (4 pattern arms in toast infra) | Pending | R23-tail (optional) |
| Three untracked root-level audit docs (APP_UNDERSTANDING_REPORT.md, AUDIT_REPORT.md, NOBLORA_CURRENT_STATE_AUDIT.md) | Untracked since R20+ | Decision needed: gitignore, move to `.claude/`, or commit as historical record |
| AAB rebuild after R21→R24 stack | Pending | **R25 — recommended next** |

---

## 9. Recommended Next Sprint — R25

**Branch (suggested):** `dalga-r25-aab-rebuild`
**Concern (one):** Build a fresh signed AAB for the Play Store on top of the R21 → R24 commit stack.

**Why R25 next:**
- The last documented AAB was post-R15 (commit `f92aee4`, before R17B/R18/R19/R20/R21/R22A/R22B/R23/R24). Anything submitted today should bundle the dev_auto_verify revocation, the post-tables drop, the Signal cleanup, and the legacy-dir purge.
- Pure release-engineering sprint. No code or DB change.
- Verifies the cleaned-up codebase actually builds release-mode end-to-end (analyze + test catch a lot, but `flutter build appbundle --release` is the last gate).

**Steps (for the prompt):**
1. `flutter clean`
2. `flutter pub get`
3. `flutter build appbundle --release` (with the existing signing keystore — never log the key.properties contents)
4. Verify .aab output, smoke-install on a real device or emulator
5. Record SHA-256, size, and version info in a small `R25_AAB_BUILD_REPORT.md`
6. Stop and ask for upload approval

This naturally pauses before any Play Store upload — the user retains final say on what gets shipped.

---

## 10. Compliance With Project Rules

- **CLAUDE.md §1 (kanıt zorunluluğu):** every claim cites grep result, git output, or analyzer/test status.
- **CLAUDE.md §3 (DONE checklist):**
  - [x] Code path: 1 directory deleted (35 files), 2 config/doc files edited
  - [x] Backend kanıtı: N/A (no DB change)
  - [x] UI kanıtı: analyze+test green; reachable behavior unchanged
  - [x] Regresyon kontrolü: R7 (audit claims without verification) — every audit pointer to `noblora feed/` cross-referenced before deletion via `grep` for active vs. historical hits
  - [x] Guardrail testi: 281/281
- **CLAUDE.md §5 (scope creep):** sprint touched the legacy directory + two tiny config/doc cleanups that pointed at it. Did NOT touch app/runtime code, DB, Discover/Match/Chat/Travel/Profile/Auth flows.
- **CLAUDE.md §6 (security migration protokolü):** N/A (no migration).

---

## 11. Awaiting Approval

Per sprint brief: **"Commit/push öncesi dur ve özet ver."**

Working tree state (R24-relevant only):

```
A  (deletion) 35 files from "noblora feed/"
M  analysis_options.yaml
M  lib/core/utils/mock_mode.dart
?? R24_LEGACY_FEED_DIR_PURGE_REPORT.md
```

`R-series` historical reports + `.claude/*.png` + untracked old audit docs are NOT included — they're outside R24 scope.

The R22A / R22B / R23 split pattern suggests:

**Option (a) — single commit:**
```
fix(noblora): R24 purge legacy noblora feed directory
```

**Option (b) — split commits (matches the R22A→R23 pattern):**
```
chore(noblora): purge legacy noblora feed directory
docs(noblora): add R24 legacy purge report
```

(Note: this one is `chore` rather than `fix` — pure repo hygiene with no bug fix involved.)

`go (a)` / `go (b)` / `stop` — your call.

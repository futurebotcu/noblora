# R23 — Signal Unreachable Branch Cleanup Report

**Date:** 2026-05-13
**Sprint:** R23 (Yol A — extended scope after stop-and-report)
**Branch (suggested):** `dalga-r23-signal-unreachable-branch`
**Scope:** Flutter-only. No Supabase migration. No DB object touched. Match / Chat / Travel / Profile / Auth flows unchanged. Discover surface lightly touched ONLY to remove the unreachable branch — no behavior change for any reachable user path.

---

## Executive Summary

What started as "delete the 4 dead Signal files" became R23 only after a stop-and-report turn: direct grep showed the audit's "Signal dead code" claim was incomplete. The Signal feature was **unreachable**, not dead — `feed_screen.dart` had a live Signal/Note button that called `sendSignal()` in its `else` branch, but V1 has no construction path to `NobleMode.noblara` (`mode_switcher.dart:12` restricts to `[NobleMode.date]`) so the `else` arm could not fire. R23 removes that unreachable branch and the entire Signal Flutter chain it pinned alive.

**No user-reachable behavior changed.** The Signal/Note button is still there, still gated, still opens the Note dialog in date mode. The only deleted code path was one that V1 could not execute.

After R23:
- 5 files changed, 2 files deleted, net **−150 lines**
- `flutter analyze --fatal-infos`: **No issues found**
- `flutter test`: **281 / 281 pass**
- Repo-wide grep for Signal runtime refs (`SignalRepository`, `signalRepositoryProvider`, `sendSignal`, `superLike`, `signal_received`): **0 hits** except 2 explanatory `R23 — …` comments I added
- `ToastType.signal` enum value still defined in `swipe_toast.dart` and matched in `toast_service.dart` / `swipe_toast.dart` switch arms — left untouched per scope ("scope creep yapma")

---

## 1. Why R23 Was Needed — and Why It Looked Like "Dead Code"

The audit (`NOBLORA_CURRENT_STATE_AUDIT.md` §4 item 2) called Signal "dead code" with:

> Signal feature dead code — `lib/data/repositories/signal_repository.dart` + `lib/data/models/signal.dart` exist with full CRUD. No `signal_provider.dart`, no UI surface in `matches_screen.dart`. … notification handler has the plumbing but Signals cannot arrive or be displayed.

Two of those statements were correct (no signal_provider, no Requests-tab rendering), one was wrong (no UI surface). The UI surface was the Signal/Note button in Discover (`feed_screen.dart:513–546`). It calls `feedProvider.notifier.sendSignal()` **only in the `else` branch of `if (mode == NobleMode.date)`**:

```dart
// BEFORE R23 — feed_screen.dart:513–524
onTap: () {
  if (_checkGate(context, mode.name)) {
    if (mode == NobleMode.date) {
      _showNoteDialog(context, topCard.id);
    } else {
      ref.read(feedProvider.notifier).sendSignal(topCard.id);
      ToastService.show(context, message: 'Signal sent', type: ToastType.signal);
    }
  }
}
```

R18 removed BFF, R19 removed Status. The mode enum kept two values (`date`, `noblara`) but the only mode-switcher UI in V1 is `lib/shared/widgets/mode_switcher.dart:12`:

```dart
const List<NobleMode> _availableModes = [NobleMode.date];
```

Result: `modeProvider` is initialised to `NobleMode.date` (`mode_provider.dart:5`) and there is no V1 code path that calls `setMode(NobleMode.noblara)`. The `else` branch was therefore **unreachable at runtime**, but live at compile time — it pinned `feed_provider.sendSignal`, which pinned `signalRepositoryProvider`, which pinned `signal_repository.dart` and `signal.dart`.

This is the difference between **dead** (no live import chain) and **unreachable** (live import chain, no possible execution). The audit missed it, the R23 brief said "stop if active", and the stop-and-report turn re-scoped R23 to "Yol A — unreachable branch cleanup" with your explicit go-ahead.

---

## 2. Which Discover Branch Was Removed

Single block in `feed_screen.dart:513–524`. After R23:

```dart
// AFTER R23 — feed_screen.dart:513–520
// Note (GATED) — R23: Signal else branch was unreachable in V1
// (only NobleMode.date is constructible) so the `else` arm and
// its sendSignal call were removed along with the Signal feature.
PressEffect(
  onTap: () {
    if (_checkGate(context, mode.name)) {
      _showNoteDialog(context, topCard.id);
    }
  },
  …
```

Everything else about the button — its position in the action row, its visual (`Icons.bolt_rounded` 52pt emerald), its press effect, its gate check — is **identical** to before. The only difference: the inner `if (mode == NobleMode.date)` fork is gone because the `else` arm couldn't run anyway.

---

## 3. Why No User-Visible Behavior Changed

Reachable execution traces:

| Scenario | Before R23 | After R23 |
|---|---|---|
| User in date mode taps Signal/Note button → gate fails | Toast: gate dialog | Toast: gate dialog (unchanged) |
| User in date mode taps Signal/Note button → gate passes | `_showNoteDialog(context, topCard.id)` | `_showNoteDialog(context, topCard.id)` (identical) |
| User in `NobleMode.noblara` mode taps button | (impossible — mode unreachable) | (impossible — mode unreachable) |
| App receives push with `type='signal_received'` | `_switchTo(1)` → Chats tab | (impossible — no V1 sender; if it ever arrived the default branch routes to Chats too) |
| User toggles notification prefs for 'signals' category | Suppressible via `signal_received → signals` map | (impossible — no V1 sender) |

The only thing that became impossible is the impossible.

---

## 4. Files Changed

```
M  lib/features/feed/feed_screen.dart                 (-4 / +5 net)
M  lib/providers/feed_provider.dart                   (-19 / +6 net)
M  lib/navigation/main_tab_navigator.dart             (-2 / +1 net)
D  lib/data/repositories/signal_repository.dart       (110 lines)
D  lib/data/models/signal.dart                        (30 lines)
```

Diff totals: **5 files changed, 2 deleted, ~140 lines deleted, ~12 lines added (comments + R23 markers).** `git diff --stat` confirms ~150 lines net removed.

### 4.1 Imports / providers removed

In `lib/providers/feed_provider.dart`:

```diff
- import '../data/repositories/signal_repository.dart';
- 
- final signalRepositoryProvider = Provider<SignalRepository>((ref) {
-   if (isMockMode) return SignalRepository();
-   return SignalRepository(supabase: ref.watch(supabaseClientProvider));
- });
```

### 4.2 Methods removed

In `lib/providers/feed_provider.dart`:

```diff
- Future<void> sendSignal(String cardId) async {
-   final userId = _ref.read(authProvider).userId;
-   if (userId == null) return;
-
-   final signalRepo = _ref.read(signalRepositoryProvider);
-   final canSend = await signalRepo.canSendSignal(userId);
-   if (!canSend) return;
-
-   await signalRepo.sendSignal(senderId: userId, receiverId: cardId);
- }
-
- Future<void> superLike(String cardId) async {
-   await sendSignal(cardId);
- }
```

Replaced with a short `R23 — …` comment marker so future readers find the why.

### 4.3 Notification handler cleanup

In `lib/navigation/main_tab_navigator.dart:72–74`:

```diff
  case 'note_received':
- case 'signal_received':
    _switchTo(1); // Requests tab inside Chats
```

In `lib/navigation/main_tab_navigator.dart:268` (notification preference category map):

```diff
- 'signal_received': 'signals', 'note_received': 'notes',
+ 'note_received': 'notes',
```

### 4.4 Deletes

```
git rm lib/data/repositories/signal_repository.dart
git rm lib/data/models/signal.dart
```

Both were tracked. `git rm` staged both deletions.

---

## 5. Repo-Wide Verification

### 5.1 Active runtime refs

Grep over `lib/` for: `SignalRepository`, `signalRepositoryProvider`, `sendSignal`, `superLike`, `signal_received`, `signal_repository`, `models/signal`.

Result:

```
lib/providers/feed_provider.dart:177:  // R23 — `sendSignal()` and `superLike()` removed along with the Signal
lib/features/feed/feed_screen.dart:515:   // its sendSignal call were removed along with the Signal feature.
```

Only my own R23 explanatory comments. **Zero runtime references.**

### 5.2 `ToastType.signal` — intentionally left

```
lib/core/services/toast_service.dart:17:    ToastType.signal => const Duration(seconds: 6),
lib/shared/widgets/swipe_toast.dart:66:    ToastType.signal => AppColors.emerald500,
lib/shared/widgets/swipe_toast.dart:81:    ToastType.signal => Icons.bolt_rounded,
lib/shared/widgets/swipe_toast.dart:92:    final isImportant = widget.type == ToastType.signal || widget.type == ToastType.match || widget.type == ToastType.error;
```

`ToastType.signal` is an enum value in the toast infrastructure. Now that nothing emits a Signal-typed toast (the call site was removed in §4 alongside the `else` branch), the enum value is unused at emission sites but still pattern-matched in switch arms. Removing the enum value would require editing four unrelated files, all of which are generic toast infrastructure used by Match, Chat, etc. Per the sprint brief's "scope creep yapma" / "Match/Chat/Travel/Profile/Auth davranışını değiştirme" rules, **left in place.** A future R23-tail PR can either delete the enum value (and all four pattern arms) or leave it as future-reserved infrastructure.

### 5.3 Other "signal" hits in `lib/` — unrelated

```
lib/data/repositories/verification_repository.dart:14:  bool _isStrongFraud(List<String> signals) {
lib/data/repositories/verification_repository.dart:19:    return signals.any(...);
lib/data/repositories/verification_repository.dart:86:    return 'Inconclusive signals flagged — manual review required';
lib/features/profile/profile_screen.dart:36:  // prioritizes strong identity signals
lib/features/profile/profile_screen.dart:608:  // Directly under the hero photo. Strongest identity signals in the locked
lib/features/profile/profile_screen.dart:1210:  // are the strongest signals about *how* this person wants to connect.
lib/features/settings/settings_screen.dart:39: //   - Reach / Signal / Note permission rows (read nowhere; phantom UI)
```

All unrelated to the Signal feature — different domain word ("fraud signals", "identity signals") or comment-only mentions of the removed feature. No action.

### 5.4 Test directory

```
grep Signal|signal|... test/ → No matches found
```

---

## 6. Build / Test Results

```
flutter analyze --fatal-infos : No issues found! (ran in 4.7s)
flutter test                  : All tests passed! (281 / 281)
```

Identical to the post-R22B baseline. Zero regression. Notably, analyze does **not** flag `ToastType.signal` as unused because the enum value is still pattern-matched in switch arms — defining and matching it counts as "used" even if no emission site fires it.

---

## 7. Remaining DB-Side Signal Leftovers (NOT touched by R23)

R23 is Flutter-only. DB-side Signal objects remain intentionally:

| Object | Type | Risk |
|---|---|---|
| `public.signals` | Table | Latent — no Flutter inserts, no enumeration risk (no advisor finding on the table itself in current advisor output) |
| `public.check_signal_limit()` | SECDEF RPC | Latent — Flutter no longer calls it; still anon/authenticated executable. Visible in advisor 102-finding baseline as 2 entries (anon + auth). |
| `public.can_user_interact()` | SECDEF RPC | Latent — was called by Signal CRUD path; advisor-flagged |
| `public.can_reach_user()` | SECDEF RPC | Latent — same |
| `public.increment_signal_count()` | SECDEF RPC | Latent — same |
| Any `signals_*` RLS policies | Policy | Likely empty table by now; unreachable |

These should be addressed in a later **V1.x signal DB sweep** (R23-DB or similar). Pattern: same as R22B — apply a single `DROP TABLE CASCADE` + explicit `DROP FUNCTION` for the orphaned RPCs.

Expected advisor delta from that future sweep: −8 to −10 findings (4–5 SECDEF RPCs × 2 roles each).

---

## 8. Risk Assessment

**Behavioral risk: zero.**
- The `else` branch was demonstrably unreachable (mode_switcher restricts construction, no other setMode call sites).
- The Note dialog (date mode) is unchanged in code, gate, position, visuals.
- Notification handler default branch (`_switchTo(1)`) catches any stray `signal_received` push that would never come, so even if a phantom server-side trigger were to fire, the app gracefully routes to Chats.

**Build risk: zero.** Analyze + test green; no warnings about unused imports, dead methods, or orphan provider registrations.

**Schema coupling risk: none.** No DB changes. R23 is pure Flutter dead-branch removal; the database is identical to its post-R22B state.

**Rollback:** `git revert <r23-commit>` undoes all 5 file changes cleanly. No data migration to undo. Restoring `signal_repository.dart` + `signal.dart` would also re-add the dependency chain, so revert is atomic at the commit level.

---

## 9. Recommended Next Sprint

**Candidate R22C — Latent RPC orphan cleanup**
- Drop the 15 post-content-querying RPCs flagged in R22B §10 (advisor delta target: −30 findings).
- Backend-only, single migration.
- Same pattern as R22B's R22A→R22B split: in this case the Flutter side is already proven empty for these RPCs (grep done in R22B §2.2).

**Candidate R24 — `noblora feed/` legacy directory purge**
- Pure repo hygiene; not in build path, just confusing to future readers and explorer agents.
- Could be a `git rm -rf` + commit.

**Candidate R23-DB — Signal DB sweep**
- DROP TABLE `signals` + `DROP FUNCTION` for the 4 Signal SECDEF RPCs.
- Smallest scope, biggest advisor delta among Signal-related work (~−8 to −10 findings).
- Now safe because R23 left the Flutter side already empty.

Recommendation order: **R22C (closes biggest advisor surface) → R23-DB (closes Signal DB tendrils) → R24 (cosmetic).** Pick whichever fits your appetite.

---

## 10. Compliance With Project Rules

- **CLAUDE.md §1 (kanıt zorunluluğu):** every claim cites either grep result, `git diff --stat`, or tool output.
- **CLAUDE.md §3 (DONE checklist):**
  - [x] Code path: 5 files (3 modified, 2 deleted)
  - [x] Backend kanıtı: N/A (no DB change)
  - [x] UI kanıtı: analyze+test green; behavioral table in §3 shows reachable scenarios unchanged
  - [x] Regresyon kontrolü: R7 (audit claims without verification) — explicitly re-verified before action via stop-and-report. Audit's "Signal dead code" reframed to "Signal unreachable branch" in §1.
  - [x] Guardrail testi: 281/281
- **CLAUDE.md §5 (scope creep):** sprint touched exactly 5 files. Did NOT remove `ToastType.signal` enum (would force edits to 4 unrelated infrastructure files). Did NOT touch DB. Did NOT touch `noblora feed/` legacy directory.
- **CLAUDE.md §6 (security migration protokolü):** N/A (no migration).

---

## 11. Awaiting Approval

Per sprint brief: **"Commit/push öncesi dur ve özet ver."**

Working tree state (Signal-related only — `.claude/*.png` and prior reports are untouched):

```
M  lib/features/feed/feed_screen.dart
M  lib/navigation/main_tab_navigator.dart
M  lib/providers/feed_provider.dart
D  lib/data/repositories/signal_repository.dart
D  lib/data/models/signal.dart
?? R23_SIGNAL_UNREACHABLE_BRANCH_CLEANUP_REPORT.md
```

Nothing committed yet. The R22A / R22B split pattern suggests:

**Option (a) — single commit:**
```
fix(noblora): R23 remove unreachable signal branch
```

**Option (b) — split commits (matches R22A / R22B pattern):**
```
fix(noblora): remove unreachable signal branch
docs(noblora): add R23 signal cleanup report
```

`go (a)` / `go (b)` / `stop` — your call.

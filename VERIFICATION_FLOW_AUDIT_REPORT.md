# Noblara Verification Flow Audit Report

**Date:** 2026-05-13
**Sprint type:** Read-only audit. No code change. No migration. No fix.
**Method:** Flutter grep + sub-agent map + live Supabase queries against project `xgkkslbeuydbbcvlhsli`.

---

## Executive Summary

The verification feature is **half-real**. The happy path works for an honest user who takes a real selfie + uploads a real photo: the `verify-images` Edge Function calls Gemini, the Flutter client interprets the AI response, uploads + writes DB rows, and on approval flips three downstream flags. Discover + Chats actually gate behind it. Verified badges actually render on swipe cards.

But the **non-happy paths have load-bearing holes** that turn this from "real V1 feature" into "release-blocker risk":

1. **🔴 A malicious user can self-verify with three direct API calls — no photo upload required.** RLS policies on `photo_verifications` (`pv_update_own`), `profiles` (`profiles_update_own`), and `gating_status` (`gating_update_own`) all allow users to UPDATE their own rows with **no column restriction**. Combined with the `sync_is_verified` trigger that auto-flips `profiles.is_verified=true` when both flag columns are true, anyone holding a JWT can self-verify in ~3 PATCH calls.
2. **🔴 Any authenticated user can read every other user's verification selfie.** The storage policy `"authenticated users can read verification photos"` uses `USING (bucket_id = 'verification-photos')` with **no folder check** — meaning a user can list and download anyone else's `verification-photos/<their_user_id>/selfie_*.jpg`.
3. **🔴 Admin approval is non-functional.** `admin_repository.approvePhotoVerification` issues a client-side UPDATE to `photo_verifications` for the target user, but the RLS `auth.uid() = user_id` check rejects it (admin's UID ≠ target's user_id) → silent zero-row update. It then tries to set `profiles.photo_verified = true`, but **that column does not exist** → 42703 error. Result: stuck "manual_review" cases cannot be unblocked via the admin UI.

**Recommendation:** **Hide the verification surface in V1** (treat as gated/admin-only feature) UNTIL the three fixes above ship. The audit's "Settings shows verified badge" is fine to keep cosmetically, but the upgrade path (the modal-gate that pushes users to `VerificationHubScreen`) and the self-verify holes should be closed before any external user touches the store binary. See §10 for two concrete fix paths.

---

## 1. UI Entry Points

| File:line | Surface | Behavior |
|---|---|---|
| `lib/navigation/main_tab_navigator.dart:112–204` | Tab gate modal | Triggered on Discover/Chats tap when `verificationStatus != approved`. Modal CTA "Verify now" pushes `VerificationHubScreen`. **Primary entry point.** |
| `lib/features/settings/settings_screen.dart:176–183` | Settings rows | "Photo Verification" + "Selfie Verification" **read-only status display** (no `onTap`). Shows "Verified" / "Pending" / "In review" / "Not started" based on `s['photos_verified']`, `s['selfie_verified']`, and `verification_status`. Cannot initiate verification from here. |
| All other surfaces | (none) | Profile, Discover, Match — no entry points |

**Effective UX:** Verification is only discoverable by hitting the locked tab gate. A user who never taps Discover or Chats won't see it. This is a deliberate-feeling gate-driven flow, not a Profile-Setup-style required step.

---

## 2. Flutter Flow Map

`lib/features/verification/verification_hub_screen.dart` (483 lines):
- Two-step upload: **selfie via camera** + **profile photo via gallery** (sequential, not blended)
- Local staging (`pendingSelfieBytes`, `pendingProfileBytes` in `verificationProvider`) before any network call
- `"Verify Both Photos"` button → `verificationProvider.notifier.verifyBoth()`
- Banners: idle → loading → approved / manualReview / rejected / error
- Gender reminder banner reads `profileProvider.profile?.gender` to discourage gender-mismatch submissions

`lib/providers/verification_provider.dart` (241 lines):
- Enum: `VerificationStatus { idle, loading, approved, manualReview, rejected, error }`
- Ground truth: **the most-recent `photo_verifications` row's status**
- Subscribes to realtime CDC stream on `photo_verifications` → admin/state changes propagate immediately

`lib/data/repositories/verification_repository.dart` (335 lines):
- `verifyBothPhotos()` orchestrates: upload selfie → upload profile photo → call `verify-images` Edge Function → parse Gemini JSON → compute decision → insert two `photo_verifications` rows → if approved, also UPDATE `profiles` (+`selfie_verified`, +`photos_verified`, set `photos`) AND `gating_status` (+`is_verified`, +`is_entry_approved`)
- Decision engine is **client-side** (`_computeDecision`) — Edge Function is a Gemini passthrough; the trust decision lives in Dart code

`lib/data/models/photo_verification.dart`:
- Status as plain string, no client-side enum
- Includes `aiReason`, `realSelfieProbability`, `genderDetected`, `claimedGender` for UX

`lib/features/admin/admin_screen.dart` Verifications tab:
- Pulls pending/manual_review rows via `fetchPendingVerifications()` (read-only — works)
- Approve button → `adminRepository.approvePhotoVerification(userId)` → broken (see §6)

`lib/features/feed/swipe_card_widget.dart:284–320`:
- Badge: emerald "Verified" pill, top-right of swipe card
- Reads from `ProfileCard.isVerified` (denormalized `profiles.is_verified`)

---

## 3. Supabase Contract — Live State

### `public.profiles` columns (verified via live query)
```
is_verified         boolean  default false   -- denormalized; trigger maintains
selfie_verified     boolean  default false
photos_verified     boolean  default false
verification_status text     default 'pending'
is_onboarded        boolean  default false
is_admin            boolean  NOT NULL default false
photos              text[]   default '{}'
gender              text
```
**`photo_verified` does NOT exist.** Admin repo tries to write it (line 87) — 42703 if reached.

### `public.photo_verifications` columns (verified)
```
id                       uuid PK
user_id                  uuid NOT NULL  (auth.users FK)
photo_url                text
photo_type               text             -- 'profile' | 'selfie'
status                   text NOT NULL default 'pending'  -- 'pending' | 'approved' | 'rejected' | 'manual_review'
ai_reason                text
decision                 text
ai_score                 double precision
real_selfie_probability  double precision
gender_detected          text
gemini_response          jsonb
raw_response             jsonb
rejection_reason         text
reviewed_by              uuid
reviewed_at              timestamptz
review_note              text
created_at               timestamptz NOT NULL default now()
claimed_gender           text
```

### `public.gating_status` columns
```
user_id            uuid
is_verified        boolean default false
is_entry_approved  boolean default false
updated_at         timestamptz default now()
```

### Trigger `profiles_sync_is_verified` (BEFORE UPDATE ON profiles)
```sql
IF NEW.selfie_verified = TRUE AND NEW.photos_verified = TRUE THEN
  NEW.is_verified := TRUE;
END IF;
```
Trigger does NOT clear `is_verified` if flags revert. One-way only.

### Edge Function `verify-images`
- POST endpoint; receives base64 selfie + profile image
- Validates `apikey` header against `SUPABASE_ANON_KEY`
- Calls Gemini 2.5 Flash → returns raw JSON
- **Has no auth check beyond anon key + no rate limit + no idempotency**

---

## 4. Storage Audit — Live State

### Buckets (verified)
| Bucket | Public? | Notes |
|---|---|---|
| `verification-photos` | **private** | Where selfies go |
| `profile-photos` | public | Where profile shots go |
| `selfies` | private | Defined but unused by current code |
| `verifications` | private | Defined but unused by current code |
| `avatars` | public | Legacy |
| `galleries` | public | Legacy gallery photos |
| `chat-media` | private | Chat attachments |

### Storage policies on `verification-photos`
| Policy | Cmd | Predicate | Verdict |
|---|---|---|---|
| `users can upload own verification photos` | INSERT | `bucket_id='verification-photos' AND folder[1] = auth.uid()::text` | ✅ Correctly folder-scoped |
| `users can update own verification photos` | UPDATE | Same | ✅ |
| `users can delete own verification photos` | DELETE | Same | ✅ |
| **`authenticated users can read verification photos`** | **SELECT** | **`bucket_id='verification-photos'`** | **🔴 NO folder check — any authenticated user can list+download any selfie** |

`profile-photos` has the analogous insert/update/delete policies (folder-scoped) and is a **public** bucket, so anyone can read; that's expected for profile pictures.

---

## 5. RLS Audit — `photo_verifications`

| Policy | Cmd | USING | WITH CHECK |
|---|---|---|---|
| `pv_insert_own` | INSERT | — | `auth.uid() = user_id` ✅ |
| `pv_select_own` | SELECT | `auth.uid() = user_id` ✅ | — |
| **`pv_update_own`** | **UPDATE** | **`auth.uid() = user_id`** | **(null — no column restriction)** |

**The UPDATE policy allows a user to overwrite any column of their own row**, including `status`. Combined with the absence of a service-role-only path, this means a user can submit a row with `status='pending'` and then immediately PATCH it to `status='approved'` from the client. No AI call needed, no admin needed.

The audit-report agent's claim "no UPDATE policy" was incorrect — the policy exists, but it's too permissive.

---

## 6. RLS Audit — `profiles` and `gating_status`

### `profiles` UPDATE policies
| Policy | Cmd | USING | WITH CHECK |
|---|---|---|---|
| `profiles_update_own` | UPDATE | `auth.uid() = id` | (null) |
| `profiles_update_active_modes` | UPDATE | `auth.uid() = id` | `auth.uid() = id` |

**No column-level restriction.** A user can set `selfie_verified=true`, `photos_verified=true` on their own row. The `sync_is_verified` trigger then flips `is_verified=true`. Combined with `gating_status` self-update (below), the self-verify attack is end-to-end.

### `gating_status` UPDATE policy
| Policy | Cmd | USING | WITH CHECK |
|---|---|---|---|
| `gating_update_own` | UPDATE | `auth.uid() = user_id` | `auth.uid() = user_id` |

User can flip `is_verified=true` and `is_entry_approved=true` on their own row.

---

## 7. Runtime Test Result

**Not performed.** No Android device or running emulator (`adb devices` empty). Per scope ("Eğer blocker bulursan stop-and-report"), the audit relied on:
- Code-level inspection of Flutter source
- Live Supabase queries to verify table/policy/storage state (10 SQL queries against project `xgkkslbeuydbbcvlhsli`)
- Cross-reference of Flutter expectations vs. live schema

The findings below are **definitive at the data layer**. A runtime test on a real device would only verify that the UX paths reach the policies as expected — it cannot make a permissive policy safer.

---

## 8. Security Risks (P0/P1)

### 🔴 P0-1 — Self-verify attack (full bypass)

**Severity:** Auth-bypass.
**Steps an attacker (any authenticated user) can perform:**
```http
# 1. Upload nothing. Insert a placeholder verification row:
POST /rest/v1/photo_verifications
  { "user_id": "<self>", "photo_url": "https://example.com/any.jpg", "photo_type": "selfie", "status": "pending" }
# RLS allows: pv_insert_own (auth.uid() = user_id)

# 2. PATCH it to approved:
PATCH /rest/v1/photo_verifications?id=eq.<row_id>
  { "status": "approved", "decision": "approved" }
# RLS allows: pv_update_own (auth.uid() = user_id, no column restriction)

# 3. Flip profile flags + gating directly (one round-trip):
PATCH /rest/v1/profiles?id=eq.<self>
  { "selfie_verified": true, "photos_verified": true }
# RLS allows: profiles_update_own (auth.uid() = id, no column restriction)
# Trigger profiles_sync_is_verified flips is_verified=true

PATCH /rest/v1/gating_status?user_id=eq.<self>
  { "is_verified": true, "is_entry_approved": true }
# RLS allows: gating_update_own (auth.uid() = user_id)
```
After three PATCH calls, the user is `is_verified=true`, `is_entry_approved=true`, badge renders in Discover for them. No Gemini call. No real photo. No admin. **Verification is decorative under V1's current RLS.**

**Why it exists:** The Flutter client itself performs these writes after a legit verification (verification_repository:285–302), and the policies were probably written assuming that's the only call site. The RLS doesn't model "trusted writes only via verify-images Edge Function".

### 🔴 P0-2 — Verification selfie privacy leak

**Severity:** PII leak.
**Path:** The storage policy `"authenticated users can read verification photos"` is `USING (bucket_id = 'verification-photos')`. No `(storage.foldername(name))[1] = auth.uid()::text` check.

**Steps:** Any authenticated user can:
```
GET /storage/v1/object/list/verification-photos
GET /storage/v1/object/verification-photos/<other_users_user_id>/selfie_<ts>.jpg
```
…and download every other user's verification selfie. Selfies are explicit identity documents.

**Why it exists:** Likely written this way so the admin Verifications tab could display thumbnails. But the admin uses the same anon-key client as a user — there's no admin-only read path.

### 🔴 P0-3 — Admin approval is non-functional

**Severity:** Blocked user flow (legit users can get stuck in `manual_review` forever).
**Path:** `admin_repository.approvePhotoVerification(userId)` issues:
```dart
// Step 1: doomed by RLS
await db.from('photo_verifications')
        .update({'status': 'approved'})
        .eq('user_id', userId);
// pv_update_own checks auth.uid() = user_id. Admin's UID ≠ target user_id.
// Result: zero rows updated, no error thrown.

// Step 2: doomed by missing column
await db.from('profiles')
        .update({'photo_verified': true})
        .eq('id', userId);
// profiles.photo_verified does NOT exist → 42703 column does not exist.
```
The admin UI shows "{name} approved" toast even though the DB didn't change. Admin reject (`update({'status': 'rejected'})`) has the same RLS problem.

### 🟡 P1-1 — Edge Function has no per-user rate limit

`verify-images` validates only `apikey` (the public anon key). A user can spam Gemini calls. Cost + abuse exposure.

### 🟡 P1-2 — `verify-images` is public passthrough

Anyone with the anon key (i.e., the published mobile app or reverse-engineered, plus any web client that hits Supabase) can POST arbitrary base64 to `verify-images` and burn Gemini credits.

### 🟡 P1-3 — Storage SELECT lets `is_verified` proof material leak

Even if you tightened storage to "admin-only", the `verification-photos` bucket contains explicit selfies. Without GDPR/KVKK-aware retention, this is regulatory exposure beyond just RLS.

### 🟢 INFO — `verifications` and `selfies` buckets defined but unused

Two private buckets exist in `storage.buckets` but no policy and no Flutter code path writes/reads them. Either pre-rename dead state or future-reserved.

---

## 9. Answers to the 7 Critical Questions

| # | Question | Answer |
|---|---|---|
| 1 | Is this feature really working in V1? | **Partially.** Happy path (AI-approved real user) works end-to-end. Sad paths (manual_review, admin approve, security around fake users) are broken or open. |
| 2 | Is it just UI? | No — there's a real Edge Function, real Gemini call, real storage upload, real DB writes. But the **trust model is broken**: any authenticated user can self-verify without using any of it. |
| 3 | Can a user actually become verified? | **Yes**, via the legit AI path **OR** via 3 direct API PATCH calls (no upload needed). Both produce the same `is_verified=true` end state, and the badge displays identically. |
| 4 | Can a malicious user self-verify? | **Yes.** P0-1 above. ~3 API calls, no images, no Gemini. |
| 5 | Is there an admin review path? | UI exists (`admin_screen.dart` Verifications tab + Approve/Reject buttons), data exists (`fetchPendingVerifications` reads correctly), but **writes are non-functional** (P0-3). Users in `manual_review` cannot currently be unblocked through the admin UI. |
| 6 | Should this stay enabled for the store release? | **No, not as-is.** Hide / gate the surface, or ship the fixes first. |
| 7 | Hide for V1, fix, or release? | **Hide or fix before submission.** See §10. |

---

## 10. Recommendation

Two viable paths. Pick one before any store submission.

### Path A — **Hide & defer** (lowest risk, fastest)

- Remove the modal CTA in `main_tab_navigator.dart:_showSecureTabGate` that pushes `VerificationHubScreen`. Replace with "Verification temporarily unavailable" message.
- Remove the Settings read-only verification rows (one Edit pass in `settings_screen.dart`).
- Leave backend untouched.
- Effect: V1 ships without a verification feature; the policy holes still exist but no UI surfaces them, **so the auth-bypass attack requires deliberate reverse-engineering of the API** — not zero-effort, but still possible by anyone with the anon key + a Postman.
- **Caveat:** P0-2 (storage SELECT leak) still allows enumeration of historical selfies via the anon key + direct storage URL. Unless you also drop the bucket or its SELECT policy, hiding the UI alone doesn't close that hole.

### Path B — **Fix before ship** (correct, but +~1 day)

- **Migration**: tighten three RLS UPDATE policies to only allow safe column updates:
  ```sql
  -- photo_verifications: forbid user-side UPDATE of status; restrict to service_role
  DROP POLICY pv_update_own ON public.photo_verifications;
  CREATE POLICY pv_update_own_restricted ON public.photo_verifications
    FOR UPDATE TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (
      auth.uid() = user_id
      AND status IS NOT DISTINCT FROM (SELECT status FROM public.photo_verifications WHERE id = photo_verifications.id)
    );
  -- (or just DROP the policy entirely and create a SECURITY DEFINER RPC for the legit happy path)

  -- profiles: forbid user UPDATE of selfie_verified/photos_verified/is_verified
  -- Either column-grant via GRANT/REVOKE, or split into a non-user-writable column set.

  -- gating_status: same story for is_verified, is_entry_approved.
  ```
- **Storage**: replace `"authenticated users can read verification photos"` with a folder-scoped read policy plus an explicit admin-bypass path (or just service_role-only).
- **Admin approval**: create a `SECURITY DEFINER` RPC `admin_approve_verification(target_user_id)` that runs as service_role, updates `photo_verifications.status`, sets `profiles.selfie_verified+photos_verified`, and sets `gating_status.is_verified+is_entry_approved`. Wire `admin_repository.approvePhotoVerification` to call the RPC. Also fix the `photo_verified` typo to `photos_verified`.
- **Edge Function hardening**: validate JWT (not just apikey), add per-user rate limit, optionally add idempotency by `(user_id, selfie_hash)`.

After Path B, P0-1, P0-2, P0-3 all close and the feature ships as designed.

### My read

**Path A unless you have a reason to keep verification in the V1 marketing story.** Reasons to keep it: it's currently the only thing gating Discover/Chats — if you hide it, you also need to remove (or downgrade) that gate, otherwise users can never reach the core flow. Reasons to fix (Path B): the trust model of a dating app is built on this exact feature; shipping a verified badge that any user can self-grant is a brand risk independent of the security risk.

If you go Path B, it's a multi-sprint effort (RLS rewrite + storage rewrite + admin RPC + edge function hardening + smoke retest) and probably becomes its own R26 → R29 sequence.

---

## 11. Exact Commands Run

```
# Flutter
grep verification | verified | selfie | photo verification | … (lib/, test/)
read lib/features/verification/verification_hub_screen.dart
read lib/providers/verification_provider.dart
read lib/data/repositories/verification_repository.dart
read lib/data/models/photo_verification.dart
read lib/features/settings/settings_screen.dart (around line 176)
read lib/navigation/main_tab_navigator.dart (around line 112-204)
read lib/features/admin/admin_screen.dart (Verifications tab)
read lib/data/repositories/admin_repository.dart (approve/reject methods)
read lib/features/feed/swipe_card_widget.dart (around line 284-320)

# Supabase (via mcp__supabase__execute_sql against xgkkslbeuydbbcvlhsli)
SELECT … FROM information_schema.columns WHERE table_name='profiles' AND column_name IN (…)
SELECT … FROM information_schema.columns WHERE table_name='photo_verifications'
SELECT … FROM pg_policies WHERE tablename='photo_verifications'
SELECT … FROM storage.buckets
SELECT … FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND … LIKE '%verification%'
SELECT pg_get_triggerdef(...) … pg_trigger … profiles, photo_verifications, gating_status
SELECT pg_get_functiondef(...) … sync_is_verified
SELECT … FROM information_schema.columns WHERE table_name='gating_status'
SELECT … FROM pg_policies WHERE tablename='gating_status'
SELECT … FROM pg_policies WHERE tablename='profiles'
```

No DB writes. No migrations. Read-only.

---

## 12. Files Inspected

```
lib/features/verification/verification_hub_screen.dart       (~483 lines)
lib/providers/verification_provider.dart                     (~241 lines)
lib/data/repositories/verification_repository.dart           (~335 lines)
lib/data/models/photo_verification.dart                      (~55 lines)
lib/features/settings/settings_screen.dart                   (verification rows)
lib/navigation/main_tab_navigator.dart                       (tab gate + modal)
lib/features/admin/admin_screen.dart                         (Verifications tab)
lib/data/repositories/admin_repository.dart                  (approve/reject)
lib/features/feed/swipe_card_widget.dart                     (badge)
lib/data/models/profile_card.dart                            (isVerified mapping)
supabase_schema.sql                                          (photo_verifications, profiles columns)
supabase/migrations/20260324000001_photo_verifications_manual_review.sql
supabase/migrations/20260326000001_realtime_gating_verifications.sql
supabase/migrations/20260326000002_photo_verif_claimed_gender.sql
supabase/migrations/20260327000001_profiles_verification_flags.sql
supabase/functions/verify-images/index.ts
```

Live DB state queried, not just the migration files (audit sub-agents over-trusted migration set; live state differed in important ways — bucket names, missing columns, etc.).

---

## 13. Status / Next Step

Sprint complete. **No code changed. No DB changed. No commit.** Working tree only has this report file as untracked.

Awaiting your call between Path A (hide), Path B (fix), or some interleaved option (e.g., close P0-2 storage policy now, defer P0-1 and P0-3 RLS rewrite for a later sprint).

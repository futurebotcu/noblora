# Noblara Monetization Baseline Audit

**Date:** 2026-05-13
**Sprint type:** Read-only audit. No code change. No migration. No billing/fix work.
**Method:** Flutter grep + sub-agent maps + live Supabase queries against project `xgkkslbeuydbbcvlhsli`.

---

## Executive Summary

| Question | Live state |
|---|---|
| Unlimited likes? | **No.** Server-enforced daily quota (Observer 30 / Explorer 50 / Noble 100) and daily match cap (Observer 2 / Explorer 4 / Noble 7). |
| Unlimited messages? | **Yes.** Once a match reaches `chatting`, no per-day cap, no rate limit, no debounce. |
| Liked-You feasible? | **Yes.** Data is in `swipes`. Today's RLS blocks the inverse lookup; a single SECURITY DEFINER RPC unblocks it. |
| Premium / billing infra present? | **No.** Zero IAP SDK, zero BILLING permission, zero subscription/entitlement table, zero webhook function, zero paywall screen. The `lib/core/theme/premium.dart` file is **pure visual theming**, not monetization. |
| Liked-You as first monetization feature? | **Sensible**, but only after a billing-infra sprint (~2 sprints) — Liked-You needs a paywall to convert. Verification trust holes should be closed before paid users land in the funnel. |
| Minimum-safe technical plan? | 4-phase, ~5 sprints. See §10. |

The tier system already exists (`nob_tier` ∈ {`observer`, `explorer`, `noble`}) and the swipe/match quota functions already key off it. **Monetization can reuse the existing tier rails** instead of building a parallel premium system — the cheapest path is to make `noble` tier purchasable rather than purely merit-earned.

---

## 1. Current Like / Swipe Reality

### Flow chain
`feed_screen._ActionRow → feedProvider.swipeRight → matchProvider.swipe → swipeRepository.swipe`:

1. `check_swipe_limit(user)` — RPC; if false, swipe rejected.
2. `check_connection_limit(user)` — RPC; right-swipes only; if false, blocked.
3. `increment_swipe_count(user)` — RPC.
4. `create_swipe_with_gate(swiper, target, direction, mode)` — RPC; inserts `swipes` row, enforces TH/VN/PH gate.
5. `check_and_create_match(swiper, target, mode)` — RPC; if mutual, creates `conversations` + `conversation_participants` + `matches` (status `pending_first_message`).

### Tier limits (live, verified via `pg_get_functiondef`)

```sql
-- check_swipe_limit body (paraphrased):
v_limit := CASE v_tier
  WHEN 'observer' THEN 30
  WHEN 'explorer' THEN 50
  WHEN 'noble'    THEN 100
  ELSE 30
END;
RETURN v_used < v_limit;
```

```sql
-- check_connection_limit (Observer 2 / Explorer 4 / Noble 7 per day, server-confirmed)
```

Daily reset: `daily_swipes_reset` and `daily_connections_reset` rolling 24h. Cron at 0 UTC also exists.

### Tier source — NOT paid, merit-earned
`profiles.nob_tier` defaults to `'observer'`. Tier promotion driven by `noble_score`, `trust_score`, `maturity_score` engagement metrics — there is a `TierPromotionScreen` for the celebration moment, but no UI or schema allows buying a tier upgrade.

### Client-side enforcement
**None.** No `kSwipesPerDay`, `_remainingSwipes`, or similar constants in `lib/`. The client trusts the server. `swipeRepository.swipe` returns silently on quota-exhausted — there is **no UI feedback** for "you hit your daily limit".

### Super-like / Signal / Rewind
- `signal_repository.dart` + `lib/data/models/signal.dart` removed in R23.
- `rewind()` removed in R19. `FeedState.lastRemovedCard` exists for error-rollback only; no user-facing undo button.
- `super_likes_remaining INT default 3` column on `profiles` — orphan; nothing wires it.
- `boost_active_until`, `boosts_remaining` columns on `profiles` — orphan; nothing wires them.
- `rewinds_remaining` column — orphan since R19.

### Geo gate
`create_swipe_with_gate` requires `country IN ('TH','VN','PH') OR (travel_mode AND travel_country IN ...)`. Right-swipes outside this gate are rejected with `error: 'travel_mode_required'`.

---

## 2. Current Message / Chat Reality

### Flow
- Pre-condition: a `matches` row exists with status `chatting` (or `pending_first_message`).
- `messagesRepository.sendMessage` directly inserts into `messages` with `conversation_id`.
- `_assertMatchActive` guards against `expired` / `closed` status and past `chat_expires_at`.

### First-message gate (R11)
- New match starts in status `pending_first_message`.
- 24h deadline via `matches.video_deadline_at` (column repurposed from the killed video feature).
- `first_message_advance_match()` AFTER INSERT trigger on `messages`: flips match status to `chatting` on the first **non-system** message from either party.
- If no message arrives within 24h, an `expire-stale-matches` cron expires the match.
- Implication: **either user can unlock chat by sending the first message**. The `MiniIntroScreen` is courtesy UX, not enforced asymmetry. Compared to Bumble (women-first) this is **symmetric** — no monetization lever there.

### Per-day / per-conversation cap
**None.** Searched lib/ for `maxMessagesPerDay`, `messageLimit`, quota, throttle — zero hits. Searched migrations for triggers or functions that gate message INSERT — none beyond the first-message advance trigger. Once `chatting`, a user can send as many messages as they like, as fast as TCP allows.

### Rate limit / spam guard
- No client-side debounce on send.
- No server-side rate-limit function.
- Typing indicator is debounced for UX only.

### Chat expiry
- `matches.chat_expires_at` column exists, but is `NULL` by default and **no code path sets it**.
- Defensive guard in `_assertMatchActive` will block sends if it's ever populated.
- Effective behaviour today: chats never expire.

---

## 3. Match Creation — Live Function Body

`check_and_create_match(p_swiper, p_target, p_mode)` (SECURITY DEFINER, full body verified live):
1. Check if `p_target` has already swiped right/super on `p_swiper` for the same mode.
2. Reject if a non-expired/closed match already exists between the pair.
3. Order the IDs deterministically (smaller UUID → user1).
4. Create `conversations(type='alliance', mode=p_mode)` row.
5. Insert two `conversation_participants` rows.
6. Insert `matches` with `status='pending_first_message'`, `video_deadline_at = NOW() + 24h`, `conversation_id`.
7. Insert two `notifications` ("New Connection!").
8. Return the match row as JSON.

Idempotency: re-running on the same pair after expiry creates a new match (the "expired/closed" check is by status, not by row count). Re-running while a non-expired match already exists returns NULL.

---

## 4. Liked-You Feasibility

### Data shape (live)
```
swipes columns: id, swiper_id (uuid), swiped_id (uuid), direction (text), created_at, mode
RLS policies:
  swipes_insert_own  INSERT  with_check (auth.uid() = swiper_id)
  swipes_select_own  SELECT  using (auth.uid() = swiper_id)
```

Note: the live column is **`swiped_id`**, not `target_id` (one sub-agent claimed `target_id` — incorrect).

### The blocker
The current SELECT policy lets a user read **only their own outbound** swipes. To answer "who right-swiped on me?" you must query `WHERE swiped_id = me`, which the policy rejects.

### The fix shape (proposed for a future sprint — not in this audit)
A SECURITY DEFINER RPC, e.g.:
```sql
CREATE FUNCTION public.fetch_inbound_likes(p_user uuid)
RETURNS TABLE (
  swiper_id        uuid,
  swiper_name      text,
  swiper_age       int,
  swiper_avatar    text,   -- redact / blur for free tier in app layer
  created_at       timestamptz
)
LANGUAGE sql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT s.swiper_id,
         p.display_name,
         p.age,
         p.date_avatar_url,
         s.created_at
  FROM public.swipes s
  JOIN public.profiles p ON p.id = s.swiper_id
  WHERE s.swiped_id = p_user
    AND s.direction IN ('right','super')
    AND s.mode = 'date'
    -- Exclude pairs that already match
    AND NOT EXISTS (
      SELECT 1 FROM public.matches m
      WHERE ((m.user1_id = s.swiper_id AND m.user2_id = p_user) OR
             (m.user1_id = p_user AND m.user2_id = s.swiper_id))
        AND m.status NOT IN ('expired','closed')
    )
    -- Exclude blocked / hidden by caller
    AND s.swiper_id <> ALL (COALESCE((SELECT blocked_users FROM public.profiles WHERE id = p_user), '{}'))
    AND s.swiper_id <> ALL (COALESCE((SELECT hidden_users  FROM public.profiles WHERE id = p_user), '{}'))
    -- Exclude paused / un-onboarded swipers
    AND p.is_onboarded = TRUE
    AND COALESCE(p.is_paused, FALSE) = FALSE
  ORDER BY s.created_at DESC
  LIMIT 50;
$$;
REVOKE EXECUTE ON FUNCTION public.fetch_inbound_likes(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fetch_inbound_likes(uuid) TO authenticated;
```

Cost: one new function, no schema change, no RLS edit. The `swipes_select_own` policy stays restrictive at the table level; the RPC opens a controlled window.

Caveats to think about before shipping:
- If you want "free user sees count + blurred", the RPC can either return the rows always and let Flutter blur, OR have a `p_show_photos` parameter that only `true` for premium callers (server enforced by reading `profiles.is_premium`). Server-side enforcement is safer; client blur can be bypassed.
- Sorting strategy matters for engagement: recent-first vs. mutual-likelihood-first vs. "people you might also like".
- Need a "Pass / Like back" surface — clicking "Like back" should call the existing `create_swipe_with_gate` + `check_and_create_match` chain, instantly converting an inbound like into a match.

---

## 5. Premium / Billing Infrastructure — Zero

| Check | Result |
|---|---|
| pubspec dependency: `in_app_purchase` / `purchases_flutter` / `flutter_inapp_purchase` | **None.** No IAP package. |
| `android/app/src/main/AndroidManifest.xml`: `com.android.vending.BILLING` | **Not declared.** |
| Schema: tables matching `subscription`, `purchase`, `entitlement`, `premium`, `plus`, `product`, `payment`, `revenuecat`, `billing`, `boost` | **Zero rows.** |
| Profile columns matching `premium`, `subscription`, `entitlement`, `plus`, `gold`, `tier` (paid) | **None of those.** `nob_tier` exists but is merit-earned. `boost_active_until`, `boosts_remaining`, `super_likes_remaining` exist but are orphan. |
| Edge functions: `revenuecat-webhook`, `play-webhook`, `apple-webhook` | **None.** Only `gemini-text`, `places-proxy`, `send-push`, `verify-images`. |
| Paywall / Premium upsell screen in `lib/features/` | **None.** `lib/features/profile/tier_promotion_screen.dart` exists but is a celebration modal for merit-based tier promotion, not a purchase flow. |
| Theming "premium" | `lib/core/theme/premium.dart` is **visual design tokens only** — shadows, gradients, animations. Not monetization. |

**Verdict:** Noblara has the *tier rails* but not the *purchase rails*. To turn `noble` into a paid SKU you need ~2 sprints of new infrastructure.

---

## 6. Supabase / RLS Risks Around Liked-You

Current state lets you safely add Liked-You via a SECDEF RPC. **But** three pre-existing risks compound if you build a paid funnel on top of unsafe data:

1. **Verification self-verify hole** (P0-1 in audit). Containment hid the UI but the RLS still allows it. A free user can self-verify and look "real" inside Liked-You. Paid users converting on that lie is a brand risk for a dating app.
2. **No spam rate-limit on messages.** Once Liked-You generates more matches → more chats → premium customers can be flooded by free users mass-DMing. Cost: moderation backlog, retention churn.
3. **`profiles_update_own` is column-open.** A bad actor can set `nob_tier='noble'` themselves and bypass swipe quotas entirely. This means today *any* user can already self-grant Noble's 100 swipes/day. **You probably want to confirm this isn't being exploited before tightening it as part of the premium sprint.**

---

## 7. Recommended Free Tier (V1.x)

Reusing the existing `observer` settings:
- 30 right-swipes/day (current Observer cap)
- 2 matches/day (current Observer cap)
- Unlimited messages within an active chat (current behaviour)
- See Liked-You **count only**, photos hidden / blurred ("X people liked you")
- See own outbound swipes (current behaviour)
- Travel Mode for non-region users (current)
- No rewinds, no boosts (current)

This is intentionally tight enough to make the "X liked you" count tantalising — the classic dating-app pattern.

---

## 8. Recommended Premium Tier (V1.1)

**Single price point**, monthly, weekly trial.

What it unlocks (all reusing existing rails — minimal new code):
- 100 right-swipes/day (current Noble cap; just bypass `check_swipe_limit` for premium).
- 7 matches/day (current Noble cap).
- See Liked-You **with photos and names** (RPC variant or client-side gating).
- 3 monthly boosts (reuse `boosts_remaining`, wire it into feed ranking — out of scope for V1.1).
- Optional: weekly "Spotlight" (premium-only candle in Discover).

**Explicitly NOT day-one premium unlocks** (V1.2+):
- Travel Plus (paid non-region geo bypass)
- Read receipts
- Profile undo/edit history
- Daily boost stacks

Pricing intuition (region-adjusted, your call):
- TH/VN/PH base: USD 4.99–6.99/mo on a weekly plan ($1.49–1.99/week) seems mainstream-mobile.
- Apple Family Sharing eligible? — Probably no; subscription per-user.

---

## 9. Liked-You V1.1 Minimum-Safe Design

**Backend (1 sprint):**
1. Add SECURITY DEFINER RPC `fetch_inbound_likes(p_show_photos boolean)` (signature variant for premium check, OR have it always return URLs and gate on server-side `is_premium`).
2. Add `inbound_likes_count(p_user uuid)` RPC for the free-tier teaser badge.
3. Add `dismiss_inbound_like(p_swiper uuid)` RPC for the "Pass" action (sets a dismissal flag without becoming a swipe-left).

**Flutter (1 sprint):**
1. `LikedYouScreen` — grid of inbound-like cards.
2. Cards blurred-or-not based on `is_premium`.
3. "Like back" button → calls existing `create_swipe_with_gate` + `check_and_create_match` → instant match path.
4. Discover tab badge: "🔥 12 liked you" → tap → LikedYouScreen.
5. Paywall trigger: tapping a blurred card → premium upsell modal.

**Telemetry — required before pricing tuning**:
- Liked-You opens / day
- Paywall views / day
- Paywall → trial start
- Trial → paid conversion
- Liked-Back rate

---

## 10. Required Implementation Order (4 phases)

### Phase 0 — Verification rebuild (P0-1 hard-fix)
Path-B from the verification audit. Tighten RLS on photo_verifications/profiles/gating_status so that the trust badge means something. ~1 sprint.

### Phase 1 — Liked-You data layer (1 sprint)
- Migration: `fetch_inbound_likes`, `inbound_likes_count`, `dismiss_inbound_like` SECDEF RPCs.
- No table changes (data is already in `swipes`).

### Phase 2 — Billing infrastructure (2 sprints)
**Sprint 2A — SDK + permission + paywall plumbing:**
- Choose IAP path. Recommendation: **RevenueCat (`purchases_flutter`)** — handles iOS+Android receipt verification, sandbox testing, and webhook complexity for one SDK addition. Direct `in_app_purchase` package is cheaper short-term but more receipt-verification work.
- Add `BILLING` permission to AndroidManifest.xml.
- Add `purchases_flutter: ^X.Y.Z` to pubspec.
- Schema migration: `subscriptions(user_id, product_id, expires_at, platform, store_transaction_id, status, revenuecat_user_id, updated_at)` + `is_premium` boolean column on profiles (or a view).
- Edge function `revenuecat-webhook` to ingest entitlement events.

**Sprint 2B — Paywall UI + entitlement enforcement:**
- `PaywallScreen` with single product card, one CTA.
- `premiumProvider` (Riverpod) that wraps `profiles.is_premium` for app-wide checks.
- Hook into `check_swipe_limit` / `check_connection_limit` server-side: if `is_premium`, bypass observer/explorer/noble decision and use `noble` cap. (One SQL function edit, not a new table.)
- Hook Liked-You: `fetch_inbound_likes` server-side returns photo URLs only when caller `is_premium`.

### Phase 3 — Liked-You + Paywall UI (1 sprint)
Per §9.

### Phase 4 — Telemetry, A/B (V1.2+)
- Analytics SDK (Firebase Analytics is already present via firebase_core — minimal lift).
- Conversion funnel event taxonomy.
- Pricing A/B once volume permits.

**Total to first paid user: ~5 sprints + Phase 0.** Phase 0 can be parallelised with Phases 1–2 by different folks but should land before the paywall goes live; otherwise the trust-badge promise is a brand liability.

---

## 11. P0/P1 Risks to Resolve BEFORE Monetization Goes Live

| # | Risk | Severity | Solve before paywall? |
|---|---|---|---|
| 1 | Self-verify via RLS (P0-1 from verification audit) | P0 | **Yes** — Phase 0 |
| 2 | Self-grant Noble tier via `profiles_update_own` open UPDATE | P0 | **Yes** — column-lock `nob_tier` in same migration as Phase 0 |
| 3 | No message rate limit / spam guard | P1 | Yes — risk grows once Liked-You drives more matches |
| 4 | Verification selfie privacy leak (P0-2) | **CLOSED** today (R-containment) | — |
| 5 | Admin verifications path broken (P0-3) | P1 | Tolerable for V1; rebuild in Phase 0 |
| 6 | `verify-images` Edge Function is anon-key only | P1 | Add JWT check + rate limit in Phase 0 |
| 7 | No store-receipt verification | P0 for billing | Phase 2A |
| 8 | No GDPR/KVKK paid-data export pathway | P1 | Document policy before paywall; add export later |

---

## 12. Required DB Changes Summary

| Phase | Migration intent |
|---|---|
| 0 | Tighten RLS on `photo_verifications`, `profiles` (column-restrict), `gating_status`; admin RPC; verify-images JWT check |
| 1 | Add `fetch_inbound_likes`, `inbound_likes_count`, `dismiss_inbound_like` RPCs |
| 2A | Add `subscriptions` table; add `profiles.is_premium`; install `revenuecat-webhook` Edge Function |
| 2B | Server-side `check_swipe_limit` premium bypass + `fetch_inbound_likes` premium photo gate |
| 3 | (Flutter only) |

No table is being dropped. The orphan columns (`super_likes_remaining`, `rewinds_remaining`, `boost_active_until`, etc.) can either be repurposed for the premium model (recommended — re-wire instead of re-create) or dropped in a V1.2 cleanup sweep.

---

## 13. Required Flutter Changes Summary

| Phase | Files |
|---|---|
| 0 | (Mostly DB) – minor: undo R-containment hides if verification path is now safe |
| 1 | New repo method `fetchInboundLikes()` in a `liked_you_repository.dart` |
| 2A | pubspec dep, AndroidManifest entry, `lib/services/billing_service.dart`, `lib/providers/premium_provider.dart` |
| 2B | `lib/features/paywall/paywall_screen.dart` |
| 3 | `lib/features/liked_you/liked_you_screen.dart`, Discover tab badge integration |

Zero changes to existing Discover/Match/Chat/Travel/Profile/Auth screens beyond the badge insertion + paywall handoff.

---

## 14. Store / Billing Operational Notes

- **Google Play Billing**: requires the `BILLING` permission + Play Console product setup + closed-track release before live testing.
- **Apple StoreKit**: if/when iOS launches — RevenueCat covers both, otherwise duplicate work.
- **Receipt verification**: never trust the client. The webhook approach (RevenueCat → Edge Function → DB) keeps `is_premium` server-authoritative.
- **Subscription cancellation**: webhook must clear `is_premium` on `subscription:cancelled` / `subscription:expired` events.
- **Refund handling**: same path.
- **Family / fraudulent account sharing**: out of scope for V1.1.
- **Tax handling**: Play handles VAT/sales tax in Türkiye, TH, VN, PH at point of sale. Document for users in privacy policy.

---

## 15. Final Answers to the 6 Critical Questions

1. **Şu an kullanıcı sınırsız like atabiliyor mu?**
   **Hayır.** Observer 30, Explorer 50, Noble 100 swipe/gün; ayrıca right-swipe için match limit (Observer 2, Explorer 4, Noble 7). Sunucu enforce ediyor, client'a görünür "kalan X swipe" UI'ı yok.

2. **Şu an kullanıcı sınırsız mesaj atabiliyor mu?**
   **Evet.** Match `chatting`'e geçtikten sonra hiçbir günlük cap, rate limit veya debounce yok. Spam koruması yok. First-message 24 saat içinde gönderilmeli (matched ardından), gönderildiği an chat açılıyor.

3. **Liked You mevcut veriyle yapılabilir mi?**
   **Evet.** Tüm veri `swipes` tablosunda (`swiper_id`, `swiped_id`, `direction`). Tek engel: RLS `swipes_select_own` user'a sadece kendi outbound'unu okutuyor. Bir SECURITY DEFINER RPC ile ters yöne pencere açılır. Yeni tablo gerekmez.

4. **Premium için altyapı var mı?**
   **Hayır, sıfır.** IAP SDK yok, BILLING permission yok, subscription/entitlement tablosu yok, webhook function yok, paywall ekranı yok. ~2 sprintlik kurulum gerekir. `lib/core/theme/premium.dart` sadece görsel tema — monetization değil.

5. **İlk para kazanma özelliği olarak Liked You mantıklı mı?**
   **Evet, ama önce billing altyapısı + verification trust fix.** Liked-You tek başına anlamsız — paywall'a takılmayan free user için sadece bir başlık. Tinder/Bumble pattern'i: Liked-You count = teaser, photos = paywall. Altyapı olmadan Liked-You ekranı UI mock'tan ibaret kalır.

6. **Liked You için minimum güvenli teknik plan?**
   **5 sprintlik sıralama:**
   - Phase 0: Verification RLS rebuild (P0-1 + tier self-grant fix).
   - Phase 1: 3 SECDEF RPC ile Liked-You veri katmanı.
   - Phase 2A: RevenueCat SDK + `subscriptions` table + webhook Edge Function.
   - Phase 2B: Premium server-side gating (swipe quota bypass + photo gate).
   - Phase 3: Paywall + Liked-You Flutter UI + Discover badge.

   En kritik nokta: **Phase 0 paywall'dan ÖNCE landmek zorunda.** Bir dating app'te "verified" rozeti satıyorsan ve self-verify hole'u açıksa, paying user düşüşü ya da regulatory baş ağrısı kaçınılmaz.

---

## 16. Recommended Next Sprint

**Sprint = Path B (Verification rebuild).** This is the gating dependency for everything monetization. The R-containment closed the immediate privacy leak (P0-2) but left the trust-bypass holes (P0-1) latent. Before any paid user is asked to trust a verified badge, those RLS policies need to be column-locked, the `nob_tier` self-grant has to be closed, and the admin path has to actually work.

After Verification rebuild lands, the natural sequence is:
1. Liked-You RPC sprint (1 sprint, low risk, no SDK change)
2. Billing infra sprint (2 sprints, new SDK + new tables)
3. Paywall + Liked-You UI sprint (1 sprint, mostly Flutter)

If you want to ship V1 to the store with monetization deferred: that's already supported. R25-tail produced a clean signed AAB at `1.0.1+2`. Containment guarantees no new user can hit the broken verification flow. Add Phase 0 + 1 + 2 + 3 as a V1.1 minor release.

---

## 17. Files Inspected / Queries Run

```
Flutter (read or grep)
  lib/data/repositories/swipe_repository.dart
  lib/data/repositories/match_repository.dart
  lib/data/repositories/messages_repository.dart
  lib/providers/feed_provider.dart, match_provider.dart, messages_provider.dart
  lib/features/feed/feed_screen.dart
  lib/features/match/individual_chat_screen.dart, mini_intro_screen.dart, match_found_screen.dart
  lib/data/models/match.dart, message.dart, profile.dart, profile_card.dart
  lib/core/theme/premium.dart   (confirmed: visual theming only)
  lib/features/profile/tier_promotion_screen.dart
  pubspec.yaml
  android/app/src/main/AndroidManifest.xml
  android/app/build.gradle.kts

Supabase (live, via mcp__supabase__execute_sql)
  swipes / matches / messages / conversations / conversation_participants column inventory
  RLS policies on the above five tables
  pg_get_functiondef for: check_swipe_limit, get_remaining_swipes, increment_swipe_count,
                          create_swipe_with_gate, check_and_create_match,
                          first_message_advance_match
  profiles columns matching premium/subscription/tier/swipe/like/super/rewind/quota/limit/daily/weekly
  public tables matching subscription/purchase/entitlement/premium/plus/product/payment/revenuecat/billing/liked/boost
```

No DB writes. No migrations. No commits. This is a planning audit.

---

## 18. Status

Working tree state (R-monetization-relevant only):
```
?? MONETIZATION_BASELINE_AUDIT.md  (this file)
```

No commit unless you call for one. The natural follow-up sprint is **Verification rebuild (Path B)** — say "go Path B" and I'll scope it concretely, or "commit this audit" and I'll just commit the report.

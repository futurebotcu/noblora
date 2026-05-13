# Noblara Monetization Simplification Plan (3-Tier Revision)

**Date:** 2026-05-13 (3-tier revision applied)
**Sprint type:** Read-only audit + plan. No code change. No migration. No billing.
**Decision input (revised):**
> "Herkes standard kullanıcı yerine 3 katman: **Free** (default) + **Plus** (yarı ücretli) + **Premium / Unlimited** (tam ücretli). Plus + Premium aboneliği RevenueCat ile, Boost / Extra Swipe pack consumable. Eski Observer / Explorer / Noble tier sistemi product/limit mantığında kullanılmayacak."

The previous 2-tier draft (Free + Plus + consumables) is replaced. Premium is added as a distinct paid tier above Plus.

---

## Executive Summary

Noblara today runs a **merit-based tier system** (Observer / Explorer / Noble) where a `recalculate_tiers` cron job ranks every user by a composite `maturity_score` every 6 hours. Tier sets daily swipe quota (Observer 30 / Explorer 50 / Noble 100) and daily match cap (Observer 2 / Explorer 4 / Noble 7). Tier also drives a visible coloured pill in other-user profile headers and a Noble bypass for the photo verification gate.

The revised monetization model retires that system in favour of **three explicit, billing-driven tiers**:

| Tier | Cost | Daily right-swipes | Liked-You | Travel | Boost | Source |
|---|---|---|---|---|---|---|
| **Free** | $0 | 30 | Count + blurred grid | Current region only (TH/VN/PH gate, no override) | None | Default |
| **Plus** | Subscription, lower tier | 100 | Clear photos + names + "Like back" | Single selected travel city | Optional weekly rewind (1/week) | RevenueCat subscription |
| **Premium / Unlimited** | Subscription, higher tier | "Unlimited" surfaced to user; **backend soft cap 500/day** (with 1000/day hard ceiling for abuse) | Clear + priority sort + filter options | Multi-city Travel Plus | 1/week boost included | RevenueCat subscription |
| **Consumables (any tier)** | One-time | `noblora_swipe_pack_30` tops bonus_swipes_remaining | — | — | `noblora_boost_1` activates a 30-min Spotlight | RevenueCat consumable |

Three findings still make M0 (tier neutralization + trust lockdown) the urgent first sprint regardless of tier-count decisions:

- **🔴 The `recalculate_tiers` cron is silently broken.** `calculate_maturity_score` queries `public.posts` and `public.video_sessions` — both dropped (R22B + R10/R11). Every 6h since R22B the cron throws `42P01: relation does not exist`. Tier ranks are frozen and log noise accumulates.
- **🔴 The self-grant tier hole is unpatched.** `profiles_update_own` RLS has no column restriction; any authenticated user can `PATCH profiles SET nob_tier='noble'` and grant themselves 100 swipes/day. Same column-open policy that powers the self-verify attack from the verification audit.
- **🔴 With Premium added, the same RLS hole becomes a Premium self-grant hole** the moment we add `plan_level`. M0 must close it before M1 ships the column.

Recommended first sprint: **M0 — Tier neutralization + trust lockdown**.

---

## 1. Current Tier System Map

### 1.1 DB-side mechanics (live, verified)

**Cron** (`cron.job`): `recalculate-tiers`, schedule `0 */6 * * *`, command `SELECT public.recalculate_tiers();`

**`recalculate_tiers()` SECDEF function:**
1. `PERFORM public.calculate_maturity_score(id)` for every non-`tier_locked` profile.
2. Rank by `maturity_score DESC, vitality_score DESC, random()`.
3. Top 10% → `'noble'`, next 40% → `'explorer'`, rest → `'observer'`.
4. INSERT `tier_promoted` notifications for changed users.
5. UPDATE `profiles.nob_tier`.

**`calculate_maturity_score()`** weights: Profile completeness 20% / Community 15% / Depth 15% / Trust 20% / Follow-through 20% / Vitality 10% + bonus.

🔴 **Broken in production** — references `public.posts`, `public.video_sessions`, `public.event_participants`, `public.event_checkins`. All gone.

**Tier-gated functions still live:**

| Function | Behaviour |
|---|---|
| `check_swipe_limit(uid)` | Observer=30 / Explorer=50 / Noble=100 daily swipes |
| `check_connection_limit(uid)` | Observer=2 / Explorer=4 / Noble=7 daily right-swipe matches |
| `check_signal_limit(uid)` | Observer=1/mo / Explorer=2/wk / Noble=1/day (**Signal feature removed in R23**) |
| `get_remaining_swipes(uid)` | Returns remaining; not called by Flutter |
| `increment_swipe_count(uid)` | Advances `daily_swipes_used` |

**RLS hole** (still present):
```
profiles_update_own  UPDATE  USING (auth.uid() = id)  WITH CHECK (null)
```
No column restriction. Anyone with a JWT can self-update `nob_tier`. Once `plan_level` and `is_premium` columns land in M1, the same hole becomes self-grant for Premium.

### 1.2 Flutter-side surfaces

| File | Behaviour |
|---|---|
| `lib/data/models/profile.dart:211, 299` | `Profile.nobTier: NobTier` field, serialised to `nob_tier`. |
| `lib/features/profile/profile_screen.dart:1496–1497` | Own-profile "BADGES" chip shown if `nobTier == explorer \|\| noble`. |
| `lib/features/profile/user_profile_screen.dart:269–327` | Other-user hero header pill ("NOBLE" / "EXPLORER" / "OBSERVER"), colour-coded, always visible. |
| `lib/shared/widgets/tier_badge.dart` | Reusable TierBadge widget. |
| `lib/features/profile/tier_promotion_screen.dart` | Celebration modal triggered by `tier_promoted` push. |
| `lib/providers/interaction_gate_provider.dart:54` | **Tier-gated UX**: `gate.nobTier == 'noble'` bypasses photo gate. |
| `lib/navigation/main_tab_navigator.dart:73, 287–295` | Routes `tier_promoted` push → Profile tab + pushes TierPromotionScreen. |

**Write sites (Flutter → DB):** zero. Promotion is server-side.

---

## 2. Why the 3-Tier Move Is Right (vs. the prior 2-tier draft)

The earlier draft proposed Free + Plus with consumables on top. The 3-tier revision is stronger for three reasons:

1. **"Unlimited" is the highest-converting headline lever in dating apps** (Tinder Gold "unlimited likes", Bumble Premium "unlimited swipes", Hinge HingeX). A two-tier ceiling at 100/day leaves that lever on the table. Splitting Plus (raised cap) and Premium ("unlimited") lets you capture both the price-sensitive and the maximalist segments.
2. **Plus → Premium is a graceful upsell ladder.** Users who hit Plus's 100 cap have a tangible reason to upgrade rather than churn.
3. **The DB lift is small.** A single `plan_level text` column on `profiles` (`'free' | 'plus' | 'premium'`) replaces the boolean `is_premium`. RPC branches add one CASE statement. No schema multiplication.

The cost is one extra Apple/Google product set (and one extra subscription review surface — covered in §10).

---

## 3. Free Plan (default)

| Lever | Limit / behaviour |
|---|---|
| Right-swipes | **30 per day** (Observer's existing cap; flat in `check_swipe_limit`) |
| Matches | **Unlimited** (drop `check_connection_limit`) |
| Messages once matched | **Unlimited per day, no rate limit** (current; spam rate-limit deferred to V1.2) |
| First-message gate | 24h post-match (current R11 trigger) |
| Travel Mode | TH/VN/PH gate; no override (current behaviour for non-region users) |
| Liked-You | **Count + blurred grid** ("🔥 12 liked you" badge → blurred photos → tap = paywall) |
| Boost / rewinds | None |
| Profile badge to others | None (no tier pill, no premium pill) |
| Receipts / advanced filters | None |

Reuses existing rails. No new DB write needed for free behaviour beyond the M0 function rewrite.

---

## 4. Plus Plan ("Noblora Plus", lower-tier subscription)

| Lever | Value | Implementation |
|---|---|---|
| Right-swipes | **100 per day** | Existing Noble cap; `check_swipe_limit` branches on `plan_level = 'plus'`. |
| Matches | Unlimited | Same as Free. |
| Liked-You | **Clear photos + names + "Like back" CTA** | RPC returns `avatar_url` when caller plan_level IN ('plus','premium'). |
| Travel Mode | **Single selected travel city** | Current single-city Travel works; the upgrade is making non-TH/VN/PH users able to set ONE travel city for swipe gate bypass. |
| Rewinds | **Optional weekly rewind allowance** (e.g., 1/week) | `weekly_rewinds_remaining int default 0`; cron tops up to 1 on Mondays for Plus users. |
| Boost | None included | Consumable purchase only. |
| Profile "Plus" badge to others | Optional cosmetic — off by default in V1.1, can be opt-in later. | New small TierBadge variant. |

**Pricing anchor (your call — RevenueCat handles regional):** monthly ≈ USD 4.99 / yearly ≈ USD 23.99 (≈ 4 months free).

---

## 5. Premium / Unlimited Plan ("Noblora Premium", upper-tier subscription)

| Lever | Value | Implementation |
|---|---|---|
| Right-swipes | **"Unlimited"** (UX label) | Backend **soft cap 500/day** (typical fair-use), **hard ceiling 1000/day** abuse guard. `check_swipe_limit` allows up to 500 silently; 500–1000 returns success but logs `quota_warning`; above 1000 hard-rejects to protect against scripted abuse. |
| Matches | Unlimited | Same as Plus / Free. |
| Liked-You | **Clear photos + names + "Like back" CTA + priority sort/filter options** | RPC has additional `p_sort` parameter (`'recent' \| 'best_match' \| 'verified_first'`). Free/Plus use default sort; Premium unlocks the parameter. |
| Travel Mode | **Multi-city Travel Plus** | `travel_cities text[]` column (in addition to existing `travel_country` / `travel_place_id`). Premium can set up to 5 cities; the geo gate accepts a match in any of them. |
| Boost | **1 included boost per week** | `weekly_boost_remaining int default 0`; cron tops up to 1 on Mondays for Premium users only. |
| Advanced filters | Reserved for V1.2 (height range, dating intent, education filters) | Hidden behind a feature flag until designed. Not day-one. |
| Profile "Premium" badge to others | Optional, off by default | Same comment as Plus. |

**Why surface "Unlimited" with a backend soft cap:**

- **Apple/Google review**: a literal "Unlimited" promise is allowed as long as the in-app text reflects fair-use language. "Unlimited swipes (subject to fair-use limits)" satisfies App Store §3.1.2(a) and Play Console subscription policy.
- **Abuse protection**: dating apps are a known bot/script vector. A user (or scraper) burning 5000 right-swipes/day breaks Discover ranking for everyone and floods the swipes table. A 500/day soft cap with a 1000/day hard ceiling stops scripted abuse without inconveniencing real users (Tinder reports the 99th percentile real-user swipe count at ~200/day).
- **Cost management**: every right-swipe touches `fetch_nearby_profiles`, `check_swipe_limit`, `create_swipe_with_gate`, `check_and_create_match`. At 5000/day per heavy user, that's a measurable Supabase compute multiplier.

**Pricing anchor (your call):** monthly ≈ USD 9.99 / yearly ≈ USD 47.99. The Plus → Premium delta should feel like a 2× upgrade for genuine power users.

---

## 6. Consumables (any tier)

Two SKUs to start; both one-time consumable purchases.

| SKU | What it does | Reuses |
|---|---|---|
| `noblora_boost_1` | 30-min Spotlight: profile sorts higher in Discover for 30 min after activation. | `boost_active_until`, `boosts_remaining` columns already exist. Feed RPC honours `boost_active_until > NOW()` ordering. |
| `noblora_swipe_pack_30` | +30 right-swipes added to today's quota. (Renamed from `_10` to `_30` to align with Free's daily 30 — feels like "one extra day"; tune per pricing testing.) | New column `bonus_swipes_remaining int default 0`. `check_swipe_limit` returns TRUE if bonus > 0; `increment_swipe_count` decrements bonus first. |

Both are **consumable** product type (StoreKit + Play Billing). Receipts validated via RevenueCat webhook → Edge Function → SECDEF RPC. Client never grants its own entitlement.

---

## 7. Tier Neutralization Plan (M0)

### 7.1 DB-side (single M0 migration)

```sql
-- 1. Stop the broken cron.
SELECT cron.unschedule('recalculate-tiers');

-- 2. Drop the broken functions.
DROP FUNCTION IF EXISTS public.recalculate_tiers();
DROP FUNCTION IF EXISTS public.calculate_maturity_score(uuid);

-- 3. Retire tier-keyed gates and the dead Signal limit.
DROP FUNCTION IF EXISTS public.check_connection_limit(uuid);
DROP FUNCTION IF EXISTS public.check_signal_limit(uuid);

-- 4. Rewrite check_swipe_limit flat (M1 adds plan_level branching).
CREATE OR REPLACE FUNCTION public.check_swipe_limit(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_used INT;
  v_reset TIMESTAMPTZ;
  v_bonus INT;
BEGIN
  SELECT daily_swipes_used, daily_swipes_reset, COALESCE(bonus_swipes_remaining, 0)
    INTO v_used, v_reset, v_bonus
  FROM public.profiles WHERE id = p_user_id;

  IF v_reset < NOW() - INTERVAL '1 day' THEN
    v_used := 0;
    UPDATE public.profiles SET daily_swipes_used = 0, daily_swipes_reset = NOW()
      WHERE id = p_user_id;
  END IF;

  -- M0 baseline: everyone gets 30/day + bonus. M1 introduces plan-aware branching.
  RETURN v_used < 30 OR v_bonus > 0;
END;
$$;

-- (analogous flat rewrites for get_remaining_swipes and increment_swipe_count)
```

**Not dropped in M0** (keep for history / future cleanup sweep): `nob_tier`, `noble_score`, `maturity_score`, the score columns, `tier_locked`, `is_noble`. They become inert.

### 7.2 Flutter-side (small M0 UI hide)

- Strip tier badge from `user_profile_screen.dart` hero header.
- Strip tier chip from `profile_screen.dart` BADGES section.
- Drop Noble bypass in `interaction_gate_provider.dart:54`.
- Strip `tier_promoted` notification routing in `main_tab_navigator.dart`.
- Keep `NobTier` enum + `Profile.nobTier` field + `TierBadge` + `TierPromotionScreen` files (orphan, future V1.x cleanup).

---

## 8. Trust Lockdown (M0, same migration)

Replace column-open UPDATE policies on `profiles`, `gating_status`, `photo_verifications` with triggers that reject sensitive-column writes from non-service-role connections.

```sql
CREATE OR REPLACE FUNCTION public.profiles_block_sensitive_writes()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF current_setting('request.jwt.claim.role', true) = 'service_role' THEN
    RETURN NEW;
  END IF;

  IF NEW.nob_tier IS DISTINCT FROM OLD.nob_tier
     OR NEW.tier_locked IS DISTINCT FROM OLD.tier_locked
     OR NEW.noble_score IS DISTINCT FROM OLD.noble_score
     OR NEW.maturity_score IS DISTINCT FROM OLD.maturity_score
     OR NEW.trust_score IS DISTINCT FROM OLD.trust_score
     OR NEW.is_noble IS DISTINCT FROM OLD.is_noble
     OR NEW.is_verified IS DISTINCT FROM OLD.is_verified
     OR NEW.selfie_verified IS DISTINCT FROM OLD.selfie_verified
     OR NEW.photos_verified IS DISTINCT FROM OLD.photos_verified
     OR NEW.verification_status IS DISTINCT FROM OLD.verification_status
     OR NEW.is_admin IS DISTINCT FROM OLD.is_admin
     OR NEW.daily_swipes_used IS DISTINCT FROM OLD.daily_swipes_used
     OR NEW.daily_swipes_reset IS DISTINCT FROM OLD.daily_swipes_reset
     OR NEW.daily_connections IS DISTINCT FROM OLD.daily_connections
     OR NEW.daily_connections_reset IS DISTINCT FROM OLD.daily_connections_reset
     OR NEW.boost_active_until IS DISTINCT FROM OLD.boost_active_until
     OR NEW.boosts_remaining IS DISTINCT FROM OLD.boosts_remaining
     -- M1 will append: plan_level, premium_until, bonus_swipes_remaining,
     -- weekly_rewinds_remaining, weekly_boost_remaining, travel_cities
  THEN
    RAISE EXCEPTION 'Cannot modify protected profile fields from client';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_profiles_block_sensitive_writes
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.profiles_block_sensitive_writes();
```

Analogous triggers on `gating_status` (block writes to `is_verified`, `is_entry_approved`) and `photo_verifications` (block writes to `status`, `reviewed_by`, `reviewed_at`).

Admin path: a `SECURITY DEFINER` RPC `admin_set_plan_level(p_target, p_plan, p_expires)` becomes the only path to grant entitlements. Wired in M1; webhook calls it in M4.

---

## 9. Liked-You Plan (M2 + M3)

### 9.1 Backend (M2)

```sql
CREATE OR REPLACE FUNCTION public.fetch_inbound_likes(
  p_limit int DEFAULT 50,
  p_sort  text DEFAULT 'recent'   -- 'recent' | 'best_match' | 'verified_first' (Premium only)
) RETURNS TABLE (
  swiper_id    uuid,
  display_name text,
  age          int,
  avatar_url   text,
  created_at   timestamptz,
  is_verified  boolean
) LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_plan text;
BEGIN
  SELECT COALESCE(plan_level, 'free') INTO v_plan FROM public.profiles WHERE id = auth.uid();

  -- Reject non-default sorts for non-Premium callers.
  IF p_sort <> 'recent' AND v_plan <> 'premium' THEN
    p_sort := 'recent';
  END IF;

  RETURN QUERY
  WITH base AS (
    SELECT s.swiper_id, p.display_name, p.age,
           CASE WHEN v_plan IN ('plus','premium') THEN p.date_avatar_url ELSE NULL END AS avatar_url,
           s.created_at, COALESCE(p.is_verified, FALSE) AS is_verified
      FROM public.swipes s
      JOIN public.profiles p ON p.id = s.swiper_id
     WHERE s.swiped_id = auth.uid()
       AND s.direction IN ('right','super')
       AND s.mode = 'date'
       AND NOT EXISTS (
         SELECT 1 FROM public.matches m
         WHERE ((m.user1_id = s.swiper_id AND m.user2_id = auth.uid()) OR
                (m.user1_id = auth.uid() AND m.user2_id = s.swiper_id))
           AND m.status NOT IN ('expired','closed')
       )
       AND s.swiper_id <> ALL (COALESCE((SELECT blocked_users FROM public.profiles WHERE id = auth.uid()), '{}'))
       AND s.swiper_id <> ALL (COALESCE((SELECT hidden_users  FROM public.profiles WHERE id = auth.uid()), '{}'))
       AND p.is_onboarded = TRUE
       AND COALESCE(p.is_paused, FALSE) = FALSE
  )
  SELECT * FROM base
   ORDER BY
     CASE WHEN p_sort = 'verified_first' THEN (NOT is_verified)::int ELSE 0 END,
     CASE WHEN p_sort = 'best_match'    THEN -age                  ELSE 0 END,  -- placeholder
     created_at DESC
   LIMIT p_limit;
END;
$$;
```

**Server-side photo gating** (Premium gate is enforced inside the function, not via client trust). `inbound_likes_count` is a plain SECDEF count function.

### 9.2 Flutter (M3)

| State | Behaviour |
|---|---|
| Free | Blurred grid (Flutter blurs the placeholder; RPC returns null `avatar_url`). Card row: blurred avatar + age. Tap → paywall. |
| Plus | Clear photos + names. Tap → profile preview + "Like back" button. |
| Premium | Clear photos + names. Sort/filter toggle row at top (Recent / Best match / Verified first). Same "Like back". |

---

## 10. Billing Architecture (M4 + M5)

### 10.1 SDK

**RevenueCat (`purchases_flutter`)** — single SDK across Apple + Google, server-side receipt validation, webhook delivery, refund handling. Strongly preferred over raw `in_app_purchase` for a two-subscription + two-consumable catalogue.

### 10.2 Products

```
noblora_plus_monthly        (auto-renewable subscription, 1 month)
noblora_plus_yearly         (auto-renewable subscription, 12 months)
noblora_premium_monthly     (auto-renewable subscription, 1 month)
noblora_premium_yearly      (auto-renewable subscription, 12 months)
noblora_boost_1             (consumable)
noblora_swipe_pack_30       (consumable)
```

### 10.3 Backend tables (M4 migration)

```sql
CREATE TABLE public.subscriptions (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  product_id            text NOT NULL,
  plan_level            text NOT NULL CHECK (plan_level IN ('plus','premium')),
  store                 text NOT NULL,
  store_transaction_id  text NOT NULL,
  status                text NOT NULL,
  expires_at            timestamptz,
  started_at            timestamptz NOT NULL DEFAULT NOW(),
  revenuecat_user_id    text,
  raw_event             jsonb,
  updated_at            timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (store, store_transaction_id)
);

CREATE TABLE public.purchases (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  product_id            text NOT NULL,
  store                 text NOT NULL,
  store_transaction_id  text NOT NULL UNIQUE,
  qty                   int NOT NULL DEFAULT 1,
  granted_at            timestamptz NOT NULL DEFAULT NOW(),
  raw_event             jsonb
);

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS plan_level                text NOT NULL DEFAULT 'free'
                              CHECK (plan_level IN ('free','plus','premium')),
  ADD COLUMN IF NOT EXISTS premium_until             timestamptz,
  ADD COLUMN IF NOT EXISTS bonus_swipes_remaining    int NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS weekly_rewinds_remaining  int NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS weekly_boost_remaining    int NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS travel_cities             text[] NOT NULL DEFAULT '{}';

-- Extend M0 trust-lockdown trigger to also block the 5 new sensitive columns.
```

Both tables RLS-locked: user can SELECT own rows; only `service_role` can INSERT/UPDATE.

### 10.4 plan_level rewrite of check_swipe_limit (M4 update)

```sql
CREATE OR REPLACE FUNCTION public.check_swipe_limit(p_user_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_used INT; v_reset TIMESTAMPTZ; v_bonus INT;
  v_plan TEXT; v_cap INT;
BEGIN
  SELECT daily_swipes_used, daily_swipes_reset,
         COALESCE(bonus_swipes_remaining, 0),
         COALESCE(plan_level, 'free')
    INTO v_used, v_reset, v_bonus, v_plan
  FROM public.profiles WHERE id = p_user_id;

  IF v_reset < NOW() - INTERVAL '1 day' THEN
    v_used := 0;
    UPDATE public.profiles SET daily_swipes_used = 0, daily_swipes_reset = NOW()
      WHERE id = p_user_id;
  END IF;

  v_cap := CASE v_plan
    WHEN 'premium' THEN 500   -- soft cap; UX surfaces "unlimited" but DB enforces fair-use
    WHEN 'plus'    THEN 100
    ELSE                30
  END;

  -- Premium hard ceiling (abuse guard): refuse beyond 1000/day even with bonus.
  IF v_plan = 'premium' AND v_used >= 1000 THEN
    RETURN FALSE;
  END IF;

  RETURN v_used < v_cap OR v_bonus > 0;
END;
$$;
```

### 10.5 Webhook Edge Function

`supabase/functions/revenuecat-webhook/index.ts`:
1. Verify RevenueCat signature header.
2. Parse event (`INITIAL_PURCHASE`, `RENEWAL`, `CANCELLATION`, `EXPIRATION`, `NON_RENEWING_PURCHASE`, `PRODUCT_CHANGE`).
3. **Subscription events**: upsert `subscriptions`; call `admin_set_plan_level(user, plan_level, expires_at)`.
4. **Consumable events**: insert `purchases`; call `admin_grant_boost` or `admin_grant_swipe_pack`.
5. **Cancellation / expiration**: call `admin_set_plan_level(user, 'free', NULL)`.
6. **Plan change** (downgrade Premium → Plus, upgrade Plus → Premium): update both `subscriptions.plan_level` and call `admin_set_plan_level`.

### 10.6 Weekly entitlement cron

Plus + Premium ship with periodic allowances (rewinds, boost). Daily/weekly reset cron extends to:

```sql
-- Monday 00:00 UTC: top up weekly allowances for active subs
UPDATE public.profiles p
   SET weekly_rewinds_remaining = CASE WHEN p.plan_level IN ('plus','premium') THEN 1 ELSE 0 END,
       weekly_boost_remaining   = CASE WHEN p.plan_level = 'premium'           THEN 1 ELSE 0 END;
```

---

## 11. Required DB Changes by Sprint

| Sprint | Migration name | Intent |
|---|---|---|
| M0 | `tier_neutralization_and_trust_lockdown.sql` | unschedule recalculate-tiers; DROP recalculate_tiers, calculate_maturity_score, check_connection_limit, check_signal_limit; flat-rewrite check_swipe_limit + get_remaining_swipes + increment_swipe_count; install profiles_block_sensitive_writes trigger + analogues on gating_status + photo_verifications |
| M1 | `plan_level_schema.sql` | ADD profiles.plan_level + premium_until + bonus_swipes_remaining + weekly_rewinds_remaining + weekly_boost_remaining + travel_cities; extend lockdown trigger with these columns; add `admin_set_plan_level`, `admin_grant_boost`, `admin_grant_swipe_pack` SECDEF RPCs |
| M2 | `liked_you_rpcs.sql` | `fetch_inbound_likes(p_limit, p_sort)`, `inbound_likes_count`, `dismiss_inbound_like`. Server-side photo + sort gating based on `plan_level`. |
| M3 | (Flutter only) | — |
| M4 | `monetization_tables.sql` | `subscriptions` + `purchases` tables with RLS; extend `check_swipe_limit` with plan_level branch + Premium hard ceiling; Monday weekly-allowance cron entry; deploy `revenuecat-webhook` Edge Function |
| M5 | `boost_ranking.sql` | minor update to `fetch_nearby_profiles` ordering to honour `boost_active_until > NOW()` |
| M6 | (no DB) | — |

---

## 12. Required Flutter Changes by Sprint

| Sprint | Files |
|---|---|
| M0 | `user_profile_screen.dart` (drop tier pill), `profile_screen.dart` (drop tier chip), `interaction_gate_provider.dart` (drop Noble bypass), `main_tab_navigator.dart` (drop tier_promoted routing) |
| M1 | `lib/data/models/profile.dart` (+`planLevel: PlanLevel` field, fromJson `plan_level` key, copyWith); guardrail test for round-trip |
| M2 | `lib/data/repositories/liked_you_repository.dart` (new); `lib/providers/liked_you_provider.dart` (new) |
| M3 | `lib/features/liked_you/liked_you_screen.dart` (new) with 3 visual states (Free blur / Plus clear / Premium clear+sort row); Discover tab badge integration in main_tab_navigator |
| M4 | pubspec: `purchases_flutter`; AndroidManifest: `BILLING`; `lib/services/billing_service.dart`, `lib/providers/premium_provider.dart` (exposes `PlanLevel` enum + `isPlus`, `isPremium` getters), `lib/features/paywall/paywall_screen.dart` (single-screen carousel comparing Free / Plus / Premium) |
| M5 | `lib/features/boost/boost_purchase_modal.dart`, `lib/features/swipe_pack/swipe_pack_modal.dart`; small `feed_repository` change to surface boost-active sort to UI |
| M6 | pubspec version bump; small R25-style smoke report |

---

## 13. Security / RLS Risk Matrix

| Risk | Before M0 | After M0 | After M1 | After M4 |
|---|---|---|---|---|
| User self-grants `nob_tier='noble'` for 100 swipes | OPEN | CLOSED (trigger) | CLOSED | CLOSED |
| User self-grants `plan_level='premium'` | (column doesn't exist) | (column doesn't exist) | CLOSED (trigger covers) | CLOSED |
| User self-grants `selfie_verified=true` (verification audit P0-1) | OPEN | CLOSED | CLOSED | CLOSED |
| User self-flips `gating_status.is_entry_approved` | OPEN | CLOSED | CLOSED | CLOSED |
| User PATCHes `daily_swipes_used = 0` to refresh quota | OPEN | CLOSED | CLOSED | CLOSED |
| User PATCHes `bonus_swipes_remaining` to gift themselves consumables | (column doesn't exist) | (column doesn't exist) | CLOSED (trigger covers) | CLOSED |
| Recalculate-tiers cron throws 42P01 every 6h | ACTIVE | STOPPED | STOPPED | STOPPED |
| Premium user runs a script and spawns 10 000 right-swipes/day | (not yet billable) | (not yet billable) | (cap unchanged) | CLOSED (1000/day hard ceiling) |
| Refund / cancellation continues to grant premium | (not yet billable) | — | — | CLOSED (webhook downgrade) |
| Storage SELECT on verification-photos | CLOSED (R-containment) | CLOSED | CLOSED | CLOSED |
| Admin approve path broken (verification audit P0-3) | OPEN | OPEN | OPEN | OPEN (Path-B verification rebuild remains a separate sprint) |
| Message spam / no rate limit | OPEN | OPEN | OPEN | OPEN (V1.2) |

---

## 14. Risks Specific to 3-Tier Monetization

1. **"Unlimited" promise vs. backend soft cap** — the public marketing language must say something like "Unlimited swipes (fair-use applies)". Misleading copy → store review rejection, refund-rate spike, ASO penalties. The 500/day soft cap + 1000/day hard ceiling lets you ship the headline honestly.
2. **Apple/Google subscription review** — Multiple subscription tiers in one app must be presented in a single, side-by-side comparison screen (Apple guideline §3.1.2). RevenueCat's prebuilt paywall templates handle this; building a custom one means hitting Apple's "Subscription Group" + comparison-card requirements explicitly.
3. **Dating app abuse vector** — Premium "unlimited" attracts scrapers and bot farms. Watch for spike in right-swipe per-user per-day; alert on outliers (>500/day) and have manual ban workflow ready. Pair with the verification trust rebuild (Path B) to keep paying users on a real network.
4. **Paywall pressure → retention churn** — Three paywalls (Liked-You blur, swipe cap hit, premium upsell from Plus) layered too aggressively will visibly hurt D7/D30 retention. Soft-launch each rail separately. Liked-You-only paywall (M3) before billing (M4) lets you measure conversion intent without irreversible price exposure.
5. **Plus → Premium upgrade flow** — Apple and Google handle subscription upgrades natively (proration), but the in-app "Upgrade to Premium" CTA needs different copy from "Subscribe". RevenueCat exposes upgrade as a single API call; the paywall screen must understand which surface to show.
6. **Refund / cancellation timing** — A user who refunds on day 3 of a 30-day Plus should drop to `plan_level='free'` immediately. Webhook latency is usually <1 minute but can spike to hours; add a defensive cron that sweeps `subscriptions` daily and downgrades any whose `expires_at < NOW()` and `status != 'active'`.

---

## 15. Sprint Roadmap (M0–M6)

### M0 — Tier neutralization + trust lockdown
- **Goal:** make tier inert; close the column-open RLS holes (tier self-grant, verification self-grant, gating self-grant, swipe-counter self-reset). Stop the broken `recalculate-tiers` cron.
- **DB:** 1 migration.
- **Flutter:** 4 small UI edits.
- **Risk:** medium-low.
- **Commit shape:** split — `fix(noblora): tier neutralization + trust lockdown migration` + `chore(noblora): hide tier UI surfaces` + `docs(noblora): M0 sprint report`.

### M1 — plan-level entitlement schema
- **Goal:** add `plan_level`, `premium_until`, `bonus_swipes_remaining`, `weekly_rewinds_remaining`, `weekly_boost_remaining`, `travel_cities` to `profiles`; extend lockdown trigger; add admin RPCs.
- **DB:** 1 migration.
- **Flutter:** 1 model field (`Profile.planLevel`) + guardrail tests.
- **Risk:** low.
- **Commit shape:** `fix(noblora): plan-level entitlement schema + admin RPCs` + `chore(noblora): Profile.planLevel field` + `docs(noblora): M1 sprint report`.

### M2 — Liked-You data RPCs
- **Goal:** `fetch_inbound_likes(p_limit, p_sort)` (server-side plan_level gating for photos + sort), `inbound_likes_count`, `dismiss_inbound_like`.
- **DB:** 1 migration.
- **Flutter:** repo + provider only.
- **Risk:** low.
- **Commit shape:** `fix(noblora): liked-you RPCs with plan-level gating` + `docs(noblora): M2 sprint report`.

### M3 — Liked-You UI with Free/Plus/Premium states
- **Goal:** `LikedYouScreen` with three render states; Discover tab badge.
- **DB:** none.
- **Flutter:** new screen + paywall handoff hook.
- **Risk:** low.
- **Commit shape:** `feat(noblora): liked-you screen with tiered states` + `docs(noblora): M3 sprint report`.

### M4 — RevenueCat billing + plan sync
- **Goal:** SDK + AndroidManifest BILLING + `subscriptions` + `purchases` tables + paywall screen + plan_level branch in `check_swipe_limit` + revenuecat-webhook Edge Function + weekly-allowance cron.
- **DB:** 1 migration + 1 Edge Function.
- **Flutter:** pubspec + 4 files.
- **Risk:** medium-high. Most new infrastructure of any sprint. Sandbox-test end-to-end before production.
- **Commit shape:** split into 4 — `feat(noblora): RevenueCat SDK + AndroidManifest`, `fix(noblora): subscriptions + purchases tables + webhook RPCs`, `feat(noblora): paywall screen + premiumProvider`, `docs(noblora): M4 sprint report`.

### M5 — Boost + extra swipes consumables
- **Goal:** `noblora_boost_1` and `noblora_swipe_pack_30` wired through RevenueCat; `fetch_nearby_profiles` honours `boost_active_until` for ranking.
- **DB:** small ranking update.
- **Flutter:** 2 purchase modals.
- **Risk:** medium. Boost ranking change can have unintended discovery effects — instrument before scaling.
- **Commit shape:** `fix(noblora): consumable RPCs + boost ranking` + `feat(noblora): boost + swipe-pack purchase modals` + `docs(noblora): M5 sprint report`.

### M6 — Smoke + AAB rebuild + store metadata
- **Goal:** real-device smoke install of M0+M1+M2+M3+M4+M5 stack; Play Console product setup (6 SKUs); App Store equivalent if iOS in scope; AAB rebuild with bumped versionCode.
- **DB:** none.
- **Flutter:** pubspec bump.
- **Risk:** low.
- **Commit shape:** `chore(noblora): bump version 1.0.3+4` + `docs(noblora): M6 release smoke report`.

**Pre-M0 dependency:** the verification audit's P0-1 + tier-self-grant are solved as a side-effect of M0's lockdown trigger when extended to `pv_update_own` and `gating_update_own` policy targets. Path-B verification rebuild proper (admin RPC, photo_verified → photos_verified typo fix, etc.) remains a separate sprint after M6 if launch timing permits, otherwise after launch.

---

## 16. Recommendation

**Run M0 next.**

Three reasons, unchanged from the 2-tier draft:

1. `recalculate_tiers` is throwing 42P01 every 6 hours and accumulating log noise.
2. Tier self-grant gives any authenticated user 100 swipes/day for free today; the same RLS hole becomes a Premium self-grant the moment M1 ships `plan_level`.
3. Every monetization sprint after M0 assumes "tier is dead, plan_level is the only entitlement that matters" — building M1–M6 on top of an unsecured baseline means rebuilding their server-side checks twice.

M0 is the lowest-risk sprint of the seven: ~1 migration + 4 Flutter UI edits. No new SDK. No new tables. No customer-visible behaviour change for existing verified users.

---

## 17. Final Answers (3-Tier Revision)

1. **Yeni katmanlar:** Free / Plus / Premium-Unlimited + Consumables (Boost, Extra Swipes).

2. **Limitler:**
   - Free: 30 swipes/gün, count+blur Liked-You, current-region Travel.
   - Plus: 100 swipes/gün, açık Liked-You + Like-back, 1-şehir Travel, opsiyonel haftalık 1 rewind.
   - Premium: "unlimited" (UI label) / **500/gün soft cap, 1000/gün hard ceiling** (abuse guard), açık Liked-You + priority sort/filter, multi-city Travel Plus, haftalık 1 boost dahil.
   - Consumables (her katmana): boost_1 (30dk Spotlight), swipe_pack_30 (+30 swipe).
   - Match sonrası chat: **her katmanda sınırsız**, V1.2'de basit anti-spam rate-limit (30 msg/dakika) eklenmeli.

3. **İlk uygulanacak sprint:** **M0 — Tier neutralization + trust lockdown.** (Roadmap: M0 → M1 → M2 → M3 → M4 → M5 → M6.)

4. **Billing için minimum teknik plan:**
   - SDK: **RevenueCat (`purchases_flutter`)**.
   - 6 ürün: `noblora_plus_monthly`, `noblora_plus_yearly`, `noblora_premium_monthly`, `noblora_premium_yearly`, `noblora_boost_1`, `noblora_swipe_pack_30`.
   - Backend: `subscriptions` + `purchases` tabloları (RLS: kullanıcı sadece kendi satırını okur, write yalnızca service_role); `profiles.plan_level` + `premium_until` + 4 ek kolon; `admin_set_plan_level` + `admin_grant_*` SECDEF RPC'leri.
   - Edge Function: `supabase/functions/revenuecat-webhook` — RevenueCat event'lerini doğrular ve admin RPC'lerine çevirir.
   - Server-side enforce: `check_swipe_limit` plan-level branch ile günlük cap'i belirler; Premium için 1000/gün hard ceiling.
   - Defensive: günlük cron `subscriptions` taraması, `expires_at < NOW()` olanları `plan_level='free'`'e düşürür.

---

## 18. Files Inspected / Queries Run

Same audit set as the original draft (see git history for the prior version). No additional DB writes or migrations in this revision — only the report file is updated.

---

## 19. Status

Working tree state (revision-relevant only):
```
?? MONETIZATION_SIMPLIFICATION_PLAN.md   (this file — revised in place, not yet committed)
?? MONETIZATION_BASELINE_AUDIT.md        (prior sprint; still untracked)
```

No code/DB changes. No commits.

Awaiting your call to **`go M0`** (start the tier neutralization + trust lockdown sprint) or **`commit plans`** (commit the two audits + this revised plan as historical record without starting any sprint).

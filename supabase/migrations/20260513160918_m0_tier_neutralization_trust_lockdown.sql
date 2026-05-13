-- =============================================================================
-- M0 — Tier neutralization + trust lockdown
-- =============================================================================
-- Purpose:
--   First technical step of the 3-tier monetization plan
--   (MONETIZATION_SIMPLIFICATION_PLAN.md). Retires the merit-based
--   Observer / Explorer / Noble tier system from product / limit / premium
--   logic, and closes the column-open RLS holes that let any authenticated
--   user self-grant nob_tier='noble', self-verify, self-reset swipe quotas,
--   self-approve gating, etc.
--
--   No billing infra, no plan_level column, no Liked-You, no Boost in this
--   migration — those are M1 onwards. M0 is the load-bearing prerequisite.
--
-- What this migration does:
--   1. Unschedules the broken `recalculate-tiers` cron (throwing 42P01
--      every 6h since R22B dropped public.posts / public.video_sessions
--      / public.event_* that calculate_maturity_score still references).
--   2. Drops the broken tier-promotion machinery: recalculate_tiers(),
--      calculate_maturity_score().
--   3. Drops the now-dead tier-keyed gates: check_connection_limit(),
--      check_signal_limit() (Signal removed in R23 anyway).
--   4. Rewrites check_swipe_limit() / get_remaining_swipes() /
--      increment_swipe_count() to a flat 30/day Free-baseline model.
--      Tier branches are gone; plan_level branches will come back in M4.
--   5. Installs the **trust lockdown trigger** that prevents any client
--      (authenticated user) from writing protected columns on profiles /
--      gating_status / photo_verifications. SECURITY DEFINER functions
--      that legitimately need to write these columns set a session-local
--      bypass marker first.
--
-- Why a marker pattern instead of plain auth.jwt() role check:
--   increment_swipe_count / check_swipe_limit are SECDEF functions called
--   by authenticated users. Inside their bodies, auth.jwt() still returns
--   the *caller's* JWT (role='authenticated'), not service_role. A naive
--   role-only check would block these legitimate paths. The bypass marker
--   (`app.bypass_lockdown` set local=true) is the standard Postgres way
--   for a SECDEF to whitelist its own writes. Direct user PATCH calls
--   never set the marker → blocked.
--
-- What this migration explicitly does NOT touch (kept for future / merit
-- history / V1.x cleanup):
--   - profiles.nob_tier, .noble_score, .maturity_score, .trust_score,
--     .tier_locked, .is_noble — columns stay, nothing writes them.
--   - profiles.boost_active_until, .boosts_remaining,
--     .super_likes_remaining, .rewinds_remaining — kept for M5 boost work.
--   - photo_verifications table — still wired for AI verification path
--     (verify-images Edge Function); UI containment hides the entry.
--   - profiles_sync_is_verified trigger — kept; will get its own
--     containment in a future verification-rebuild sprint (Path B).
--
-- Rollback note:
--   None of the dropped functions can be recovered from version control
--   (they pre-date the chronological migration set). Recovery requires
--   pg_dump of pre-migration state or recreation from session notes.
--   The lockdown triggers can be dropped via `DROP TRIGGER ... ON ...`
--   if a rollback is needed; the trigger functions can be dropped too.
-- =============================================================================

-- ── 1. Stop the broken cron ──────────────────────────────────────────────────

SELECT cron.unschedule('recalculate-tiers');

-- ── 2. Drop broken tier-promotion functions ──────────────────────────────────

DROP FUNCTION IF EXISTS public.recalculate_tiers();
DROP FUNCTION IF EXISTS public.calculate_maturity_score(uuid);

-- ── 3. Drop dead tier-keyed gates ────────────────────────────────────────────

DROP FUNCTION IF EXISTS public.check_connection_limit(uuid);
DROP FUNCTION IF EXISTS public.check_signal_limit(uuid);

-- ── 4. Rewrite swipe-quota gates to flat 30/day Free baseline ───────────────

CREATE OR REPLACE FUNCTION public.check_swipe_limit(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_used  INT;
  v_reset TIMESTAMPTZ;
BEGIN
  SELECT daily_swipes_used, daily_swipes_reset
    INTO v_used, v_reset
  FROM public.profiles WHERE id = p_user_id;

  IF v_used IS NULL THEN
    RETURN FALSE;
  END IF;

  -- Rolling 24h reset
  IF v_reset IS NULL OR v_reset < NOW() - INTERVAL '1 day' THEN
    v_used := 0;
    PERFORM set_config('app.bypass_lockdown', 'true', true);
    UPDATE public.profiles
       SET daily_swipes_used = 0,
           daily_swipes_reset = NOW()
     WHERE id = p_user_id;
  END IF;

  -- M0 baseline: everyone gets 30 swipes/day. M4 will branch on plan_level.
  RETURN v_used < 30;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_remaining_swipes(p_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_used  INT;
  v_reset TIMESTAMPTZ;
BEGIN
  SELECT daily_swipes_used, daily_swipes_reset
    INTO v_used, v_reset
  FROM public.profiles WHERE id = p_user_id;

  IF v_used IS NULL THEN RETURN 0; END IF;

  IF v_reset IS NULL OR v_reset < NOW() - INTERVAL '1 day' THEN
    v_used := 0;
  END IF;

  RETURN GREATEST(0, 30 - v_used);
END;
$$;

CREATE OR REPLACE FUNCTION public.increment_swipe_count(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  PERFORM set_config('app.bypass_lockdown', 'true', true);
  UPDATE public.profiles
     SET daily_swipes_used = daily_swipes_used + 1
   WHERE id = p_user_id;
END;
$$;

-- ── 5. Trust lockdown — trigger function for profiles ───────────────────────

CREATE OR REPLACE FUNCTION public.profiles_block_sensitive_writes()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- Allow service_role (Edge Functions, webhooks) and bypass-marker callers
  -- (SECDEF functions that legitimately need to write protected columns).
  IF (auth.jwt() ->> 'role') = 'service_role' THEN
    RETURN NEW;
  END IF;
  IF current_setting('app.bypass_lockdown', true) = 'true' THEN
    RETURN NEW;
  END IF;
  IF auth.jwt() IS NULL THEN
    -- Direct DB access (psql / migrations / cron jobs that run as postgres)
    RETURN NEW;
  END IF;

  -- Block any change to protected columns from an authenticated user JWT.
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
     OR NEW.super_likes_remaining IS DISTINCT FROM OLD.super_likes_remaining
     OR NEW.rewinds_remaining IS DISTINCT FROM OLD.rewinds_remaining
  THEN
    RAISE EXCEPTION 'Cannot modify protected profile fields from client (M0 trust lockdown)';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_profiles_block_sensitive_writes ON public.profiles;
CREATE TRIGGER trg_profiles_block_sensitive_writes
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.profiles_block_sensitive_writes();

-- ── 6. Trust lockdown — trigger function for gating_status ──────────────────

CREATE OR REPLACE FUNCTION public.gating_status_block_sensitive_writes()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF (auth.jwt() ->> 'role') = 'service_role' THEN RETURN NEW; END IF;
  IF current_setting('app.bypass_lockdown', true) = 'true' THEN RETURN NEW; END IF;
  IF auth.jwt() IS NULL THEN RETURN NEW; END IF;

  IF NEW.is_verified IS DISTINCT FROM OLD.is_verified
     OR NEW.is_entry_approved IS DISTINCT FROM OLD.is_entry_approved
  THEN
    RAISE EXCEPTION 'Cannot modify protected gating fields from client (M0 trust lockdown)';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_gating_status_block_sensitive_writes ON public.gating_status;
CREATE TRIGGER trg_gating_status_block_sensitive_writes
  BEFORE UPDATE ON public.gating_status
  FOR EACH ROW
  EXECUTE FUNCTION public.gating_status_block_sensitive_writes();

-- ── 7. Trust lockdown — trigger function for photo_verifications ────────────

CREATE OR REPLACE FUNCTION public.photo_verifications_block_status_writes()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF (auth.jwt() ->> 'role') = 'service_role' THEN RETURN NEW; END IF;
  IF current_setting('app.bypass_lockdown', true) = 'true' THEN RETURN NEW; END IF;
  IF auth.jwt() IS NULL THEN RETURN NEW; END IF;

  IF NEW.status IS DISTINCT FROM OLD.status
     OR NEW.decision IS DISTINCT FROM OLD.decision
     OR NEW.reviewed_by IS DISTINCT FROM OLD.reviewed_by
     OR NEW.reviewed_at IS DISTINCT FROM OLD.reviewed_at
     OR NEW.review_note IS DISTINCT FROM OLD.review_note
     OR NEW.ai_reason IS DISTINCT FROM OLD.ai_reason
  THEN
    RAISE EXCEPTION 'Cannot modify protected verification fields from client (M0 trust lockdown)';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_photo_verifications_block_status_writes ON public.photo_verifications;
CREATE TRIGGER trg_photo_verifications_block_status_writes
  BEFORE UPDATE ON public.photo_verifications
  FOR EACH ROW
  EXECUTE FUNCTION public.photo_verifications_block_status_writes();

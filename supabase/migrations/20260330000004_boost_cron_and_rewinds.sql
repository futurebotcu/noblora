-- Migration: boost expiry cron + decrement_rewinds RPC
-- Created: 2026-03-30

-- 1. decrement_rewinds RPC (mirrors decrement_super_likes)
CREATE OR REPLACE FUNCTION public.decrement_rewinds(uid uuid)
RETURNS void
LANGUAGE sql
AS $$
  UPDATE public.profiles
  SET rewinds_remaining = GREATEST(rewinds_remaining - 1, 0)
  WHERE id = uid;
$$;

-- 2. pg_cron: clear boost_active_until when it expires
-- Runs every 5 minutes; named so re-running is idempotent
SELECT cron.unschedule('expire-boosts');

SELECT cron.schedule(
  'expire-boosts',
  '*/5 * * * *',
  $$
    UPDATE public.profiles
    SET boost_active_until = NULL
    WHERE boost_active_until IS NOT NULL
      AND boost_active_until < NOW();
  $$
);

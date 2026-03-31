-- =============================================================================
-- Video Sessions: scheduling rebuild
-- Adds proposed_at, expires_at, must_complete_by, decline_reason, counter_proposed_at
-- Updates status check constraint
-- Schedules pg_cron job to expire stale sessions
-- =============================================================================

-- 1. Add missing columns
ALTER TABLE public.video_sessions
  ADD COLUMN IF NOT EXISTS proposed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS must_complete_by TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS decline_reason TEXT,
  ADD COLUMN IF NOT EXISTS counter_proposed_at TIMESTAMPTZ;

-- Backfill existing rows
UPDATE public.video_sessions
  SET
    expires_at      = proposed_at + INTERVAL '12 hours',
    must_complete_by = proposed_at + INTERVAL '24 hours'
  WHERE expires_at IS NULL;

-- Trigger to auto-fill expiry columns on INSERT
CREATE OR REPLACE FUNCTION public.set_video_session_expiry()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.expires_at IS NULL THEN
    NEW.expires_at := NEW.proposed_at + INTERVAL '12 hours';
  END IF;
  IF NEW.must_complete_by IS NULL THEN
    NEW.must_complete_by := NEW.proposed_at + INTERVAL '24 hours';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_video_session_expiry ON public.video_sessions;
CREATE TRIGGER trg_video_session_expiry
  BEFORE INSERT ON public.video_sessions
  FOR EACH ROW EXECUTE FUNCTION public.set_video_session_expiry();

-- 2. Fix status constraint — migrate data BEFORE adding constraint
UPDATE public.video_sessions
  SET status = 'pending'
  WHERE status NOT IN ('pending', 'counter_proposed', 'accepted', 'completed', 'expired', 'cancelled');

ALTER TABLE public.video_sessions
  DROP CONSTRAINT IF EXISTS video_sessions_status_check;

ALTER TABLE public.video_sessions
  ADD CONSTRAINT video_sessions_status_check
  CHECK (status IN ('pending', 'counter_proposed', 'accepted', 'completed', 'expired', 'cancelled'));

-- 3. Enable pg_cron
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 4. Cron job: every 15 min — expire sessions past 12h, delete their matches
SELECT cron.schedule(
  'expire-video-sessions',
  '*/15 * * * *',
  $$
    WITH expired AS (
      UPDATE public.video_sessions
        SET status = 'expired'
        WHERE status IN ('pending', 'counter_proposed')
          AND expires_at < NOW()
        RETURNING match_id
    )
    DELETE FROM public.matches
      WHERE id IN (SELECT match_id FROM expired);
  $$
);

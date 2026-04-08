-- ═══════════════════════════════════════════════════════════════════
-- P0 SECURITY + DATA INTEGRITY FIXES
-- ═══════════════════════════════════════════════════════════════════

-- B67: Notifications INSERT RLS — restrict to own user_id only
DROP POLICY IF EXISTS "notifications_insert" ON public.notifications;
CREATE POLICY "notifications_insert" ON public.notifications
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- B71: can_reach_user() must reject paused targets
CREATE OR REPLACE FUNCTION public.can_reach_user(
  p_sender_id UUID,
  p_target_id UUID,
  p_action_type TEXT DEFAULT 'reach'
) RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_target RECORD;
  v_sender RECORD;
  v_permission TEXT;
BEGIN
  SELECT is_paused, incognito_mode, calm_mode,
         reach_permission, signal_permission, note_permission,
         is_verified, is_onboarded, nob_tier
    INTO v_target
    FROM public.profiles WHERE id = p_target_id;

  IF v_target IS NULL THEN RETURN FALSE; END IF;

  -- Paused users cannot be reached
  IF v_target.is_paused THEN RETURN FALSE; END IF;

  -- Get the correct permission column
  v_permission := COALESCE(
    CASE p_action_type
      WHEN 'signal' THEN v_target.signal_permission
      WHEN 'note'   THEN v_target.note_permission
      ELSE               v_target.reach_permission
    END,
    'everyone'
  );

  IF v_permission = 'nobody' THEN RETURN FALSE; END IF;
  IF v_permission = 'everyone' THEN
    -- Calm mode: only verified + onboarded + explorer+ can reach
    IF v_target.calm_mode THEN
      SELECT is_verified, is_onboarded, nob_tier INTO v_sender
        FROM public.profiles WHERE id = p_sender_id;
      IF NOT (v_sender.is_verified AND v_sender.is_onboarded
              AND v_sender.nob_tier IN ('explorer', 'noble')) THEN
        RETURN FALSE;
      END IF;
    END IF;
    RETURN TRUE;
  END IF;

  -- Tier-based permissions
  SELECT is_verified, is_onboarded, nob_tier INTO v_sender
    FROM public.profiles WHERE id = p_sender_id;
  IF v_permission = 'verified' AND NOT v_sender.is_verified THEN RETURN FALSE; END IF;
  IF v_permission = 'explorer_plus' AND v_sender.nob_tier NOT IN ('explorer', 'noble') THEN RETURN FALSE; END IF;
  IF v_permission = 'noble_only' AND v_sender.nob_tier != 'noble' THEN RETURN FALSE; END IF;

  -- Calm mode second check for tier-based
  IF v_target.calm_mode THEN
    IF NOT (v_sender.is_verified AND v_sender.is_onboarded
            AND v_sender.nob_tier IN ('explorer', 'noble')) THEN
      RETURN FALSE;
    END IF;
  END IF;

  RETURN TRUE;
END;
$$;

-- B72: advanceToVideo() — add status check constraint
-- Ensure matches can only advance to pending_video FROM pending_intro
-- (RLS already restricts to participants; this adds state-machine guard)
CREATE OR REPLACE FUNCTION public.safe_advance_to_video(
  p_match_id UUID,
  p_user_id UUID
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.matches
     SET status = 'pending_video'
   WHERE id = p_match_id
     AND status = 'pending_intro'
     AND (user1_id = p_user_id OR user2_id = p_user_id);
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cannot advance: invalid match state or unauthorized';
  END IF;
END;
$$;

-- B44 (12h/24h deadline): Cron job to expire stale matches
-- Expire pending_intro matches older than 24h
-- Expire pending_video matches older than 24h
-- Expire video_scheduled sessions older than 12h
SELECT cron.schedule(
  'expire-stale-matches',
  '*/30 * * * *',
  $$
    UPDATE public.matches
       SET status = 'expired'
     WHERE status IN ('pending_intro', 'pending_video')
       AND created_at < NOW() - INTERVAL '24 hours';

    UPDATE public.video_sessions
       SET status = 'expired'
     WHERE status = 'pending'
       AND created_at < NOW() - INTERVAL '12 hours';
  $$
);

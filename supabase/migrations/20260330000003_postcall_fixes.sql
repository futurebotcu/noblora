-- =============================================================================
-- Post-call fixes:
--   1. Fix double-count bug in process_call_decision
--   2. Change chat window 5 days → 3 days
--   3. Cron job: expire chatting matches after 3 days of inactivity
-- =============================================================================

-- 1 & 2: Rewrite process_call_decision (fix double-count, 3-day window)
CREATE OR REPLACE FUNCTION public.process_call_decision(
  p_video_session_id UUID,
  p_user_id UUID,
  p_enjoyed BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_match     public.matches;
  v_session   public.video_sessions;
  v_conv_id   UUID;
  v_decisions INTEGER;
  v_yes_count INTEGER;
BEGIN
  -- Get session + match
  SELECT * INTO v_session FROM public.video_sessions WHERE id = p_video_session_id;
  SELECT * INTO v_match FROM public.matches WHERE id = v_session.match_id;

  -- The calling code has already upserted the row — count what's in the table now
  SELECT COUNT(*), COUNT(*) FILTER (WHERE enjoyed = TRUE)
  INTO v_decisions, v_yes_count
  FROM public.call_decisions
  WHERE video_session_id = p_video_session_id;

  -- Need exactly 2 rows (one per user) to proceed
  IF v_decisions < 2 THEN
    RETURN jsonb_build_object('result', 'waiting');
  END IF;

  -- Both decisions received
  IF v_yes_count = 2 THEN
    -- Both said yes → open chat (3-day window)
    INSERT INTO public.conversations (type, mode, expires_at)
    VALUES ('alliance', v_match.mode, NOW() + INTERVAL '3 days')
    RETURNING id INTO v_conv_id;

    INSERT INTO public.conversation_participants (conversation_id, user_id)
    VALUES (v_conv_id, v_match.user1_id), (v_conv_id, v_match.user2_id);

    UPDATE public.matches
    SET status = 'chatting',
        chat_expires_at = NOW() + INTERVAL '3 days',
        conversation_id = v_conv_id
    WHERE id = v_match.id;

    -- Notify both
    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES
      (v_match.user1_id, 'chat_opened', 'Chat is open!',
       'You both enjoyed the call. Start chatting — you have 3 days.',
       jsonb_build_object('match_id', v_match.id, 'conversation_id', v_conv_id)),
      (v_match.user2_id, 'chat_opened', 'Chat is open!',
       'You both enjoyed the call. Start chatting — you have 3 days.',
       jsonb_build_object('match_id', v_match.id, 'conversation_id', v_conv_id));

    RETURN jsonb_build_object('result', 'chat_opened', 'conversation_id', v_conv_id);

  ELSE
    -- At least one said no → close match
    UPDATE public.matches SET status = 'closed' WHERE id = v_match.id;

    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES
      (v_match.user1_id, 'connection_closed', 'Connection Ended',
       'This connection has come to a close. Keep exploring.',
       jsonb_build_object('match_id', v_match.id)),
      (v_match.user2_id, 'connection_closed', 'Connection Ended',
       'This connection has come to a close. Keep exploring.',
       jsonb_build_object('match_id', v_match.id));

    RETURN jsonb_build_object('result', 'closed');
  END IF;
END;
$$;

-- 3. Cron: expire chatting matches where chat_expires_at has passed
DO $$ BEGIN
  PERFORM cron.unschedule('expire-chatting-matches');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

SELECT cron.schedule(
  'expire-chatting-matches',
  '*/30 * * * *',
  $$
    UPDATE public.matches
    SET status = 'expired'
    WHERE status = 'chatting'
      AND chat_expires_at < NOW();
  $$
);

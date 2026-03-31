-- Add 'closed' status to matches (post-call: at least one user said no)
-- 'expired' = time limit missed, 'closed' = decided after call

ALTER TABLE public.matches
  DROP CONSTRAINT IF EXISTS matches_status_check;

ALTER TABLE public.matches
  ADD CONSTRAINT matches_status_check
  CHECK (status IN (
    'pending_video',
    'video_scheduled',
    'video_completed',
    'chatting',
    'meeting_scheduled',
    'expired',
    'closed'
  ));

-- Update process_call_decision:
--   • "at least one no" → status = 'closed' (not 'expired')
--   • Notify BOTH users when connection is closed
CREATE OR REPLACE FUNCTION public.process_call_decision(
  p_video_session_id UUID,
  p_user_id          UUID,
  p_enjoyed          BOOLEAN
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_match     public.matches;
  v_session   public.video_sessions;
  v_conv_id   UUID;
  v_decisions INTEGER;
  v_yes_count INTEGER;
BEGIN
  -- Get session + match
  SELECT * INTO v_session
  FROM public.video_sessions
  WHERE id = p_video_session_id;

  SELECT * INTO v_match FROM public.matches WHERE id = v_session.match_id;

  -- Count total decisions for this session (already includes the just-inserted row)
  SELECT COUNT(*), COUNT(*) FILTER (WHERE enjoyed = TRUE)
  INTO v_decisions, v_yes_count
  FROM public.call_decisions
  WHERE video_session_id = p_video_session_id;

  -- Add current decision (+1 because we just inserted before calling this)
  v_decisions := v_decisions + 1;
  IF p_enjoyed THEN v_yes_count := v_yes_count + 1; END IF;

  -- Both decisions received
  IF v_decisions >= 2 THEN
    IF v_yes_count = 2 THEN
      -- Both said yes → open chat
      INSERT INTO public.conversations (type, mode, expires_at)
      VALUES (
        'alliance',
        v_match.mode,
        NOW() + INTERVAL '5 days'
      )
      RETURNING id INTO v_conv_id;

      INSERT INTO public.conversation_participants (conversation_id, user_id)
      VALUES (v_conv_id, v_match.user1_id), (v_conv_id, v_match.user2_id);

      UPDATE public.matches
      SET status = 'chatting',
          chat_expires_at = NOW() + INTERVAL '5 days',
          conversation_id = v_conv_id
      WHERE id = v_match.id;

      -- Notify both
      INSERT INTO public.notifications (user_id, type, title, body, data)
      VALUES
        (v_match.user1_id, 'chat_opened', 'Chat is open!',
         'You both enjoyed the call. Start chatting — you have 5 days.',
         jsonb_build_object('match_id', v_match.id, 'conversation_id', v_conv_id)),
        (v_match.user2_id, 'chat_opened', 'Chat is open!',
         'You both enjoyed the call. Start chatting — you have 5 days.',
         jsonb_build_object('match_id', v_match.id, 'conversation_id', v_conv_id));

      RETURN jsonb_build_object('result', 'chat_opened', 'conversation_id', v_conv_id);
    ELSE
      -- At least one said no → close match
      UPDATE public.matches SET status = 'closed' WHERE id = v_match.id;

      -- Notify both users the connection ended
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
  END IF;

  RETURN jsonb_build_object('result', 'waiting');
END;
$$;

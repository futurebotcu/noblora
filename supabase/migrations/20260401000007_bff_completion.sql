-- =============================================================================
-- BFF COMPLETION: Direct connect from reach out, plan check-in support
-- =============================================================================

-- ═══════════════════════════════════════════════════════════════════
-- 1. RPC: Accept reach out → create BFF match + chat
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.accept_reach_out(p_reach_out_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_ro   public.reach_outs;
  v_conv UUID;
BEGIN
  SELECT * INTO v_ro FROM public.reach_outs WHERE id = p_reach_out_id;
  IF v_ro IS NULL THEN RETURN jsonb_build_object('error', 'not_found'); END IF;
  IF v_ro.status != 'pending' THEN RETURN jsonb_build_object('error', 'already_resolved'); END IF;

  -- Only receiver can accept
  IF auth.uid() != v_ro.receiver_id THEN RETURN jsonb_build_object('error', 'unauthorized'); END IF;

  -- Create conversation
  INSERT INTO public.conversations (type, mode) VALUES ('alliance', 'bff') RETURNING id INTO v_conv;
  INSERT INTO public.conversation_participants (conversation_id, user_id)
  VALUES (v_conv, v_ro.sender_id), (v_conv, v_ro.receiver_id);

  -- Create match
  INSERT INTO public.matches (user1_id, user2_id, mode, status, conversation_id)
  VALUES (v_ro.sender_id, v_ro.receiver_id, 'bff', 'chatting', v_conv);

  -- Update reach out status
  UPDATE public.reach_outs SET status = 'connected' WHERE id = p_reach_out_id;

  -- Notify sender
  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (v_ro.sender_id, 'bff_connected', 'Someone connected!',
    'Your reach out was accepted. Start chatting!',
    jsonb_build_object('conversation_id', v_conv));

  RETURN jsonb_build_object('result', 'connected', 'conversation_id', v_conv);
END;
$$;

-- ═══════════════════════════════════════════════════════════════════
-- 2. BFF_PLANS: Add check-in support
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE public.bff_plans
  ADD COLUMN IF NOT EXISTS checkin_response TEXT;

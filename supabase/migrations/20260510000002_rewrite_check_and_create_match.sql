-- R11 PR-2: Rewrite check_and_create_match for Bumble first-message gate
--
-- Eski akış: match yaratılır → status='pending_intro' → process_call_decision
-- → conversation INSERT (video_completed sonrası).
-- Yeni akış: match yaratılır → conversation + participants INSERT önce →
-- status='pending_first_message' + conversation_id set. M3 trigger'ı ilk
-- user mesajında 'chatting'e flip eder.
--
-- Eski 24h video_deadline_at semantik genişletildi: artık first-message
-- deadline. expire-stale-matches cron (M1) bu kolon yerine matched_at
-- kullanıyor (semantic clarity).

CREATE OR REPLACE FUNCTION public.check_and_create_match(p_swiper uuid, p_target uuid, p_mode text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_mutual  BOOLEAN;
  v_match   public.matches;
  v_conv_id UUID;
  v_user1   UUID;
  v_user2   UUID;
BEGIN
  -- Mutual swipe check
  SELECT EXISTS (
    SELECT 1 FROM public.swipes
    WHERE swiper_id = p_target
      AND swiped_id = p_swiper
      AND direction IN ('right', 'super')
      AND mode = p_mode
  ) INTO v_mutual;

  IF NOT v_mutual THEN
    RETURN NULL;
  END IF;

  -- No existing active match
  IF EXISTS (
    SELECT 1 FROM public.matches
    WHERE ((user1_id = p_swiper AND user2_id = p_target) OR
           (user1_id = p_target AND user2_id = p_swiper))
      AND mode = p_mode
      AND status NOT IN ('expired', 'closed')
  ) THEN
    RETURN NULL;
  END IF;

  -- Determine ordered ids (matches_ordered CHECK: user1_id < user2_id)
  IF p_swiper < p_target THEN
    v_user1 := p_swiper;
    v_user2 := p_target;
  ELSE
    v_user1 := p_target;
    v_user2 := p_swiper;
  END IF;

  -- Conversation önce (Bumble pattern: chat hazır ama gate'li)
  INSERT INTO public.conversations (type, mode)
  VALUES ('alliance', p_mode)
  RETURNING id INTO v_conv_id;

  INSERT INTO public.conversation_participants (conversation_id, user_id)
  VALUES (v_conv_id, v_user1), (v_conv_id, v_user2);

  -- Match: pending_first_message + conversation_id set + 24h deadline
  INSERT INTO public.matches (user1_id, user2_id, mode, status, video_deadline_at, conversation_id)
  VALUES (v_user1, v_user2, p_mode, 'pending_first_message', NOW() + INTERVAL '24 hours', v_conv_id)
  RETURNING * INTO v_match;

  -- Notify both users
  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES
    (v_user1, 'new_match', 'New Connection!',
     'Send the first message to start chatting.',
     jsonb_build_object('match_id', v_match.id, 'conversation_id', v_conv_id)),
    (v_user2, 'new_match', 'New Connection!',
     'Send the first message to start chatting.',
     jsonb_build_object('match_id', v_match.id, 'conversation_id', v_conv_id));

  RETURN to_jsonb(v_match);
END;
$function$;

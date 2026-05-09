-- R11 PR-3: First-message trigger (state machine flip)
--
-- Bumble first-message gate: ilk user mesajında matches.status
-- 'pending_first_message' → 'chatting'.
--
-- AFTER INSERT trigger; messages.is_system=true mesajlar atlanır
-- (sistem mesajları "Match made" gibi); WHERE clause ile no-op
-- idempotent (status zaten 'chatting' veya başka bir state ise UPDATE
-- bulamaz, hata atmaz).

CREATE OR REPLACE FUNCTION public.first_message_advance_match()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.is_system THEN
    RETURN NEW;
  END IF;

  UPDATE public.matches
     SET status = 'chatting'
   WHERE conversation_id = NEW.conversation_id
     AND status = 'pending_first_message';

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_first_message_advance_match ON public.messages;
CREATE TRIGGER trg_first_message_advance_match
AFTER INSERT ON public.messages
FOR EACH ROW
EXECUTE FUNCTION public.first_message_advance_match();

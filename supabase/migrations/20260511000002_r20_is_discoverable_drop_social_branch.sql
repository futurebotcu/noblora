-- R20 -- is_discoverable() referenced v_target.social_visible, a column
-- that never existed on profiles. PL/pgSQL resolves rowtype field access
-- at function-evaluation time regardless of branch reachability, so every
-- filter_discoverable_ids() call raised:
--   ERROR 42703: record "v_target" has no field "social_visible"
-- This silently 400'd every Discover load in V1 (feed_repository.dart
-- step 1.5). Symptom: "Could not load profiles / Retry" on the main
-- surface. Root-cause confirmed by direct RPC call as fatihkartal75.
--
-- Fix: drop the 'social' branch. V1 only ships 'date' mode; the 'bff'
-- branch stays because bff_visible column still exists (deferred V1.x
-- schema cleanup) and the branch is unreachable from V1 client code
-- anyway (BFF removed in R18). No behavior change for date-mode
-- discovery.
CREATE OR REPLACE FUNCTION public.is_discoverable(p_target_id uuid, p_mode text, p_requester_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_target public.profiles;
BEGIN
  SELECT * INTO v_target FROM public.profiles WHERE id = p_target_id;
  IF v_target IS NULL THEN RETURN FALSE; END IF;

  -- Paused users are never discoverable
  IF v_target.is_paused THEN RETURN FALSE; END IF;

  -- Mode-specific visibility
  IF p_mode = 'date' AND NOT v_target.dating_visible THEN RETURN FALSE; END IF;
  IF p_mode = 'bff' AND NOT v_target.bff_visible THEN RETURN FALSE; END IF;
  -- R20 -- 'social' branch removed; social_visible column never existed.

  -- Incognito: only visible to existing connections
  IF v_target.incognito_mode THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.matches m
      WHERE ((m.user1_id = p_target_id AND m.user2_id = p_requester_id)
          OR (m.user1_id = p_requester_id AND m.user2_id = p_target_id))
        AND m.status NOT IN ('expired', 'closed')
    ) THEN
      RETURN FALSE;
    END IF;
  END IF;

  RETURN TRUE;
END;
$function$;

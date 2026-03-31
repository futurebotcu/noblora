-- =============================================================================
-- SETTINGS COMPLETION: Missing columns + backend enforcement for privacy/modes
-- =============================================================================

-- ═══════════════════════════════════════════════════════════════════
-- 1. Missing profile columns for chats & AI preferences
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS auto_save_media       BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS call_reminders        BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS language              TEXT NOT NULL DEFAULT 'en',
  ADD COLUMN IF NOT EXISTS blocked_users         UUID[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS hidden_users          UUID[] DEFAULT '{}';

-- ═══════════════════════════════════════════════════════════════════
-- 2. FEED QUERY: Enforce mode active/visible + incognito + paused
-- Update the feed to respect visibility settings
-- ═══════════════════════════════════════════════════════════════════

-- This RPC replaces direct profile queries for discovery.
-- It enforces: is_paused, mode_visible, incognito_mode
CREATE OR REPLACE FUNCTION public.is_discoverable(
  p_target_id UUID,
  p_mode TEXT,
  p_requester_id UUID
)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER AS $$
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
  IF p_mode = 'social' AND NOT v_target.social_visible THEN RETURN FALSE; END IF;

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
$$;

-- ═══════════════════════════════════════════════════════════════════
-- 3. REACH PERMISSION: Check before signal/note/reach out
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.can_reach_user(
  p_sender_id UUID,
  p_target_id UUID,
  p_action TEXT  -- 'reach' | 'signal' | 'note'
)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_target public.profiles;
  v_sender public.profiles;
  v_perm TEXT;
BEGIN
  SELECT * INTO v_target FROM public.profiles WHERE id = p_target_id;
  SELECT * INTO v_sender FROM public.profiles WHERE id = p_sender_id;
  IF v_target IS NULL OR v_sender IS NULL THEN RETURN FALSE; END IF;

  -- Get the relevant permission
  v_perm := CASE p_action
    WHEN 'signal' THEN COALESCE(v_target.signal_permission, 'everyone')
    WHEN 'note' THEN COALESCE(v_target.note_permission, 'everyone')
    ELSE COALESCE(v_target.reach_permission, 'everyone')
  END;

  -- Check permission level
  IF v_perm = 'nobody' THEN RETURN FALSE; END IF;
  IF v_perm = 'everyone' THEN RETURN TRUE; END IF;
  IF v_perm = 'verified' AND v_sender.is_verified THEN RETURN TRUE; END IF;
  IF v_perm = 'explorer_plus' AND v_sender.nob_tier IN ('explorer', 'noble') THEN RETURN TRUE; END IF;
  IF v_perm = 'noble_only' AND v_sender.nob_tier = 'noble' THEN RETURN TRUE; END IF;

  -- Calm mode: only verified + complete + explorer+
  IF v_target.calm_mode THEN
    IF NOT (v_sender.is_verified AND v_sender.is_onboarded AND v_sender.nob_tier IN ('explorer', 'noble')) THEN
      RETURN FALSE;
    END IF;
  END IF;

  -- Default: if permission is unrecognized, allow
  RETURN v_perm = 'everyone';
END;
$$;

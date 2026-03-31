-- =============================================================================
-- NOB FEED HARDENING: tone tags, pass filtering, note limits, quality trigger
-- =============================================================================

-- ═══════════════════════════════════════════════════════════════════
-- 1. POSTS: Add tone tag for feed filtering
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS tone TEXT;

-- ═══════════════════════════════════════════════════════════════════
-- 2. RPC: Fetch Nob feed with filters
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fetch_nob_feed(
  p_user_id UUID,
  p_type TEXT DEFAULT NULL,          -- 'thought' | 'moment' | NULL = all
  p_sort TEXT DEFAULT 'newest',      -- 'newest' | 'trending' | 'ai_pick'
  p_tone TEXT DEFAULT NULL,          -- 'reflective' | 'grounded' | 'curious' | 'creative' | NULL
  p_hide_passed BOOLEAN DEFAULT FALSE,
  p_prioritize_connected BOOLEAN DEFAULT FALSE,
  p_limit INT DEFAULT 50
)
RETURNS SETOF public.posts LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT p.*
  FROM public.posts p
  WHERE p.is_draft = FALSE
    AND p.is_archived = FALSE
    -- type filter
    AND (p_type IS NULL OR p.nob_type = p_type)
    -- tone filter
    AND (p_tone IS NULL OR p.tone = p_tone)
    -- hide passed content
    AND (
      NOT p_hide_passed
      OR NOT EXISTS (
        SELECT 1 FROM public.post_reactions pr
        WHERE pr.post_id = p.id AND pr.user_id = p_user_id AND pr.reaction_type = 'pass'
      )
    )
  ORDER BY
    -- pinned first
    p.is_pinned DESC,
    -- connected users priority
    CASE WHEN p_prioritize_connected AND EXISTS (
      SELECT 1 FROM public.matches m
      WHERE ((m.user1_id = p_user_id AND m.user2_id = p.user_id)
          OR (m.user1_id = p.user_id AND m.user2_id = p_user_id))
        AND m.status NOT IN ('expired', 'closed')
    ) THEN 0 ELSE 1 END,
    -- sort mode
    CASE p_sort
      WHEN 'trending' THEN (
        SELECT COUNT(*) FROM public.post_reactions pr
        WHERE pr.post_id = p.id AND pr.reaction_type IN ('appreciate', 'support')
      )
      ELSE 0
    END DESC,
    CASE p_sort
      WHEN 'ai_pick' THEN p.quality_score
      ELSE 0
    END DESC,
    p.published_at DESC
  LIMIT p_limit;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════
-- 3. RPC: Get reaction counts for author's own post
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.get_own_reaction_counts(p_post_id UUID, p_author_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_counts JSONB;
BEGIN
  -- Only the author can see counts
  IF NOT EXISTS (SELECT 1 FROM public.posts WHERE id = p_post_id AND user_id = p_author_id) THEN
    RETURN '{}'::jsonb;
  END IF;

  SELECT jsonb_build_object(
    'appreciate', COUNT(*) FILTER (WHERE reaction_type = 'appreciate'),
    'support', COUNT(*) FILTER (WHERE reaction_type = 'support'),
    'pass', COUNT(*) FILTER (WHERE reaction_type = 'pass'),
    'total', COUNT(*)
  ) INTO v_counts
  FROM public.post_reactions
  WHERE post_id = p_post_id;

  RETURN COALESCE(v_counts, '{}'::jsonb);
END;
$$;

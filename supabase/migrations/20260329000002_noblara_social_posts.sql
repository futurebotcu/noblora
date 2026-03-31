-- =============================================================================
-- Noblara Social Posts
-- =============================================================================

-- 1. Add is_noble flag to profiles
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_noble BOOLEAN NOT NULL DEFAULT FALSE;

-- 2. posts table
CREATE TABLE public.posts (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  content     TEXT NOT NULL CHECK (char_length(content) <= 150),
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

-- Everyone can read posts
CREATE POLICY "posts_select" ON public.posts
  FOR SELECT TO authenticated USING (true);

-- Only nobles can insert
CREATE POLICY "posts_insert" ON public.posts
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE user_id = auth.uid() AND is_noble = TRUE
    )
  );

-- Authors can update/delete their own posts
CREATE POLICY "posts_update" ON public.posts
  FOR UPDATE TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "posts_delete" ON public.posts
  FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- Ensure set_updated_at helper exists
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$;

-- updated_at trigger
CREATE TRIGGER posts_updated_at
  BEFORE UPDATE ON public.posts
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- 3. post_reactions table
CREATE TABLE public.post_reactions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id       UUID REFERENCES public.posts(id) ON DELETE CASCADE NOT NULL,
  user_id       UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  reaction_type TEXT NOT NULL CHECK (reaction_type IN ('like', 'support', 'dislike')),
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(post_id, user_id)
);

ALTER TABLE public.post_reactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "reactions_select" ON public.post_reactions
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "reactions_insert" ON public.post_reactions
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

CREATE POLICY "reactions_delete" ON public.post_reactions
  FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- 4. Indexes
CREATE INDEX posts_user_idx       ON public.posts(user_id);
CREATE INDEX posts_created_idx    ON public.posts(created_at DESC);
CREATE INDEX reactions_post_idx   ON public.post_reactions(post_id);
CREATE INDEX reactions_user_idx   ON public.post_reactions(user_id);

-- 5. Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.posts;
ALTER PUBLICATION supabase_realtime ADD TABLE public.post_reactions;

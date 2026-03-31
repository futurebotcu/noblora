-- =============================================================================
-- Noblara Social Posts
-- =============================================================================

-- 1. Add is_noble flag to profiles
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_noble BOOLEAN NOT NULL DEFAULT FALSE;

-- 2. posts table
CREATE TABLE IF NOT EXISTS public.posts (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  content     TEXT NOT NULL CHECK (char_length(content) <= 150),
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

-- Everyone can read posts
DO $$ BEGIN
  CREATE POLICY "posts_select" ON public.posts
    FOR SELECT TO authenticated USING (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Only nobles can insert
DO $$ BEGIN
  CREATE POLICY "posts_insert" ON public.posts
    FOR INSERT TO authenticated
    WITH CHECK (
      EXISTS (
        SELECT 1 FROM public.profiles
        WHERE user_id = auth.uid() AND is_noble = TRUE
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Authors can update/delete their own posts
DO $$ BEGIN
  CREATE POLICY "posts_update" ON public.posts
    FOR UPDATE TO authenticated USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "posts_delete" ON public.posts
    FOR DELETE TO authenticated USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Ensure set_updated_at helper exists
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$;

-- updated_at trigger
DROP TRIGGER IF EXISTS posts_updated_at ON public.posts;
CREATE TRIGGER posts_updated_at
  BEFORE UPDATE ON public.posts
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- 3. post_reactions table
CREATE TABLE IF NOT EXISTS public.post_reactions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id       UUID REFERENCES public.posts(id) ON DELETE CASCADE NOT NULL,
  user_id       UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  reaction_type TEXT NOT NULL CHECK (reaction_type IN ('like', 'support', 'dislike')),
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(post_id, user_id)
);

ALTER TABLE public.post_reactions ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "reactions_select" ON public.post_reactions
    FOR SELECT TO authenticated USING (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "reactions_insert" ON public.post_reactions
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "reactions_delete" ON public.post_reactions
    FOR DELETE TO authenticated USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 4. Indexes
CREATE INDEX IF NOT EXISTS posts_user_idx       ON public.posts(user_id);
CREATE INDEX IF NOT EXISTS posts_created_idx    ON public.posts(created_at DESC);
CREATE INDEX IF NOT EXISTS reactions_post_idx   ON public.post_reactions(post_id);
CREATE INDEX IF NOT EXISTS reactions_user_idx   ON public.post_reactions(user_id);

-- 5. Realtime
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'posts') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.posts;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'post_reactions') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.post_reactions;
  END IF;
END $$;

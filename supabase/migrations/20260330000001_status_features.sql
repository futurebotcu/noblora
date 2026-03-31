-- =============================================================================
-- Status Features: profile stats, super likes, boost, rewind
-- =============================================================================

-- profiles columns
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS profile_views INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS super_likes_remaining INT NOT NULL DEFAULT 3,
  ADD COLUMN IF NOT EXISTS rewinds_remaining INT NOT NULL DEFAULT 3,
  ADD COLUMN IF NOT EXISTS boosts_remaining INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS boost_active_until TIMESTAMPTZ;

-- super_likes table
CREATE TABLE IF NOT EXISTS public.super_likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  receiver_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(sender_id, receiver_id)
);

ALTER TABLE public.super_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "super_likes_select" ON public.super_likes
  FOR SELECT TO authenticated
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "super_likes_insert" ON public.super_likes
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "super_likes_delete" ON public.super_likes
  FOR DELETE TO authenticated USING (auth.uid() = sender_id);

CREATE INDEX IF NOT EXISTS super_likes_sender_idx ON public.super_likes(sender_id);
CREATE INDEX IF NOT EXISTS super_likes_receiver_idx ON public.super_likes(receiver_id);

-- RPC helpers
CREATE OR REPLACE FUNCTION public.increment_profile_views(uid UUID)
RETURNS void LANGUAGE sql AS $$
  UPDATE public.profiles SET profile_views = profile_views + 1 WHERE id = uid;
$$;

CREATE OR REPLACE FUNCTION public.decrement_super_likes(uid UUID)
RETURNS void LANGUAGE sql AS $$
  UPDATE public.profiles
  SET super_likes_remaining = GREATEST(super_likes_remaining - 1, 0)
  WHERE id = uid;
$$;

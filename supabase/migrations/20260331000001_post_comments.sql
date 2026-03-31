-- Migration: post_comments table + notification_preferences + is_admin
-- Created: 2026-03-31

-- 1. Comments on Noblara posts
CREATE TABLE IF NOT EXISTS public.post_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  content text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT NOW(),
  CONSTRAINT content_length CHECK (char_length(content) BETWEEN 1 AND 300),
  CONSTRAINT content_ascii CHECK (content ~ '[\\x20-\\x7E\\n\\r\\t]+')
);

ALTER TABLE public.post_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "view_comments" ON public.post_comments FOR SELECT USING (true);
CREATE POLICY "insert_own_comment" ON public.post_comments FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "delete_own_comment" ON public.post_comments FOR DELETE USING (auth.uid() = user_id);

ALTER PUBLICATION supabase_realtime ADD TABLE public.post_comments;

-- 2. Notification preferences jsonb column
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS notification_preferences jsonb NOT NULL DEFAULT
  '{"new_match": true, "new_message": true, "video_proposed": true, "video_confirmed": true, "post_comment": true}';

-- 3. Admin flag
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS is_admin boolean NOT NULL DEFAULT false;

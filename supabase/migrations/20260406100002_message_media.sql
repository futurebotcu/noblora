-- Add media support to messages (photo messages)
ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS media_url  TEXT,
  ADD COLUMN IF NOT EXISTS media_type TEXT CHECK (media_type IN ('image', 'voice'));

-- Relax the content CHECK: allow empty content when media is present
-- Drop old check and add new one
ALTER TABLE public.messages DROP CONSTRAINT IF EXISTS messages_content_check;
ALTER TABLE public.messages
  ADD CONSTRAINT messages_content_check
    CHECK (char_length(content) > 0 OR media_url IS NOT NULL);

-- Storage bucket for chat media (run via Supabase dashboard or CLI)
-- INSERT INTO storage.buckets (id, name, public) VALUES ('chat-media', 'chat-media', true)
-- ON CONFLICT DO NOTHING;

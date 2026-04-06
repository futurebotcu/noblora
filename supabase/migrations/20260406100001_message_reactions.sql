-- Message reactions: emoji reactions on chat messages
CREATE TABLE IF NOT EXISTS public.message_reactions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id      UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  emoji           TEXT NOT NULL CHECK (char_length(emoji) BETWEEN 1 AND 8),
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (message_id, user_id, emoji)
);

-- Index for fast lookup by message
CREATE INDEX IF NOT EXISTS idx_message_reactions_message
  ON public.message_reactions (message_id);

-- RLS
ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read reactions in their conversations"
  ON public.message_reactions FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.messages m
      JOIN public.conversation_participants cp
        ON cp.conversation_id = m.conversation_id
      WHERE m.id = message_reactions.message_id
        AND cp.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert their own reactions"
  ON public.message_reactions FOR INSERT WITH CHECK (
    user_id = auth.uid()
  );

CREATE POLICY "Users can delete their own reactions"
  ON public.message_reactions FOR DELETE USING (
    user_id = auth.uid()
  );

-- Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.message_reactions;

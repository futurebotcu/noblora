-- Migration: Add read receipt columns to messages table
-- Why: Chat UI needs delivered/read indicators for outgoing messages.
--      The ChatMessage model already expects these fields but they didn't exist in DB.
-- Impact: Enables sent → delivered → read status on chat bubbles.

ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ;

-- Index for efficient "mark undelivered as delivered" queries
CREATE INDEX IF NOT EXISTS idx_messages_delivered
  ON public.messages (conversation_id, sender_id)
  WHERE delivered_at IS NULL;

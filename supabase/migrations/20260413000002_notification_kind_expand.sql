-- Expand noblara_notifications kind CHECK to include Second Thought and Future Nob types.
ALTER TABLE public.noblara_notifications DROP CONSTRAINT noblara_notifications_kind_check;
ALTER TABLE public.noblara_notifications ADD CONSTRAINT noblara_notifications_kind_check
  CHECK (kind = ANY (ARRAY['reply','reaction','echo','second_thought','future_nob_due']));

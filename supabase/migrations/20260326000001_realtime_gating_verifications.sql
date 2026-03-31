-- Migration: Enable Realtime for gating_status and photo_verifications
-- Required for live admin-approval → app auto-navigate flow.
-- Run in Supabase Dashboard → SQL Editor.

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'gating_status') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.gating_status;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'photo_verifications') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.photo_verifications;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'profiles') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
  END IF;
END $$;

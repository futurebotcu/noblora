-- Migration: Enable Realtime for gating_status and photo_verifications
-- Required for live admin-approval → app auto-navigate flow.
-- Run in Supabase Dashboard → SQL Editor.

ALTER PUBLICATION supabase_realtime ADD TABLE public.gating_status;
ALTER PUBLICATION supabase_realtime ADD TABLE public.photo_verifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;

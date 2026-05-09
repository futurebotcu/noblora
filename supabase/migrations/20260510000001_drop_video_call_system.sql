-- R11 PR-1: Drop video call system + rebuild matches state machine
--
-- Bumble first-message gate'e geçiş. R10 Flutter söküm sonrası backend
-- cleanup. Eski state machine: 'pending_intro' → 'pending_video' → ...
-- Yeni state machine: 'pending_first_message' → 'chatting' → ...
--
-- Pre-check (R7 kanıt): SELECT status, count(*) FROM matches WHERE status
-- IN ('pending_intro','pending_video','video_scheduled','video_completed')
-- GROUP BY status; → 0 row (test ortamı, prod'da match data yok)
--
-- Bağımlılık:
--   M2: rewrite_check_and_create_match (yeni state + conversation_id set)
--   M3: first_message_trigger (state machine flip)
-- Bu migration M2 ve M3'ten önce uygulanmalı.

-- 1. Eski video state matches'leri 'expired'a çevir (defansif, pre-check 0 olsa bile)
UPDATE public.matches
   SET status = 'expired'
 WHERE status IN ('pending_intro', 'pending_video', 'video_scheduled', 'video_completed');

-- 2. matches.status CHECK constraint rebuild (8 değer → 5 değer)
ALTER TABLE public.matches DROP CONSTRAINT matches_status_check;
ALTER TABLE public.matches ADD CONSTRAINT matches_status_check
  CHECK (status IN ('pending_first_message', 'chatting', 'meeting_scheduled', 'expired', 'closed'));
ALTER TABLE public.matches ALTER COLUMN status SET DEFAULT 'pending_first_message';

-- 3. Video function'ları DROP (Advisor finding'leri: SECDEF + search_path)
DROP FUNCTION IF EXISTS public.process_call_decision(uuid, uuid, boolean);
DROP FUNCTION IF EXISTS public.safe_advance_to_video(uuid, uuid);

-- 4. Video tabloları DROP CASCADE (Advisor finding: video_sessions.video_update_own RLS always_true)
DROP TABLE IF EXISTS public.call_decisions CASCADE;
DROP TABLE IF EXISTS public.video_sessions CASCADE;
DROP TABLE IF EXISTS public.mini_intros CASCADE;

-- 5. Cron jobs: expire-video-sessions DROP, expire-stale-matches REWRITE
SELECT cron.unschedule('expire-video-sessions');
SELECT cron.unschedule('expire-stale-matches');
SELECT cron.schedule('expire-stale-matches', '*/30 * * * *', $$
  UPDATE public.matches
     SET status = 'expired'
   WHERE status = 'pending_first_message'
     AND matched_at < NOW() - INTERVAL '24 hours';
$$);

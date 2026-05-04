-- Dalga 13: Events feature complete removal
-- - Tablolar: events, event_participants, event_messages, event_checkins (CASCADE)
-- - RPC'ler: join_event, leave_event, submit_event_checkin
-- - profiles kolonları: leave_event_chat_auto, social_active, social_visible,
--                       social_bio, social_avatar_url
-- - active_modes array'inden 'social' temizle
-- - notifications type='event_farewell' temizle
-- KORUNUR: feed_events tablosu, feed_event_*_trg/feed_event_*() (feed activity log)
-- KORUNUR: profiles.social_energy, social_interests (personality traits, Events özel değil)

-- 1) RPC'ler
DROP FUNCTION IF EXISTS public.join_event(uuid, integer);
DROP FUNCTION IF EXISTS public.leave_event(uuid);
DROP FUNCTION IF EXISTS public.submit_event_checkin(uuid, boolean, boolean, boolean);

-- 2) Notifications event_farewell temizle (push history)
DELETE FROM public.notifications WHERE type = 'event_farewell';

-- 3) active_modes array'inden 'social' çıkar
UPDATE public.profiles
SET active_modes = array_remove(active_modes, 'social')
WHERE 'social' = ANY(active_modes);

-- 4) profiles kolonları (Events özel)
ALTER TABLE public.profiles DROP COLUMN IF EXISTS leave_event_chat_auto;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS social_active;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS social_visible;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS social_bio;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS social_avatar_url;

-- 5) Tablolar (FK CASCADE — children: event_participants, event_messages, event_checkins)
DROP TABLE IF EXISTS public.event_messages CASCADE;
DROP TABLE IF EXISTS public.event_checkins CASCADE;
DROP TABLE IF EXISTS public.event_participants CASCADE;
DROP TABLE IF EXISTS public.events CASCADE;

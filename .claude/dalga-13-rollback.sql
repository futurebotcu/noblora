-- Dalga 13 ROLLBACK — Events feature recreate (acil durum)
-- NOT: Tablolar/RPC'ler/policies eski state'ten yeniden yazılmalı.
-- Bu dosya skeleton — gerçek rollback için 20260401000002_social_events.sql
-- ve 20260401000008_social_finish.sql migration'larını re-apply gerekir.

-- 1) profiles kolonları geri ekle (default'larla)
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS leave_event_chat_auto boolean DEFAULT true;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS social_active boolean DEFAULT true;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS social_visible boolean DEFAULT true;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS social_bio text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS social_avatar_url text;

-- 2) Tablolar — original migration'ları re-apply et:
--    psql -f supabase/migrations/20260401000002_social_events.sql
--    psql -f supabase/migrations/20260401000008_social_finish.sql
-- (Tablo, RLS policy, RPC ve trigger'lar bu iki migration'da yeniden kurulur.)

-- VERİ KAYBI UYARISI:
-- - DROP edilen veri: 1 events satır + 1 event_participants satır + 1 event_farewell notif
-- - active_modes 'social' değeri kullanıcılarda silindi (geri eklenmez, manuel UPDATE gerekir)

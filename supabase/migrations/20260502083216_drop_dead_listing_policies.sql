-- Dalga 9: public_bucket_allows_listing fix
--
-- Advisor BEFORE: 117 (2 lint public_bucket_allows_listing)
-- Hedef: 115 (-2)
--
-- Strateji: Dead SELECT policy'leri DROP
-- - "anyone can read gallery photos" (galleries bucket)
-- - "authenticated users can read profile photos" (profile-photos bucket)
--
-- Frontend kullanimi: 0 (.list()/.download() grep sonuc 0)
--   - getPublicUrl CDN-level, RLS bypass eder, etkilenmez
--   - uploadBinary INSERT policy ayri ("users can upload own ..."), korunur
--   - remove DELETE policy ayri ("users can delete own ..."), korunur
--   - StorageRepository sadece uploadBinary + getPublicUrl + remove kullanir
--
-- Davranis degisikligi: SIFIR (R5b benzeri cosmetic dead policy cleanup)
--
-- R10 dersi: apply sonrasi pg_policies SQL dogrulama sart
--   SELECT policyname FROM pg_policies WHERE schemaname='storage'
--     AND tablename='objects' AND policyname IN (...) -> 0 satir bekleniyor
--
-- Rollback: .claude/dalga-9-rollback.sql (2 CREATE POLICY)

DROP POLICY IF EXISTS "anyone can read gallery photos"
  ON storage.objects;

DROP POLICY IF EXISTS "authenticated users can read profile photos"
  ON storage.objects;

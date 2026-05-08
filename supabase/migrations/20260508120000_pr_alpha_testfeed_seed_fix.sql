-- =================================================================
-- PR-α: R12+R13 birleşik testfeed seed fix
--
-- R12: auth.users 13 string kolonu COALESCE (NULL → '')
-- R13: testfeed* missing photo_verifications.approved (selfie + profile)
--
-- Idempotent: NULL satırlar için no-op, healthy rows etkilenmez.
-- Production safe: sign-up flow zaten doğru dolduruyor.
-- =================================================================

-- R12 PART 1: 12 string kolonu COALESCE (phone hariç — UNIQUE)
UPDATE auth.users SET
  aud = COALESCE(aud, ''),
  role = COALESCE(role, ''),
  email = COALESCE(email, ''),
  encrypted_password = COALESCE(encrypted_password, ''),
  confirmation_token = COALESCE(confirmation_token, ''),
  recovery_token = COALESCE(recovery_token, ''),
  email_change_token_new = COALESCE(email_change_token_new, ''),
  email_change_token_current = COALESCE(email_change_token_current, ''),
  email_change = COALESCE(email_change, ''),
  phone_change = COALESCE(phone_change, ''),
  phone_change_token = COALESCE(phone_change_token, ''),
  reauthentication_token = COALESCE(reauthentication_token, '')
WHERE
  aud IS NULL OR role IS NULL OR email IS NULL OR encrypted_password IS NULL
  OR confirmation_token IS NULL OR recovery_token IS NULL
  OR email_change_token_new IS NULL OR email_change_token_current IS NULL
  OR email_change IS NULL OR phone_change IS NULL
  OR phone_change_token IS NULL OR reauthentication_token IS NULL;

-- R12 PART 2: phone unique placeholder (UNIQUE INDEX users_phone_key)
UPDATE auth.users
SET phone = '+placeholder_' || id::text
WHERE phone IS NULL;

-- R13: testfeed* photo_verifications.approved (selfie + profile çifti)
-- Schema-correct: status='approved' (no is_approved column), minimal AI fields
INSERT INTO photo_verifications (
  user_id, photo_type, photo_url, status, created_at
)
SELECT
  u.id,
  pt.photo_type,
  'placeholder://testfeed-seed',
  'approved',
  now()
FROM auth.users u
CROSS JOIN (VALUES ('selfie'), ('profile')) AS pt(photo_type)
WHERE u.email LIKE 'testfeed%@test.noblara.com'
  AND NOT EXISTS (
    SELECT 1 FROM photo_verifications pv
    WHERE pv.user_id = u.id
      AND pv.photo_type = pt.photo_type
      AND pv.status = 'approved'
  );

-- Verification queries (manuel run sonrası):
-- 1. R12 NULL: tüm 13 kolon 0 olmalı
-- 2. R13 coverage: 35 user × 2 photo = 70 approved row
-- 3. R12 phone unique: SELECT phone, COUNT(*) FROM auth.users WHERE phone LIKE '+placeholder_%' GROUP BY phone HAVING COUNT(*)>1 → 0 row

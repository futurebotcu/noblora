-- Migration: Add claimed_gender to photo_verifications
-- Stores the gender the user declared at verification time.
-- Used in admin panel to cross-check selfie vs. claimed gender.

ALTER TABLE public.photo_verifications
  ADD COLUMN IF NOT EXISTS claimed_gender TEXT
  CHECK (claimed_gender IN ('male', 'female', 'other'));

-- Migration: Add manual_review status and admin review columns to photo_verifications
-- Safe to run on an existing database — uses IF EXISTS / IF NOT EXISTS guards.

-- 1. Extend status CHECK to include 'manual_review'
--    We must drop + re-add the constraint because ALTER CONSTRAINT is not supported.
ALTER TABLE public.photo_verifications
  DROP CONSTRAINT IF EXISTS photo_verifications_status_check;

ALTER TABLE public.photo_verifications
  ADD CONSTRAINT photo_verifications_status_check
  CHECK (status IN ('pending', 'approved', 'rejected', 'manual_review'));

-- 2. Admin review columns — populated when a human reviewer acts on a manual_review record.
ALTER TABLE public.photo_verifications
  ADD COLUMN IF NOT EXISTS reviewed_by  UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS reviewed_at  TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS review_note  TEXT;

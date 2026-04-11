-- Make AI failure modes queryable from the row.
--
-- Before this column the nob-quality-check edge function had two failure
-- channels:
--   1. console.warn server log (24h retention, no per-row association)
--   2. response body field that the client never inspected
-- and the row itself silently landed at quality_score=0.5 / primary_mood=null
-- with zero hint about *why*. With ai_status persisted we can answer
-- "which posts fell back and what branch fired" with a single SELECT.

ALTER TABLE posts ADD COLUMN IF NOT EXISTS ai_status TEXT;

-- Partial index — we only ever query the failures, not the happy path.
-- Keeps the index small and the happy-path INSERT cost flat.
CREATE INDEX IF NOT EXISTS posts_ai_status_failed_idx
  ON posts (ai_status, analyzed_at DESC)
  WHERE ai_status IS NOT NULL AND ai_status <> 'ok';

-- AI parser debug: persist ai_error so Gemini raw responses survive
-- beyond the 24h edge-function log window.
-- Nullable text, only populated on failure branches.

ALTER TABLE posts ADD COLUMN IF NOT EXISTS ai_error TEXT;

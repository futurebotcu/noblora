-- Push notification token storage
CREATE TABLE IF NOT EXISTS public.push_tokens (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token       TEXT NOT NULL,
  platform    TEXT NOT NULL DEFAULT 'android' CHECK (platform IN ('android', 'ios', 'web')),
  updated_at  TIMESTAMPTZ DEFAULT NOW(),
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (user_id, token)
);

CREATE INDEX idx_push_tokens_user ON public.push_tokens (user_id);

ALTER TABLE public.push_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own tokens"
  ON public.push_tokens FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Secure config table for internal trigger use.
-- RLS enabled with NO policies = invisible via public API.
-- Only SECURITY DEFINER functions can read it.
CREATE TABLE IF NOT EXISTS public._internal_config (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
ALTER TABLE public._internal_config ENABLE ROW LEVEL SECURITY;

-- Setup: populate after migration via SQL editor or seed script:
--   INSERT INTO _internal_config (key, value) VALUES
--     ('project_url', 'https://<ref>.supabase.co'),
--     ('anon_key', '<your-anon-key>');

-- Function: send push notification via Edge Function when notification is inserted.
-- Reads credentials from _internal_config (no hardcoded secrets in code).
CREATE OR REPLACE FUNCTION public.trigger_push_notification()
RETURNS TRIGGER AS $$
DECLARE
  _url  TEXT;
  _key  TEXT;
BEGIN
  SELECT value INTO _url FROM public._internal_config WHERE key = 'project_url';
  SELECT value INTO _key FROM public._internal_config WHERE key = 'anon_key';

  IF _url IS NULL OR _key IS NULL THEN
    RAISE WARNING 'Push trigger: _internal_config not populated';
    RETURN NEW;
  END IF;

  PERFORM net.http_post(
    url := _url || '/functions/v1/send-push',
    body := jsonb_build_object(
      'user_id', NEW.user_id,
      'title', NEW.title,
      'body', NEW.body,
      'type', NEW.type,
      'data', COALESCE(NEW.data, '{}'::jsonb)
    ),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || _key
    )
  );
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Push notification trigger failed: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger: fire on every notification insert
DROP TRIGGER IF EXISTS on_notification_send_push ON public.notifications;
CREATE TRIGGER on_notification_send_push
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_push_notification();

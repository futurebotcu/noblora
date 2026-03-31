-- =============================================================================
-- Noblara Nob System Rebuild
-- Created: 2026-03-31
-- =============================================================================

-- 1. Drop post_comments
DROP TABLE IF EXISTS public.post_comments CASCADE;

-- 2. Update post_reactions
UPDATE public.post_reactions SET reaction_type = 'appreciate' WHERE reaction_type = 'like';
UPDATE public.post_reactions SET reaction_type = 'pass'       WHERE reaction_type = 'dislike';
ALTER TABLE public.post_reactions DROP CONSTRAINT IF EXISTS post_reactions_reaction_type_check;
ALTER TABLE public.post_reactions ADD CONSTRAINT post_reactions_reaction_type_check
  CHECK (reaction_type IN ('appreciate', 'support', 'pass'));

-- 3. Extend posts table
ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS nob_type             text      NOT NULL DEFAULT 'thought',
  ADD COLUMN IF NOT EXISTS photo_url            text,
  ADD COLUMN IF NOT EXISTS caption              text,
  ADD COLUMN IF NOT EXISTS quality_score        float     NOT NULL DEFAULT 0.5,
  ADD COLUMN IF NOT EXISTS is_pinned            boolean   NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_archived          boolean   NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_draft             boolean   NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS published_at         timestamptz;

ALTER TABLE public.posts DROP CONSTRAINT IF EXISTS posts_nob_type_check;
ALTER TABLE public.posts ADD CONSTRAINT posts_nob_type_check
  CHECK (nob_type IN ('thought', 'moment'));

UPDATE public.posts SET published_at = created_at, is_draft = false WHERE published_at IS NULL;

-- 4. Extend profiles
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS nob_tier               text        NOT NULL DEFAULT 'observer',
  ADD COLUMN IF NOT EXISTS daily_nob_count        int         NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS daily_nob_reset_at     timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS weekly_nob_count       int         NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS weekly_nob_reset_at    timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS weekly_photo_nob_count int         NOT NULL DEFAULT 0;

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_nob_tier_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_nob_tier_check
  CHECK (nob_tier IN ('observer', 'explorer', 'noble'));

UPDATE public.profiles SET nob_tier = 'noble' WHERE is_noble = true;

-- 5. check_nob_limit function
CREATE OR REPLACE FUNCTION public.check_nob_limit(p_user_id uuid, p_type text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tier         text;
  v_daily        int;
  v_weekly       int;
  v_weekly_photo int;
  v_daily_reset  timestamptz;
  v_weekly_reset timestamptz;
BEGIN
  SELECT nob_tier, daily_nob_count, weekly_nob_count, weekly_photo_nob_count,
         daily_nob_reset_at, weekly_nob_reset_at
  INTO v_tier, v_daily, v_weekly, v_weekly_photo, v_daily_reset, v_weekly_reset
  FROM public.profiles WHERE id = p_user_id;

  IF v_tier IS NULL THEN RETURN false; END IF;

  IF v_daily_reset < NOW() - INTERVAL '1 day' THEN
    v_daily := 0;
    UPDATE public.profiles SET daily_nob_count = 0, daily_nob_reset_at = NOW() WHERE id = p_user_id;
  END IF;
  IF v_weekly_reset < NOW() - INTERVAL '7 days' THEN
    v_weekly := 0; v_weekly_photo := 0;
    UPDATE public.profiles
    SET weekly_nob_count = 0, weekly_photo_nob_count = 0, weekly_nob_reset_at = NOW()
    WHERE id = p_user_id;
  END IF;

  IF v_tier = 'observer' THEN
    RETURN v_weekly < 1 AND p_type != 'moment';
  ELSIF v_tier = 'explorer' THEN
    RETURN v_weekly < 4 AND (p_type != 'moment' OR v_weekly_photo < 1);
  ELSIF v_tier = 'noble' THEN
    RETURN v_daily < 1 AND (p_type != 'moment' OR v_weekly_photo < 2);
  END IF;
  RETURN false;
END;
$$;

-- 6. Trigger: increment nob count on publish
CREATE OR REPLACE FUNCTION public.increment_nob_count()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF (TG_OP = 'INSERT' AND NEW.is_draft = false) OR
     (TG_OP = 'UPDATE' AND OLD.is_draft = true AND NEW.is_draft = false) THEN
    UPDATE public.profiles
    SET daily_nob_count  = daily_nob_count + 1,
        weekly_nob_count = weekly_nob_count + 1,
        weekly_photo_nob_count = CASE
          WHEN NEW.nob_type = 'moment' THEN weekly_photo_nob_count + 1
          ELSE weekly_photo_nob_count
        END
    WHERE id = NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS posts_nob_count ON public.posts;
CREATE TRIGGER posts_nob_count
  AFTER INSERT OR UPDATE OF is_draft ON public.posts
  FOR EACH ROW EXECUTE FUNCTION public.increment_nob_count();

-- 7. RLS update
DROP POLICY IF EXISTS "posts_select" ON public.posts;
DROP POLICY IF EXISTS "posts_select_public" ON public.posts;
DROP POLICY IF EXISTS "posts_insert" ON public.posts;

DO $$ BEGIN
  CREATE POLICY "posts_select" ON public.posts
    FOR SELECT TO authenticated
    USING ((is_draft = false AND is_archived = false) OR auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "posts_insert" ON public.posts
    FOR INSERT TO authenticated
    WITH CHECK (
      auth.uid() = user_id
      AND (is_draft = true OR public.check_nob_limit(auth.uid(), nob_type) = true)
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 8. Cron jobs
DO $$ BEGIN
  PERFORM cron.unschedule('reset-daily-nob-count');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
SELECT cron.schedule('reset-daily-nob-count', '0 0 * * *',
  $$UPDATE public.profiles SET daily_nob_count = 0, daily_nob_reset_at = NOW();$$);

DO $$ BEGIN
  PERFORM cron.unschedule('reset-weekly-nob-count');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
SELECT cron.schedule('reset-weekly-nob-count', '0 0 * * 1',
  $$UPDATE public.profiles SET weekly_nob_count = 0, weekly_photo_nob_count = 0, weekly_nob_reset_at = NOW();$$);

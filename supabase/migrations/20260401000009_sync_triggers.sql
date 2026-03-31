-- =============================================================================
-- SYNC: Document trigger RPCs that exist in remote DB but not in migrations.
-- These were created via Supabase Dashboard before migration system was used.
-- This migration ensures repo and remote stay consistent.
-- =============================================================================

-- ═══════════════════════════════════════════════════════════════════
-- 1. handle_new_user_profile — creates profile row on user signup
-- Trigger: on_auth_user_created_profile (AFTER INSERT on auth.users)
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.handle_new_user_profile()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)))
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created_profile ON auth.users;
CREATE TRIGGER on_auth_user_created_profile
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user_profile();

-- ═══════════════════════════════════════════════════════════════════
-- 2. handle_new_user_gating — creates gating_status row on user signup
-- Trigger: on_auth_user_created_gating (AFTER INSERT on auth.users)
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.handle_new_user_gating()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.gating_status (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created_gating ON auth.users;
CREATE TRIGGER on_auth_user_created_gating
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user_gating();

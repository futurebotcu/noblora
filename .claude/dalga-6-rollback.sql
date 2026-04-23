-- ---------------------------------------------------------------------------
-- Dalga 6 ROLLBACK — emergency restore for migration:
--   20260423122907_filter_discoverable_ids_batch.sql
-- ---------------------------------------------------------------------------
-- Use case: feed kırılırsa (RPC unexpected behavior, exception storm,
-- veya incognito enforce yanlış user'ları gizliyorsa).
--
-- Run as service_role / postgres in Supabase SQL editor or via
-- mcp__supabase__execute_sql. Do NOT commit this file's SQL into a new
-- migration unless you intend to permanently revert the enforce.
-- ---------------------------------------------------------------------------

DROP FUNCTION IF EXISTS public.filter_discoverable_ids(uuid[], text, uuid);

-- After rollback: feed_repository Step 1.5 RPC çağrısı fail eder
-- (function does not exist), app exception fırlatır, feed boş gelir.
-- Hot-fix: feed_repository.dart Step 1.5 bloğunu commentle/sil → revert.
-- (Ya da: bu dosyadaki DROP'u yapmadan migration'ı baştan apply et.)

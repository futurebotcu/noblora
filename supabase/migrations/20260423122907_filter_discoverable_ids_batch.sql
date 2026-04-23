-- ---------------------------------------------------------------------------
-- Dalga 6 — R8: filter_discoverable_ids batch RPC for feed enforce
-- ---------------------------------------------------------------------------
-- Context:
--   is_discoverable(target, mode, requester) RPC mevcut (migration
--   20260401000011) — is_paused + mode_visible + incognito_mode kontrolü
--   tam mantığıyla yazılmış. Ancak feed_repository client'ı bu RPC'yi
--   ÇAĞIRMAMIŞ — incognito_mode toggle'ı DB'ye yazılıyor, davranış
--   değişmiyordu (R8 örüntüsü, FEATURE_REGISTRY UI_ONLY).
--
-- Scope:
--   - Yeni batch RPC: filter_discoverable_ids(uuid[], text, uuid) → uuid[]
--   - SECURITY DEFINER (is_discoverable de DEFINER, mantığı taşır)
--   - SET search_path = public (function_search_path_mutable advisor için
--     bonus hijyen, R8 fix scope dışı ama RPC kendisi temiz)
--   - GRANT EXECUTE TO authenticated
--   - feed_repository Step 1.5'te çağrılacak
--
-- Out of scope (ayrı dalga):
--   - hide_exact_distance enforce (mesafe ProfileCard'da yok, altyapı eksik)
--   - Diğer 7 UI_ONLY setting (calm, show_city_only, ...) — R8 fazlaları
--   - feed_repository.dart:49 catch (_) — R4 hijyen dalgası
--
-- Evidence ref:
--   - .claude/known_regressions.md R8
--   - FEATURE_REGISTRY.md:42 "Incognito mode | UI_ONLY"
--   - README.md:101
--
-- ---------------------------------------------------------------------------
-- ROLLBACK SQL (run if anything breaks after apply):
-- ---------------------------------------------------------------------------
--   DROP FUNCTION IF EXISTS public.filter_discoverable_ids(uuid[], text, uuid);
--
-- (Also stored standalone at .claude/dalga-6-rollback.sql for emergencies.)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.filter_discoverable_ids(
  candidate_ids uuid[],
  mode text,
  requester_id uuid
)
RETURNS uuid[]
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result uuid[];
BEGIN
  SELECT array_agg(id) INTO result
  FROM unnest(candidate_ids) AS id
  WHERE public.is_discoverable(id, mode, requester_id) = true;
  RETURN COALESCE(result, ARRAY[]::uuid[]);
END;
$$;

GRANT EXECUTE ON FUNCTION public.filter_discoverable_ids(uuid[], text, uuid) TO authenticated;

-- Post-apply verification:
--   1. SELECT public.filter_discoverable_ids(
--        ARRAY[<test uuid 1>, <test uuid 2>]::uuid[],
--        'date',
--        '<requester uuid>'
--      );
--   2. Incognito_mode=true olan + matches'ta requester ile bağlı OLMAYAN
--      user → sonuç array'inden çıkmalı (NULL filter).
--   3. Incognito_mode=false + visible olan → sonuç array'inde olmalı.
--   4. Advisor: rls_policy_always_true sayısı değişmemeli (1 kalır,
--      video_update_own intentional). function_search_path_mutable
--      sayısı 1 düşmeli (yeni fonksiyon SET search_path ile).

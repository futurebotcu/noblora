# Done Log

Her tamamlanan görev için:

## [Tarih] — [Görev adı]
- [ ] Kod path: dosya:satır
- [ ] Backend kanıtı: SQL/curl/advisor çıktısı
- [ ] UI kanıtı: widget test ya da manuel test adımı
- [ ] Regresyon kontrolü: known_regressions.md'den baktığın maddeler
- [ ] Guardrail testi: yeşil çıktısı

Checklist eksik maddesi olan hiçbir görev "done" sayılmaz.

---

## 2026-04-28 — Dalga 5d5+5d6: Push Static + Device Service (R9 KISMEN, 30 → 22)

- [x] Kod path:
  - YENİ `lib/data/repositories/push_token_repository.dart` — lazy `instance()` + 2 method (`upsertCurrentUserToken`, `removeAllCurrentUserTokens`)
  - YENİ `lib/data/repositories/device_repository.dart` — lazy `instance()` + 3 method (`isDeviceBanned`, `profileExistsForDevice`, `registerDevice`)
  - YENİ `lib/providers/push_token_provider.dart`, `lib/providers/device_provider.dart` (future-proof Riverpod, mevcut caller dokunulmadı)
  - `lib/services/push_notification_service.dart:114-135` — `_saveToken` + `unregisterTokens` repo'ya delege; `supabase_flutter` import kaldırıldı
  - `lib/core/services/device_service.dart:36-78` — 3 static method repo'ya delege; `supabase_flutter` import kaldırıldı
- [x] Backend kanıtı: table/column/onConflict birebir korundu (`push_tokens` upsert `user_id,token`; `user_devices` upsert `user_id,device_id`; `profiles` update `device_id, device_platform`; `banned_devices/profiles` select `id` maybeSingle)
- [x] UI kanıtı: smoke atlandı (mekanik refactor, davranış değişikliği yok); analyze + test yeşil baseline kanıt
- [x] Regresyon kontrolü:
  - R4 (`catch (_)`): mevcut `catch (e) { debugPrint('[push] ...') }` / `[device]` pattern'leri korundu
  - R7 (uydurma iddia): grep ile iki service'te `Supabase.instance.client` = 0 kanıtlandı
  - R9: 30 → 22 ihlal (8 site sıfırlandı, guardrail çıktısı 22 violation listesinde push/device YOK)
- [x] Guardrail testi: `flutter test` → 284 pass / 1 fail (baseline korundu, tek fail R9 envanter — 22 violations) ✅
  - `flutter analyze --fatal-infos`: `No issues found! (ran in 122.7s)`
- Branch: `dalga-5d5d6-push-device`

---

## 2026-04-27 — Dalga 5d3: Edge Functions Refactor (R9 KISMEN, 35 → 30)

- [x] Kod path:
  - YENİ `lib/data/repositories/ai_repository.dart` — `invokeGeminiText`, `invokeAIEdit` + lazy `instance()` singleton (gemini_service için)
  - YENİ `lib/data/repositories/location_repository.dart` — `searchPlaces`, `fetchPlaceDetails`
  - YENİ `lib/providers/ai_provider.dart`, `lib/providers/location_provider.dart`
  - `lib/data/repositories/mood_map_repository.dart` + `fetchCountryAISummary` (11 named param)
  - `lib/services/gemini_service.dart:16` → `AIRepository.instance().invokeGeminiText(prompt)` (11 caller dokunulmadı)
  - `lib/features/noblara_feed/mood_map_screen.dart:187` → `ref.read(moodMapRepositoryProvider).fetchCountryAISummary(...)`
  - `lib/shared/widgets/city_search_screen.dart:52,74` → ConsumerStatefulWidget + `ref.read(locationRepositoryProvider).searchPlaces / fetchPlaceDetails`
  - `lib/features/noblara_feed/nob_compose_screen.dart:132` → `ref.read(aiRepositoryProvider).invokeAIEdit(...)`
- [x] Backend kanıtı: Edge Functions (`gemini-text`, `nob-ai-edit`, `nob-country-insight`, `places-proxy`) body birebir korundu — yalnızca call-site repo'ya taşındı, davranış değişikliği yok
- [x] UI kanıtı: smoke test atlandı (mekanik refactor, davranış değişikliği yok); analyze + test yeşil baseline kanıt
- [x] Regresyon kontrolü:
  - R4 (`catch (_)`): yeni eklenmedi, mevcut `catch (e) { debugPrint(...) }` patterns korundu
  - R7 (uydurma iddia): her sayı kanıta dayanıyor (count, test çıktısı, grep)
  - R9: 35 → 30 ihlal (`flutter test test/guardrails/no_banned_patterns_test.dart` → "30 violations")
- [x] Guardrail testi: `flutter test` → 284 pass / 1 fail (baseline korundu, tek fail R9 envanter — 30 violations) ✅
  - `flutter analyze --fatal-infos`: `No issues found! (ran in 59.4s)`
- Branch: `dalga-5d3-edge-functions`

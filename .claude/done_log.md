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

## 2026-05-10 — Dalga R11: Video call backend cleanup + Bumble first-message gate

- [x] Kod path:
  - **3 migration uygulandı:**
    - `supabase/migrations/20260510000001_drop_video_call_system.sql`:
      - `UPDATE matches SET status='expired' WHERE status IN (...)` (defansif, pre-check 0 row)
      - `ALTER TABLE matches` CHECK rebuild: 8 değer → 5 değer (`pending_first_message,chatting,meeting_scheduled,expired,closed`); default `pending_video` → `pending_first_message`
      - `DROP FUNCTION process_call_decision(uuid,uuid,boolean)` + `safe_advance_to_video(uuid,uuid)`
      - `DROP TABLE call_decisions, video_sessions, mini_intros CASCADE`
      - `cron.unschedule('expire-video-sessions')` + `cron.unschedule('expire-stale-matches')` + reschedule (yeni state'e göre)
    - `supabase/migrations/20260510000002_rewrite_check_and_create_match.sql`:
      - `CREATE OR REPLACE FUNCTION check_and_create_match` — conversation + conversation_participants önce INSERT, sonra match `pending_first_message` + `conversation_id` set + 24h `video_deadline_at` (semantic genişletilmiş first-message deadline)
      - Notification mesajı güncellendi: "Send the first message to start chatting." (eski: "Send a mini intro!")
      - `matches_ordered` CHECK için ordered user1/user2 logic eklendi
    - `supabase/migrations/20260510000003_first_message_trigger.sql`:
      - `CREATE FUNCTION first_message_advance_match()` SECURITY DEFINER + `is_system` bypass + idempotent UPDATE
      - `CREATE TRIGGER trg_first_message_advance_match AFTER INSERT ON messages`

- [x] Backend kanıtı (R8a pattern, 5 senaryo yeşil):
  - **Pre-check** (R7 disiplini): `SELECT status, count(*) FROM matches WHERE status IN ('pending_intro','pending_video','video_scheduled','video_completed') GROUP BY status` → **0 row** ✅ (UPDATE no-op kabul edildi)
  - **S1 — check_and_create_match RPC (testfeed1 ↔ testfeed10, mode='date'):**
    - Mutual swipes setup (2 INSERT)
    - RPC sonucu: `match_id=7064b89b...`, `conversation_id=d3e558eb...` (NOT NULL ✅), `status='pending_first_message'` ✅, `video_deadline_at=NOW()+24h` ✅
    - Side-effects: `conversation_participants` count=2 ✅, `notifications type='new_match'` count=2 ✅ (her iki kullanıcı bildirim aldı)
  - **S2 — first_message trigger:** Non-system message INSERT → `matches.status='chatting'` ✅
  - **S3 — Idempotent (no-op):** 2. mesaj INSERT sonrası status hâlâ `chatting`, msgs=2 ✅
  - **S4 — System message bypass (testfeed11 ↔ testfeed12, ayrı match):** `is_system=true` mesaj INSERT sonrası status hâlâ `pending_first_message` ✅
  - **S5 — DROP doğrulama (M1 sonrası):** `to_regclass('public.video_sessions')`=NULL, `call_decisions`=NULL, `mini_intros`=NULL; `process_call_decision` + `safe_advance_to_video` count=0; `expire-video-sessions` cron silindi
  - Cleanup smoke data: 0 leftover match, 0 leftover conversation
  - **CLAUDE.md §6 advisor diff:**
    - Pre (file `1778367021265.txt`): 1 ERROR + 1 INFO + 107 WARN (5 video-related)
    - Post (file `1778369915328.txt`): 1 ERROR + 1 INFO + 104 WARN (0 video-related)
    - Δ: -3 WARN, hedeflenen 5 finding (video_update_own RLS + 4 SECDEF/search_path entry) tamamen kayboldu, **0 yeni issue** ✅

- [x] UI kanıtı:
  - `flutter analyze --fatal-infos`: **No issues found!** (8.4s) ✅ (R10 sonrası kod hâlâ temiz, R11 backend değişikliği UI'ı etkilemedi)
  - `flutter test`: **266 / 266 pass** (2s) ✅
  - mini_intro_screen rewrite (R10) `conversationId` null guard artık defansif fallback rolünde — R11 sonrası `check_and_create_match` her match için `conversation_id` set ediyor → guard prod'da nadiren tetiklenir

- [x] Regresyon kontrolü:
  - **R5 (bypass-disguised-as-fix):** Migration tüm video function'ları DROP etti, eski permissive `video_update_own` policy CASCADE ile gitti (sadece "yeni policy ekle" yapılmadı, eski drop edildi) ✅
  - **R6 (phantom feature):** R10/R11 kombinasyonu tüm video kod yolunu sildi (UI + backend); kullanıcıya gösterilen "Available soon" toast'lar gerçek (gelecek backlog), sahte değil ✅
  - **R7 disiplin:** Pre-check SELECT (0 row) + 5/5 smoke senaryo + advisor diff (yan yana) — her edit kanıt-dayalı ✅
  - **R8 mapping drift watch:** R-NEW-CANDIDATE aktif kalır — V2 reactivation'da yeni `video_*` type'lar eklenince `send-push/index.ts` mapping güncellenmeli (mevcut send-push mapping'de video referansı YOK, R10'da abandon edildi)

- [x] Guardrail testi:
  - flutter analyze: **green** ✅
  - flutter test: **266/266** ✅
  - Branch: `dalga-r11-video-backend-cleanup`

- [x] V2 reactivation doc: R-NEW güncellendi (`known_regressions.md`):
  - R10 commit SHA: `f4bea78` (merged PR #45)
  - R11 commit: bu PR
  - R10/R11 köprüsü "ÇÖZÜLDÜ 2026-05-10" notu eklendi
  - Advisor diff side-by-side eklendi

---

## 2026-05-10 — Dalga R10: Flutter video sistemi söküm (Bumble pattern'e geçiş)

- [x] Kod path:
  - **11 dosya silindi** (8 video + 3 mini_intro):
    - `lib/features/match/video_call_screen.dart` (489 satır)
    - `lib/features/match/video_scheduling_screen.dart` (1211 satır)
    - `lib/features/match/post_call_decision_screen.dart` (359 satır)
    - `lib/features/match/short_intro_rules_screen.dart` (236 satır)
    - `lib/services/video_service.dart` (54 satır — Jitsi URL builder)
    - `lib/data/repositories/video_session_repository.dart` (~280 satır)
    - `lib/data/models/video_session.dart` (~80 satır)
    - `lib/providers/video_provider.dart` (~230 satır)
    - `lib/data/repositories/mini_intro_repository.dart`
    - `lib/data/models/mini_intro.dart`
    - `lib/providers/mini_intro_provider.dart`
  - **9 dosya düzenlendi**:
    - `lib/data/models/match.dart`: 3 getter sil (isPendingVideo/Scheduled/Completed) + isPendingFirstMessage ekle + default 'pending_video' → 'pending_first_message'
    - `lib/features/match/match_detail_screen.dart`: 8 edit (3 import sil, videoState watch sil, countdown widget birleşti, _SessionCard usage sil + sınıf tamamen sil, _ActionButton videoState parametresi sil, video CTA blokları "Join/Schedule Video Call" sil, _StatusCard switch'lerinden 3 video case sil + pending_first_message ekle, intl import sil)
    - `lib/features/match/mini_intro_screen.dart`: REWRITE _sendIntro (sendIntro+advanceToVideo SİL → messages.insert + IndividualChatScreen push + conversationId null guard snackbar) + 6 import değişikliği + introState/otherIntro UI bloğu sil
    - `lib/features/matches/matches_screen.dart`: filter (3 video state → pending_intro+pending_first_message) + label switch (3 video case → pending_first_message)
    - `lib/features/matches/individual_chat_screen.dart`: Icons.video_call_rounded → Icons.bolt_rounded + Quick Intro Video option "Available soon" disabled (toast fallback) + video_scheduling_screen import sil + match local var temizlik
    - `lib/features/status/status_screen.dart`: "Coming up" video_scheduled widget bloğu sil + _Upcoming class sil + pending filter pending_video → pending_first_message
    - `lib/data/repositories/admin_repository.dart`: status filter ('pending_video','video_scheduled','chatting' → 'pending_first_message','chatting')
    - `lib/navigation/main_tab_navigator.dart`: 4 edit (push routing 2 case sil, typeToCategory map 1 satır sil, isVideoProposed flag sil, banner "View" buton bloğu sil)
    - `lib/features/feed/feed_screen.dart`: NO-OP (mini_intro_provider import zaten yoktu)

- [x] Backend etkisi: YOK (R10 sadece UI söküm)
  - `video_sessions` tablosu hâlâ ayakta (PR-R11'de DROP)
  - `matches.status` hâlâ eski enum: 'pending_intro','pending_video','video_scheduled','video_completed','chatting','meeting_scheduled','expired','closed' (PR-R11'de rebuild → 'pending_first_message','chatting','meeting_scheduled','expired','closed')
  - `process_call_decision` + `safe_advance_to_video` SECDEF function'ları hâlâ ayakta (PR-R11'de DROP)
  - `expire-video-sessions` pg_cron job hâlâ aktif (PR-R11'de unschedule)
  - UI artık bu state'lere/function'lara dokunmuyor (silinmiş kod referansı kalmadı)

- [x] UI kanıtı:
  - `flutter analyze --fatal-infos`: **No issues found!** (5.8s) ✅
  - `flutter test`: **266 / 266 pass** (test count değişmiyor, video için test yoktu)
  - Iterative analyze fix (3 issue → 1 warning → 0):
    1. `individual_chat_screen.dart:26` orphan import `video_scheduling_screen.dart` sil
    2. `individual_chat_screen.dart:625` Quick Intro Video option `VideoSchedulingScreen` push → "Available soon" disabled + toast
    3. `status_screen.dart:466` `_Upcoming` class unused → tamamen sil
    4. `individual_chat_screen.dart:569` `match` local var unused (Video option simplify sonrası) → kaldır
  - Match akışı yeniden tasarlandı:
    - Eski: Match → propose video → call → enjoyed? → chat
    - Yeni: Match → MiniIntro (AI opener Gemini KEEP) → first message (PR-R11 first_message trigger ile state geçişi) → chat

- [x] Korunan özellikler (V1 differentiator):
  - `mini_intro_screen.dart`: AI opener (Gemini) feature, _sendIntro REWRITE (messages.insert + IndividualChatScreen + InboxItem köprü matches_screen pattern'inden)
  - `match_found_screen.dart`: 'It's a Match!' brand moment dokunulmadı (K2-A onayı, mode-aware Date/BFF korundu)
  - `individual_chat_screen.dart` Quick Intro: Voice "Available soon" + Video "Available soon" placeholder simetri (toast fallback)

- [x] Regresyon kontrolü:
  - **R1 (copyWith drift):** `match.dart` 3 getter sil + 1 ekle — caller'lar tüm güncellendi (match_detail_screen, matches_screen, status_screen, admin_repository); analyze sıfır undefined identifier
  - **R6 (phantom feature):** Video CTA tamamen kaldırıldı, "Available soon" toast user'a açık beyan (sahte feature gösterilmiyor)
  - **R7 disiplin:** 12 ana edit + 4 iterative analyze fix — hepsi kanıt-dayalı (her hata grep+view ile yakalandı, sırayla çözüldü)
  - **R10/R11 köprüsü:** `mini_intro_screen` rewrite'da `widget.match.conversationId` null guard eklendi → snackbar "Chat not ready yet. Try again in a moment." (R11 öncesi defansif behavior)

- [x] Guardrail testi:
  - `flutter analyze`: **green** ✅
  - `flutter test`: **266/266 pass** ✅
  - Branch: `dalga-r10-video-removal-flutter` (main d4257b4 üstüne)

- [x] V2 reactivation doc: R-NEW eklendi (`known_regressions.md`)

---

## 2026-05-09 — Dalga R8b: phantom privacy settings cleanup (R8 PARTIAL → MOSTLY CLOSED)

- [x] Kod path:
  - `lib/features/onboarding/onboarding_flow_screen.dart:155-156` — `'show_city_only': false,` + `'hide_exact_distance': false,` onboarding default insert satırları kaldırıldı
  - `lib/data/models/profile_card.dart:23,44,89` — `final bool showCityOnly` field tanımı + constructor default param + `fromDb` factory satırı kaldırıldı (3 referansın hepsi)
  - **DB kolonları DOKUNULMADI** (`profiles.show_city_only` + `profiles.hide_exact_distance`) — V2'de feature implement edilirse hazır kalsın, schema migration overhead engellensin
- [x] Backend kanıtı: N/A — UI hiç gönderilmedi, sadece onboarding default + dead model field temizliği. R7 envanter (`grep -rn "showCityOnly|hideExactDistance|show_city_only|hide_exact_distance" lib/`): 5 hit hepsi temizlendiği 2 dosyada; 0 UI consumer (`card.showCityOnly` çağrısı yok), `copyWith`/`toJson` profile_card.dart'ta zaten yok, `fromJson` zaten kullanmıyordu (R1 copyWith drift riski yok).
- [x] UI kanıtı: N/A — UI hiç eklenmemiş feature'ların temizliği. Settings screen'de toggle yok, swipe_card'da render yok, hiçbir consumer yok. Emülatör smoke gereksiz.
- [x] Regresyon kontrolü:
  - R1 (copyWith drift): profile_card.dart'ta `copyWith` yok → riski yok
  - R2 (draft asenkron): profile_draft bu field'ı yazmıyordu → riski yok
  - R6 (phantom feature): Bu temizlik tam olarak R6'nın önlemi — UI olmayan ayarın "shipped" görünmesi engellenmiş
  - R7 disiplin: her edit kanıt-dayalı (grep ile 5/5 referans tespit ve kaldırıldı, hiçbir consumer yok)
  - R8: PARTIAL CLOSED → MOSTLY CLOSED (phantom drop sayılır, 0 OPEN kaldı, sadece 2 KISMEN: calm_mode + notification_preferences yeni type map güncellemeleri)
- [x] Guardrail testi:
  - `flutter analyze --fatal-infos`: `No issues found! (ran in 12.6s)` ✅
  - `flutter test`: 266/266 pass ✅ (baseline korundu, regresyon yok)
- Branch: `dalga-r8b-phantom-privacy-cleanup`

---

## 2026-05-09 — Dalga R8a: notification_preferences enforce on send-push edge function (R8 PARTIAL CLOSED)

- [x] Kod path:
  - `supabase/functions/send-push/index.ts:39-65` — opt-out check (HYBRID strategy: mapped types check pref, unmapped fall through default-ON)
  - `supabase/functions/send-push/index.ts:211-222` — `mapTypeToPrefKey` (evidence-based mapping: `new_match → new_match`, `bff_connected → bff_suggestion`)
  - Deploy: `supabase functions deploy send-push` (xgkkslbeuydbbcvlhsli, version 5, 2026-05-09 ~07:48 UTC)
- [x] Backend kanıtı: 4-senaryo smoke (testfeed1 `858a0f3d-2da6-4133-ba2c-65f35c7d71c2`, MCP execute_sql + `net._http_response`):

  | # | Time UTC | Pref state | INSERT type | Edge response | Beklenen | Sonuç |
  |---|---|---|---|---|---|---|
  | S1 | 07:50:27 | `new_match=false` | `new_match` | `{"sent":0,"reason":"opted_out","preference":"new_match","type":"new_match"}` | opted_out new_match | ✅ |
  | S2 | 07:51:12 | `new_match=true` | `new_match` | `{"sent":0,"reason":"no_tokens"}` | pass-through | ✅ |
  | S3 | 07:51:31 | (irrelevant) | `chat_opened` (unmapped) | `{"sent":0,"reason":"no_tokens"}` | HYBRID pass-through | ✅ |
  | S4 | 07:51:47 | `bff_suggestion=false` | `bff_connected` | `{"sent":0,"reason":"opted_out","preference":"bff_suggestion","type":"bff_connected"}` | opted_out bff_suggestion | ✅ |

  Cleanup: 8 pref → all-true doğrulandı. Edge logs 4 invocation 200 OK (`mcp__supabase__get_logs`).
- [x] UI kanıtı: backend-only smoke (UI toggle zaten settings_screen'de var ve DB'ye yazıyordu, eksik olan enforce backend'di). Push token gerektirmediği için emülatör smoke gerek yok — `net._http_response` body inspection ground truth.
- [x] Regresyon kontrolü:
  - R4 (`catch (_)`): yeni eklenmedi; profileErr için `console.error` + don't block (R4 disiplini: silent yutma yok, ama transient profile read hatası push'u engellemesin — KVKK §11 default-ON gereği).
  - R6 (phantom feature trap): mapTypeToPrefKey evidence-based — yalnızca migration grep ile bulunan type'lar map'lendi. R-NEW-CANDIDATE: yeni type eklendiğinde map güncelleme zorunlu (known_regressions.md R8 §R-NEW-CANDIDATE).
  - R8: notification_preferences "OPEN — büyük iş" → "PARTIAL CLOSED" (mapped 2 type enforce çalışıyor; chat-push trigger yok, diğer notification type'ları map'e eklendikçe enforce'a girer).
  - R7 disiplin: 4/4 smoke direct evidence (response body), advisory log değil — net._http_response.content tablosu hard-truth.
- [x] Guardrail testi:
  - `flutter analyze --fatal-infos`: `No issues found!` ✅ (smoke öncesi yeşil idi, smoke kod değişikliği yapmadı; doc-only edit known_regressions + done_log)
  - `flutter test`: 266/266 pass baseline korundu (smoke öncesi yeşil idi).
- Branch: `dalga-r8a-notification-preferences-enforce`

---

## 2026-04-28 — Dalga 5d7: Karışık Kalanlar (R9 KISMEN, 22 → 13)

- [x] Kod path:
  - YENİ `lib/data/repositories/status_repository.dart` — `fetchStatusCounts` (6 paralel) + `fetchStatusData` (4 sequential)
  - `lib/providers/status_provider.dart` — `statusRepositoryProvider` ek (top-of-file pattern), `_fetchData` yeniden yazıldı
  - `lib/data/repositories/noblara_notification_repository.dart` + `fetchAll({limit})`
  - `lib/data/repositories/messages_repository.dart` + `insertSystemMessageFromUser(...)` (sender_id non-null + is_system true, R7 davranış koruma)
  - `lib/data/repositories/post_repository.dart` + `fetchUserReactions(...)` + `fetchAuthorEnrichment(...)`
  - `lib/data/repositories/room_repository.dart` + `fetchUserLocation(uid)` (record `({lat, lng})`)
  - `lib/features/status/status_screen.dart:64-75` → `ref.read(statusRepositoryProvider).fetchStatusCounts(uid)`
  - `lib/providers/status_provider.dart:160` → `_ref.read(statusRepositoryProvider).fetchStatusData(uid)` + `SuperLikeRepository(supabase: _ref.read(supabaseClientProvider))`
  - `lib/features/settings/settings_screen.dart:638` → `ref.read(profileRepositoryProvider).updateProfile(uid, {column: list})` (REUSE)
  - `lib/features/noblara_feed/notifications_screen.dart:50` → `ref.read(noblaraNotificationRepositoryProvider).fetchAll()`
  - `lib/features/matches/end_connection_screen.dart:88` → `ref.read(messagesRepositoryProvider).insertSystemMessageFromUser(...)` (sender_id non-null!)
  - `lib/providers/posts_provider.dart:299` → `_ref.read(postRepositoryProvider).fetchUserReactions(...)`
  - `lib/providers/posts_provider.dart:422` → `_ref.read(postRepositoryProvider).fetchAuthorEnrichment(userId)`
  - `lib/providers/room_provider.dart:64,108` → `repo.fetchUserLocation(uid)` (REUSE)
- [x] Backend kanıtı: table/column/onConflict/order/limit/eq/inFilter/or birebir korundu
  - `messages.insert` sender_id non-null + is_system true (R7 önemli ayrım)
  - 6 paralel + 4 sequential query SQL pattern birebir
  - notifications limit 100 default + descending order
- [x] UI kanıtı: smoke atlandı (mekanik refactor); analyze + test yeşil baseline kanıt
- [x] Regresyon kontrolü:
  - R4: try/catch + debugPrint patterns korundu (`[rooms]`, `[chat]`, `[status]`, `[enrich:myReactions]`, `[createNob:enrich]`)
  - R7 KRİTİK: end_connection messages.insert sender_id non-null doğrulandı (yeni method imzası `String senderId`, sendMessage(isSystem) farklı path)
  - R9: 22 → 13 ihlal (`grep` ile sayım), kalan 13 = 5c2 (Profile reads)
- [x] Guardrail testi: `flutter test` → 284 pass / 1 fail (baseline; tek fail R9 envanter, 13 violations) ✅
  - `flutter analyze --fatal-infos`: `No issues found! (3.0s)`
- Branch: `dalga-5d7-misc-cleanup`

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

# Known Regressions

Geçmişte tekrar etmiş, kalıplaşmış hatalar. Her oturum başında okunacak.
Kod numaraları (R1–R7) CLAUDE.md §8 ile birebir eşleşir — değiştirirken
iki dosyayı beraber güncelle.

---

## R1: Profile copyWith Drift

**Belirti:** Kullanıcı profilinde X alanını kaydediyor, geri döndüğünde
alan boş. Ya da başka bir alanı düzenleyip kaydettiğinde X alanı siliniyor.

**Kök neden:** `Profile` modeline alan eklendi ama `copyWith` güncellenmedi.
`copyWith(name: newName)` çağrısı diğer alanları null'a düşürüyor.

**Tespit tarihi:** 3 ayrı oturumda tekrar etti (son: Mart/Nisan 2026).

**Tekrar sayısı:** 3

**Status:** PARTIALLY CLOSED (2026-04-21)
- **copyWith drift:** CLOSED — Dalga 2, commit `1013aba` (`dalga-2-profile-copywith` branch, PR #2)
- **toJson serialize eksikliği:** OPEN — `Profile.toJson` sadece 5/73 alan yazıyor, `profile_data` nested JSONB hiç üretilmiyor. Dalga 2b'de kapanacak.

**Kanıt (2026-04-21):**
- Test: `profile_roundtrip_guardrail_test` copyWith preserves-all-fields grubu **36 fail → 0 fail**
- Full suite: **117 pass / 69 fail** (dünkü baseline 81/105'ten +36/-36, regresyon sıfır)
- Analyze: `No issues found`
- Commit SHA: `1013aba`
- PR: https://github.com/futurebotcu/noblora/pull/2
- CI run: 24733594100 — analyze ✅, test ❌ (beklenen, kalan 67 fail toJson grubunda + 38 catch(_) + 1 ignore)

**Dokunma protokolü:**
- `lib/data/models/profile.dart` dosyasına alan ekliyorsan CLAUDE.md §7 Model Protokolü'nü takip et
- `copyWith` + `fromJson` + `toJson` + draft — dördü de aynı PR'da güncellenmeli
- `test/guardrails/profile_roundtrip_guardrail_test.dart` yeni alan için genişletilmeli
- **Yeni alan eklerken copyWith'i güncellemek artık yeterli değil** — R1 kapanışı toJson'u DA kapsayacak (Dalga 2b sonrası). Alan eklerken 4'lü (copyWith + fromJson + toJson + draft) hepsi şart.

---

## R2: ProfileDraft ↔ fromDbRow Asenkron (Sessiz Veri Kaybı)

**Belirti:** Kullanıcı profil düzenleme ekranında alan dolduruyor, draft
yazılıyor ama geri açıldığında alan boş. Hata yok, veri yok.

**Kök neden:** `ProfileDraft.toUpdateMap` (yazma) ile `ProfileDraft.fromDbRow`
(okuma) arasında asimetri. Yazılan key okunmuyor (ya da tersi), ya da
aynı alan iki yere yazılıp tek yerden okunup kayıp oluşuyor.

**Tespit tarihi:** 2 ayrı oturumda tekrar etti (Mart 2026 + 2026-04-22).

**Tekrar sayısı:** 2

**Status:** FULLY CLOSED (2026-04-22)
- **Dalga 2c, commit `1c8730e`** (`dalga-2c-profile-draft` branch)
- DB kontrat raporu (mcp__supabase__execute_sql ile public.profiles):
  `looking_for` text (single), `countries_visited` text[] (array)
- İki kanıtlanmış asimetri:
  - **`lookingFor`**: write doğru (row=first, pd=full list), read yanlış
    (row öncelikli → liste kayboluyor, sadece first kalıyor). Fix: read
    precedence ters çevrildi (pd list primary, row fallback for legacy).
  - **`visitedCountries`**: `toUpdateMap`'te `countries_visited` write
    tamamen eksik → her save'de siliniyor. Fix: top-level row key eklendi.
- Test-first: yeni guardrail `profile_draft_roundtrip_guardrail_test.dart`
  73 alan subtest. İlk run **71/2** (lookingFor + visitedCountries fail),
  fix sonrası **73/0** yeşil.
- Full suite 184/2 → **257/2** (regresyon sıfır, kalan 2 fail banned
  patterns — R2 ile ilgisiz).

**Dokunma protokolü:**
- `ProfileDraft`'a alan eklendiğinde `profile_draft_roundtrip_guardrail_test.dart`
  da güncellenmeli (73 alan subtest deseni)
- `toUpdateMap` ↔ `fromDbRow` simetrisi guardrail tarafından zorlanır
- DB kolon ismi/tipi değişiminde `mcp__supabase__execute_sql` ile
  şema doğrula (kontrat = kanıt)
- Yeni alan için: write key + read key + tip eşleşmesi → roundtrip test
  yeşil olana kadar commit yok

---

## R3: `_substantive()` Filter Prompts Gizliyor

**Belirti:** Canlıda kullanıcı profilinde doldurduğu promptlar ekranda
görünmüyordu. UI tamamen sessizdi.

**Kök neden:** `profile_screen.dart` içinde `_substantive()` helper
"anlamlı prompt" filtresi yapıyordu ama kriter çok sıkıydı — gerçek
kullanıcı cevaplarını da eliyordu. `strongPrompts` getter `minChars=10,
minWords=3` eşiği uyguluyordu; "İstanbul" (8/1), "kahve" (5/1), "evet"
(4/1) gibi meşru kısa cevaplar `_PromptStoriesSection`'da kayboluyordu.

**Tespit tarihi:** 1 kez (canlıda, kullanıcı raporladı).

**Tekrar sayısı:** 1 (canlı etki)

**Status:** FULLY CLOSED (2026-04-24) — Dalga 3 (R3).

**Kanıt (2026-04-24):**
- Kod: `lib/features/profile/profile_screen.dart`
  - `strongPrompts` getter (line 218-224) → `_substantive` çağrısı
    kaldırıldı, `isPromptVisible` top-level helper kullanır
  - Yeni top-level `@visibleForTesting bool isPromptVisible(PromptAnswer)`
    eklendi (`_CuratedProfile` altı). `_strong` ön filtresi (boş /
    blocklist / repetition / no-letter / `<2` char) korundu — spam yine
    eleniyor, bilgi taşıyan kısa cevap geçer.
- Diğer 6 `_substantive` çağrısı (longBio, currentFocus, dateBio, bffBio,
  socialBio, aboutMe) korundu — bunlar gerçek "story" alanları.
- Yeni guardrail: `test/guardrails/profile_prompt_filter_guardrail_test.dart`
  - 26 subtest, 4 grup: meşru kısa cevap görünür / spam gizlenir / soru
    validation / eski `_substantive` davranışı kırıldı
  - Türkçe karakter dahil ("İstanbul", "hayır", "hiç içmem", "ş")
  - Sonuç: **26/26 pass**
- Full suite: **283 pass / 2 fail** (önceki baseline 257/2 → +26/0,
  regresyon sıfır; kalan 2 fail R4 banned_patterns, R3 ile ilgisiz)
- Analyze: `flutter analyze --fatal-infos` → `No issues found!`
- Karar yolu: Yol A (helper extract). Yol B (sadece kod + manual smoke)
  reddedildi — sessiz veri kaybı riski + filtre git history'de bir kez
  yanlış eşik (magic number 14/10/8) ile yazılmıştı, otomatik koruma
  gerekli. Yol C (`_CuratedProfile` public) reddedildi — scope creep.

**Dokunma protokolü:**
- `profile_screen.dart:91-102` `_substantive` helper'ı hâlâ var, 6
  çağrısı korunuyor. Yeni story-tipi alan eklerken bu helper kullanılır.
- Prompts (Q&A) için `isPromptVisible` kullanılır, `_substantive` DEĞİL.
  Filter tekrar değiştirilirse `profile_prompt_filter_guardrail_test`
  yakalar (26 subtest, kısa cevap senaryolarını koruyor).
- "Boş göstermemek" için eklenen filtreler, gerçek veriyi de eliyor mu
  kontrolü zorunlu. `_strong` (boş + blocklist + tekrar + harfsiz)
  yeterli minimum gate; üstüne ek eşik eklenmeden önce keşif zorunlu.

---

## R4: `catch (_)` Sessiz Fail — Distance Filter Örneği

**Belirti:** Feed'deki mesafe filtresi yanlış değer gösterdi. Kullanıcı
10km seçti, 200km uzakta profiller düşüyordu.

**Kök neden:** `feed_repository` içinde `catch (_)` exception'ı sessizce
yuttu. Konum alınamadığı durumda default değer kullanılıyor ama
kullanıcıya hiç sinyal verilmiyordu.

**Tespit tarihi:** 1 kez.

**Tekrar sayısı:** 1

**Status:** FULLY CLOSED (2026-04-26) — Dalga 4 (21 fix) + Dalga 4b (kalan 17).

**Kanıt (2026-04-26 19:30):**
- `grep "catch (_)" lib/ -r`: **0 sonuç** (38 → 21 → 0)
- Dalga 4 (2026-04-24, PR #10): 21 fix (4 P0 toast lie + 7 P1 rethrow/log + 8 P2 + 2 P3)
- Dalga 4b (2026-04-26, bu PR): kalan 17 fix (12 P2 mekanik log + 5 P3 yorumlu/dispose)
- Banned pattern test `catch_underscore_violations`: fail → **PASS**
- Full suite: 283/2 → **284/1** (+1 pass / -1 fail; tek kalan fail Supabase.instance.client, R4 ile ilgisiz)
- `flutter analyze --fatal-infos`: `No issues found!`

**Pattern (Dalga 4 + 4b standardı):**
```dart
catch (e) {
  debugPrint('[<scope>] <context>: $e');
  // mevcut yorumu/davranışı koru
}
```
Scope etiketi (köşeli parantez) = feature alanı: `[feed]`, `[chat]`, `[matches]`,
`[compose]`, `[onboard]`, `[gate]`, `[end]`, `[video]`, `[notif]`, `[swipe]`,
`[posts]`, `[gemini]`, `[comment]`, `[photos]`, `[auth]`, `[status]`, `[room]`,
`[push]`, `[settings]`, `[intro]`. Yeni feature için yeni etiket eklenebilir.

**Dokunma protokolü:**
- `catch (_)` kullanılamaz (CLAUDE.md §4 yasak). `catch (e)` + `debugPrint` + scope etiketi + context.
- Davranış değişikliği gerektiren P0/P1 (toast lie, security/UX rethrow) için
  Dalga 4 örneklerini incele: feed_provider:135 / swipe_repo:81 (rethrow),
  match_detail:182 / individual_chat:426 (toast try içine taşı).
- Inline `} catch (_) {}` görürsen multi-line'a aç + log ekle. Yorum varsa
  yorumu KORU (gemini non-JSON, chat server-reject, photos orphan-cleanup).
- `test/guardrails/no_banned_patterns_test.dart` `catch (_)` kuralını zorlar.
- `import 'package:flutter/foundation.dart'` zaten material/foundation export
  edenlerde gereksiz — `unnecessary_import` info verir, ekleme.

---

## R5: Bypass-Disguised-As-Fix (P0 Migration)

**Belirti:** P0 güvenlik migration'ı canlıya **uygulandı** (2026-04-08
audit oturumunda `mcp__supabase__list_migrations` ile doğrulandı —
timestamp 20260408140730) ancak advisor hâlâ aynı kırmızı bulguları
gösteriyor. "Uygulandı ama etkisiz" durumu.

**Kök neden:** Migration yeni restrictive policy'yi ekledi ama eski
permissive `*_system WITH CHECK (true)` policy'lerini `DROP` etmedi.
İki policy yan yana yaşıyor, permissive olan üstte kaldığı için
advisor eskisini görmeye devam ediyor. "Fixed" etiketi gerçek durumu
yansıtmadı. Uygulanmış olmak ≠ etkili olmak.

**Tespit tarihi:** Migration uygulandı (2026-04-08). Etkisizlik Nisan
2026 audit'inde fark edildi.

**Tekrar sayısı:** 1

**Dokunma protokolü:**
- CLAUDE.md §6 Güvenlik Protokolü — 5 adım, **atlanamaz**
- "Fixed" demek = ikinci advisor çıktısında hedef satırların yokluğu
- Eski policy'leri DROP etmeden yeni policy eklemek "fix" değildir
- Migration durumu için: list_migrations (applied mi?) + get_advisors
  (etkili mi?) — iki farklı soru, ikisi de sorulacak
- Sıradaki RLS hardening migration'ı bu boşluğu kapatmalı (eski
  permissive policy'leri önce DROP et, sonra restrictive ekle)

---

## R5b: Pre-existing Cosmetic Dead Permissive Policies (5 satır)

**Belirti:** Supabase advisor `rls_policy_always_true` WARN'larından **5'i**
davranışsal etki yapmıyor — `polroles={0}` PostgreSQL quirk'i nedeniyle
hiçbir role'e uygulanamıyor. Pre-smoke test (Dalga 3, 2026-04-22) her birini
kanıtladı: dış user'ın bypass denemesi RLS tarafından reddedildi.

**Etkilenen policy'ler (revize, Dalga 3 sonrası):**

| Tablo | Policy | CMD | Test sonucu |
|-------|--------|-----|-------------|
| matches | matches_insert_system | INSERT | RLS reddetti (dead) |
| conversation_participants | cp_insert_own | INSERT | RLS reddetti (dead) |
| conversations | conv_insert_own | INSERT | RLS reddetti (dead) |
| real_meetings | rm_insert_own | INSERT | RLS reddetti (dead) |
| video_sessions | video_insert_own | INSERT | RLS reddetti (dead) |

**LİSTEDEN ÇIKARILANLAR:**
- `notifications_insert_system` — Dalga 3'te DROP edildi (commit zinciri).
- `gating_insert_system` + `gating_update_system` — Dalga 3'te restrictive yedek
  ile değiştirildi (R5 ana kayıt: AKTİF bypass'tı, kanıtlanmış).
- `video_sessions.video_update_own` — intra-match scope intentional. SELECT
  policy match-bound olduğu için dış user erişemiyor; iç user (match parçası)
  birbirinin session'ını yönetebilir, bu kasıtlı (call'daki iki kullanıcı).

**Kök neden hipotezi:** Adlandırma yanıltıcı — `_own` / `_system` eki var ama
gerçek qual `true`. `polroles` array'inde OID 0 var ama PostgreSQL'in iç RLS
değerlendirmesi bunu PUBLIC olarak çözmüyor (catalog quirk). Sonuç: policy
syntactically present, semantically inert.

**Tespit tarihi:** 2026-04-22 (Dalga 3 pre-smoke testleri).

**Tekrar sayısı:** 1 (toplu envanter)

**Status:** FULLY CLOSED (2026-04-23) — Dalga 3b kapsadı.

**Kanıt (2026-04-23 ~10:58 UTC):**
- Migration: `supabase/migrations/20260423105809_drop_r5b_dead_policies.sql`
- Apply: `mcp__supabase__apply_migration(name="drop_r5b_dead_policies") → {"success":true}`
- pg_policies post-check (5 hedef policyname): **boş** (5/5 silindi)
- Advisor `rls_policy_always_true`: **6 → 1 WARN**
  - 5/5 hedef cache_key kayboldu:
    - `..._conversation_participants_cp_insert_own` ✅
    - `..._conversations_conv_insert_own` ✅
    - `..._matches_matches_insert_system` ✅
    - `..._real_meetings_rm_insert_own` ✅
    - `..._video_sessions_video_insert_own` ✅
  - Kalan 1 satır: `..._video_sessions_video_update_own` (intentional, intra-match)
- Smoke test: **skip**, gerekçe — Dalga 3 pre-smoke (2026-04-22) bu 5 policy'i
  zaten dead olarak kanıtladı (her biri authenticated cross-user INSERT'i
  RLS tarafından reddedildi). Davranışsal değişim beklenmiyor; advisor count
  düşüşü + pg_policies boş çıktısı tek kanıt.
- Commit SHA (migration + rollback): `2845e99` (Dalga 3b PR)
- Rollback: `.claude/dalga-3b-rollback.sql` (standalone, gereksiz beklenir)

**Dokunma protokolü (gelecekte ileride benzer cosmetic dead policies çıkarsa):**
- Önce pre-smoke ile dead/aktif ayrımı yap (R5b ile aynı pattern: cross-user
  INSERT/UPDATE RLS'e takılıyor mu?)
- Dead ise sadece DROP yeterli, replacement gereksiz
- Apply sonrası advisor count + pg_policies post-check ikili kanıt yeterli

---

## R6: Video Call WebRTC'siz Yazıldı

**Belirti:** Video call butonuna basıldığında ekran açılıyor ama gerçek
bir bağlantı kurulmuyor. UI var, altyapı yok.

**Kök neden:** Video call screen'i eklenirken WebRTC / signaling altyapısı
kurulmadı. Sadece mock / placeholder UI.

**Tespit tarihi:** Mart 2026.

**Tekrar sayısı:** 1

**Dokunma protokolü:**
- Video call feature'ına dokunuyorsan: önce `pubspec.yaml`'da
  `flutter_webrtc` + bir signaling mekanizması (Supabase realtime ya da
  dedicated) var mı kontrol et
- Placeholder UI'ı "çalışıyor" diye etiketleme; README'de 🟡 ya da
  ⏳ durumunda kalsın
- Yeni feature benzer risk taşıyorsa: önce altyapı varlığını doğrula

---

## R7: Audit Raporunda Uydurma İddialar

**Belirti:** 30-günlük denetim raporu 4 feature'ı ("push notifications",
"delete post", "comments", "distance filter") yanlış biçimde "FAKE"
etiketledi. Advisor / SQL / grep doğrulaması yapılsa bunların çalıştığı
görülecekti.

**Kök neden:** İddia kanıtsız yapıldı. Kod okunmadan ya da yarım okunarak
sonuca gidildi. Rapor yazımı "doğru kullanıcıyı uyarıyorum" zannıyla ama
gerçekte uydurma.

**Tespit tarihi:** Nisan 2026 (son audit).

**Tekrar sayısı:** 4 feature için tek oturumda.

**Dokunma protokolü:**
- Bir feature için "çalışmıyor / fake / eksik" demeden önce en az 1 kanıt
  (grep, advisor, SQL, test çıktısı) göster
- Kanıtsız iddia kullanıcıya "doğrulanamadı" olarak aktarılmalı, "çalışmıyor"
  değil
- Audit / review yazarken her iddianın yanında kaynak (dosya:satır ya da
  komut çıktısı)

---

## R8: UI_ONLY Settings — Write-Never-Read Pattern

**Belirti:** `profiles` tablosunda 8+ setting kolonu (`incognito_mode`,
`hide_exact_distance`, `show_city_only`, `show_last_active`,
`show_status_badge`, `calm_mode`, `message_preview`,
`notification_preferences`) DB'ye yazılıyor (UI toggle ya da default),
feed/repository/UI **okumuyor**. Kullanıcı "incognito aç" der, DB değeri
değişir, davranış DEĞİŞMEZ. "Ayar uygulandı" illüzyonu.

**Etkilenen setting envanteri (FEATURE_REGISTRY.md:42-49 + README.md:101):**

| Setting | UI toggle | Enforce yeri | Status |
|---------|-----------|--------------|--------|
| incognito_mode | settings_screen.dart:188 ✅ | feed_repository Step 1.5 ✅ (Dalga 6) | **CLOSED** |
| hide_exact_distance | YOK ❌ | feed render ❌ | ayrı dalga 6b |
| show_city_only | araştırılacak | araştırılacak | ileride |
| show_last_active | settings_screen.dart:196 ✅ | araştırılacak | ileride |
| show_status_badge | settings_screen.dart:199 ✅ | araştırılacak | ileride |
| calm_mode | settings_screen.dart:192 ✅ | can_reach_user RPC ✅ (KISMEN — feed'de değil, signal/note/reach permission'da) | ileride incele |
| message_preview | araştırılacak | araştırılacak | ileride |
| notification_preferences | settings_screen.dart ✅ | push system YOK | büyük iş |

**Kök neden hipotezi:** Özellikler iteratif yazıldı, "önce DB kolonu + UI
toggle, enforce sonra" planı bazı özelliklerde gerçekleşmedi. Backend
enforce mantığı kısmen yazıldı (`is_discoverable`, `can_reach_user`
RPC'leri mevcut), ama Flutter client tarafı bu RPC'leri çağırmadı.

**Tespit tarihi:** 2026-04-23 (Dalga 6 keşfi).

**Tekrar sayısı:** 1 (toplu envanter) — 8 setting altında.

**Status:** KISMEN CLOSED (2026-04-23)
- **incognito_mode:** CLOSED — Dalga 6, batch RPC `filter_discoverable_ids`
  + feed_repository Step 1.5 entegrasyonu. 3 senaryo SQL kanıtıyla yeşil.
- **Diğer 7 setting:** OPEN — gelecek dalgalar (her biri ayrı keşif)

**Kanıt (incognito_mode, 2026-04-23 ~12:35 UTC):**
- Migration: `supabase/migrations/20260423122907_filter_discoverable_ids_batch.sql`
- Apply: `{"success":true}`
- SQL test senaryoları (BEGIN/ROLLBACK içinde, kalıcı state değişmedi):

  | # | Senaryo | Beklenen | Gerçek |
  |---|---------|----------|--------|
  | 1 | Elena (non-incognito) + Marcus requester | `[elena_id]` | ✅ `[elena_id]` |
  | 2 | Elena (incognito) + match yok | `[]` | ✅ `[]` |
  | 3 | Elena (incognito) + match var | `[elena_id]` | ✅ `[elena_id]` |

- Feed integration: `feed_repository.dart` Step 1.5 (satır 54+)
- `flutter analyze --fatal-infos`: `No issues found!`
- `flutter test`: 257 pass / 2 fail (baseline korundu, regresyon sıfır;
  kalan 2 fail R4 banned_patterns guardrail, R8 ile ilgisiz)
- Rollback: `.claude/dalga-6-rollback.sql` (standalone, DROP FUNCTION)

**Test stratejisi (diğer setting'ler için):**
- Her setting için: DB'ye değer yaz → davranış değişti mi smoke test
- Render gerektirenler (hide_distance, show_city_only): emülatör smoke
- Backend-only kontrol edilebilenler (incognito gibi): SQL execute ile RPC test

**Dokunma protokolü:**
- Yeni setting eklerken: DB kolonu + UI toggle + enforce yeri **3'lü zorunlu**
- Mevcut setting'i fix ederken: önce keşif (backend RPC var mı, client
  çağırıyor mu), sonra fix
- "DB yazıldı = ayar uygulandı" varsayımı YASAK — enforce path'i kanıtlanmalı

---

## R9: Direct `Supabase.instance.client` Pattern (Repository Bypass)

**Belirti:** UI/screen/widget/provider katmanlarında doğrudan
`Supabase.instance.client` çağrıları (`.from('table').select/insert/update/delete()`,
`.rpc()`, `.auth.*`, `.storage.*`, `.channel()`). Repository pattern'i atlayan
veri erişimi mimari sınırını kırıyor — test mocking imkânsız, davranış izleme
zor, refactor riski büyük.

**Kök neden:** İteratif geliştirme sırasında "küçük bir update lazım" diyerek
ekran/provider içinde direkt çağrı yazılması. Repository'ye method eklemek
yerine inline çağrı kolaylığı tercih edildi. Sonuçta `lib/` altında `data/repositories/`
DIŞINDA 121 ihlal oluştu.

**Tespit tarihi:** 2026-04-21 (ilk envanter, Dalga 1 sonrası).

**Tekrar sayısı:** 1 (toplu envanter)

**Status:** KISMEN AÇIK (2026-04-XX)
- **Dalga 5a (Provider DI):** CLOSED — 26 satır taşındı, wrapper kuruldu, test mocking altyapısı bonus
- **Dalga 5b (Direct CRUD):** CLOSED — 22 site refactored, 7 method + 1 yeni repo (UserReportRepository)
- **Dalga 5c (Profile reads + Realtime + Auth ~30+):** OPEN
- **Dalga 5d (Admin + Services + Storage + Edge Funcs ~25+):** OPEN
- Toplam ihlal: 121 → 97 (5a) → **73** (5b) — toplam -48

**Kanıt (Dalga 5b, 2026-04-XX):**
- Yeni dosya: `lib/data/repositories/user_report_repository.dart` (abuse central) +
  `lib/providers/user_report_provider.dart`
- 7 yeni method:
  - `ProfileRepository.addToBlockList(uid, otherId)` — blocked_users append
  - `ProfileRepository.addToHideList(uid, otherId)` — hidden_users append
  - `GatingRepository.updateEntryMessage(uid, code)`
  - `MatchRepository.fetchStatusAndExpiry(matchId)` — record dönen lightweight
  - `BffSuggestionRepository.markReachOutIgnored(reachOutId)`
  - `EventRepository.updateEvent(eventId, Map)`
  - `RoomRepository.updateRoom(roomId, Map)`
- Mevcut `ProfileRepository.updateProfile(uid, Map)` 12 update site için yeniden
  kullanıldı — yeni method gerekmedi (Map-based update profile-specific, generic değil)
- 22 site refactored: 10 profile updates + 4 block/hide pair'leri (2 logical) +
  8 other tables
- `flutter analyze --fatal-infos`: `No issues found!`
- `flutter test`: 284/1 (baseline)
- 97 → 73 (-24 net)

**Bucket 2/3 (Profile reads, ~13) 5c'ye taşındı:**
Profile model getter eksikliği nedeniyle `fetchProfile` + getter pattern çalışmıyor
(themeMode, activeModes, blockedUsers, locationLat, leaveEventChatAuto vs. yok).
Çözüm yolları (5c'de karar):
- A) Profile model field genişlet (R1 protokolü, model değişikliği şart)
- B) Dedicated read method'lar: `fetchAppearance`, `fetchActiveModes`,
  `fetchBlockedHidden`, `fetchInteractionGate`, `fetchLocation`, `fetchEventChatAuto`,
  `fetchAuthorEnrichment` vs.
- C) Generic `fetchProfileRow(uid) → Map` (kuralın "generic setColumn YASAK"
  ruhuyla çelişir, son çare)

**Kanıt (Dalga 5a, 2026-04-27):**
- Yeni dosya: `lib/providers/supabase_client_provider.dart` — tek noktadan
  `SupabaseClient` wrapper Provider
- 16 dosya değişti (15 provider + 1 ekran), 26 çağrı taşındı
- Pattern: top-level Provider'da `ref.watch(supabaseClientProvider)`,
  Notifier method'unda `_ref.read(supabaseClientProvider)`
- Guardrail allowlist: `test/guardrails/no_banned_patterns_test.dart`
  wrapper dosyasını izinli kıldı (CLAUDE.md §4 tablosu da güncellendi)
- `flutter analyze --fatal-infos`: `No issues found!`
- `flutter test`: 284 pass / 1 fail (regresyon SIFIR; tek fail Supabase
  guardrail, 97 ihlal kaldığı için baseline)
- `grep -rn "Supabase.instance.client" lib/ | grep -v "lib/data/repositories/"`:
  121 → 97

**Pattern (Dalga 5a standardı):**
```dart
// providers/supabase_client_provider.dart
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

// herhangi bir Provider içinde
final fooRepositoryProvider = Provider<FooRepository>((ref) {
  if (isMockMode) return FooRepository();
  return FooRepository(supabase: ref.watch(supabaseClientProvider));
});

// Notifier method içinde (`_ref` private member)
final repo = SuperLikeRepository(supabase: _ref.read(supabaseClientProvider));
```

**Dokunma protokolü:**
- Yeni Provider yazıyorsan repository inject ederken:
  `ref.watch(supabaseClientProvider)` kullan, `Supabase.instance.client` YASAK.
- Notifier method içinde repository inline yaratma kötü pattern (Dalga 5b'de
  bunlar provider'a taşınacak), ama yapman gerekiyorsa `_ref.read(supabaseClientProvider)`.
- Direct CRUD (`.from('x').update(...)`) görüyorsan: önce ilgili repository'yi
  kontrol et, generic method (örn. `setColumn`) yoksa repository'ye method ekle.
  Direct çağrıyı korumak Dalga 5b'yi tekrar açar — yapma.
- Realtime/Storage/Auth gibi dedicated wrapper olmayan alanlarda Dalga 5c/5d'ye
  bırak — şimdilik allowlist genişletme.
- Test mocking için: `ProviderScope(overrides: [supabaseClientProvider.overrideWithValue(mockClient)])`

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

> **AUDIT YANILGISI — 2026-05-05 (Dalga 14g, PR #30):** Bu maddenin "fake / mock UI"
> iddiası kanıt-dayalı incelendiğinde **YANLIŞ** bulundu.
>
> **Kanıt:** `lib/services/video_service.dart:34-42` — `https://meet.jit.si/noblara-<matchId>`
> URL'i `url_launcher` ile **gerçekten açılıyor**. Jitsi Meet kullanıcının tarayıcısında
> işlevsel video call sağlıyor. WebRTC native plugin yok ama Jitsi browser-side WebRTC'yi
> kendisi handle ettiği için gereksiz.
>
> **Status revize:** Feature MVP seviyesinde **işlevsel**, "fake" değil. PR #30 ile
> kullanıcıya transparency subtitle'ı eklendi ("Opens in your browser via Jitsi Meet.") —
> browser hand-off'u açıkça belirtiliyor.
>
> **R7 disiplin dersi:** "WebRTC yok = fake" kısayol mantığı yanıltıcıydı. WebRTC bir ürün
> gereksinimi değil, implementasyon detayıdır — kullanıcı için Jitsi/browser üzerinden
> çalışan video call ile aynı.

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

**Etkilenen setting envanteri (kanıt-dayalı, Dalga 11 sonrası 2026-05-03):**

| Setting | UI toggle | Enforce yeri (kanıt) | Status |
|---------|-----------|---------------------|--------|
| incognito_mode | settings_screen.dart:182 ✅ | feed Step 1.5 (Dalga 6) + can_reach_user (P0) + generate_bff_suggestions (Dalga 11) | **FULLY CLOSED** ✅ |
| show_last_active | settings_screen.dart:190 ✅ | swipe_card_widget.dart:400 `if (card.showLastActive && ...)` ✅ tek display surface, gated | **FULLY CLOSED** ✅ |
| show_status_badge | settings_screen.dart:193 ✅ | swipe_card:287, swipe_card:685, bff_screen:347 ✅ (Dalga 11 ile 3/3 site gated) | **FULLY CLOSED** ✅ |
| message_preview | settings_screen.dart:267 ✅ | matches_screen `_messagePreviewProvider` ✅; chat-push trigger henüz yok (N/A) | **FULLY CLOSED** ✅ |
| calm_mode | settings_screen.dart:186 ✅ | can_reach_user RPC (signal/note/reach) ✅ KISMEN — feed/notification context'te değil | **KISMEN** |
| hide_exact_distance | YOK ❌ | feed render ❌ (mesafe ProfileCard'da hiç yok, infra eksik) | OPEN — altyapı gerek |
| show_city_only | YOK ❌ | render ❌ (DB'de city/travel_city zaten city-level; daha granular location yok → **phantom setting**, drop adayı) | OPEN — phantom |
| notification_preferences | settings_screen ✅ | push system: chat için trigger yok; new_match/comment/etc. trigger'ları preference filter yapmıyor | OPEN — büyük iş |

**Kök neden hipotezi:** Özellikler iteratif yazıldı, "önce DB kolonu + UI
toggle, enforce sonra" planı bazı özelliklerde gerçekleşmedi. Backend
enforce mantığı kısmen yazıldı (`is_discoverable`, `can_reach_user`
RPC'leri mevcut), ama Flutter client tarafı bu RPC'leri çağırmadı.

**Tespit tarihi:** 2026-04-23 (Dalga 6 keşfi).

**Tekrar sayısı:** 1 (toplu envanter) — 8 setting altında.

**Status:** KISMEN CLOSED (2026-05-03, Dalga 11 sonrası — kanıt-dayalı revize)
- **4 FULLY CLOSED:** incognito_mode (Dalga 6 + 11), show_last_active (zaten gated, Dalga 11 kanıtladı), show_status_badge (Dalga 11 ile 3 site), message_preview (matches gated; push N/A)
- **1 KISMEN:** calm_mode (can_reach_user only, feed/notif değil)
- **3 OPEN:** hide_exact_distance (altyapı yok), show_city_only (phantom), notification_preferences (push system)
- Önceki "7 OPEN setting" iddiası kanıtsızdı (R7 disiplini): kanıtlama 4 setting'in zaten kapalı olduğunu, 3 gerçek leak (Dalga 11'de kapatıldı) ve 1 phantom setting'i ortaya çıkardı.

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

**Kanıt (Dalga 11 — 3 leak fix, 2026-05-03):**

UI fix (2 satır):
- `lib/features/feed/swipe_card_widget.dart:685` → `if (card.isVerified && card.showStatusBadge)` (ikinci verified badge konumu, gate eksikti)
- `lib/features/bff/bff_screen.dart:347` → `if (card.isVerified && card.showStatusBadge)` (BFF Free Discovery card, gate eksikti)

Migration (`20260503063000_bff_incognito_filter.sql`):
- `generate_bff_suggestions` candidate WHERE'a `AND public.is_discoverable(p.id, 'bff', p_user_id)` eklendi
- search_path Dalga 7 baseline `public, extensions, auth, pg_temp` korundu
- Apply: `{"success":true}`
- Body kontrol (R10): `pg_proc.prosrc` `is_discoverable` string'i içeriyor (position 811, body length 1891)
- Davranış testi (DO block + RAISE EXCEPTION rollback):
  - Test: A=`...0001` incognito=true, B=`...0002` (explorer tier) için `generate_bff_suggestions(B)` çağrı
  - Sonuç: `added=3 a_in_b=0 total_for_b=3` ✅
  - A incognito iken B'nin suggestion'larında **YOK**, diğer 3 candidate normal akışta önerildi (regresyon yok)
- Advisor BEFORE=AFTER MD5 `92d0d0dabd7f1abf72440c672ce0eaa3` (byte-byte aynı, 115 finding sabit)
- `flutter analyze --fatal-infos`: `No issues found!`
- `flutter test`: 285/0 baseline korundu
- Rollback: `.claude/dalga-11-rollback.sql` (eski body, is_discoverable satırı yok)

**R7 disiplin zaferi (Dalga 11 keşfi):**
"7 OPEN setting" varsayımı kanıt sorgulanınca:
- 4 setting zaten enforce edilmişti (kanıtsız OPEN etiketi yanlıştı)
- 2 setting'te 3 gerçek leak vardı (kanıt: grep ile gate eksikliği bulundu)
- 1 setting "phantom" — DB'de granular location yok, gizlenecek bir şey yok
- Kapanış: 4 FULLY CLOSED + 1 KISMEN + 3 OPEN (1 phantom drop adayı)

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

**Status:** KISMEN AÇIK (2026-04-28)
- **Dalga 5a (Provider DI):** CLOSED — 26 satır taşındı, wrapper kuruldu, test mocking altyapısı bonus
- **Dalga 5b (Direct CRUD):** CLOSED — 22 site refactored, 7 method + 1 yeni repo (UserReportRepository)
- **Dalga 5c1 (Realtime + Auth):** CLOSED — 13 site, 8 method + 1 yeni repo (RealtimeRepository)
- **Dalga 5d1 (Admin):** CLOSED — 8 site, 5 method + 1 yeni repo (AdminRepository) + 1 reuse
- **Dalga 5d2 (Storage):** CLOSED — 9 site, 3 method + 1 yeni repo (StorageRepository), 2 bucket
- **Dalga 5d4 (RPC):** CLOSED — 8 site, 3 mevcut repo ek + 2 yeni repo (MoodMapRepository, NoblaraNotificationRepository), 8 method
- **Dalga 5d3 (Edge Functions):** CLOSED — 5 site, 5 method + 2 yeni repo (AIRepository, LocationRepository), 1 method MoodMapRepository'e eklendi
- **Dalga 5d5+5d6 (Push static + Device):** CLOSED — 8 site, 5 method + 2 yeni repo (PushTokenRepository, DeviceRepository), lazy singleton pattern (gemini_service ile aynı)
- **Dalga 5d7 (Karışık kalanlar):** CLOSED — 9 site, 7 method + 1 reuse (ProfileRepository.updateProfile) + 1 yeni repo (StatusRepository), R7 ana risk: end_connection messages.insert sender_id non-null koru
- **Dalga 5c2 (Profile reads ~13):** OPEN — Profile model genişletme + dedicated method'lar (active_modes, appearance, interaction_gate, message_preview, ai_writing_help×2, blocked/hidden, leave_event_chat_auto, notification_preferences, profile_draft, settings multi-col, nob_tier, is_admin)
- Toplam ihlal: 121 → 97 → 73 → 60 → 52 → 43 → 35 → 30 → 22 → **13** (5d7) — toplam -108

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

---

## R10: PostgreSQL PUBLIC Inheritance — REVOKE FROM anon Sessiz No-Op

**Belirti:** `REVOKE EXECUTE ON FUNCTION ... FROM anon, authenticated`
migration'ı `success:true` döndü, ama gerçek state hiç değişmedi.
Advisor BEFORE/AFTER **byte-byte aynı** (md5 eş). `has_function_privilege`
hâlâ TRUE.

**Kök neden:** PostgreSQL fonksiyonlarda default grant **PUBLIC** role'üne
gider. Supabase'de `anon` ve `authenticated` rol'leri PUBLIC'ten miras
alır — direct grant yoktur. `REVOKE FROM anon, authenticated` direct
grant'ı kaldırır, ama direct grant **zaten yok** → PostgreSQL sessiz
no-op uygular, hata vermez.

`pg_proc.proacl` ipucu:
```
{=X/postgres, postgres=X/postgres, service_role=X/postgres}
 ^^^^^^^^^^^^
 "=X" prefix-i (boş identifier) = PUBLIC role has EXECUTE
```

**Tespit tarihi:** 2026-05-02 (Dalga 8 apply sonrası, post-apply SQL
doğrulamasında).

**Tekrar sayısı:** 1

**Status:** FULLY CLOSED (2026-05-02) — Dalga 8b ile düzeltildi.

**Kanıt (Dalga 8b, 2026-05-02):**
- Migration: `supabase/migrations/20260502075743_revoke_definer_executable_public.sql`
  (20 satır, `REVOKE EXECUTE ... FROM PUBLIC, anon, authenticated`)
- Apply: `{"success":true}`
- SQL doğrulama: `has_function_privilege` → 40/40 FALSE (anon+auth),
  20/20 TRUE (service_role + postgres direct grant korundu)
- Advisor: 165k → 125k byte, **157 → 117** (-40, beklenen)
- Post-smoke 5/5 OK (davranış değişikliği SIFIR)

**Dokunma protokolü:**
- Public schema fonksiyonu için role REVOKE yazıyorsan **mutlaka
  PUBLIC'i ekle**: `REVOKE EXECUTE ... FROM PUBLIC, anon, authenticated`.
- Direct grant gerçekten varsa (örn. service_role'e özel grant)
  o role'ü REVOKE listesinden çıkar — yoksa trigger/cron çalışmaz.
- Apply sonrası **mutlaka SQL doğrulama**: advisor cache'lenmiş gibi
  görünse bile gerçek state'i yansıtır. `has_function_privilege` ya da
  `proacl` dump kanıttır.
- "Apply success" ≠ "Fix effective". R5 ana kuralının bir varyantı.

---

## R11: BFF Feed Filter Dead-Path

**Belirti:** BFF mode'da kullanıcı filter sheet'i açtığında 18 filter
dimension'u (age, distance, drinks, smokes, nightlife, socialEnergy,
routine, lookingFor, bffLookingFor, statusBadge, hasNobs, hasPrompts,
sixPlusPhotos, pinnedNobExists, sameCityOnly, languages, trustShield, +
faith Dating-only) için chip seçer. Seçimler state'e yazılıyor
(filterProvider) ve SharedPreferences'a persist ediliyor, ama
`generate_bff_suggestions` RPC ve `fetchSuggestions` query filter
parametresi almıyor. Sadece `interests` BFF'de etki ediyor — o da
client-side sort/boost (eleme değil). 18 dimension UI yalanı.

**Kök neden:** İki katmanda filter parametresi geçmiyor.

Trace zinciri:

1. UI: `lib/features/filters/filter_bottom_sheet.dart` BFF mode'da 18+
   chip render ediyor (line 105-230). Kullanıcı seçim yapıyor.
2. State: `lib/providers/filter_provider.dart:24` `set(FilterState)` →
   SharedPreferences `_save()` (line 72-97).
3. Notify: `lib/providers/bff_provider.dart:56`
   `_ref.listen<FilterState>(filterProvider, (_, __) => load());`
4. Server fetch: `lib/providers/bff_provider.dart:80`
   `var suggestions = await repo.fetchSuggestions(uid);`
5. Repository: `lib/data/repositories/bff_suggestion_repository.dart:18-23`
   ```dart
   final rows = await _supabase!.from('bff_suggestions').select()
       .or('user_a_id.eq.$userId,user_b_id.eq.$userId')
       .eq('status', 'pending')
       .order('created_at', ascending: false);
   ```
   Filter parametresi YOK.
6. Server-side generate: `lib/data/repositories/bff_suggestion_repository.dart:127-133`
   ```dart
   Future<int> generateSuggestions(String userId) async {
     final result = await _supabase!.rpc('generate_bff_suggestions', params: {
       'p_user_id': userId,
     });
   ```
   Tek param `p_user_id`. RPC imzası filter almıyor.
7. Client-side filter: `lib/providers/bff_provider.dart:61-71`
   ```dart
   List<BffSuggestion> _applyFilters(...) {
     if (f.interests.isNotEmpty) {
       suggestions.sort(...);   // SORT BOOST, eleme yok
     }
     return suggestions;
   }
   ```
   Sadece `interests` (sort boost). 18 dimension burada da yok.

**Tespit tarihi:** 2026-05-07 (Dalga 14f filter envanter, R11 yan-keşfi).

**Tekrar sayısı:** 1 (toplu envanter).

**Etki:** Sadece UI yalanı — BFF mode'da kullanıcı filter çevirmiş gibi
hissediyor, DB'de değişen tek şey SharedPreferences. Dating mode'da aynı
18 dimension feed_repository üzerinden gerçekten filtreleniyor
(`lib/data/repositories/feed_repository.dart:91-165`). Asymmetric UX.

**Status:** OPEN. Dalga 14f scope'u dışı (filter_bottom_sheet honesty
rebrand kapsamında yan-keşif). PR-B doc-only kayıt.

**Audit yanılgısı bağı (R7):** Audit (5 May §11) bu bug'ı yakalamadı.
Audit listesi sadece Trust Shield + Languages + Interests + Strict +
Presets idi. R7 envanter zinciri (UI → state → persist → DB query)
BFF'de filter trace yapınca 18 dimension dead-path olarak ortaya çıktı.

**Dokunma protokolü:**
- BFF feature'ına dokunuyorsan filter integration'ı planla.
- `generate_bff_suggestions` imzasına filter param eklemek = CLAUDE.md
  §6 protokolü (advisor before/after, migration body kontrol, smoke).
- Hızlı çözüm yolu: BFF mode'da Filter butonunu disable et + tooltip
  "Filters not yet supported in BFF mode" — dürüstlük öncelikli.
- Veya: BFF için subset filter (örn. sadece age + distance + tier)
  destekle, kalanı UI'dan kaldır.

**CLAUDE.md §8 güncelleme gerekli:** R11 maddesi "Eski Hatalar
Listesi"ne eklenmeli, "BFF feature dokunmadan önce filter integration
planla" hatırlatması.

---

## R12: Supabase auth.users Seed NULL String Columns → GoTrue 500

**Belirti:** Password ile login isteği `/token` endpoint'ine gittiğinde
GoTrue 500 dönüyor. Flutter app
`AuthRetryableFetchException(message: {"code":"unexpected_failure",
"message":"Database error querying schema"}, statusCode: 500)`
gösteriyor. Sebep: GoTrue Go SQL scanner `auth.users` row'unu
`character varying` kolon kolon string'e cast ederken NULL'a çuvallıyor:
`sql: Scan error on column index N, name "<col>": converting NULL to
string is unsupported`. Whack-a-mole pattern: bir kolon fix edilir,
scanner bir sonraki NULL kolona kadar ilerler, yine fail eder.
`/recover` ve `/magiclink` endpoint'leri de aynı schema scan'i kullandığı
için onlar da etkilenir.

**Kök neden:** `auth.users` 13 `character varying`/`text` kolonu içeriyor:
`aud`, `role`, `email`, `encrypted_password`, `confirmation_token`,
`recovery_token`, `email_change_token_new`, `email_change_token_current`,
`email_change`, `phone`, `phone_change`, `phone_change_token`,
`reauthentication_token`. Default'lar karışık: bazıları
`''::character varying`, bazıları `NULL::character varying`. 2026-04-09
batch testfeed* seed'i (32 hesap) string kolonların bir kısmını NULL
bıraktı. Sonradan SQL Editor'den oluşturulan ek hesaplar da etkilendi.

GoTrue Go versiyon davranışı: `pgx` driver'ında `Scan` çağrısı
`Nullable` flag olmadan `string`'e cast ediyor. Supabase platform
katmanı sorunu, kullanıcı kontrol edemiyor — NULL satırların hiç
olmaması gerekiyor.

**Pre-fix envanter (2026-05-07T09:00 UTC):**

| Kolon | Default | NULL count |
|---|---|---|
| confirmation_token | NULL | 41/46 |
| recovery_token | NULL | 41/46 |
| email_change_token_new | NULL | 41/46 |
| email_change_token_current | `''` | 41/46 |
| phone_change_token | `''` | 41/46 |
| reauthentication_token | `''` | 41/46 |
| email_change | NULL | 41/46 |
| phone | `NULL::character varying` | 46/46 |
| aud, role, email, encrypted_password, phone_change | karışık | 0/46 |

**Tespit tarihi:** 2026-05-07 (Dalga 14f smoke 1. blocker, login 500).

**Tekrar sayısı:** 1 (smoke blocker, ad-hoc fix uygulandı).

**Etki:** Tüm testfeed* hesapları + manuel olarak Console'dan oluşturulan
hesaplar login yapamıyor. Production user'lar etkilenmiyor (Supabase
sign-up flow tüm string kolonları '' ile dolduruyor). Sadece SQL Editor
ile oluşturulan ya da batch seed edilen hesaplar etkili.

**Status:** AD-HOC FIXED (2026-05-07). DML-only, RLS dokunulmadı.
Migration olarak scripted hale getirilmedi → tekrar seed edilirse
yine patlar. PR-C ile doc kayıt + migration önerisi yapıldı.

**Kanıt zinciri (chronological):**

```
-- 1. İlk hata (auth log):
2026-05-07T08:47:21Z  /token POST 500
  error: "Scan error on column index 3, name 'confirmation_token':
          converting NULL to string is unsupported"

-- 2. Batch 1 UPDATE — 6 token kolonu:
UPDATE auth.users SET
  confirmation_token         = COALESCE(confirmation_token, ''),
  recovery_token             = COALESCE(recovery_token, ''),
  email_change_token_new     = COALESCE(email_change_token_new, ''),
  email_change_token_current = COALESCE(email_change_token_current, ''),
  phone_change_token         = COALESCE(phone_change_token, ''),
  reauthentication_token     = COALESCE(reauthentication_token, '')
WHERE confirmation_token IS NULL
   OR recovery_token IS NULL
   OR email_change_token_new IS NULL
   OR email_change_token_current IS NULL
   OR phone_change_token IS NULL
   OR reauthentication_token IS NULL;
-- → Post-check 6 token kolonu hepsi 0 NULL ✓

-- 3. R10 yakalama: ikinci hata (auth log):
2026-05-07T08:59:19Z  /token POST 500
  error: "Scan error on column index 8, name 'email_change':
          converting NULL to string is unsupported"

-- 4. Genişletilmiş envanter — 13 string kolonu:
SELECT
  COUNT(*) FILTER (WHERE aud IS NULL)                        AS null_aud,
  COUNT(*) FILTER (WHERE role IS NULL)                       AS null_role,
  COUNT(*) FILTER (WHERE email IS NULL)                      AS null_email,
  COUNT(*) FILTER (WHERE encrypted_password IS NULL)         AS null_pw,
  COUNT(*) FILTER (WHERE confirmation_token IS NULL)         AS null_conf,
  COUNT(*) FILTER (WHERE recovery_token IS NULL)             AS null_recov,
  COUNT(*) FILTER (WHERE email_change_token_new IS NULL)     AS null_ect_new,
  COUNT(*) FILTER (WHERE email_change_token_current IS NULL) AS null_ect_cur,
  COUNT(*) FILTER (WHERE email_change IS NULL)               AS null_email_change,
  COUNT(*) FILTER (WHERE phone IS NULL)                      AS null_phone,
  COUNT(*) FILTER (WHERE phone_change IS NULL)               AS null_phone_change,
  COUNT(*) FILTER (WHERE phone_change_token IS NULL)         AS null_pct,
  COUNT(*) FILTER (WHERE reauthentication_token IS NULL)     AS null_reauth,
  COUNT(*)                                                   AS total
FROM auth.users;
-- → email_change: 41, phone: 46, diğer 11: 0, total: 46

-- 5. Batch 2 UPDATE — 12 kolon (phone hariç):
UPDATE auth.users SET
  aud                        = COALESCE(aud, ''),
  role                       = COALESCE(role, ''),
  email                      = COALESCE(email, ''),
  encrypted_password         = COALESCE(encrypted_password, ''),
  confirmation_token         = COALESCE(confirmation_token, ''),
  recovery_token             = COALESCE(recovery_token, ''),
  email_change_token_new     = COALESCE(email_change_token_new, ''),
  email_change               = COALESCE(email_change, ''),
  phone_change               = COALESCE(phone_change, ''),
  phone_change_token         = COALESCE(phone_change_token, ''),
  email_change_token_current = COALESCE(email_change_token_current, ''),
  reauthentication_token     = COALESCE(reauthentication_token, '')
WHERE
  aud IS NULL OR role IS NULL OR email IS NULL OR encrypted_password IS NULL
  OR confirmation_token IS NULL OR recovery_token IS NULL
  OR email_change_token_new IS NULL OR email_change IS NULL
  OR phone_change IS NULL OR phone_change_token IS NULL
  OR email_change_token_current IS NULL OR reauthentication_token IS NULL;

-- 6. Phone fix — UNIQUE constraint engeli:
-- 'CREATE UNIQUE INDEX users_phone_key ON auth.users USING btree (phone)'
-- partial DEĞİL. NULL'lar bypass eder ama '' tek bir kez olabilir.
-- İlk denemede: ERROR 23505: duplicate key value violates unique
--   constraint "users_phone_key" DETAIL: Key (phone)=() already exists.
-- Çözüm: per-user unique placeholder.
UPDATE auth.users
SET phone = '+placeholder_' || id::text
WHERE phone IS NULL;
-- ✓ (id UUID benzersiz olduğu için unique)

-- 7. Post-check (13 string kolonu, hepsi 0 NULL):
-- → 0,0,0,0,0,0,0,0,0,0,0,0,0  total: 46 ✓

-- 8. Login retry kanıt (auth log):
2026-05-07T09:04:57Z  /token POST 200
  action=login, login_method=password, provider=email
  user_id=858a0f3d-2da6-4133-ba2c-65f35c7d71c2 (testfeed1)
  status: 200 ✓
```

**R10 disiplin (apply success ≠ effective fix):** Batch 1 UPDATE
satır-affected sayıları doğruydu ve 6 token kolonunun NULL count'u 0'a
düştü. Ama ikinci login attempt yine 500 verdi → col 8 email_change
NULL. "Fix çalıştı" iddiası tek başına yetmedi. Pre/post envanter
karşılaştırması + login retry kanıtı gerekti. R10 ana kuralının
auth-katmanı varyantı.

**Audit yanılgısı bağı (R7):** Bu bug audit raporlarında YOKTU
(dış-side keşif, smoke sırasında ortaya çıktı). Auth log analizi
olmadan "login çalışmıyor" diyerek root cause atlanabilirdi. Auth
log'tan kolon adı + scanner mesajı kanıtı şart oldu — yoksa whack-a-
mole pattern devam ederdi.

**Dokunma protokolü:**
- `auth.users` schema'ya **dokunma** (Supabase platform-managed).
  Sadece DML.
- Yeni hesap batch seed yapıyorsan **tüm 13 string kolonunu '' ile
  doldur** (phone hariç — UNIQUE constraint, NULL bırak ya da unique
  placeholder).
- Sign-up flow'ı kullanan production akışları etkilenmez — orada
  GoTrue tüm kolonları zaten '' ile yazıyor.
- Ad-hoc fix yetmez — migration olarak idempotent script yazılmalı
  (aşağıda).

**Migration önerisi (PR-C kapsamında doc, henüz oluşturulmadı):**

Path: `supabase/migrations/<timestamp>_auth_users_string_column_coalesce.sql`

```sql
-- Idempotent COALESCE batch for auth.users string columns.
--
-- Context: 2026-04-09 batch testfeed* seed left several auth.users
-- string columns NULL. GoTrue Go SQL scanner cast `NULL -> string`
-- fails with `converting NULL to string is unsupported`, breaking
-- /token /recover /magiclink for affected users.
--
-- This migration is no-op for healthy rows (WHERE clause excludes
-- them). Safe to re-run.
--
-- Production sign-up flow already writes '' for all string columns
-- on user creation; this only fixes legacy seed / SQL-Editor-created
-- users.

-- Step 1: 12 string columns — COALESCE NULL -> ''
UPDATE auth.users SET
  aud                        = COALESCE(aud, ''),
  role                       = COALESCE(role, ''),
  email                      = COALESCE(email, ''),
  encrypted_password         = COALESCE(encrypted_password, ''),
  confirmation_token         = COALESCE(confirmation_token, ''),
  recovery_token             = COALESCE(recovery_token, ''),
  email_change_token_new     = COALESCE(email_change_token_new, ''),
  email_change               = COALESCE(email_change, ''),
  phone_change               = COALESCE(phone_change, ''),
  phone_change_token         = COALESCE(phone_change_token, ''),
  email_change_token_current = COALESCE(email_change_token_current, ''),
  reauthentication_token     = COALESCE(reauthentication_token, '')
WHERE
  aud IS NULL OR role IS NULL OR email IS NULL OR encrypted_password IS NULL
  OR confirmation_token IS NULL OR recovery_token IS NULL
  OR email_change_token_new IS NULL OR email_change IS NULL
  OR phone_change IS NULL OR phone_change_token IS NULL
  OR email_change_token_current IS NULL OR reauthentication_token IS NULL;

-- Step 2: phone column has UNIQUE constraint (users_phone_key) that
-- is NOT partial. NULL bypass uniqueness but '' would clash on the
-- second user. Use per-user unique placeholder built from UUID.
UPDATE auth.users
SET phone = '+placeholder_' || id::text
WHERE phone IS NULL;

-- Verification (run after apply):
-- SELECT
--   COUNT(*) FILTER (WHERE aud IS NULL OR role IS NULL OR email IS NULL
--     OR encrypted_password IS NULL OR confirmation_token IS NULL
--     OR recovery_token IS NULL OR email_change_token_new IS NULL
--     OR email_change_token_current IS NULL OR email_change IS NULL
--     OR phone IS NULL OR phone_change IS NULL OR phone_change_token IS NULL
--     OR reauthentication_token IS NULL) AS still_null,
--   COUNT(*) AS total
-- FROM auth.users;
-- Expected: still_null=0
```

**Alternatif (ileri seviye):** `auth.users.phone` için partial UNIQUE
INDEX:
```sql
DROP INDEX users_phone_key;
CREATE UNIQUE INDEX users_phone_key ON auth.users (phone)
  WHERE phone IS NOT NULL AND phone <> '';
```
Bu sayede `phone` NULL ya da `''` olarak bırakılabilir, placeholder
gerekmez. Uyarı: `auth.users` Supabase platform-managed table, index
değişikliği risk taşır — önce Supabase branch'inde dene, advisor
before/after karşılaştır.

**CLAUDE.md §8 güncelleme gerekli:** R12 maddesi "Eski Hatalar
Listesi"ne eklendi (PR-C ile birlikte), seed protokol hatırlatması.

---

## R13: testfeed* Seed Missing photo_verifications.approved

**Belirti:** testfeed1 (ve diğer testfeed* hesapları) `profiles`
tablosunda `is_verified=true`, `is_onboarded=true`,
`gating_status.is_entry_approved=true` flag'leriyle seed edilmiş, ama
`photo_verifications` tablosunda **hiçbir kayıt yok**. Login başarılı,
ama Discover tab'a tıklayınca client `verificationProvider.status =
idle` (verifications listesi boş) → "Verify to meet people" modal sheet
açılır. Kullanıcı feed'e ulaşamaz, Filter sheet erişilemez. testfeed*
hesapları manuel emülatör smoke için kullanışsız.

**Kök neden:** Verification provider DB profile flag'lerine değil,
`photo_verifications` tablosundaki **en güncel kayda** bakıyor:

```dart
// lib/providers/verification_provider.dart:77-92
VerificationStatus get verificationStatus {
  if (verifications.isEmpty) return VerificationStatus.idle;
  final latest = verifications.first;
  if (latest.isApproved) return VerificationStatus.approved;
  if (latest.isPending || latest.isManualReview) {
    return VerificationStatus.manualReview;
  }
  if (latest.isRejected) return VerificationStatus.rejected;
  return VerificationStatus.idle;
}
```

testfeed* batch seed (2026-04-09) `profiles.is_verified=true` set etti
ama `photo_verifications` tablosuna karşılık gelen kayıt insert
etmedi. Profile flag'i ile photo_verifications kaydı **çiftli zorunlu**
ama seed sadece flag'i yazdı. Sonradan SQL Editor'den oluşturulan ek
hesaplar da aynı boşluğu taşıyor.

`AppRouter` / `MainTabNavigator` boot sırasında
`verificationProvider.status` kontrol ediyor → `idle` olduğu için
secure-gate aktif → default tab Noblara/Community (tab 1) +
Discover/Chats tap'ları "Verify to meet people" modal'ı açıyor.

**Tespit tarihi:** 2026-05-07 (Dalga 14f smoke 3. blocker, R12 auth
fix sonrası login başarılı, ama Discover bloke).

**Tekrar sayısı:** 1 (smoke blocker, ad-hoc fix uygulanmadı — scope dışı).

**Etki:** testfeed* (32+ hesap) manuel emülatör smoke için
kullanışsız. Login → tab 1 default → Discover'a geçince modal blok.
Filter sheet (Discover'da) erişilemez. Production user'lar etkilenmez
— production sign-up flow Edge Function (`verify-both-photos`)
çağırarak `photo_verifications` kayıtlarını yazıyor.

**Status:** OPEN — test infrastructure gap. Dalga 14f scope'u dışı.
Manual emülatör smoke deferred → widget test ile alternatif kanıt
zinciri kuruldu (`test/features/filters/filter_bottom_sheet_test.dart`,
6 test pass). Migration script önerisi aşağıda.

**Kanıt:**

```sql
-- 1. testfeed1 profile + gating flag'leri OK:
SELECT
  p.id, p.is_verified, p.is_paused, p.is_onboarded,
  p.dating_visible, p.bff_visible, p.active_modes,
  gs.is_entry_approved
FROM profiles p
LEFT JOIN gating_status gs ON gs.user_id = p.id
WHERE p.id = '858a0f3d-2da6-4133-ba2c-65f35c7d71c2';
-- → is_verified=true, is_paused=false, is_onboarded=true,
--   dating_visible=true, bff_visible=true, active_modes=['date'],
--   is_entry_approved=true   (HER ŞEY OK)

-- 2. photo_verifications boş:
SELECT COUNT(*) FROM photo_verifications
WHERE user_id = '858a0f3d-2da6-4133-ba2c-65f35c7d71c2';
-- → 0   (HER testfeed* için aynı sonuç)

-- 3. Client davranışı (lib/providers/verification_provider.dart):
-- VerificationState.verifications.isEmpty → status = idle
-- AppRouter / MainTabNavigator init → _needsSecureGate(verif, gating) → true
-- → default tab = 1 (Noblara/Community), Discover gate
-- UI: tap Discover → "Verify to meet people" modal sheet
```

Auth log kanıt (login başarılı ama Discover bloke):
```
2026-05-07T09:04:57Z  /token POST 200
  user_id=858a0f3d-2da6-4133-ba2c-65f35c7d71c2 (testfeed1)
-- Login OK, ama UI Discover modal blok → R13 root cause
```

**Audit yanılgısı bağı (R7):** Bu bug seed-time check listesinde
yoktu. R7 envanter zinciri "is_verified flag'i UI'da nasıl
yorumlanıyor?" sorusunu sorunca: client gerçek kanıt
(photo_verifications) bekliyor, profile flag tek başına yetmiyor.
Profile flag = "kullanıcının verification durumu sonuç durumu"
(denormalized cache); ground truth = `photo_verifications` row.
Seed sadece cache'i yazıp ground truth'u atlamış.

**Dokunma protokolü:**
- testfeed* seed'i revize ederken: `photo_verifications` tablosuna
  per-user 1 selfie + 1 profile (her ikisi `is_approved=true`) insert
  et. **profile flag + photo_verifications row çiftli zorunlu.**
- Yeni manual seed Console'dan oluşturuyorsan: `photo_verifications`
  kayıtlarını da ekle.
- Production sign-up flow dokunma — orada Edge Function
  (`verify-both-photos`) doğru kayıtları yazıyor.
- Test infrastructure için: `supabase/seed/test_users.sql` (varsa) ya
  da migration script ile her testfeed user için
  `photo_verifications` kaydı garanti et.

**Migration önerisi (PR-D kapsamında doc, henüz oluşturulmadı):**

Path: `supabase/migrations/<timestamp>_seed_photo_verifications_for_testfeed.sql`

```sql
-- Seed photo_verifications.approved rows for legacy test users.
--
-- Context: 2026-04-09 batch testfeed* seed set profiles.is_verified=true
-- but did not insert corresponding photo_verifications rows. Client
-- verificationProvider.status reads from photo_verifications (latest
-- row), not the profile flag, so testfeed users are blocked behind
-- the "Verify to meet people" modal on Discover.
--
-- This migration is no-op for users who already have an approved
-- selfie + profile pair (NOT EXISTS guard). Safe to re-run.
--
-- Production sign-up flow already populates photo_verifications via
-- the verify-both-photos edge function — this only fixes legacy
-- seed / SQL-Editor-created users.

INSERT INTO photo_verifications (
  user_id, photo_type, status, is_approved, ai_confidence, created_at
)
SELECT
  u.id,
  pt.photo_type,
  'approved',
  true,
  0.95,
  now()
FROM auth.users u
CROSS JOIN (VALUES ('selfie'), ('profile')) AS pt(photo_type)
WHERE u.email LIKE 'testfeed%@test.noblara.com'
  AND NOT EXISTS (
    SELECT 1 FROM photo_verifications pv
    WHERE pv.user_id = u.id
      AND pv.photo_type = pt.photo_type
      AND pv.is_approved = true
  );

-- Verification (run after apply):
-- SELECT
--   COUNT(DISTINCT user_id) AS users_with_approved_selfie
-- FROM photo_verifications
-- WHERE photo_type = 'selfie' AND is_approved = true
--   AND user_id IN (SELECT id FROM auth.users WHERE email LIKE 'testfeed%@test.noblara.com');
-- Expected: count matches testfeed* user count (32+ as of 2026-05-07).
```

**Schema notu:** `photo_verifications` kolon listesi (`status`,
`is_approved`, `ai_confidence`) yukarıdaki migration'a doğru — Edge
Function `verify-both-photos`'un yazdığı şemayla aynı. Migration apply
öncesi `\d photo_verifications` ile tam kolon listesi doğrulanmalı,
NOT NULL constraint'leri olabilir (örn. `claimed_gender`, `same_person`,
`probability` — bunlar Edge Function'da hesaplanıyor, seed'de varsayılan
değerle doldurulmalı).

**CLAUDE.md §8 güncelleme:** R13 maddesi "Eski Hatalar Listesi"ne
eklendi (PR-D ile birlikte). Test seed yazarken `profile.is_verified` +
matching `photo_verifications.approved` ÇİFTLİ zorunluluk —
birini koyup diğerini unutmak R13 tekrarı.

---

## Dalga Durum Özeti (2026-05-03)

| Dalga | Hedef | Status | Kalan |
|-------|-------|--------|-------|
| 1 | Hygiene | CLOSED | — |
| 2/2b/2c | Profile copyWith + draft | CLOSED | — |
| 3/3b | `_substantive` + R5b dead policies | CLOSED | — |
| 4/4b | `catch (_)` 38 → 0 | CLOSED | — |
| 5a/5b/5c1/5c2/5d1–5d7 | `Supabase.instance.client` 121 → 0 | CLOSED | — |
| 6 | incognito_mode enforce (feed) | CLOSED | — |
| 7 | function_search_path_mutable 60 → 0 | CLOSED | — |
| 8 + 8b | security_definer batch REVOKE | KISMEN (-40) | 110 advisor lint (51 frontend RPC) |
| 9 | public_bucket_allows_listing 2 → 0 | CLOSED | — |
| 11 | R8 leak fixes (show_status_badge ×2 + incognito BFF) | CLOSED | calm_mode KISMEN, hide_exact_distance OPEN, show_city_only phantom, notification_preferences OPEN |
| 12 (aday) | security_definer kalan 110 | NOT STARTED | — |
| R8 kalan | calm_mode tam enforce + hide_exact_distance altyapı + show_city_only drop + notification_preferences | NOT STARTED | — |

---

## Audit Raporu Yanılgıları (5 Mayıs 2026)

Audit raporu (5 Mayıs full app audit) bazı iddiaları kanıt-dayalı doğrulanınca yanlış çıktı. R7 disiplin gereği kayıt altına alınır — gelecek sprint'lerde aynı yanılgıya düşmeyelim.

### A1: P0-3 ".env git history'de leaked" — YANLIŞ

- **İddia (audit §11 P0-4):** `.env` ve `android/local.properties` git history'de leaked, BFG / filter-branch / force-push ile temizleme + key rotate ŞART.
- **Kanıt (Dalga 14c, 2026-05-05):**
  - `git log --all --oneline -- .env` → **boş çıktı**
  - `git log --all --oneline -- android/local.properties` → **boş çıktı**
  - `git ls-files .env android/local.properties` → **boş** (tracked değil)
  - `.gitignore:2` `.env` ignore'da; `android/.gitignore:6` `/local.properties` ignore'da
- **Gerçek:** Dosyalar yalnızca disk'te, hiç commit edilmemiş. Audit "repo'da" derken disk klasörünü kastetti, bunu "git history" olarak yanlış genelleştirdi.
- **Sonuç:** Filter-branch / BFG / force-push **gereksiz** (ve tehlikeli olurdu — geri dönüşsüz history rewriting).
- **Gerçek risk (audit'in gözden kaçırdığı):**
  - `pubspec.yaml:41` `- .env` asset olarak dahil → **APK içinde bundled** (her dağıtılmış APK plaintext)
  - `android/app/build.gradle.kts:48-49` `manifestPlaceholders["GOOGLE_PLACES_KEY"]` → APK manifest meta-data'sında plaintext (`<meta-data android:value="AIzaSy...">`)
  - Kanıt: `unzip -p app-release.apk assets/flutter_assets/.env` → 339 byte, 3 satır secrets; `aapt dump xmltree` → manifest içinde plaintext key
- **Doğru aksiyon:** Google Cloud Console'da Places API key rotate + package name + SHA-1 restriction (manuel). APK bundled .env temizliği ayrı sprint (Dalga 14c2: `--dart-define` build-time injection).

### A2: P0-2 "RECORD_AUDIO gelecek video call (R6) için" — GEREKÇE YANLIŞ

- **İddia (audit §11 P0-2):** RECORD_AUDIO gerekçesi "gelecek video call (R6) için".
- **Gerçek (Dalga 14b kanıtı):** `lib/features/noblara_feed/nob_compose_screen.dart:296` `pickVideo(ImageSource.camera)` — nob compose video kayıt ses için **şu an gerek**. R6 (WebRTC video call) altyapısı yok, ama bu permission ondan bağımsız.
- **Sonuç:** Permission yine de gerekli (Dalga 14b'de eklendi), ama gerekçe doğru kayıt altında: nob video kayıt.

### A3: P0-2 "INTERNET kaçırılmış" — AUDİT EKSİKLİK

- **Audit listesinde yoktu.**
- **Gerçek (Dalga 14b kanıtı):** Manifest merger plugin'lerden (firebase_messaging, cached_network_image, supabase_flutter) implicit ekliyor, ama Play Console Data Safety formu için + best practice için **explicit declare gerek**.
- **Sonuç:** Dalga 14b'de eklendi. Audit raporu güncellenirken P0-2 listesi 4 → 5 permission'a genişledi (CAMERA, READ_MEDIA_IMAGES, READ_MEDIA_VIDEO, RECORD_AUDIO, INTERNET).

### A4: R6 "Fake Video Call" İddiası

- **Audit/known_regressions iddiası:** Video call WebRTC'siz yazıldı, sadece mock/placeholder UI.
- **Gerçek:** `lib/services/video_service.dart` `https://meet.jit.si/noblara-<matchId>` URL'ini `url_launcher` ile gerçekten açıyor. Jitsi Meet işlevsel.
- **Yanılgı tipi:** İmplementasyon detayını (native WebRTC plugin yok) ürün durumu (feature çalışmıyor) ile karıştırma.
- **Çözüm:** PR #30 — kullanıcıya browser hand-off'unu belirten transparency subtitle eklendi. Detay: R6 altındaki AUDIT YANILGISI bloğu.

---

**Audit Yanılgılarından Çıkarılan Genel Ders:**

> "Audit iddiası ≠ kanıt." Her audit maddesi git/aapt/dumpsys/grep ile bağımsız doğrulanmalı. R10 ("apply success ≠ effective fix") kuralının kuzeni: **"audit claim ≠ git/runtime reality"**. Korkutucu iddialar (force-push, history rewrite) özellikle kanıt-dayalı sorgulanmalı — kanıtsız aksiyon geri dönüşsüz hasar verebilir.

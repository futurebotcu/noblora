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
kullanıcı cevaplarını da eliyordu.

**Tespit tarihi:** 1 kez (canlıda, kullanıcı raporladı).

**Tekrar sayısı:** 1 (canlı etki)

**Dokunma protokolü:**
- `profile_screen.dart:94-106` civarındaki `_substantive` benzeri helperlar'a
  dokunurken: önce mevcut kullanıcı verisini mock'la, filtre sonrası
  korunduğunu doğrula
- "Boş göstermemek" için eklenen filtreler, gerçek veriyi de eliyor mu
  kontrolü zorunlu

---

## R4: `catch (_)` Sessiz Fail — Distance Filter Örneği

**Belirti:** Feed'deki mesafe filtresi yanlış değer gösterdi. Kullanıcı
10km seçti, 200km uzakta profiller düşüyordu.

**Kök neden:** `feed_repository` içinde `catch (_)` exception'ı sessizce
yuttu. Konum alınamadığı durumda default değer kullanılıyor ama
kullanıcıya hiç sinyal verilmiyordu.

**Tespit tarihi:** 1 kez.

**Tekrar sayısı:** 1

**Dokunma protokolü:**
- `catch (_)` kullanılamaz (CLAUDE.md §4 yasak). `catch (e, st)` + log + UI surface
- `test/guardrails/no_banned_patterns_test.dart` bu kuralı CI'da zorlar
- Konum, mesafe, filtre hesaplamalarında fail-silent yerine
  "bilinmiyor" göster

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

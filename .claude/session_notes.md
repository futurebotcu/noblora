# Session Notes

Her oturum açılışında bu dosyaya bir kayıt açılır. İlk 3 adım CLAUDE.md'deki
"Oturum Açılış Ritüeli"ni takip eder.

---

## 2026-04-20 — Gözetim Sistemi Kurulumu

### Bu oturumda dokunulan alanlar
- `.claude/` klasörü kurulumu (4 boş şablon dosya)
- CLAUDE.md proje anayasası (9 başlık + hızlı referans)
- `.claude/known_regressions.md` (R1–R7 kayıtları)
- `test/guardrails/no_banned_patterns_test.dart` (4 subtest)
- `test/guardrails/profile_roundtrip_guardrail_test.dart` (146 subtest)
- `.github/workflows/validate.yml` (analyze + test + apk build)
- `.claude/current_violations.md` (ihlal envanteri + düzeltme dalgaları)
- README.md tam yeniden yazım
- Memory düzeltmesi: MEMORY.md'deki stale P0 migration index satırı

### Oluşturulan / güncellenen dosyalar
- **Yeni:** `CLAUDE.md` (155 satır)
- **Yeni:** `.claude/known_regressions.md` (son halinde ~165 satır; R5 audit düzeltmesiyle genişledi)
- **Yeni:** `.claude/done_log.md` (14 satır şablon)
- **Yeni:** `.claude/todos.md` (13 satır şablon)
- **Yeni:** `.claude/session_notes.md` (bu dosya)
- **Yeni:** `.claude/current_violations.md` (172 satır)
- **Yeni:** `test/guardrails/no_banned_patterns_test.dart` (134 satır)
- **Yeni:** `test/guardrails/profile_roundtrip_guardrail_test.dart` (237 satır)
- **Yeni:** `.github/workflows/validate.yml` (45 satır)
- **Yeniden yazıldı:** `README.md` (207 satır, önceki 75 satır "Next Phase"
  yanıltıcı sürümünün yerine)
- **Güncellendi:** `~/.claude/projects/C--dev-noblara/memory/MEMORY.md`
  (P0 migration index satırı stale → "applied-but-ineffective")

### Kırmızı bayraklar (envanterden)
- **Banned pattern ihlali:** 171 toplam
  - `catch (_)`: 48
  - `// ignore: unused_*`: 2
  - Dış alanda `Supabase.instance.client`: 121 çağrı / 46 dosya
- **Profile roundtrip:** 146 subtest → **+43 pass / -103 fail**
  - copyWith'te kaybolan: 36 / 72 alan
  - toJson → fromJson'da kaybolan: 67 / 73 alan
- **500+ satır dosya:** 25 adet (en büyüğü 1868 satır)
- **Bu oturumda yaşanan sistem-yakalaması:** README P0 migration satırını
  "pending" diye yazdım — kanıtsız, eski memory index'ine dayanarak.
  Kullanıcı düzeltti, CLAUDE.md §9 ihlali olarak işaretledi. Memory
  index + README + known_regressions R5 üçlüsü senkronize edildi.

### Guardrail test durumu (ilk run)
- `no_banned_patterns_test.dart`: ❌ +1 / -3 (TODO test passed; diğer 3 fail)
- `profile_roundtrip_guardrail_test.dart`: ❌ +43 / -103

**Bu kasıtlı.** Testler envanteri görünür kılıyor; düzeltme sonraki oturumlara.

### CI durumu
- `.github/workflows/validate.yml` oluşturuldu, henüz remote'a push edilmedi.
- İlk push sonrası GitHub Actions sekmesinde `validate` workflow'u
  guardrail testlerini çalıştıracak ve kırmızı dönecek (171 banned + 103
  roundtrip fail). Bu renk düzeltmeler merge edilene kadar kırmızı kalmalı
  — fix'in somut kanıtı.

### Sonraki oturumda yapılacak (öneriler, kullanıcı onayı bekliyor)

1. **Dalga 1 — Hijyen (düşük risk):**
   - 3 `// ignore:` kaldır
   - `// ignore: unused_*` 2 ihlali için `profile_screen.dart:46,48`
     alanlarını kullan ya da sil
   - En mekanik 10 `catch (_)` → `catch (e, st)` + debug log (davranış
     değişmeden, log ekleme)

2. **Dalga 2 — Profile model fix (R1/R2 kapanır):**
   - `Profile.copyWith` 73 alanı da kapsayacak şekilde genişlet
   - `Profile.toJson` full profil + `profile_data` nested JSONB üretsin
   - `profile_roundtrip_guardrail_test.dart` yeşil olana kadar itere et
   - Guardrail yeşile döndüğünde commit + push

3. **Dalga 3 — RLS hardening migration (R5 kapanır):**
   - Baseline: `mcp__supabase__get_advisors(type=security)` kayıt
   - Migration: eski `*_system WITH CHECK (true)` policy'leri DROP et
   - Yeni restrictive policy'lerin yerinde kaldığını doğrula
   - Post-migration advisor → yan yana karşılaştırma
   - Kullanıcıya iki çıktıyı side-by-side sun

Hangi dalga ile başlayacağımız kullanıcı kararı. CLAUDE.md §5'e göre
scope creep yok — bir dalga bitmeden sonrakine geçme.

---

## 2026-04-21 — Dalga 1 Hijyen + CI Fix

### Hedef (scope limiti bu 3 madde)
1. CI'daki flutter analyze failure'ı çöz
2. 3 adet // ignore: kullanımını kaldır
3. 10 mekanik catch (_) → catch (e, st) + debugPrint

### Kural
- Branch: dalga-1-hygiene (main'e push YOK)
- Her 3 değişiklikte: flutter analyze + flutter test çalıştır
- Emülatör smoke test gerekli noktalarda yapılacak
- Scope creep yasak — yukarıdaki 3 madde dışına çıkılmayacak
- Şüphede DUR, sor

### Risk haritası
- CI fix: sıfır risk (app dışı)
- ignore kaldırma: sıfır risk (unused field'lar)
- catch (_) düzeltme: düşük risk — catch BLOCK İÇİ DEĞİŞMEYECEK,
  sadece parametre değişecek + debugPrint eklenecek

### R-kod risk alanları (CLAUDE.md §8)
- **R3:** 3 `// ignore:`'in ikisi `profile_screen.dart:46,48` — dosya
  1677 satır, `_substantive` filter mahalli. Unused field'ları
  silmek davranış değiştirmez ama dosyaya dokunduk sayılır.
- **R4:** catch (_) listesinden seçilecek 10 örnekte
  `feed_repository.dart:49` (R4 olay mahalli) **hariç tutulacak** —
  orada davranış değişikliği gerekir, hijyen değil.
- **R7:** "CI fail çözüldü" iddiası kanıtsız yapılmayacak — local
  yeşil ≠ CI yeşil (aşağıya bakın).

### CI anomali — araştırma notu
- Run: https://github.com/futurebotcu/noblora/actions/runs/24676092155
- Fail eden adım: #7 `Static analysis` (`flutter analyze --fatal-infos`)
- Skipped: #8 test, #9 apk (önceki adım fail)
- Yerel repro denemesi:
  - `flutter --version` → 3.35.4 (CI ile aynı)
  - `flutter analyze --fatal-infos` → **"No issues found! (ran in 77.6s)"**
  - Commit: 17ecc26 (main tepesi, CI'ın koştuğu aynı SHA)
- Log zip indirme: HTTP 403 (anonim erişim yok, PAT gerek)
- **Durum:** Hata henüz görünür değil. Yerel yeşil, CI kırmızı.
  Olası nedenler (doğrulanmadı): `pub get` sonrası platform-specific
  warning (CI linux, local windows), `.dart_tool` cache farkı,
  `--fatal-infos` ile `info`-level uyarı CI'da tetikleniyor olabilir.
- **Plan:** kullanıcıdan GitHub PAT ya da log erişimi istenecek —
  yoksa "tahmin ederek fix" denenmeyecek (R7 tuzağı).

### CI fix uygulandı — milestone
- Kullanıcı CI UI'dan fail log'u yapıştırdı:
  `warning • The asset file '.env' doesn't exist • pubspec.yaml:41:7`
  `--fatal-infos` warning'i error'a çeviriyor → analyze red
- Yerel `.env` var (gitignore), CI temiz ortam → yok. Doğru davranış.
- Fix: `.github/workflows/validate.yml`'ye "Install dependencies"
  öncesi tek satır: `cp .env.example .env` (mock mode)
- Commit: **c2abef6** (dalga-1-hygiene)
- Push: `origin/dalga-1-hygiene`
- Workflow tetikleyici (`on: push: branches: [main, master]`) feature
  branch'ine reaksiyon vermedi — bugün keşfedildi. PR event'i ise
  target main olduğu için tetikleniyor.
- **PR #1** açıldı (draft, main ← dalga-1-hygiene), CI çalıştı.
- CI sonucu:
  - Static analysis: ✅ **yeşil** (ilk defa — fix tuttu)
  - Run tests: ❌ kırmızı, **80 pass / 106 fail**. Fail sayısı envanter
    beklentileriyle örtüşüyor (171 banned ihlal + 103 roundtrip — bir
    kısmı subtest gruplandırmasıyla 106'ya düşüyor). Yeni / beklenmedik
    fail yok.
  - Build APK: ⏭️ skipped (test fail → sonraki adımlar atlandı)
- Dalga 1 Adım 1 kapandı. Adım 2/3 devam ediyor.

### Dalga 1 kapanışı
- Commit'ler (hepsi `dalga-1-hygiene` branch'inde, PR #1):
  - `c2abef6` — ci: .env prepare
  - `f206764` — ADIM A: `_ViewerContext` match/stranger + stale yorum
  - `8fcbc45` — ADIM B: 10 mekanik catch (_) → catch (e, st) + debugPrint
- CI Run **24732202002** sonucu:
  - `.env` prepare: ✅, Install: ✅, Static analysis: ✅, Tests: ❌
    (beklenen — envanter kalanı), Build APK: ⏭️
- İhlal sayıları: `// ignore:` 3→1 (admin_screen.dart:575 kaldı, scope),
  `catch (_)` 48→38 (kalan 38 + 1 ignore Dalga 4'e ertelendi), roundtrip
  103 fail değişmedi (Dalga 2'de kapanacak).

## 2026-04-21 — Dalga 2: Profile copyWith Fix (R1 Kapatma)

### Hedef
`Profile.copyWith` eksik 36 alanı kapsayacak şekilde genişletilecek:
- 1 top-level: `lastActiveAt`
- 35 rich (profile_data nested): longBio, tagline, currentFocus, pronouns,
  wantsChildren, relationshipType, datingStyle, communicationStyle,
  loveLanguages, musicGenres, movieGenres, weekendStyle, humorStyle,
  sleepStyle, dietStyle, fitnessRoutine, workStyle, entrepreneurshipStatus,
  secondaryRole, socialEnergy, workIntensity, educationLevel,
  relocationOpenness, interestedIn, firstMeetPreference, buildingNow,
  industry, aiTools, socialMediaUsage, techRelation, travelStyle,
  livedCountries, wishlistCountries, prompts, visibility

### Kural
- Yalnızca `Profile.copyWith` değişiyor — constructor / fromJson / toJson
  korunuyor (toJson fix Dalga 2b'ye bırakıldı)
- Başarı ölçütü: `test/guardrails/profile_roundtrip_guardrail_test.dart`
  içindeki "copyWith preserves all fields" grubunda 36 test yeşile dönecek

### Risk
- R1 area: Profile modeli. CLAUDE.md §7 Model Protokolü uygulanacak
  (fromJson + toJson + copyWith + draft — bu dalgada sadece copyWith;
  fromJson zaten tam, toJson eksik ama Dalga 2b scope'unda).
- Dokunma: tek metod. Çevre dokunulmuyor.
- Paradigma tuzağı: mevcut `value ?? this.field` nullable paradigması —
  `null` geçilirse eski değer korunur, "null'a çevir" edemezsin. Bu
  mevcut davranış; değiştirmiyoruz (scope dışı).

---

## 2026-04-21 — Dalga 2b: Profile.toJson Fix (R1 Full Close + R2 Close)

### Hedef
`Profile.toJson` 5 alan → 73 alan'a genişletilecek:
- 37 top-level JSON key (38 alan, `userId` `id`'den türediği için tek key)
- 35 rich alan → `profile_data` nested JSONB Map'i içinde
- `PromptAnswer.toJson` metodu YAZILACAK (mevcut sınıfta yok — `prompts`
  alanının serialize edilebilmesi için gerekli; aynı dosya, ayrı sınıf)
- `visibility` `Map<String, String>` doğrudan yazılır

### Başarı ölçütü
- `profile_roundtrip_guardrail_test` toJson grubu: **67 fail → 0 fail**
- Full suite: 117/69 → **~184/2 beklenen** (sadece 38 catch_ + 1 ignore
  guardrail fail'leri kalır; copyWith/roundtrip grubunun tamamı yeşil)
- `flutter analyze --fatal-infos`: yeşil kalmalı
- Regresyon: sıfır

### Kural
- `Profile.toJson` + `PromptAnswer.toJson` (aynı dosya) değişecek
- `Profile.copyWith` dokunulmaz (Dalga 2'de yeşillendi)
- `Profile.fromJson` dokunulmaz (zaten 73 alanı okuyor)
- Constructor dokunulmaz
- Başka dosya YOK

### Risk
- R1 area — Profile modeli, yüksek hassasiyet
- Key eşleşmesi zorunlu: fromJson'un okuduğu her key toJson'da AYNEN
  üretilmeli. Tek harflik mismatch = sessiz veri kaybı.
- fromJson fallback key'leri (`full_name`, `hobbies`, `photos`, `mode`)
  toJson'da yazılmayacak — primary key'ler yazılır (`display_name`,
  `interests`, `photo_urls`, `current_mode`).
- Özel serializer: `lastActiveAt.toIso8601String()`, `nobTier.name`,
  `prompts.map((p) => p.toJson())`.

### R-kod çapraz referans
- R1 — copyWith half closed; bu dalga ikinci yarıyı kapatır.
- R2 — profile_draft ↔ fromJson asenkron; Profile.toJson fix'i
  aslında R2'nin de bir yüzüdür (draft da toJson üzerinden yazıyor
  olabilir). Dokunma protokolü §7 "fromJson + toJson + copyWith + draft"
  diyor — draft kodunu incelemek bu dalgada Görev 2, toJson fix'ten
  sonra. Eğer draft Profile.toJson'u çağırıyorsa R2 buradan kapanır;
  değilse ayrı mini-iş.

---

## 2026-04-21 — End of Day (Dalga 1 + 2 + 2b kapanış)

### Bugünün commit zinciri
- `0065791` — Dalga 1 (.env fix + 10 catch (_) logs + unused enum cleanup)
- `02bf129` — Dalga 2 (Profile.copyWith fix — 36 alan, R1 half closed, PR #2 merge)
- `9028441` — Dalga 2b session note (prep)
- `2feeb9e` — Dalga 2b fix (Profile.toJson 5 → 73 alan, R1 FULLY CLOSED)

### Branch durumu
- Aktif branch: `dalga-2b-profile-tojson`
- Uzaktaki hali: push edildi, tracking origin/dalga-2b-profile-tojson
- PR: YARIN açılacak (2026-04-22), bugün açılmadı
- Main: 2 commit geride (Dalga 2b henüz merge değil)

### Test skorları (tam yolculuk)
- Başlangıç (Dalga 1 öncesi): **80 pass / 106 fail**
- Dalga 1 sonrası: 90 / 96 (catch_ + enum ayıklaması)
- Dalga 2 sonrası: 117 / 69 (copyWith 36 alan)
- Dalga 2b sonrası: **184 pass / 2 fail** ← bugünün kapanış skoru
- Kalan 2 fail: tamamen beklenen — guardrail testleri (catch_ + ignore
  lint pattern'leri), Profile modeliyle ilgisi yok

### R1 — FULLY CLOSED (test seviyesinde)
- copyWith 36 alan yeşil (Dalga 2)
- fromJson zaten 73 alan okuyor (dokunulmadı)
- toJson 73 alan üretiyor (Dalga 2b)
- Roundtrip guardrail: tüm toJson grubu yeşil
- **Üretim path uyarısı:** Profile.toJson uygulamada profile yazımı
  için *doğrudan* çağrılmıyor — asıl yazım yolu `ProfileDraft`.
  Profile.toJson fix'i guardrail/DB write için doğru, ama kullanıcı
  akışındaki veri kaybı riski ProfileDraft kanadında.

### R2 — Yeniden tanımlandı
Eski tanım: "profile_draft ↔ fromJson asenkron, draft yazıyor
fromJson okumuyor". Dalga 2b esnasında kanıtla netleşti:
- Asıl asimetri `ProfileDraft` ile `Profile` arasında.
- Somut kanıt: `lookingFor` alanı. ProfileDraft tarafında bir şekilde
  korunuyor ama Profile ↔ draft çevriminde kaybolabilir (hipotez,
  guardrail ile doğrulanacak).
- R2'nin Profile.toJson fix'iyle kapandığı varsayımı **yanlıştı** —
  fix doğru ama R2'nin kök nedeni başka: ProfileDraft.toJson /
  fromJson / Profile.fromDraft / Profile.toDraft asimetri zinciri.

### Yarın: Dalga 2c planı
**Hedef:** ProfileDraft roundtrip guardrail + fix
- Görev A: `test/guardrails/profile_draft_roundtrip_test.dart` yaz
  (mevcut `profile_roundtrip_guardrail_test` deseninden çoğalt)
- Görev B: Her Profile alanı için `profile → draft → profile`
  roundtrip — alan kaybı varsa kırmızı
- Görev C: İlk çalıştırmadaki fail listesi = R2'nin tam yüzey alanı
- Görev D: Fail'leri ProfileDraft.toJson / fromJson / Profile.fromDraft
  / toDraft'ta kapat (§7 protokolü — 4'ünü de güncelle)
- Görev E: Guardrail yeşil → R2 FULLY CLOSED

**İlk adım (yarın sabah):**
1. CLAUDE.md + known_regressions.md oku
2. Bu branch'ten yeni branch aç: `dalga-2c-profile-draft`
3. ProfileDraft kodunu oku — hangi dosya, kaç alan, toJson/fromJson
   sınırı
4. Roundtrip guardrail test dosyasını yaz, kırmızı ölçümü al

### Bugünkü scope disiplini
- Plan: Profile.toJson tek fix
- Yapılan: Profile.toJson tek fix + session note
- Scope creep: YOK (3'lü limit aşılmadı)

---

## 2026-04-22 — Dalga 2c: ProfileDraft Asymmetry Fix (R2 FULLY CLOSE)

### Hedef
`ProfileDraft.toUpdateMap` ↔ `ProfileDraft.fromDbRow` asymmetry'lerini
kapat. Test-first yaklaşım: önce guardrail testi yaz (kırmızı ölç),
sonra DB kontratına saygılı fix uygula.

### Branch durumu (oturum başı)
- Aktif branch: `dalga-2c-profile-draft` (yeni, taze main `b044e2e`'den)
- Önceki yerel `dalga-2c-profile-draft` (base 02bf129) silindi → restart
- Eski `dalga-2b-profile-tojson` lokal+remote silindi (PR #3 merge edildi)
- Main: `b044e2e` (Dalga 2b PR #3 merge — Profile.toJson 73 alan dahil)

### DB kontrat raporu (mcp__supabase__execute_sql, public.profiles)
- `looking_for`: **`text`** (single-value) — top-level tek string
- `countries_visited`: **`text[]`** (ARRAY) — top-level liste, default `'{}'`
- `visited_countries`: YOK (kolon ismi `countries_visited` tek doğru)
- `profile_data`: `jsonb` — rich nested
- `interests` / `hobbies`: ikisi de `text[]` (legacy mirror canlı)
- `photo_urls` / `photos`: ikisi de `text[]` (legacy mirror canlı)

### Tespit edilen 2 kritik asimetri (test-öncesi analiz)
1. **`lookingFor`**: write doğru (row=first, pd=full list), read YANLIŞ
   (row öncelikli → tüm liste kaybolur, sadece first kalır).
   Fix: read precedence ters çevir — önce `pd['looking_for']`, sonra row fallback.
2. **`visitedCountries`**: write tamamen eksik (toUpdateMap'te yok),
   read doğru (`row['countries_visited']`). Fix: write top-level row
   key olarak ekle.

### Plan (test-first, 3 adım)
- **ADIM 1:** `test/guardrails/profile_draft_roundtrip_guardrail_test.dart`
  yaz. 73 alan subtest, sembolik dolu değerler. Çalıştır → 2 fail (lookingFor,
  visitedCountries) + 71 pass beklenen. Çıktıyı kullanıcıya göster.
- **ADIM 2:** Fix uygula:
  - `fromDbRow` lookingFor read precedence değişikliği
  - `toUpdateMap` visitedCountries top-level write ekle
  - Test tekrar çalıştır → 73/73 yeşil hedef
- **ADIM 3:** Commit + push + PR aç. URL'i kullanıcıya ver.

### Kural
- SADECE `lib/features/profile/edit/profile_draft.dart` + yeni test dosyası
- `Profile` modeline dokunulmuyor (R1 zaten kapalı, b044e2e ile)
- `profile_repository.dart`'a dokunmuyoruz
- Scope creep yasak — 3 madde dışına çıkılmıyor
- Her adımda kullanıcı onayı

### Risk
- R2 area — `ProfileDraft` canlı üretim path'i
- Test kırmızı olduğu sürece commit YOK
- DB kontratı netleşti — write kontratı korunuyor (`looking_for` text kalır)

### Bugün öğrenilen ders (işlenmesi)
- "PR #3 merge edildi" iddiasını kanıtsız kabul ettim, R7 tuzağına düştüm
  (oturum başında dalga-2b branch'ini sildim, neyse remote sağlamdı).
  Düzeltme: branch işlemlerinden önce `git ls-remote origin <branch>` +
  `git log origin/main` ile kanıt al. Sözlü iddia ≠ kanıt.

---

## 2026-04-22 — Dalga 3: RLS Hardening (R5 CLOSE)

### Hedef
P0 migration (20260408140730) "applied-but-ineffective" durumunu kapat.
Eski permissive `*_system WITH CHECK (true)` policy'leri DROP et.
Supabase security advisor `rls_policy_always_true` satırlarını temizle.

### Branch durumu
- Aktif branch: `dalga-3-rls-hardening` (yeni, main `8aa837f`'den)

### Kural (yasak listeleri)
- KOD YAZMA / MIGRATION YAZMA / ÇALIŞTIRMA — bu oturum **SADECE PLAN**
- Production tek environment (test yok)
- DROP sırası yanlış = anonim erişim açığı; rollback planı migration'dan önce
- Scope: 1 migration dosyası + advisor karşılaştırma + 3 rol smoke test
- catch (_) kalanları, R3, R6, function_search_path WARN'ları AYRI dalga

### ADIM 1 KEŞIF — kanıtlar

**A. Advisor baseline (security):** [tam çıktı raporda saklı]
- 1 ERROR: `spatial_ref_sys` RLS disabled (PostGIS sistem tablosu —
  Supabase platform sınırı, manuel düzeltilemez, kapsam dışı)
- 1 INFO: `_internal_config` RLS enabled no policy (TÜMÜ DENY = güvenli,
  service role bypass var, kapsam dışı)
- 9 WARN `rls_policy_always_true` ← **R5'in tam yüzeyi**
- 50+ WARN `function_search_path_mutable` (ayrı dalga, R8 adayı)
- 2 WARN `public_bucket_allows_listing` (galleries, profile-photos —
  storage policy fix, ayrı dalga)
- 1 WARN `extension_in_public` (postgis — platform sınırı)
- 1 WARN `auth_leaked_password_protection` (Supabase Auth ayarı)

**B. P0 migration body (`20260408140730` — `p0_security_fixes`):**
4 değişiklik içeriyor:
1. **B67** — `notifications_insert` policy DROP+CREATE (restrictive,
   `auth.uid() = user_id`). FAKAT eski `notifications_insert_system`
   (with_check=true) **DROP EDİLMEDİ**. PostgreSQL'de PERMISSIVE policy'ler
   OR ile birleşir → eski permissive olduğu için yeni restrictive ETKİSİZ.
   **R5'in tam kanıtı.**
2. **B71** — `can_reach_user` function paused/permission/calm_mode kontrolü
   (RLS değil, function logic; advisor'a değmez)
3. **B72** — `safe_advance_to_video` function status check (function logic)
4. **B44** — `expire-stale-matches` cron job (functional, RLS değil)

**C. Canlı `*_always_true` policy envanteri (advisor + pg_policies eşlemesi):**

| # | Tablo | Policy | CMD | with_check | qual | Yerine restrictive var mı? | Risk (DROP sonrası) |
|---|-------|--------|-----|------------|------|----------------------------|---------------------|
| 1 | conversation_participants | cp_insert_own | INSERT | true | - | YOK | HIGH — INSERT tamamen kilitlenir |
| 2 | conversations | conv_insert_own | INSERT | true | - | YOK | HIGH |
| 3 | gating_status | gating_insert_system | INSERT | true | - | YOK (handle_new_user_gating muhtemelen security definer) | MEDIUM (RPC bypass varsa OK) |
| 4 | gating_status | gating_update_system | UPDATE | true | true | YOK | MEDIUM |
| 5 | matches | matches_insert_system | INSERT | true | - | YOK (check_and_create_match security definer ise OK) | MEDIUM |
| 6 | notifications | **notifications_insert_system** | INSERT | true | - | **VAR — `notifications_insert` (auth.uid()=user_id, P0'dan)** | **LOW — P0 zaten doğru policy'i koymuş** |
| 7 | real_meetings | rm_insert_own | INSERT | true | - | YOK | HIGH |
| 8 | video_sessions | video_insert_own | INSERT | true | - | YOK | HIGH |
| 9 | video_sessions | video_update_own | UPDATE | true | true | YOK | HIGH |

### Asymmetry raporu
- **Sadece 1/9** policy için yerine konulacak restrictive zaten var
  (`notifications`). Geri kalan 8 için DROP öncesi yeni restrictive YAZILMALI,
  yoksa kullanıcı INSERT/UPDATE'leri canlıda kırılır.
- Adlandırma yanıltıcı: `cp_insert_own`, `conv_insert_own`, `rm_insert_own`,
  `video_insert_own` adlarında `_own` var ama mantığı yarım — `with_check=true`.
  Yarım yazılmış policy'ler.

### Migration stratejisi taslakları (ÜÇ alternatif, henüz YAZILMADI)

**Strateji A — Dar (sadece P0 bypass'ı kapat):**
- DROP `notifications_insert_system` (yerine restrictive zaten var)
- Diğer 8 ayrı dalgada
- Advisor temizliği: 1/9
- Risk: çok düşük
- R5'i "tam kapatmaz" ama P0'ın bıraktığı boşluğu kapatır

**Strateji B — Geniş (9 policy hepsi + her biri için yedek restrictive):**
- 8 yeni restrictive policy yaz (auth.uid() constraint mantığı her tablo için)
- 9 eski permissive DROP
- Sıra: önce CREATE yedekleri (overlap güvenli), sonra DROP eskileri
- Advisor temizliği: 9/9
- Risk: yüksek — her tablonun INSERT path'i doğrulamayı gerektirir
  (RPC mi client mi, security definer mı?)
- Smoke test 3 rol kritik

**Strateji C — Kod analizi sonrası geniş:**
- Önce data/repositories + supabase functions kodunda her tablonun
  INSERT/UPDATE path'i analiz et (RPC vs client direct)
- RPC ile yapan tablolar: DROP edilebilir, security definer bypass eder
- Client direct: yeni restrictive yaz, sonra DROP
- Sonra Strateji B'ye benzer migration
- En güvenli ama 1 oturuma sığmayabilir

### Rollback planı (taslak)
- Migration'ın TERS'i: DROP edilen policy'lerin orijinal CREATE metni
- Şu anki advisor verisi + pg_policies dump yedek olarak migration'ın
  başında comment olarak saklanmalı
- Rollback test: migration sonrası tek bir tabloda smoke test fail
  ederse rollback SQL'i hazır olmalı

### Bekleyen kullanıcı kararı
1. Hangi strateji? (A/B/C)
2. Geniş seçenekte (B/C): smoke test rol matrisi nasıl? Mevcut test user'lar
   var mı yoksa migration sırasında geçici user yaratıp test edip silmek mi?
3. Cron schedule (P0'daki B44) advisor'da görünmüyor; doğrulama gerek mi?

### Karar: Strateji A revize (kullanıcı onayı, 2026-04-22)
- İlk varsayım: tüm 9 policy "P0 bypass" hipotezi → SADECE notifications DROP
- Pre-smoke testleri varsayımı kırdı (R7 örneği — kanıtsız hipoteze körü körüne güvenmedik)

### ADIM 2.5/2.6 — Genişletilmiş pre-smoke (kanıt-bazlı envanter)
9 advisor satırından 7'si test edildi (notifications + matches önceden). Her senaryo:
authenticated=elena, target=other user, BEGIN/ROLLBACK içinde.

| # | Tablo.policy | Test sonucu | Durum |
|---|--------------|-------------|-------|
| 1 | notifications_insert_system | RLS reddetti | DEAD |
| 2 | matches_insert_system | RLS reddetti | DEAD |
| 3 | conversation_participants.cp_insert_own | RLS reddetti | DEAD |
| 4 | conversations.conv_insert_own | RLS reddetti | DEAD |
| **5** | **gating_status.gating_insert_system** | **FK error (RLS GEÇTİ)** | **AKTİF** |
| **6** | **gating_status.gating_update_system** | **BAŞARILI — elena trultruva is_verified UPDATE** | **AKTİF — KANITLI BYPASS** |
| 7 | real_meetings.rm_insert_own | RLS reddetti | DEAD |
| 8 | video_sessions.video_insert_own | RLS reddetti | DEAD |
| 9 | video_sessions.video_update_own | 0 row (SELECT match-bound visibility kapatıyor) | DEAD-eq (intra-match intentional) |

**Bulgu:** R5'in gerçek davranışsal yüzeyi 9 satırdan **2'si** (gating_status). Diğer 7
cosmetic — `polroles={0}` PostgreSQL quirk'i nedeniyle hiçbir role'e uygulanmıyor.

### Function security analizi (gating compatibility)

| Function | Security | Etki |
|----------|----------|------|
| handle_new_user_gating | DEFINER | Signup INSERT, RLS bypass — restrictive policy etkilemez |
| dev_auto_verify | DEFINER | Dev tool, RLS bypass — restrictive policy etkilemez |
| sync_is_verified | INVOKER | Profiles BEFORE trigger (selfie+photos→is_verified), gating'e değmez |

**Sonuç:** gating_status için `auth.uid() = user_id` restrictive yazsak otomatik
fonksiyonlar etkilenmez. Sadece direkt client-side kötü niyetli INSERT/UPDATE etkilenir.

### ADIM 2 (FİNAL) — Migration yazıldı (HENÜZ ÇALIŞTIRILMADI)
- Dosya: `supabase/migrations/20260422081824_rls_harden_notifications_and_gating.sql`
  (Önceki `20260422081824_drop_notifications_system_policy.sql` sile + yeniden adlandırıldı,
  timestamp prefix korundu.)
- 5 SQL komutu, atomik:
  1. CREATE `gating_insert_own` (auth.uid()=user_id, TO authenticated)
  2. CREATE `gating_update_own` (USING+WITH CHECK auth.uid()=user_id, TO authenticated)
  3. DROP `notifications_insert_system`
  4. DROP `gating_insert_system`
  5. DROP `gating_update_system`
- Sıra zorunlu: önce CREATE yedekler (overlap güvenli — eski permissive hâlâ true
  dönerken yeni restrictive eklenir), sonra DROP eskileri.
- Standalone rollback dosyası: `.claude/dalga-3-rollback.sql` (commit-yok, emergency için)

### R5b kapsam revizesi (5 policy, video_update_own dahil DEĞİL)
- matches_insert_system, cp_insert_own, conv_insert_own, rm_insert_own, video_insert_own
- video_update_own LİSTEDEN ÇIKARILDI — intra-match design intentional, SELECT
  policy match-bound olduğu için dış user erişemiyor zaten
- Aksiyon: Dalga 3b ayrı PR (toplu DROP, davranışsal risk yok, sadece advisor temizlik)

### ADIM 3 PLANI (apply onayı sonrası)
a) Pre-apply baseline advisor zaten kayıtlı
b) `mcp__supabase__apply_migration` ile uygula
c) Post-advisor: 3 cache_key (notifications + 2 gating) gitmeli
d) Post-smoke (kritik 2 senaryo + signup analog):
   - Test 4 re-run (gating UPDATE different user) → REDDEDİLMELİ
   - Test 3 re-run (gating INSERT random uuid) → REDDEDİLMELİ (RLS, FK öncesi)
   - Self gating UPDATE (elena→elena) → BAŞARILI
   - SECURITY DEFINER simülasyon (mümkünse `handle_new_user_gating` çağrı testi)
e) Davranış değişim tablosu pre vs post yan yana
f) Advisor karşılaştırma (3 WARN kaldırıldı kanıtı)
g) Hepsi yeşilse → ADIM 4 (commit) için kullanıcı onayı

### ADIM 3 SONUÇ — TÜMÜ YEŞİL (2026-04-22 06:15 UTC)

**Apply çıktısı:**
```
mcp__supabase__apply_migration(
  name="rls_harden_notifications_and_gating",
  query=<5 SQL statements>
) → {"success":true}
```

**Advisor diff (`rls_policy_always_true`): 9 satır → 6 satır**

| Cache key | Pre | Post |
|-----------|-----|------|
| notifications.notifications_insert_system | VAR | **YOK ✅** |
| gating_status.gating_insert_system | VAR | **YOK ✅** |
| gating_status.gating_update_system | VAR | **YOK ✅** |
| conversation_participants.cp_insert_own | VAR | VAR (R5b) |
| conversations.conv_insert_own | VAR | VAR (R5b) |
| matches.matches_insert_system | VAR | VAR (R5b) |
| real_meetings.rm_insert_own | VAR | VAR (R5b) |
| video_sessions.video_insert_own | VAR | VAR (R5b) |
| video_sessions.video_update_own | VAR | VAR (R5b — intra-match intentional) |

**3/3 hedef cache_key advisor'dan kayboldu.**

**Smoke test pre/post tablosu:**

| # | Senaryo | Pre-fix (06:00 UTC) | Post-fix (06:15 UTC) | Sonuç |
|---|---------|---------------------|----------------------|-------|
| (a) Test 4 | elena → trultruva gating UPDATE | ✅ BAŞARILI (`is_verified` toggle, RETURNING dolu — **BYPASS**) | 🔒 0 row affected (RLS USING qual filtreliyor) | **FIX KANITLI** |
| (b) Test 3 | elena → random uuid gating INSERT | ⚠️ FK error (RLS geçmişti — **BYPASS**) | 🔒 RLS violation (FK'ya varmıyor) | **FIX KANITLI** |
| (c) Self | elena → elena gating UPDATE | n/a | ✅ BAŞARILI (`updated_at=2026-04-22 06:15:08`) | **Restrictive policy doğru yazıldı** |

**R5 davranışsal kapanış kanıtı:**
- Cross-user UPDATE artık engelli (Test 4)
- Cross-user INSERT artık RLS reddi (Test 3)
- Self UPDATE çalışıyor (Test c)
- Apply atomik, regresyon sıfır
- 0 aktif kullanıcı esnasında deploy → kesinti riski yok

**Kalan R5b kapsam (teyit, 6 cosmetic policy):**
- conversation_participants.cp_insert_own
- conversations.conv_insert_own
- matches.matches_insert_system
- real_meetings.rm_insert_own
- video_sessions.video_insert_own
- video_sessions.video_update_own (intra-match — opsiyonel)

R5b ayrı PR (Dalga 3b) — sadece DROP, davranış değişmez, advisor temizlik.

**R5 ana — FULLY CLOSED (2026-04-22 06:15 UTC).**

---

## Sabah kapanış — 2026-04-22 09:30

**Bugünün net iki kazanımı:**
- R2 (ProfileDraft asymmetry, lookingFor + visitedCountries
  sessiz veri kaybı) tam kanıtlı fix
- R5 (gating_status cross-user UPDATE bypass) davranışsal kanıtlı
  fix, pre-smoke'da Elena → Trultruva is_verified toggle
  BAŞARILIYDI, post-smoke'da 0 row

**Bugünün iki R7 dersi:**
- Branch state iddiaları kanıtsız kabul edilmez (git ls-remote
  zorunlu)
- Advisor satırları hipotez yapar, pre-smoke test kanıt yapar.
  3/9 varsayımımız yanlış çıktı (aslında %66 dead, %22 aktif,
  %11 intentional). Pre-smoke olmadan yanlış fix yapılırdı.

**Yarın ilk 15 dakika:**
1. CLAUDE.md oku (anayasayı tazele)
2. known_regressions.md oku (R3, R4, R5b, R6 güncel kayıtlar)
3. session_notes.md son kayıt oku (bu rapor)
4. Dalga seçimi — A/B/C/D/E, taze kafayla tercih
5. Seçilen dalga için oturum açılış ritüeli (yeni session_notes
   kaydı + branch)

---

## 2026-04-23 — Dalga 3b: R5b Cosmetic Dead Policy Cleanup

### Hedef
5 cosmetic dead permissive policy DROP. Advisor temizlik. Davranış
değişmez (dün pre-smoke'da hepsi reddedilmişti — R5b kaydında kanıtlı).

### Branch durumu (oturum başı)
- Aktif branch: `dalga-3b-r5b-cleanup` (yeni, taze main `42aaf75`'ten)
- Main: up-to-date with origin (Dalga 3 PR #5 merge edilmiş)
- Working tree: dünün "Sabah kapanış" session_notes ekleri uncommitted,
  branch'a beraber taşındı

### Başarı ölçütü
- Migration: tek dosya, 5 `DROP POLICY IF EXISTS` komutu
- Advisor: `rls_policy_always_true` 6 → 1 WARN (5 hedef temizlenir,
  `video_update_own` kalır — intentional intra-match)
- Smoke test: opsiyonel (davranış değişmeyeceği zaten kanıtlı, R5b kaydı)
- Rollback: hazır olsun ama gereksiz beklenir

### Kural
- SADECE cosmetic DROP — kod dokunulmaz
- Yeni restrictive policy YAZMA (dead zaten, gerek yok)
- Scope creep yasak — 3 madde limiti
- CLAUDE.md §6 5 adım protokol uygulanacak (baseline → migration → post → side-by-side → "fix" tanımı)

### R5b target listesi
1. `matches.matches_insert_system` (INSERT)
2. `conversation_participants.cp_insert_own` (INSERT)
3. `conversations.conv_insert_own` (INSERT)
4. `real_meetings.rm_insert_own` (INSERT)
5. `video_sessions.video_insert_own` (INSERT)

`video_sessions.video_update_own` LİSTEDEN ÇIKARILDI — intra-match
intentional, SELECT match-bound (R5b kaydında kanıtlı).

### ADIM 1 KEŞIF — kanıt taze (2026-04-23)

**A. Advisor `rls_policy_always_true` (taze, beklendiği gibi 6 satır):**

| # | cache_key | Hedef mi? |
|---|-----------|-----------|
| 1 | `..._conversation_participants_cp_insert_own` | ✅ R5b |
| 2 | `..._conversations_conv_insert_own` | ✅ R5b |
| 3 | `..._matches_matches_insert_system` | ✅ R5b |
| 4 | `..._real_meetings_rm_insert_own` | ✅ R5b |
| 5 | `..._video_sessions_video_insert_own` | ✅ R5b |
| 6 | `..._video_sessions_video_update_own` | ❌ intentional, listede DEĞİL |

5/5 hedef cache_key advisor'da mevcut.

**B. pg_policies envanteri (5/5 mevcut):**

| Tablo | Policy | cmd | permissive | roles | qual | with_check |
|-------|--------|-----|------------|-------|------|------------|
| conversation_participants | cp_insert_own | INSERT | PERMISSIVE | {public} | null | true |
| conversations | conv_insert_own | INSERT | PERMISSIVE | {public} | null | true |
| matches | matches_insert_system | INSERT | PERMISSIVE | {public} | null | true |
| real_meetings | rm_insert_own | INSERT | PERMISSIVE | {public} | null | true |
| video_sessions | video_insert_own | INSERT | PERMISSIVE | {public} | null | true |

**Anomali notu:** R5b kaydı `polroles={0}` (PostgreSQL pg_policy ham OID
quirk) diyordu. `pg_policies` view ise `roles={public}` gösteriyor (OID 0
→ PUBLIC çevirisi). Görünüm farkı; davranışsal sonuç aynı (pre-smoke
RLS reddetti). DROP risksiz çünkü policy zaten etkili değil.

**Diğer advisor satırları (kapsam dışı, kayıt için):**
- 1 ERROR `spatial_ref_sys` (PostGIS sistem tablosu, platform sınırı)
- 1 INFO `_internal_config` RLS enabled no policy (deny-by-default güvenli)
- 60+ WARN `function_search_path_mutable` (R8 adayı, ayrı dalga)
- 1 WARN `extension_in_public` postgis (platform sınırı)
- 2 WARN `public_bucket_allows_listing` (galleries + profile-photos, ayrı dalga)
- 1 WARN `auth_leaked_password_protection` (Supabase Auth ayarı)
- 1 WARN `rls_policy_always_true video_update_own` (R5b'den çıkarıldı, intentional)

### ADIM 2 — Dosyalar yazıldı (apply YOK, kullanıcı onayı bekliyor)

**Timestamp seçimi:** `20260423105809` (UTC `date -u +%Y%m%d%H%M%S` çıktısı,
dünkü `20260422081824`'ten sonra).

**Yazılan dosyalar:**
- `supabase/migrations/20260423105809_drop_r5b_dead_policies.sql`
  - 5 `DROP POLICY IF EXISTS ... ON ...` komutu
  - Header: scope, evidence ref, SECURITY DEFINER not-relevant gerekçesi
  - Inline rollback (5 CREATE POLICY commented)
  - Footer: 5 advisor cache_key + beklenen post-apply sayım (6 → 1)
- `.claude/dalga-3b-rollback.sql`
  - 5 CREATE POLICY (orijinal permissive'leri geri yarat)
  - Header: use-case (rollback gereksiz beklenir, ama ihtiyat için var)

**Henüz yapılmadı:**
- Migration apply
- Post-apply advisor karşılaştırma
- Smoke test (opsiyonel, davranış değişmez beklenir)
- known_regressions.md R5b kaydını "CLOSED" işaretleme
- Commit + push + PR

### ADIM 3 PLANI (apply onayı sonrası)
a) `mcp__supabase__apply_migration` ile uygula
b) Post-advisor: 5 hedef cache_key gitmeli (6 → 1, sadece video_update_own kalır)
c) Side-by-side karşılaştırma raporu
d) Opsiyonel smoke (kullanıcı tercihi):
   - 5 tablonun her biri için authenticated cross-user INSERT denemesi
   - Hepsi RLS tarafından reddedilmeli (zaten ediyordu, kanıt tazeleme)
e) known_regressions.md R5b → CLOSED + Dalga 3 main entry'ye link
f) session_notes ADIM 3 sonuç tablosu
g) Commit + push + PR

### ADIM 3 SONUÇ — TÜMÜ YEŞİL (2026-04-23 ~10:58 UTC)

**Apply çıktısı:**
```
mcp__supabase__apply_migration(
  project_id="xgkkslbeuydbbcvlhsli",
  name="drop_r5b_dead_policies",
  query=<5 DROP POLICY IF EXISTS, 5 satır>
) → {"success":true}
```

**pg_policies post-check (5 hedef policyname):**
```sql
SELECT policyname, tablename, cmd FROM pg_policies
WHERE schemaname='public' AND policyname IN (5 hedef);
→ []   (boş — 5/5 DROP başarılı)
```

**Advisor `rls_policy_always_true` side-by-side (6 → 1):**

| # | Cache key | Pre (~10:58 UTC) | Post (~10:58 UTC) |
|---|-----------|------------------|-------------------|
| 1 | `..._conversation_participants_cp_insert_own` | VAR | **YOK ✅** |
| 2 | `..._conversations_conv_insert_own` | VAR | **YOK ✅** |
| 3 | `..._matches_matches_insert_system` | VAR | **YOK ✅** |
| 4 | `..._real_meetings_rm_insert_own` | VAR | **YOK ✅** |
| 5 | `..._video_sessions_video_insert_own` | VAR | **YOK ✅** |
| 6 | `..._video_sessions_video_update_own` | VAR | VAR (intentional, R5b dışı) |

**5/5 hedef cache_key advisor'dan kayboldu.** Beklenti tutmuş.

**Smoke test:** Skip — Dalga 3 pre-smoke (2026-04-22) ile 5 policy dead kanıtlı,
davranışsal değişim beklenmiyor, advisor count düşüşü + pg_policies boş çıktısı
tek kanıt olarak yeterli.

**Diğer advisor satırları değişmedi (R5b dışı, kapsam dışı):**
- 1 ERROR `spatial_ref_sys` (PostGIS, platform sınırı)
- 1 INFO `_internal_config` (deny-by-default güvenli)
- 60+ WARN `function_search_path_mutable` (R8 adayı, ayrı dalga)
- 1 WARN `extension_in_public postgis` (platform sınırı)
- 2 WARN `public_bucket_allows_listing` (galleries + profile-photos, ayrı dalga)
- 1 WARN `auth_leaked_password_protection` (Supabase Auth)

**R5b — FULLY CLOSED (2026-04-23 ~10:58 UTC).**

**RLS cephesi durumu (Dalga 3 + 3b kümülatif):**
- Başlangıç (2026-04-22 sabah): 9 `rls_policy_always_true` WARN
- Dalga 3 sonrası: 6 WARN (3 satır temizlendi — gating + notifications)
- Dalga 3b sonrası: **1 WARN** (5 satır temizlendi — R5b cosmetic)
- Kalan 1: `video_update_own` intentional (intra-match design)

**R-kod sayacı (Dalga 3b sonrası):**
- R1 ✅ FULLY CLOSED (Dalga 2 + 2b, test-level)
- R2 ✅ FULLY CLOSED (Dalga 2c)
- R3 ⏳ OPEN (profile_screen `_substantive` filter, ayrı dalga)
- R4 🟡 PARTIAL (10/48 catch_(_) düzeltildi Dalga 1, kalan 38 ayrı dalga)
- R5 ✅ FULLY CLOSED (Dalga 3)
- R5b ✅ FULLY CLOSED (Dalga 3b)
- R6 ⏳ OPEN (video call WebRTC altyapı)
- R7 disipliner — her oturumda kanıt-zorunlu, ayrı kayıt yok

---

## Akşam kapanış — 2026-04-23

### Bugün kapanan
- **R5b FULLY CLOSED** (Dalga 3b, 5 cosmetic dead policy DROP, PR #6 merge)

### Kümülatif R-kod durumu (4 gün)
- R1 ✅ FULLY CLOSED (Dalga 2 + 2b)
- R2 ✅ FULLY CLOSED (Dalga 2c)
- R3 AÇIK (`_substantive` filter prompts)
- R4 KISMEN (48 → 38 `catch (_)`)
- R5 ✅ FULLY CLOSED (Dalga 3)
- R5b ✅ FULLY CLOSED (Dalga 3b — bugün akşam)
- R6 AÇIK (Video WebRTC, büyük iş)
- R7 META (kanıt disiplini, her oturumda)

### Advisor RLS cephesi (gün boyu seyir)
- Başlangıçta (Dalga 3 öncesi): 9 `rls_policy_always_true` WARN
- Sabah (Dalga 3 sonrası): 6 WARN
- Akşam (Dalga 3b sonrası): **1 WARN** (`video_update_own` intentional)

### Main commit zinciri (6 PR squash commit)
- `6c36bf6` — Dalga 3b PR #6 (R5b CLOSED)
- `42aaf75` — Dalga 3 PR #5 (R5 CLOSED)
- `8aa837f` — Dalga 2c PR #4 (R2 CLOSED)
- `b044e2e` — Dalga 2b PR #3 (R1 toJson)
- `02bf129` — Dalga 2 PR #2 (R1 copyWith)
- `0065791` — Dalga 1 (.env + 10 catch logs)

### Test durumu
- 257/2 (değişmedi, bugünkü iş tamamen DB tarafıydı)
- Kalan 2 fail: guardrail (catch_ + ignore pattern envanteri, R4 kapsamında)

### R7 uyarısı (bugün)
gh CLI yoktu (bash + PowerShell ikisinde de bulunamadı).
Pre-filled URL ile çözüldü (compare URL + URL-encoded title/body).
Tekrarlanan manuel PR açma disiplinine devam. Token / `gh` kurulum
kararı Dalga 5 sonrasına ertelendi.

### Yarın için seçenekler (kararı taze kafayla ver)
A) **Dalga 4** — R4 catch (_) hijyeni (38 örnek, ~1-1.5 saat)
B) **Dalga 5** — Direct `Supabase.instance.client` çıkarma (121 çağrı / 46 dosya, 3-5 saat, 1 oturuma sığmaz, alt dalgalara böl)
C) **Dalga 6** — Feed incognito enforce (~45 dakika)
D) **Dalga 7** — Video WebRTC altyapı (R6, 1-2 hafta, ayrı sprint)

### Yarın ilk 15 dakika
1. CLAUDE.md oku
2. known_regressions.md oku (özellikle R3, R4, R6)
3. session_notes.md son kayıt oku (bu rapor)
4. Dalga seçimi (A/B/C/D)
5. Seçilen dalga için oturum açılış ritüeli (yeni session_notes kaydı + branch)

---

## 2026-04-23 15:00 — Dalga 6: Feed Incognito + Hide-Distance Enforce

### Hedef (keşif sonrası netleşti)
- `incognito_mode` toggle DB'ye yazılıyor (settings_screen direct SQL),
  feed query okumuyor → **incognito user'lar feed'e düşüyor (kullanıcıya
  illüzyon).** FEATURE_REGISTRY zaten UI_ONLY işaretlemiş.
- `hide_exact_distance` toggle DB'ye yazılıyor (kolon var,
  migration 20260401000004), feed UI okumuyor → **mesafe her zaman
  gösteriliyor.**

### Branch durumu
- Aktif branch: `dalga-6-feed-incognito-enforce` (yeni, main `6c36bf6`'tan)
- `git pull origin main` başarısız: DNS error (`Could not resolve host:
  github.com`) — internet/DNS geçici sorun. Lokal main `origin/main` ile
  zaten "up to date" görünüyor (pull öncesi status). Etkisi yok.
- Working tree: dünün akşam kapanış session_notes ekleri uncommitted,
  branch'a beraber taşındı.

### R-kod referans uyarısı (KULLANIN BİLDİRİLDİ)
Kullanıcı talimatında "(R6)" dedi ama known_regressions.md R6 = **Video
Call WebRTC** (büyük iş, ayrı sprint). Bu Dalga 6 farklı bir konu —
FEATURE_REGISTRY UI_ONLY settings sorunları için known_regressions'da
mevcut R-kod YOK. Kapanış için yeni R-kod (R8 önerisi) açmak gerekecek.
Karar plan onayında.

### ADIM 1 KEŞIF — kanıtlar (KOD YAZILMADI)

**A. R-kod kaydı durumu:**
- known_regressions.md'de bu konu için **KAYIT YOK**. R6 video call.
- Ancak `README.md:101` ve `FEATURE_REGISTRY.md:42-49` zaten dokumante:
  "Incognito mode | UI_ONLY | Yes (written) | Never read" + 8 benzer
  setting (calm_mode, show_city_only, hide_exact_distance, show_last_active,
  show_status_badge, message_preview, notification_prefs, delete_account).
- Bu Dalga 6 sadece **incognito + hide-distance** kapsıyor (kullanıcı
  scope'u). Diğer 6 UI_ONLY setting ileride.

**B. Settings nerede yazılıyor:**
- `lib/features/settings/settings_screen.dart:35-46` — `_load()` doğrudan
  `Supabase.instance.client.from('profiles').select(...)` yapıyor; 22 kolon
  okuyor (incognito_mode dahil).
- `:64-76` — `_save(column, value)` doğrudan
  `client.from('profiles').update({column: value})` ile her toggle'ı tek
  kolon yazıyor.
- `:188-191` — UI: `_Toggle('Incognito Mode', s['incognito_mode'], n.toggleBool('incognito_mode'))`,
  alt yazı: "Only connections can discover you" (söz vaadi var).
- **Hide-distance toggle ekranda YOK** — ne settings'te ne profile_edit'te.
  Kolon DB'de var (`hide_exact_distance`, migration 20260401000004:36)
  ama UI hiç toggle göstermiyor. **Bu sürpriz bulgu.**
- `lib/features/onboarding/onboarding_flow_screen.dart:153` — onboarding
  defaults `'incognito_mode': false` set ediyor.
- `lib/features/profile/edit/sections/visibility_section.dart` — bu
  AYRI bir sistem (profil alanlarının Public/Matches/Private dropdown'ı).
  Incognito/distance ile ilgisi YOK.

**C. DB kontratı (migration 20260401000004 + 20260401000011):**
- `profiles.incognito_mode` BOOLEAN NOT NULL DEFAULT FALSE
- `profiles.hide_exact_distance` BOOLEAN NOT NULL DEFAULT FALSE
- `profiles.show_city_only` BOOLEAN NOT NULL DEFAULT FALSE
- `profiles.show_last_active` BOOLEAN NOT NULL DEFAULT TRUE
- **RPC `is_discoverable(target_id, mode, requester_id)` SECURITY DEFINER
  MEVCUT** (migration 20260401000011:23-57):
  - is_paused → false döner
  - mode_visible (dating/bff/social) → false ise false
  - **incognito_mode → matches tablosunda
    (user1_id, user2_id) eşleşme yoksa false döner**
  - Tam mantık zaten yazılı, sadece feed çağırmıyor.

**D. Feed enforce yeri:**
- `lib/data/repositories/feed_repository.dart:63-70` — Step 2 query:
  ```dart
  var query = client.from('profiles').select()
      .eq('is_verified', true)
      .eq('is_paused', false)
      .eq(visibleCol, true)            // dating_visible/bff_visible/social_visible
      .filter('active_modes', 'cs', '{"$mode"}')
      .inFilter('id', toFetch.toList());
  ```
  - `is_paused`, `mode_visible` ✅ (ediyor)
  - **`incognito_mode` ❌ filtre YOK** ← bu boşluk
  - **`is_discoverable` RPC ❌ çağrılmıyor** (varlığından bihaber)
- `feed_repository.dart:49` — **R4 banned pattern `catch (_)`** (geo
  filter try). **Scope dışı, R4 hijyen dalgasına bırakılmalı.** Bugün
  dokunulmaz.

**E. Distance gösterimi yeri:**
- `lib/data/models/profile_card.dart:23-46` — privacy display alanları:
  `showCityOnly`, `showStatusBadge`, `showLastActive` ProfileCard'ta var
  ve `fromDb`'de okunuyor. **`hideExactDistance` alanı YOK.**
- `fetch_nearby_profiles` RPC mesafe hesaplıyor ama `feed_repository`
  bu RPC'yi sadece **filtreleme için** kullanıyor (Step 1b), mesafe
  değerini ProfileCard'a taşımıyor. Yani mesafe **ProfileCard'da hiç
  yok şu an**. UI tarafında mesafe gösterimi YOK gibi görünüyor —
  daha derin grep gerekiyor (feed_screen render'ında).

### Fix hipotezleri (plan onayı için)

**Incognito enforce — seçenekler:**
- **Hipotez 1 (en temiz):** Feed query Step 2'ye `.eq('incognito_mode',
  false)` ekle → tüm incognito user'lar feed'den çıkar. AMA bu, incognito
  user'ın *connection*'larına da görünmemesini sağlar (söz: "Only
  connections can discover you"). Bu söze uymaz.
- **Hipotez 2 (söze uyar):** Feed query'ye matches subquery'li OR ekle:
  `incognito_mode = false OR id IN (SELECT user_id FROM matches WHERE
  match has requester)`. Karmaşık ama doğru.
- **Hipotez 3 (en temiz mimari):** `is_discoverable` RPC'sini batch eden
  yeni bir RPC yaz: `filter_discoverable_ids(ids[], mode, requester) →
  ids[]`. feed_repository Step 1.5 olarak bunu çağırır. RPC SECURITY
  DEFINER zaten yazılı, batch versiyonu küçük migration.
- **Hipotez 4 (pragmatik):** Feed'i `fetch_nearby_profiles` benzeri yeni
  bir RPC `fetch_discoverable_feed(...)` ile baştan yaz. Daha büyük iş.

**Hide-distance enforce — seçenekler:**
- **Hipotez A (eksik UI tamamla + render):** Önce settings'e toggle ekle
  (kolon zaten var). Sonra ProfileCard'a `hideExactDistance` field ekle,
  fromDb okur, UI render'ı kontrol eder. **Ama mesafe ProfileCard'da
  şu an hiç yok** → önce mesafe taşıma mekanizması gerek.
- **Hipotez B (sadece backend hazırlık):** UI toggle ekle + DB kolonunu
  okuyup ProfileCard'a taşı. Render fix'i mesafe gösterimi mevcut olduğunda.

### Önerilen küçük scope (45 dakika için)
- **Sadece incognito** kapat (Hipotez 3 batch RPC + feed Step 1.5).
- **Hide-distance**: ayrı dalga (mesafe render'ı henüz UI'da yok,
  hazır altyapı eksik — küçük iş değil).
- ya da: **Sadece incognito** Hipotez 1 (yanlış ama hızlı) — **kabul edilemez,
  söze uymaz.**

### Kullanıcı kararları (2026-04-23 plan onayı)
1. **R-kod:** R8 AÇ ("UI_ONLY Settings — Write-Never-Read Pattern")
2. **Incognito hipotezi:** H3 (Batch RPC `filter_discoverable_ids`)
3. **Hide-distance:** ayrı dalga (Dalga 6b, mesafe render altyapısı yok)
4. **Hide-distance toggle UI:** bugün HAYIR (yeni UI_ONLY setting yaratma)

### ADIM 3 SONUÇ — TÜMÜ YEŞİL (2026-04-23 ~12:35 UTC)

**Apply çıktısı:**
```
mcp__supabase__apply_migration(
  project_id="xgkkslbeuydbbcvlhsli",
  name="filter_discoverable_ids_batch",
  query=<CREATE FUNCTION + GRANT>
) → {"success":true}
```

**3 Senaryo SQL test (BEGIN/ROLLBACK, kalıcı state değişmedi):**

| # | Senaryo | Beklenen | Gerçek |
|---|---------|----------|--------|
| 1 | Elena (non-incognito) + Marcus requester | `[elena_id]` | ✅ `[elena_id]` |
| 2 | Elena (incognito) + match yok | `[]` | ✅ `[]` |
| 3 | Elena (incognito) + match var | `[elena_id]` | ✅ `[elena_id]` |

**Feed integration:**
- `lib/data/repositories/feed_repository.dart` Step 1.5 (geo filter'dan
  sonra, Step 2 query'den önce)
- RPC çağrısı: `filter_discoverable_ids(toFetch.toList(), mode, userId)`
- Defense-in-depth: Step 2'deki `.eq('is_paused', false)` ve mode_visible
  filtreleri korundu (RPC değişirse ek güvenlik)
- Fail-loud: try/catch yok, RPC exception propagate (R4 örüntüsünden uzak)

**Kod sağlığı:**
- `flutter analyze --fatal-infos`: `No issues found!` ✅
- `flutter test`: **257 pass / 2 fail** ✅ (baseline korundu, regresyon sıfır;
  kalan 2 fail R4 guardrail — R8 ile ilgisiz)

**R-kod durumu sonrası (Dalga 6 sonrası):**
- R1 ✅ FULLY CLOSED (Dalga 2 + 2b)
- R2 ✅ FULLY CLOSED (Dalga 2c)
- R3 AÇIK (`_substantive` filter, ayrı dalga)
- R4 KISMEN (10/48 catch_(_) düzeltildi, R4 hijyen dalgası bekliyor)
- R5 ✅ FULLY CLOSED (Dalga 3)
- R5b ✅ FULLY CLOSED (Dalga 3b)
- R6 AÇIK (Video WebRTC, büyük iş)
- R7 META (kanıt disiplini)
- **R8 KISMEN CLOSED** (incognito_mode CLOSED Dalga 6; 7 setting OPEN)

**Advisor beklentisi (post-apply):**
- `function_search_path_mutable` sayısı **-1** (yeni RPC `SET search_path = public`)
- `rls_policy_always_true` değişmez (1 kalır, video_update_own intentional)

### Kalan adımlar (commit + push + PR)
- Commit 1: migration + rollback
- Commit 2: feed_repository.dart
- Commit 3: docs (session_notes + known_regressions R8)
- Push + pre-fill PR URL (DNS sorunu nedeniyle bekleniyor)

---

## Gece final — 2026-04-23 (Dalga 6 KAPANIŞ)

### Bugün kapanan
- **R5b FULLY CLOSED** (sabah 11:30, Dalga 3b, PR #6)
- **R8 incognito enforce CLOSED** (akşamüstü ~16:00, Dalga 6, PR #7)
- **CI Baseline policy** dokümante edildi (PR #8, CLAUDE.md §4 alt-bölümü)

### Kümülatif R-kod durumu (4 gün, 8 squash commit)
- R1 ✅ FULLY CLOSED (Dalga 2 + 2b)
- R2 ✅ FULLY CLOSED (Dalga 2c)
- R3 AÇIK (`_substantive` filter prompts, ~30 dk)
- R4 KISMEN (48 → 38 `catch (_)`, Dalga 4)
- R5 ✅ FULLY CLOSED (Dalga 3)
- R5b ✅ FULLY CLOSED (Dalga 3b)
- R6 AÇIK (Video WebRTC, büyük iş)
- **R8 KISMEN** (1/8 setting CLOSED: `incognito_mode`; 7 OPEN)

### Main commit zinciri (8 squash commit — doğrulanmış)
```
577e38a — docs: CI baseline policy (PR #8)           ← şimdi
efa37d8 — Dalga 6: Feed incognito enforce (PR #7)   ← şimdi
6c36bf6 — Dalga 3b: R5b cosmetic cleanup (PR #6)
42aaf75 — Dalga 3: RLS hardening R5 (PR #5)
8aa837f — Dalga 2c: ProfileDraft R2 (PR #4)
b044e2e — Dalga 2b: Profile.toJson R1 (PR #3)
02bf129 — Dalga 2: Profile.copyWith (PR #2)
0065791 — Dalga 1: .env + catch logs
```

### Metrikler
- **Test:** 257 pass / 2 fail (baseline, R4 + Dalga 5 sonrası yeşil hedef)
- **Advisor:**
  - `rls_policy_always_true`: 1 WARN (intentional `video_update_own`)
  - `function_search_path_mutable`: 60+ → 59 (Dalga 6 RPC `SET search_path` bonus)
- **Production migrations:** 2 apply (Dalga 3 + Dalga 6), 0 kesinti
- **CI baseline policy:** CLAUDE.md §4'te kayıtlı

### Bugünkü önemli öğrenmeler
- **Pre-smoke disiplini 3 günlük R5 varsayımını kırdı** — advisor'daki 9
  WARN'dan kaç tanesi "gerçek bypass" sanıyorduk. Pre-smoke kanıtladı: 2
  aktif (gating), 1 intentional, 6 dead. Test olmadan yanlış fix yapılacaktı.
- **CI `conclusion=failure` 4 gündür görmezden geliniyordu** — baseline
  policy artık CLAUDE.md'de. "Kırmızı CI = her zaman regresyon" varsayımı
  yanlıştı; pre-existing envanter için kasıtlı.
- **`is_discoverable` RPC zaten yazılıydı, feed çağırmıyordu** — R8
  örüntüsü temeli: "altyapı var, entegrasyon eksik". Gelecek setting
  fix'lerinde önce "backend RPC var mı" diye bak.

### Bugünkü iş yükü (~5 saat Noblora)
- Sabah 07:35–09:30: Dalga 2c + Dalga 3 (R2 + R5)
- Öğle ara (12 saat başka projeler)
- Akşamüstü 10:45–11:30: Dalga 3b (R5b)
- Akşam 15:00–~17:00: Dalga 6 + docs (R8 partial + CI baseline)

### Yarın için seçenekler (karar taze kafayla)
- A) **Dalga 3 (R3)** — ~30 dk, `_substantive` filter prompts (en kolay)
- B) **Dalga 4 (R4)** — ~1.5 saat, `catch (_)` hijyeni 38 örnek (orta risk)
- C) **Dalga 6b** — ~1–1.5 saat, hide-distance altyapı + enforce
- D) **Dalga 5** — 3–5 saat, direct Supabase çıkarma (alt dalgalara böl)

### Yarın ilk 15 dakika
1. CLAUDE.md oku (özellikle yeni §4 CI Baseline alt-bölümü)
2. known_regressions.md oku (R3, R4, R6, R8)
3. session_notes.md son kayıt oku (bu rapor)
4. Dalga seçimi (A/B/C/D)
5. Seçilen dalga için oturum açılış ritüeli (yeni kayıt + branch)

---

## 2026-04-24 05:30 — Dalga 3: R3 Substantive Filter Prompts

### Hedef (önce keşif)
`profile_screen.dart` içindeki `_substantive()` helper "anlamlı içerik"
filtresi yapıyor (line 91-102). Default `minChars=14, minWords=3` ama
prompt çağrısında `minChars=10, minWords=3` (line 223). Kriter "OR"
mantığında — biri geçerse içerik gösterilir. Filter çok sıkı olabilir
ve gerçek kullanıcı cevapları kayboluyor (canlı R3 etkisi).

### Başarı ölçütü (keşif sonrası karar)
- Ya minChars/minWords düşür (örn 4/2)
- Ya filter'ı tamamen kaldır (kullanıcı zaten yazdı, paternalizm)
- `_strong()` ön filtresi yine kalır (boş, blocklist, repetition)
- Karar keşif sonrası — spam riski vs UX kayıp dengesi
- Regresyon sıfır (test 257/2 baseline korunmalı)

### Risk
- Düşük — UI display layer, tek dosya, davranış değişikliği yalnızca
  render seviyesinde (DB'ye dokunmuyor)
- Spam riski: minChars tamamen kaldırırsak tek harf prompt'lar
  gelebilir → `_strong` zaten 2 char altını eliyor, alt güvenlik var
- 7 farklı çağrı yeri var (longBio, currentFocus, prompts × 1, dateBio,
  bffBio, socialBio); R3 sadece prompt için ama scope'u sormak şart

### Branch
- `dalga-3-r3-substantive-filter` (main'den)
- Bekleyen: dün geceki "Gece final" kaydı (1 dosya değişikliği)
  bu branch'e taşındı, Dalga 3 commit'iyle birlikte gidecek

### Scope limit (3 değişiklik üst sınırı)
1. `_substantive` parametre değişikliği VEYA çağrı yerinde override
2. Test (mevcut prompt verilerinin filter sonrası korunması)
3. Doc güncelleme (known_regressions R3 + session_notes)
4'üncüye geçersem DUR + onay iste.

### Karar (keşif sonrası, kullanıcı onayı)
- **Plan (1):** `_substantive` çağrısını `_strong`'a düşür. Plan (2)
  (`minChars:4, minWords:1`) reddedildi — `_strong` zaten <2 char
  filtreliyor, çakışma.
- **Test yolu A:** `@visibleForTesting bool isPromptVisible(PromptAnswer)`
  top-level helper. Yol B (manual smoke) reddedildi — sessiz veri
  kaybı + git history'de magic number filter geçmişi var. Yol C
  (`_CuratedProfile` public) reddedildi — scope creep.

### Yapılan değişiklikler
1. **`lib/features/profile/profile_screen.dart`**
   - `strongPrompts` getter (line 218-224) tek satıra düşürüldü:
     `(raw?.prompts ?? const <PromptAnswer>[]).where(isPromptVisible).toList()`
   - Yeni top-level `@visibleForTesting bool isPromptVisible(PromptAnswer)`
     `_CuratedProfile` altına eklendi. `_CuratedProfile._strong` (private
     static) aynı library'den çağrılıyor — public alias gereksiz.
   - Diğer 6 `_substantive` çağrısı dokunulmadı (longBio, currentFocus,
     dateBio, bffBio, socialBio, aboutMe — story alanları).
   - Import düzeni: ilk denememde `flutter/foundation.dart` explicit
     import eklemiştim; `unnecessary_import` info verdi (material zaten
     foundation export ediyor) → kaldırıldı.

2. **`test/guardrails/profile_prompt_filter_guardrail_test.dart`** (YENİ)
   - 26 subtest, 4 grup:
     - Grup 1 (8 test): meşru kısa cevap görünür — İstanbul, kahve,
       evet, hayır, "hiç içmem", "spor + okuma", "kahve seviyorum",
       "sabahları erken kalkmayı seviyorum"
     - Grup 2 (11 test): spam/blocklist gizlenir — asdf/test/na/todo,
       aaaa, 1234, "...", "a", "ş", "   ", ""
     - Grup 3 (4 test): soru tarafı validation — boş soru, spam soru,
       tek char soru, geçerli çift
     - Grup 4 (3 test): eski `_substantive` davranışı kırıldı
       regresyonu — "İstanbul" / "kahve" / "hiç içmem" artık görünür

3. **Doc güncellemeleri** (`known_regressions.md` R3 → CLOSED + kanıt;
   bu kayıt).

### Kanıt (kod sağlığı)
- `flutter test test/guardrails/profile_prompt_filter_guardrail_test.dart`
  → **26 pass, 0 fail** (`All tests passed!`)
- `flutter analyze --fatal-infos` → `No issues found!`
- `flutter test` (full suite) → **283 pass / 2 fail**
  - Önceki baseline 257/2 → 283/2 (+26/0, R3 testleri)
  - Kalan 2 fail R4 banned_patterns guardrail (CLAUDE.md §4 baseline,
    R3 ile ilgisiz)

### R-kod durumu sonrası
- R1 ✅ FULLY CLOSED (Dalga 2 + 2b)
- R2 ✅ FULLY CLOSED (Dalga 2c)
- **R3 ✅ FULLY CLOSED (Dalga 3 — bu oturum)**
- R4 KISMEN (38 `catch (_)` kalan)
- R5 ✅ FULLY CLOSED (Dalga 3 — eski oturum)
- R5b ✅ FULLY CLOSED (Dalga 3b)
- R6 AÇIK (Video WebRTC, büyük iş)
- R7 META (kanıt disiplini)
- R8 KISMEN (1/8 setting CLOSED)

### Kalan adımlar (commit + push + PR — kullanıcı onayı bekleniyor)
- Commit: 4 dosya
  - `lib/features/profile/profile_screen.dart`
  - `test/guardrails/profile_prompt_filter_guardrail_test.dart` (yeni)
  - `.claude/known_regressions.md`
  - `.claude/session_notes.md` (bu kayıt + dünkü gece final, dün
    branch'e taşınmıştı)
- Push: `dalga-3-r3-substantive-filter` → origin
- PR #9: "Dalga 3: R3 substantive filter — prompts use _strong only"



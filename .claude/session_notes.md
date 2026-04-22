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

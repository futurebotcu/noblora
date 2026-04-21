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

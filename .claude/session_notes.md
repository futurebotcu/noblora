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

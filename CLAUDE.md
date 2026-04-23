# CLAUDE.md — Noblara Proje Anayasası

> Bu dosya HER OTURUM BAŞINDA okunur. Her kural, geçmişte somut bir
> hatanın sonucu olarak yazılmıştır. Hiçbir madde "olsa iyi olur" değil,
> "olmazsa tekrar yanarız" seviyesindedir.

---

## 1. ALTIN KURAL — KANIT OLMADAN "YAPTIM" YASAK

"Yaptım", "tamam", "çalışıyor", "düzeltildi", "hazır" gibi ifadeler
KANIT olmadan kullanılamaz.

Kabul edilen kanıt türleri:
- Komut çıktısı (kopyalanmış tam çıktı, özet değil)
- `mcp__supabase__get_advisors` çıktısı
- SQL sorgu sonucu (`execute_sql`)
- Test çıktısı (`flutter test ...` yeşil/kırmızı hatlı)
- Emülatör / cihaz üstünde manuel doğrulama (screenshot ya da adım listesi)

"Muhtemelen çalışıyor", "çalışmalı", "sanırım oldu" → YASAK. Bunun
yerine **"doğrulanmadı"** yaz.

---

## 2. OTURUM AÇILIŞ RİTÜELİ (İlk 3 Eylem)

Her yeni oturumun ilk üç eylemi **sırayla** şudur. Bu 3 adım yapılmadan
iş başlatmak yasaktır.

1. `.claude/known_regressions.md` oku — geçmişteki kalıplaşmış hataları hatırla.
2. `.claude/session_notes.md`'ye yeni bir kayıt aç:
   - Bu oturumda hangi alana dokunacağını yaz
   - Hangi R-kodlu regresyonların risk alanına girdiğini listele
3. Bu oturumda "scope creep" olasılığı yüksekse, önceden limit koy:
   > Planlanan değişiklikler: [liste]. 3'ten fazlasına geçersem durup
   > kullanıcıya onay isteyeceğim.

---

## 3. "DONE" TANIMI

Bir görev ancak `.claude/done_log.md`'de **tam checklist** doldurulduğunda
"done" sayılır. Checklist:

- [ ] Kod path (dosya:satır)
- [ ] Backend kanıtı (SQL/curl/advisor çıktısı)
- [ ] UI kanıtı (widget test ya da manuel test adımı)
- [ ] Regresyon kontrolü (known_regressions.md'den bakılan maddeler)
- [ ] Guardrail testi (yeşil çıktısı)

Eksik maddesi olan iş "done" değildir. Kullanıcıya "bitirdim" denemez.

---

## 4. YASAK KALIPLAR

Aşağıdaki kalıplar `lib/` altında bulunamaz. Guardrail testi bu kuralı
CI'da otomatik zorlar.

| Kalıp | Neden yasak | Yerine ne? |
|---|---|---|
| `catch (_)` | Sessiz fail — geçmişte distance filter'ı soldurdu (R4) | `catch (e, st)` + log + UI surface |
| `// ignore: unused_*` | Ya dead code ya yarım iş | Ya tamamla ya sil |
| `// TODO` / `// FIXME` / `// HACK` / `// XXX` | Koda çöp bırakma | `.claude/todos.md`'ye yaz |
| `Supabase.instance.client` (screen/widget içinde) | Veri erişimi mimariyi kırıyor | Yalnızca `lib/data/repositories/` altında |
| 500+ satır yeni dosya | Split zor, regresyon riski yüksek | Önce split planı sun, sonra yaz |

**CI Baseline (guardrail envanter politikası):**

`no_banned_patterns_test` envanteri kasıtlı **baseline fail** olarak yazıldı.
CI `conclusion=failure` görünür ama PR-kabul edilebilir sayılır EĞER:
- `flutter analyze --fatal-infos` yeşil
- Test sayısı önceki PR'dan artmamış (ör. 257/2 → 257/2, regresyon yok)
- Yeni banned pattern eklemedi

CI yeşile tam dönüş hedefi: R4 (`catch (_)` kalan 38) + Dalga 5
(`Supabase.instance.client` kalan 121 dış çağrı) tamamlandığında.
Şu an **257 pass / 2 fail** hedef baseline'dır; bu 2 fail envanter için.

---

## 5. SCOPE CREEP YASAĞI

Bir görev sırasında **planlanmamış 3'ten fazla** değişiklik yapılamaz.

"Bir de şunu düzelteyim" dürtüsü gelince:
1. `.claude/todos.md`'ye yaz
2. Asıl göreve dön

3'ü geçtiysen **DUR**, kullanıcıya liste sun, onay bekle. Onaysız 4.
değişikliğe geçmek yasak.

---

## 6. GÜVENLİK DEĞİŞİKLİĞİ PROTOKOLÜ

RLS, policy, function ya da migration yazdıysan bu 5 adımı **sırayla**
uygula:

1. **Migration öncesi baseline:** `mcp__supabase__get_advisors(type=security)` çalıştır, çıktıyı tam haliyle kaydet.
2. **Migration uygula** (`apply_migration`).
3. **Migration sonrası:** aynı advisor'ı tekrar çağır, çıktıyı tam haliyle kaydet.
4. **Yan yana sun:** kullanıcıya iki çıktıyı side-by-side göster.
5. **"Fixed" tanımı:** yalnızca hedeflenen satırların **ikinci çıktıda olmaması**. Başka tanım yok.

Eski permissive policy drop edilmediyse "fix" eksiktir (R5 burada yandı).

---

## 7. MODEL DEĞİŞİKLİĞİ PROTOKOLÜ

`Profile`, `Post`, `Match`, `Notification` modellerinden birine alan
ekledin/çıkardıysan bu 4 adım şarttır. 4'ü eksikse commit YOK.

1. `lib/data/models/*_fields.dart` tek kaynak listesini güncelle (varsa).
2. `fromJson` + `toJson` + `copyWith` + draft (varsa) — **HEPSİNİ** güncelle.
3. `flutter test test/guardrails/` yeşil olmalı.
4. Alan için roundtrip testi ekle: `value → save → reload → value`.

Bu protokol R1 ve R2'nin (copyWith drift + draft veri kaybı) tekrar
etmesini engeller.

---

## 8. ESKİ HATALAR LİSTESİ (Her Oturum Hatırla)

Aşağıdaki alanlara dokunuyorsan, önce AÇIKÇA belirt ve önlem sun:

- **R1 — Profile copyWith drift** (3 kez tekrar). Profile'a alan eklerken copyWith güncellenmedi.
- **R2 — profile_draft ↔ fromJson asenkron** (2 kez). Draft yazıyor ama fromJson okumuyor → sessiz veri kaybı.
- **R3 — `_substantive()` filter prompts gizledi** (1 kez, canlı). profile_screen.dart:94-106 civarı.
- **R4 — `catch (_)` distance filter'ı soldurdu.** Hata sessizce yutuldu, UI yanlış veri gösterdi.
- **R5 — Bypass-disguised-as-fix.** P0 migration eski permissive policy'yi DROP etmedi, sadece yenisini ekledi.
- **R6 — Video call WebRTC'siz yazıldı.** UI var, altyapı yok. Feature sahte.
- **R7 — Audit raporunda uydurma iddialar.** `push/delete/comments/distance` aslında çalışıyordu, sen yanlışlıkla "FAKE" etiketledin. Doğrulamadan "feature çalışmıyor" denmez.

Detaylar için `.claude/known_regressions.md`.

---

## 9. İLETİŞİM KURALI

- Emin değilsen **"emin değilim"** de. Tahmini gerçek gibi sunma.
- Bir iddia için kanıt yoksa **"doğrulanamadı"** yaz.
- "Muhtemelen", "sanırım", "çalışmalı" gibi muğlak terimleri kullanma.
- Kullanıcıya durum raporu verirken: iddia + kanıt + kanıtın kaynağı.
- Kanıt yoksa iddia yok.

---

## Ek: Hızlı Referans

**Her oturum başı:**
1. `known_regressions.md` oku
2. `session_notes.md`'ye kayıt aç
3. Scope limiti koy

**Her iş bitişi:**
1. `done_log.md`'ye checklist doldur
2. Guardrail testi yeşil mi kontrol et
3. Commit + push

**Şüpheye düşünce:**
- Kod değil, **sor**.
- Atla değil, **dur**.
- Uyduruk değil, **"doğrulanamadı"**.

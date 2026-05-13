# P0 — Location / Profile Save Root-Cause Fix Report

**Tarih:** 2026-05-13
**Yöntem:** Live Supabase DB query + API logs + repo grep. **Tahmin yok, kanıt var.**
**Sonuç:** Tek root cause bulundu, 2 satır fix uygulandı, baseline test 281/0 korundu.

---

## 1. Root Cause — Net

**Onboarding completion sırasında `PATCH /rest/v1/profiles?id=eq.<uid>` çağrısı, payload'daki `'profession'` anahtarı yüzünden HTTP 400 dönüyor. Çünkü `public.profiles` tablosunda `profession` kolonu yok — kolon ismi `occupation`. PostgREST 42703'ü 400'e çeviriyor, Flutter retry loop'u 2 kez denedikten sonra "We couldn't save your profile" toast'u atıyor.**

### 1.1 Exact PostgreSQL error (live DB ile reproduce edildi)

```
ERROR: 42703: column "profession" does not exist
LINE 1: SELECT profession FROM public.profiles LIMIT 0;
               ^
```

Çalıştırılan komut: `SELECT profession FROM public.profiles LIMIT 0;` via `mcp__supabase__execute_sql` (project_id=`xgkkslbeuydbbcvlhsli`).

### 1.2 Exact failing PATCH (Supabase API logs)

Kullanıcı `f37ecbcb-d849-48e0-84fc-41d1d27c47bd` için (43 sn önce yeni signup), iki ardışık 400:

```
timestamp 1778695981030000  PATCH /rest/v1/profiles?id=eq.f37ecbcb-... | 400 | Dart/3.9
timestamp 1778695981412000  PATCH /rest/v1/profiles?id=eq.f37ecbcb-... | 400 | Dart/3.9
```

382 ms arayla — onboarding_flow_screen.dart:151 `for (var attempt = 0; attempt < 2 && !saved; attempt++)` retry desenine birebir oturuyor.

### 1.3 Exact failing payload (kaynak)

`lib/features/onboarding/onboarding_flow_screen.dart:153-194` — `updateProfile` çağrısı:

```dart
await ref.read(profileRepositoryProvider).updateProfile(uid, {
  'full_name': ...,
  'display_name': ...,
  'age': ...,
  'gender': ...,
  if (_city.isNotEmpty)    'city': _city,
  if (_country.isNotEmpty) 'country': _country,
  'bio': '',
  'date_avatar_url': ...,
  'dating_active': true,
  'dating_visible': true,
  'looking_for': 'Serious relationship',
  if (_occupation.isNotEmpty) 'profession': _occupation,  // ← BUG: key "profession" doesn't exist in DB
  if (_avatarId != null) 'avatar_id': _avatarId,
  'is_onboarded': true,
  'incognito_mode': false,
  'calm_mode': false,
  'show_last_active': true,
  'show_status_badge': true,
  'reach_permission': 'everyone',
  'signal_permission': 'everyone',
  'note_permission': 'everyone',
  'message_preview': true,
  'active_modes': kSocialEnabled ? ['date', 'social'] : ['date'],
});
```

Onboarding "Occupation" step'inde kullanıcı bir meslek yazdığında (`_occupation.isNotEmpty`), payload'a `'profession': _occupation` eklenir. Kullanıcı meslek alanını boş bırakırsa bug tetiklenmez — bu yüzden meslek yazmayan testfeed seed kullanıcılar onboarding'i bitirebilmiş olabilir.

### 1.4 Live DB column listesi (`information_schema.columns`)

`public.profiles` içinde `occupation` var, `profession` **yok**. Doğrulandı (ilgili satırlar):

```
column_name = "occupation", data_type = "text", is_nullable = "YES"
```

`SELECT * FROM information_schema.columns WHERE table_name='profiles' AND column_name LIKE 'profession%'` → 0 satır.

### 1.5 M0 trigger NOT suçlu (kanıtlı)

`profiles_block_sensitive_writes` trigger fonksiyonunu MCP ile çektim. Korunan alanlar:

```
nob_tier, tier_locked, noble_score, maturity_score, trust_score,
is_noble, is_verified, selfie_verified, photos_verified,
verification_status, is_admin, daily_swipes_used, daily_swipes_reset,
daily_connections, daily_connections_reset, boost_active_until,
boosts_remaining, super_likes_remaining, rewinds_remaining
```

Onboarding payload bu listelerin **hiçbirini içermez**. Bu trigger normal onboarding flow'una dokunmuyor. (PR2/PR3'ün M0 hipotezi reddedildi.)

### 1.6 RLS policies — NOT suçlu (kanıtlı)

`profiles_update_own` policy `USING (auth.uid() = id)` — kullanıcı sadece kendi satırını update edebilir. Onboarding'de `uid = _ref.read(authProvider).userId` kullanılır → policy geçer. PATCH 204 dönmesi gereken bir update, 400 dönüyorsa sorun RLS değil **şema** (kolon yok).

### 1.7 Country full-name vs ISO — AYRI bir bug, P0'ın sebebi DEĞİL

Travel audit raporunda flag'lenen "country=`Turkey` saver vs gate ISO `TR` bekler" mismatch'i hâlâ açık, ama **bu rapor kapsamı dışı**. Onboarding'i FAIL ettiren şey o değil — `country` text alanı her şeyi kabul ediyor, 400 sebebi değil. Bu, gate-side davranış kaybı (R-new(a)) olarak Travel sprintinde kapanacak.

---

## 2. Fix — Minimal, 2 satır

### 2.1 Write tarafı (P0 blocker)

**`lib/features/onboarding/onboarding_flow_screen.dart:179`**

```diff
-if (_occupation.isNotEmpty) 'profession': _occupation,
+// R-new(occupation-typo) — DB column is `occupation`; the prior key
+// `'profession'` PATCH'd a non-existent column and PostgREST returned
+// 42703 -> HTTP 400, surfacing as "We couldn't save your profile" on
+// the onboarding completion step. Verified via SELECT profession FROM
+// profiles -> ERROR 42703 (2026-05-13).
+if (_occupation.isNotEmpty) 'occupation': _occupation,
```

### 2.2 Read tarafı (companion silent bug — sıfır cost)

**`lib/data/models/profile_card.dart:82`**

```diff
-profession: row['profession'] as String?,
+// R-new(occupation-typo) — DB column is `occupation`, not
+// `profession`. The prior read silently returned null on every
+// Discover card so profession never rendered. Companion to the
+// onboarding payload fix.
+profession: row['occupation'] as String?,
```

`ProfileCard.fromJson` (line 101) **dokunulmadı** — bu factory dış callsite tarafından kullanılmıyor (sadece `fromDb` `feed_repository.dart:172`'de aktif); fromJson'u şimdi değiştirmek symmetric serialization sözleşmesini bozar. Scope creep yasağı.

---

## 3. Yan tespit — Onboarding "Send location" / "Manual city" path mantıklı

Kullanıcı semptomu "Send your location çalışmıyor + manual city yazınca We couldn't save your profile" olarak tanımladı. Trace:

### 3.1 "Send your location" path

`LocationService.getLocationFromGPS()` (`lib/core/services/location_service.dart:96-131`) → permission ladder + reverse geocode. Başarıdaysa `_LocationPage` callback'le `setState({_city, _country})` set eder. Başarısızsa `_LocationPage` UI'da hata mesajı ve "Try manual" fallback.

**Bu path'ta save fail'i, GPS başarısı/başarısızlığından bağımsız.** Sebep aynı: completion adımında `'profession': _occupation` payload'a giriyor → 400. GPS yolu işliyor, save işlemiyor.

### 3.2 "Manual city" path

`CitySearchScreen` callback → `_city, _country, _countryCode` set eder. Sonra Photo/Privacy → Complete → `_complete()` çağrısı → `updateProfile` → 400.

**Aynı 400.** Konum nereden geldiği önemli değil, payload'da `profession` olduğu sürece save fail oluyor.

### 3.3 Conditional bypass

`if (_occupation.isNotEmpty) 'profession': _occupation` koşullu. Kullanıcı Occupation step'inde alanı boş bırakırsa key payload'a hiç eklenmez → 400 olmaz, save geçer. **Bu yüzden bazı test akışları geçmiş, bazıları fail olmuş.** Bug deterministik olarak meslek girilirken tetikleniyor.

---

## 4. DB Contract vs Payload — Tüm key'leri karşılaştırdım

| Payload key | DB column | Durum |
|---|---|---|
| `full_name` | full_name | ✓ |
| `display_name` | display_name (NOT NULL) | ✓ |
| `age` | age | ✓ |
| `gender` | gender (CHECK male/female/other) | ✓ (input doğrulanmış) |
| `city` | city | ✓ |
| `country` | country | ✓ (text alanı; full name vs ISO ayrı bug) |
| `bio` | bio | ✓ |
| `date_avatar_url` | date_avatar_url | ✓ |
| `dating_active` | dating_active | ✓ |
| `dating_visible` | dating_visible | ✓ |
| `looking_for` | looking_for | ✓ |
| `profession` | — | ❌ **JOK — 42703** |
| `avatar_id` | avatar_id | ✓ |
| `is_onboarded` | is_onboarded | ✓ |
| `incognito_mode` | incognito_mode | ✓ |
| `calm_mode` | calm_mode | ✓ |
| `show_last_active` | show_last_active | ✓ |
| `show_status_badge` | show_status_badge | ✓ |
| `reach_permission` | reach_permission | ✓ |
| `signal_permission` | signal_permission | ✓ |
| `note_permission` | note_permission | ✓ |
| `message_preview` | message_preview | ✓ |
| `active_modes` | active_modes (NOT NULL, text[]) | ✓ |

**Tek bilinmeyen kolon `profession`.** Tüm 400'ün tek sebebi.

---

## 5. Files Changed

| Dosya | Satır | Δ |
|---|---|---|
| `lib/features/onboarding/onboarding_flow_screen.dart` | 179 | `'profession'` → `'occupation'` + 5 satır açıklama yorumu |
| `lib/data/models/profile_card.dart` | 82 | `row['profession']` → `row['occupation']` + 4 satır açıklama yorumu |

Migration: **YOK.** Schema doğru zaten; bug tamamen client-side typo.

---

## 6. Manual Smoke Checklist (gerçek cihaz)

### 6.1 Happy path

1. Yeni hesap → Welcome → Continue
2. Info step (3 bayrak) → Continue
3. Basics: isim + doğum + gender → Continue
4. **Occupation step:** "Software Engineer" yaz → Continue
5. Location step:
   - Path A: "Send your location" → GPS → Bangkok/Hanoi/Manila reverse geocode → city + country set
   - Path B: "Use manual city" → city search → bir TH/VN/PH şehri seç → set
6. Photo step → fotoğraf veya avatar seç → Continue
7. Privacy step → Continue
8. Complete step → **"Welcome to Noblara" yerine "We couldn't save your profile" toast YOK**, MainTabNavigator'a yönlendir

### 6.2 Edge: meslek boş

1. Occupation step'inde alanı boş bırak → Continue
2. Geri kalan flow → save geçer (eskiden de geçiyordu, bug bypass'lıydı)

### 6.3 Regresyon kontrolü

- Profile ekranında "Occupation" bilgisi görünür (eskiden boş veya null sayılıyordu)
- Discover deck'inde swipe kartında "Profession" satırı görünür (eskiden hep boş)
- Database'de yeni kullanıcı: `SELECT occupation FROM profiles WHERE id = '<new-uid>'` → "Software Engineer" döner

---

## 7. Quality Gates

### 7.1 flutter analyze --fatal-infos

```
Analyzing noblara...
No issues found! (ran in 9.3s)
```

### 7.2 flutter test

| Metrik | Baseline (önce) | After |
|---|---:|---:|
| pass | 281 | **281** |
| fail | 0 | **0** |

Regresyon **sıfır**. Yeni guardrail testi: onboarding payload'ı sahte DB column listesi ile karşılaştıran bir test yazılabilir ama bu PR scope dışı — minimal fix odağı.

---

## 8. Kalan Riskler & Sonraki Sprintler

### 8.1 Country full-name vs ISO (R-new(a))

`onboarding_flow_screen.dart:163` `'country': _country` (full name "Thailand") yazıyor; `country_support.dart` ISO ('TH') bekliyor. Bu BUG **save fail'in sebebi değil**, ama Discover gate'i bozar. Travel sprint kapsamında kapanmalı.

### 8.2 ProfileCard.fromJson (line 101) eski symmetric serialization

`fromJson` halen `json['profession']` okur. Şu an callsite yok (analyze yeşil). Eğer ileride caching/persistence eklenirse, model field'ı `profession` adıyla saklanabilir — sözleşme korunmuş olur. Sorun değil ama bilinmesi gereken bir asimetri (DB'de `occupation`, model'de `profession`, snake↔camel köprü `fromDb`'de).

### 8.3 Eski kullanıcı verisi

Bug "occupation girersen save fail" şeklinde olduğu için, bug-yaşamış kullanıcılar zaten kaydolamamış. Onboarding'i geçmiş kullanıcıların ya:
- meslek girmedi (NULL)
- ya da occupation seed/test-feed manuel insert'le ekledi

Önerilen check (opsiyonel):
```sql
SELECT COUNT(*) FROM profiles WHERE is_onboarded = true AND occupation IS NULL;
```
Sayı yüksekse, kullanıcılara Profile Edit'ten meslek doldurma promtu hatırlatılabilir. **Bu rapor kapsamı dışı.**

### 8.4 Yeni guardrail test (ileride)

`test/guardrails/onboarding_payload_db_contract_test.dart` — onboarding `updateProfile` payload key'lerini, live DB column listesine karşı doğrulayan bir test eklenmesi öneriliyor. Bu, `profession` tipi tekrarlı drift'leri önler. **Sprint dışı.**

---

## 9. Commit Önerisi

Tek commit, tek concern (occupation typo fix):

```
fix(noblora): P0 onboarding save - column name "profession" -> "occupation"

Root cause (live-verified):
- Onboarding completion PATCH'd profiles with key 'profession' but the
  public.profiles column is `occupation`. PostgREST returned 42703 ->
  HTTP 400, surfacing as "We couldn't save your profile" toast on the
  Complete step. Triggered only when the user filled the Occupation
  step (conditional payload key).

Evidence:
- Live SQL: SELECT profession FROM public.profiles -> 42703 column
  does not exist
- Live API logs: two consecutive PATCH /rest/v1/profiles | 400 with
  382ms gap (matches onboarding 2-attempt retry loop)
- M0 trust-lockdown trigger NOT involved (protected fields don't
  intersect onboarding payload)
- RLS profiles_update_own (auth.uid() = id) policy passes

Fix (2 lines):
- onboarding_flow_screen.dart:179 payload key 'profession' -> 'occupation'
- profile_card.dart:82 row['profession'] -> row['occupation'] (companion
  silent read-side bug: Discover cards never showed profession)

Quality gates:
- flutter analyze --fatal-infos: No issues found
- flutter test: 281 pass / 0 fail (regression zero)

Out of scope: country full-name vs ISO mismatch (separate R-new(a),
travel sprint), guardrail test against DB column drift, fromJson
factory unused-callsite cleanup.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

---

## 10. Sonuç

| Soru | Cevap |
|---|---|
| Hangi payload gönderiliyor? | §1.3 — 23 anahtar. Sadece 1 tanesi (`profession`) DB'de yok. |
| Supabase hangi hatayı döndürüyor? | PostgrestException `code=42703, message="column \"profession\" does not exist"`, HTTP 400 |
| Hangi 400/403/trigger sebebi? | Pure 400 (kolon yok). 403/trigger değil. |
| M0 lockdown blokluyor mu? | Hayır — payload trigger'in protected listesini içermiyor. |
| Hangi kolon yüzünden fail? | `profession` (DB'de yok); doğrusu `occupation`. |

**Fix komite öncesi durdum.** Commit + push komutunu verirsen tek commit + tek push yapacağım. Manuel cihaz smoke §6 checklist'iyle yapılır.

# Final V1 Cleanup Report

**Tarih:** 2026-05-13
**Yöntem:** Kanıt-dayalı audit → güvenli sil / riskli flagle ayrımı → minimal targeted edit. Kör silme yok.
**Sonuç:** 4 dosya silindi, 8 dosya düzeltildi, analyze yeşil, test 281/0 regresyon sıfır.

---

## 1. Executive Summary

V1 scope dışında kalan veya kullanıcıyı yanıltan kalıntılar temizlendi:
- **GPS/location surface** → kaldırıldı. Manual city search artık tek yol.
- **3 bayraklı tanıtım step** (OnboardingInfoStep) → kaldırıldı.
- **50 custom-painted warrior/queen avatar grid** (AvatarPicker) → kaldırıldı. Foto artık zorunlu.
- **TierBadge widget + TierPromotionScreen** → kaldırıldı (M0 sonrası dead UI).
- **Filter sheet "Tier" bölümü** (All / Explorer+ / Noble only) → kaldırıldı.
- **UserProfileScreen.initialTier param** → kaldırıldı.

DB kolonlarına dokunulmadı (`nob_tier`, `avatar_id`, `country` vb. legacy data korundu). Verification sistemi kapalı kalmaya devam ediyor.

---

## 2. Deleted Files (4)

| Dosya | Boyut | Neden |
|---|---|---|
| `lib/shared/widgets/tier_badge.dart` | 76 satır | M0 sonrası **0 caller** (grep ile doğrulandı). NobTier enum'unun tek görsel surface'iydi. |
| `lib/features/profile/tier_promotion_screen.dart` | ~120 satır | M0 commit'inde routing kaldırılmış (`main_tab_navigator` yorumu doğruladı); **0 external caller**. |
| `lib/shared/widgets/avatar_picker.dart` | ~39 KB (50 warrior CustomPainter) | Yalnız `_PhotoPage` (onboarding) kullanıyordu. AI/placeholder avatar legacy. |
| `lib/features/onboarding/info_step.dart` | 149 satır | TH/VN/PH bayrak intro step. PageView'den çıkarıldı. |

---

## 3. Modified Files (8)

### 3.1 `lib/features/onboarding/onboarding_flow_screen.dart`

Hepsi V1 final cleanup yorumlu:

- Imports temizlendi: `location_service.dart`, `avatar_picker.dart`, `info_step.dart` kaldırıldı.
- `_totalSteps = 8 → 7` (info step çıkışı).
- State: `int? _avatarId` field kaldırıldı.
- `_validateCompletion`: `photo OR avatar required` → **`photo required`** (foto artık zorunlu).
- Save payload: `'avatar_id': _avatarId` satırı kaldırıldı.
- PageView children: `OnboardingInfoStep(onNext: _next)` kaldırıldı, Welcome → Basics direct.
- **`_LocationPage`** tam yeniden yazıldı:
  - `_useGPS()` fonksiyonu kaldırıldı (5 LocationStatus branch dahil)
  - `_openSettingsForLocation()` kaldırıldı
  - State alanları kaldırıldı: `_gpsLoading`, `_error`, `_showOpenSettings`
  - Build method: GPS button + error display + Open-Settings button kaldırıldı
  - Yeni primary CTA: "Search for your city" / "Change city" (manuel city_search_screen)
- **`_PhotoPage`** sadeleşti:
  - `avatarId` + `onAvatarSelected` parametreleri kaldırıldı
  - AvatarPicker grid + "or" divider kaldırıldı
  - Button label: koşullu "Continue / Skip for now" → daima "Continue" (foto seçilmeden disabled)
  - Subtitle: "Or choose an avatar to get started" → "A real photo helps people trust your profile"

### 3.2 `lib/data/models/filter_state.dart`

- `String? statusBadge` field kaldırıldı (+ constructor + copyWith + activeCount + clearStatusBadge flag)
- `statusBadgeOptions = ['All', 'Explorer+', 'Noble only']` const kaldırıldı

### 3.3 `lib/providers/filter_provider.dart`

- `fromMap` içinde `statusBadge: map['statusBadge']` kaldırıldı (eski cache'ten silent drop, V1 yorum açıklamasıyla)
- `toMap` içinde `'statusBadge': state.statusBadge` kaldırıldı

### 3.4 `lib/features/filters/filter_bottom_sheet.dart`

- "Tier filters" bölümü (5 satır UI: label + 3 chip) kaldırıldı

### 3.5 `lib/data/repositories/feed_repository.dart`

- `if (filters.statusBadge == 'Explorer+')` ve `Noble only` query branch'leri kaldırıldı
- `count_filtered_profiles` RPC çağrısında `p_tier_filter` parametresi daima `null`

### 3.6 `lib/features/profile/user_profile_screen.dart`

- `NobTier` import kaldırıldı (`import '../../data/models/post.dart' show NobTier;`)
- `UserProfileScreen.initialTier` param + default değer kaldırıldı
- `_HeroHeader.tier` field + constructor param kaldırıldı (M0 sonrası kullanılmıyordu zaten)
- Çağrı yerleri (`swipe_card_widget.dart:351`, `individual_chat_screen.dart:661`): bu param'ı zaten geçirmiyorlardı; default değer kullanıyordu → sıfır cascade.

---

## 4. Flagged — Kasıtlı Dokunulmadı (kullanıcı kararı bekliyor)

Bu kalıntılar **silinmedi** çünkü siyaset/cascade riski var. Kullanıcı isterse ayrı PR'da kapanır.

| Konu | Lokasyon | Neden flag |
|---|---|---|
| **geolocator + geocoding pubspec deps** | `pubspec.yaml`, `lib/core/services/location_service.dart` | Kullanıcı talimatı: "Geolocator dependency kaldırma şimdilik riskliyse bırak ama runtime'da çağrılmasın." `LocationService` artık ÇAĞRILMIYOR; dosya + dep kalıyor. Pubspec temizliği = ayrı sprint. |
| **`help_center_screen.dart` Noble/tier copy** | line ~333-460 | "Noble Date / Noble BFF / Observer → Explorer → Noble tier progression" gibi help docs metinleri. Çıkarılması copy review gerektirir (Noble Date → Date olunca cümle anlamı kayıyor). Ayrı copy sprint. |
| **`appearance_provider.dart` isNoble check** | `setAccent(String id, {bool isNoble = false})` line 78-81 | Dead-ish kod (PR1 rebrand'da `nobleOnly: true` accent kalmadı, branch hiç fire etmez). Cascade riski: `AccentColor.nobleOnly` field kaldırırsam `app_colors.dart`'a inip 5 accent tanımını da güncellemem gerek. V1 davranışı bozmuyor → flag. |
| **`AppColors.nobNoble / nobExplorer / nobObserver` aliasları** | `app_colors.dart:160-164` | Internal isim alias (`nobNoble = burgundy600`, `nobObserver = textMuted`). Kullanıcıya görünmüyor; sadece kod identifier. `note_inbox_screen.dart:63,133` `AppColors.nobObserver` kullanıyor — rename = 2 satır daha + cascade. Düşük öncelik. |
| **`premium.dart:305` comment** | `/// Status label (e.g., "Verified", "Noble")` | Sadece dosya içi yorum, render edilmiyor. |
| **`NobTier` enum + `profile.nobTier` field** | `data/models/post.dart`, `data/models/profile.dart` | DB column `nob_tier` legacy data taşıyor. Kullanıcı talimatı: "DB kolonlarına bu sprintte dokunma; sadece runtime/UI kalıntısı temizle." Enum + model field korundu (sadece UI surfaces kaldırıldı). |
| **`feed_repository` `'nob_tier'` `Trust Shield` filter** | `feed_repository.dart:104` | `if (filters.trustShieldEnabled) query.inFilter('nob_tier', ['explorer', 'noble'])` — Trust Shield filter ayrı feature (verified + onboarded + nob_tier in [...]). statusBadge'den farklı. Kullanıcı Trust Shield'ı UI'dan açıkça aktive ediyor (filter sheet'te toggle). Trust Shield kararı ayrı tartışılır; bu sprintte dokunulmadı. |
| **Country full-name vs ISO** | `onboarding_flow_screen.dart:163` `'country': _country` | TRAVEL audit raporunda flag'lenen R-new(a) — `_country` full name yazılıyor, gate ISO bekliyor. Bu cleanup sprint'in scope'unda DEĞİL. Travel sprint için açık kaldı. |

---

## 5. Verification Containment — Doğrulandı, Geri Açılmadı

- `main_tab_navigator._showSecureTabGate` "Verification temporarily unavailable" modal'ı intact (light+burgundy, PR1+PR4'te tuned).
- `interaction_gate_provider.showGatingPopup` light+burgundy intact (commit `66d70ef`'te repaint edildi).
- Gold+siyah popup geri gelmedi (commit `66d70ef` doğrulandı).
- Verification flow re-açan kod **eklenmedi**.

---

## 6. Quality Gates

### 6.1 flutter analyze --fatal-infos

```
Analyzing noblara...
No issues found! (ran in 5.3s)
```

### 6.2 flutter test

| Metrik | Baseline | After |
|---|---:|---:|
| pass | 281 | **281** |
| fail | 0 | **0** |

Regresyon **sıfır**. Yeni test yazılmadı (UI deletion test gereksiz).

---

## 7. Manual Smoke Checklist (cihazda)

Yeni APK build sonrası:

### 7.1 Onboarding — kısaltılmış akış (7 step)

1. **Welcome** → Continue (Info step ARTIK YOK)
2. **Basics** (isim + doğum + gender)
3. **Occupation**
4. **Location**:
   - **GPS butonu YOK** — sadece "Search for your city" CTA
   - Tıkla → CitySearchScreen → şehir seç → yeşil "location result" kart görünür → Continue aktif
   - TH/VN/PH dışı şehir seçersen Travel Mode suggestion dialog (eski davranış korundu)
5. **Photo**:
   - **Avatar grid YOK** — sadece "Upload" daire butonu
   - Foto seçmeden Continue butonu **DISABLED**
   - Foto seç → check ikonu → Continue aktif
6. **Privacy** → Continue
7. **Complete** → "Enter Noblara" → MainTabNavigator

### 7.2 Filter sheet

- Discover header → filter icon → bottom sheet açılır
- Toggle'lar: Has active Nobs / Has completed prompts → intact
- **"Tier" bölümü YOK** (All / Explorer+ / Noble only chips gitti)
- Diğer chip'ler (Looking for / Lifestyle / vb.) intact

### 7.3 Discover + Profile

- Discover'a in → kart deck → swipe right → **gold+siyah popup ARTIK YOK** → light+burgundy "Add a photo first" modal (foto yoksa)
- Kart üstünde tier badge **YOK** (zaten M0'da gitmişti, doğrulama)
- Tap kart → UserProfileScreen → tier pill **YOK**, hero header burgundy gradient

### 7.4 Notification + system toasts

- Settings → Pause Account → onay → success toast: dark sage bg YOK (PR `66d70ef`'in fix'i hâlâ aktif)
- Sign Out confirm → çalışıyor

---

## 8. Files Changed Summary

| Tip | Sayı | Liste |
|---|---:|---|
| **Silinen** | 4 | tier_badge.dart, tier_promotion_screen.dart, avatar_picker.dart, info_step.dart |
| **Düzeltilen** | 6 | onboarding_flow_screen.dart, filter_state.dart, filter_provider.dart, filter_bottom_sheet.dart, feed_repository.dart, user_profile_screen.dart |
| **Migration** | 0 | (DB dokunulmadı) |
| **Yeni feature** | 0 | (yalnız kaldırma) |

---

## 9. Known Remaining Risks (gerçek cihazda kontrol)

1. **Manual cihaz smoke yapılmadı** — sadece analyze + test. UI değişiklikleri (silinen step, sadeleşmiş location, foto zorunlu) gerçek cihazda smoke gerektirir.
2. **`pubspec.yaml`'da geolocator/geocoding hâlâ var** — runtime'da kimse çağırmıyor, ama APK boyutu hâlâ taşıyor. Pubspec temizliği ayrı sprint.
3. **`location_service.dart` dosyası hâlâ var** — 139 satır dead code. Pubspec dep temizliği sırasında silinir.
4. **Foto zorunluluğu UX cooldown**: kullanıcı eski "Skip for now" alışkanlığıyla beklerse, button disabled görünür. "A photo is required" validation toast Complete step'te çıkar. Yeterince açık mı kullanıcı testinde doğrulanmalı.
5. **Eski cache'lerdeki `statusBadge` filter prefs** → silent drop. Kullanıcı eski uygulamadan migrate ettiyse "Noble only" filter'ı yokmuş gibi davranır. Acceptable.
6. **TRAVEL audit hâlâ uncommitted** — `TRAVEL_LOCATION_REALITY_AUDIT.md`. Ayrı sprint kapısı.
7. **`is_noble` profile field kaldırılmadı** — DB'de var, model'de var, UI'da render eden yok. Legacy data taşıyıcı. DB temizliği ayrı sprint.

---

## 10. Commit Önerisi

Tek commit, tek concern (final V1 cleanup):

```
chore(noblora): V1 final cleanup — drop GPS / avatar grid / tier UI

Removed UI/runtime remnants that V1 scope no longer covers. DB columns
(nob_tier, avatar_id, country) left untouched; legacy data still
readable from those rows. Verification containment intact (no flow
re-opened).

Deleted (4 files, ~40KB):
- lib/shared/widgets/tier_badge.dart (0 callers after M0 lockdown)
- lib/features/profile/tier_promotion_screen.dart (M0 removed routing)
- lib/shared/widgets/avatar_picker.dart (50-warrior CustomPainter)
- lib/features/onboarding/info_step.dart (TH/VN/PH flag-row intro)

Modified (6 files):
- onboarding_flow_screen.dart:
  * _totalSteps 8 -> 7 (info step out)
  * _LocationPage rewritten manual-only (GPS button + 5 LocationStatus
    branches + Open-Settings escalation removed; CitySearchScreen the
    only path)
  * _PhotoPage drops AvatarPicker grid + 'or' divider + avatarId state;
    photo becomes mandatory (validateCompletion now requires _photoUrl,
    no avatar fallback)
- filter_state.dart / filter_provider.dart / filter_bottom_sheet.dart /
  feed_repository.dart: removed statusBadge filter (All / Explorer+ /
  Noble only); count_filtered_profiles always passes null tier filter
- user_profile_screen.dart: removed initialTier param + NobTier import;
  _HeroHeader no longer takes a tier (was already ignored after M0)

Quality gates:
- flutter analyze --fatal-infos: No issues found
- flutter test: 281 pass / 0 fail (regression zero)

Flagged but not touched (kullanıcı kararı bekliyor):
- pubspec geolocator + geocoding deps (LocationService dead but the
  package costs apk size)
- help_center copy with Noble Date / Observer → Explorer → Noble
  language (needs copy review, not blind rename)
- appearance_provider.isNoble + AccentColor.nobleOnly (dead branch)
- AppColors.nobNoble/Explorer/Observer aliases (internal names)
- Country full-name vs ISO mismatch (Travel sprint)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

---

## 11. Sıradaki Adım

Commit + push komutunu verirsen tek commit yapacağım. Sonra fresh APK rebuild gerek (yeni binary'de avatar grid + GPS button + info step yok). Manuel cihaz smoke §7'deki checklist'le yapılır.

Cleanup turundan sonra TRAVEL_LOCATION_REALITY_AUDIT.md raporu hâlâ uncommitted. O ayrı.

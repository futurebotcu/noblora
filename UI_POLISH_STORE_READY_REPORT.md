# UI Polish — Store-Ready Rebrand (Multi-PR Sprint)

**Tarih:** 2026-05-13
**Başlık:** Dark+emerald → Light+burgundy tam rebrand
**Bu rapor kapsamı:** **PR 1 — Theme foundation only.**
**Diğer PR'lar:** kullanıcı onayından sonra ayrıca açılacak.

---

## 1. Executive Summary

Kullanıcı talebi: Mevcut Match / Discover / Profile tasarımını "temiz, modern,
tutarlı, store-ready" hale getirmek. Stitch referansları beyaz zemin + bordo
aksan + soft card yönü gösteriyor.

Mevcut deploy edili tema: **dark sage (`#0B0D0C` + `#1A211E`) + emerald
(`#2C8C68`)**. Hedef tema: **beyaz/açık zemin + burgundy (`#8B3A4A`)**.

Karar (kullanıcı onayı, AskUserQuestion 2026-05-13): **Option A — tam rebrand,
3-5 PR.**

PR sırası:

| PR | Konu | Durum |
|---|---|---|
| **PR 1** | Theme foundation (app_colors + app_theme + premium + app_tokens) | **BU RAPORDA** ✅ |
| PR 2 | Discover/Match — feed_screen + swipe_card_widget hardcoded dark hex sökümü | Bekleniyor |
| PR 3 | Profile — `_profileBg/_profileCard/_profileElevated/_profileBorder` light eşdeğeri | Bekleniyor |
| PR 4 | Settings + Bottom Nav + auth/welcome/sign_in/sign_up + onboarding | Bekleniyor |

PR 1'in görsel etkisi: ThemeData üzerinden Material widget'ları (AppBar,
Scaffold, BottomNav default, Button, Input, Dialog, SnackBar, Chip, Switch,
Slider, Checkbox, Radio, TabBar, ProgressIndicator, Divider) anında light +
burgundy görünür. Doğrudan `AppColors.emerald600` çağıran her callsite de
aynı anda burgundy render eder çünkü emerald aliasları burgundy'ye remap
edildi. Hardcoded dark hex kullanan ekran fragmanları (profile_screen
`_profileBg`, swipe_card foto gradient'lar gibi) hâlâ koyu — PR 2/3 bunları
söker.

---

## 2. Files Changed (PR 1)

| Dosya | Değişiklik özeti |
|---|---|
| `lib/core/theme/app_colors.dart` | Burgundy 50-900 palette eklendi; emerald* aliasları burgundy değerlere remap; foundation light (`bg=#FFFFFF`, `surface=#FAFAFA`); text dark-on-light; borders subtle light; SwipeOverlays light-bg için yumuşatıldı; AccentColor list'te default `burgundy`, eski `emerald`/`bordeaux` id'leri `accentById` içinde normalize. |
| `lib/core/theme/app_theme.dart` | `ThemeData.dark()` → `ThemeData.light()`, `ColorScheme.dark` → `ColorScheme.light` (primary=`burgundy600`); BottomNav bg = `AppColors.bg` (white); SnackBar bg = `textPrimary` (dark) kontrast için; Dialog/Sheet shadow opacity light-uygun. |
| `lib/core/theme/premium.dart` | Shadow'lar light için yumuşatıldı (0.04–0.06 opacity, eskisi 0.08–0.12); surfaceGradient/cardGradient ışık tonlu (`#FFFFFF→#FAF6F7`); `photoOverlay` photo-card legibility için bilerek koyu KORUNDU; `heroGradient` tint default burgundy; decoration'lardaki accent referansları burgundy'e döndü. Method isimleri (`emeraldGlow`, `glowBorder`, `dialogShape`, `sheetHandle`) callsite uyumluluğu için korundu. |
| `lib/core/theme/app_tokens.dart` | `isDark => false`; `shimmerHighlight` light-bg'de görünür olsun diye `elevated` → `borderLight`. |

**Yeni dosya:** Yok. **Silinen dosya:** Yok.

---

## 3. Tasarım Kararları

### 3.1 Alias stratejisi — neden emerald* isimleri silinmedi

`grep AppColors\.emerald[0-9]+` lib/ altında **43 dosyada** geçiyor.
`Premium.emeraldGlow|dialogShape|sheetHandle|glowBorder` **11 dosyada**.
Tek PR'da bu isimleri yeniden adlandırmak hem PR 1 scope'unu patlatır hem
de regresyon riskini büyük artırır. CLAUDE.md §5 scope creep yasağına
uyumla, PR 1 SADECE değerleri flipler; rename PR 2/3/4'te lazy migration
ile yapılır.

`AppColors.emerald600` artık `Color(0xFF8B3A4A)` (burgundy600) döndürür.

### 3.2 Burgundy palette gerekçesi

`AccentColor.bordeaux` zaten kod tabanında vardı (`primary: #B05060,
dim: #8B3A4A, nobleOnly: true`). Yeni burgundy500 = eski bordeaux primary,
burgundy600 = eski bordeaux dim. Hiç dolayıyla bir renk **uydurmadım**;
mevcut markada bordo zaten tanımlıydı. `nobleOnly: true` bayrağı kalktı
(burgundy artık herkes için default).

### 3.3 photoOverlay neden hâlâ koyu

Foto kart vignette'i isimden zaten "photo overlay" — uygulamanın temasından
bağımsız olarak fotonun üstündeki beyaz isim/yaş metni okunsun diye. Bu
dark-on-photo değil dark-on-photo-content; light tema gelse de tutulur.

### 3.4 Hâlâ KOYU görünecek alanlar (PR 1 sonrası)

PR 2/3/4'te söküleceği için PR 1 sonrası hâlâ aşağıdaki yerler kararını
sürdürür:

- `lib/features/profile/profile_screen.dart:21-24` — `_profileBg=#1A211E`,
  `_profileCard=#283130`, `_profileElevated=#323B38`, `_profileBorder=#445049`
- `lib/features/feed/swipe_card_widget.dart` foto gradient ve verified pill
  arka planı bilinçli koyu (`Colors.black.withValues(alpha: 0.35)`)
- Bazı Auth/Welcome ekranları (lib/features/auth/) direkt hex kullanıyorsa

Bunlar Apple/Google Store screenshot için kabul edilebilir değil — PR 2/3/4
sırayla kapatacak.

---

## 4. Removed Visual Leftovers — yok (PR 1 scope dışı)

Bu PR sadece foundation; UI surface'leri kasten dokunulmadı. Tier UI'ı
zaten bir önceki sprint (commit `3e4c641 hide tier UI surfaces`)
gizlemişti, verification CTA gating de R17/R20'yle kapanmıştı. PR 1
foundation flip'i bu kararları **etkilemez**.

---

## 5. Overflow / Responsive Checks — PR 2 scope

PR 1 sadece tokens; widget tree değişmedi, layout aynı. Overflow/responsive
checks PR 2'de gerçek ekranları sökerken yapılır (feed_screen — uzun
isim/çok chip/boş avatar). Bu raporda kapsam dışı, kasten doğrulanmadı.

---

## 6. Quality Gates (PR 1)

### 6.1 flutter analyze --fatal-infos

```
Analyzing noblara...
No issues found! (ran in 5.7s)
```

Kanıt: PR 1 öncesi baseline da No issues findi. PR 1 sonrası da aynı.

### 6.2 flutter test

| Metrik | Baseline (PR 1 öncesi) | PR 1 sonrası | Delta |
|---|---:|---:|---:|
| pass | 281 | **281** | 0 |
| fail | 0 | **0** | 0 |

Çıktı son satır:
```
00:03 +281:
```

Regresyon **sıfır**. Theme token aliaslama stratejisi callsite kontratlarını
korudu.

---

## 7. Remaining UI Risks (PR 1 sonrası, dürüst envanter)

| # | Risk | Etki | Çözüm PR'ı |
|---|---|---|---|
| 1 | profile_screen `_profileBg` constant'ları hâlâ koyu sage | Profile ekranı tema mismatch (her yer beyaz, profile koyu) | PR 3 |
| 2 | swipe_card foto altında verified pill bg `Colors.black.withValues(alpha:0.35)` | Light bg'de hâlâ koyu pill — foto üstünde KABUL edilebilir | PR 2'de değerlendir |
| 3 | feed_screen `_Header`'da büyük "N" emerald600 — şimdi burgundy ama "serif" font + standalone "N" brand identity tartışılır | Görsel kalite | PR 2'de logo refresh |
| 4 | `_PersonaSection` mode pills `mode.accentColor` kullanıyor (NobleMode enum'undan) | Mode accent enum kendi rengini taşıyor; tema fliplinde update edilmedi | PR 2/3'te NobleMode enum review |
| 5 | Test count 281 — guardrail testleri (banned patterns) PR 1'de eklenmedi; yeni hardcoded dark hex eklemediğim için zorunlu değil | OK | — |
| 6 | Hâlâ `Premium.emeraldGlow` ismi var; yeni dev confused olabilir | DX | PR 5 (rename) |
| 7 | `app_tokens.dart isDark => false` — herhangi bir callsite `if (context.isDark)` yapıyorsa dallanması bozulur | Düşük (hızlı grep ile doğrula) | PR 2/3'te kontrol |

---

## 8. Verification (manuel cihaz/emülatör)

**Bu raporda kanıt yok** — flutter analyze + flutter test koştu, manuel
emülatör smoke yapılmadı. CLAUDE.md §1 gereği "doğrulanmadı". User'ın
açık talebi "Commit/push öncesi dur" olduğu için commit de yapılmadı —
manuel smoke commit sonrasına bırakıldı.

Kullanıcının manuel olarak çalıştırması önerilen:
```
flutter run -d <android-emu>
```
Beklenen: AppBar/BottomNav/Button/Input/Dialog/SnackBar/Chip artık light
+ burgundy. Discover ve Profile ekranlarının iç render'ı kısmen koyu
(PR 2/3 sökecek).

---

## 9. Next Recommended Step

**PR 2 — Discover/Match light layout.** Dokunacak dosyalar:

- `lib/features/feed/feed_screen.dart` — `_Header`'da emerald logo, action
  buttons, empty state, error state
- `lib/features/feed/swipe_card_widget.dart` — `_CardBody` `Border.all`
  ve `Premium.cardGradient` çağrıları (zaten flip oldu otomatik); verified
  pill bg light/dark karar; foto vignette KORUNUR
- `lib/widgets/locked_swipe_banner.dart` — banner
- `lib/shared/widgets/mode_switcher.dart` — mode pills

PR 2 sonrası kullanıcı emülatörde Discover'ı görebilir → onay → PR 3
(Profile) → PR 4 (Settings + Nav + Auth).

PR 1 + 2 + 3 + 4 kapandıktan sonra → **fresh AAB rebuild** → gerçek cihaz
manuel smoke → store screenshot çekimi.

---

## 10. Commit Notu

Commit yok — kullanıcı talimatı "Commit/push öncesi dur ve özet ver".
Kullanıcının onayı sonrası commit:

```
fix(noblora): PR 1 theme rebrand foundation (dark+emerald → light+burgundy)

- app_colors: burgundy 50-900 palette; emerald* aliases now resolve to
  burgundy values (callsite-compatible flip); light foundation + dark text
- app_theme: ThemeData.light(), ColorScheme.light, primary=burgundy600;
  BottomNav/Dialog/SnackBar light-bg appropriate
- premium: shadows softened for light surfaces; gradients flipped;
  photoOverlay intentionally kept dark for photo-card text legibility
- app_tokens: isDark=false; shimmerHighlight uses borderLight

Quality gates:
- flutter analyze --fatal-infos: No issues found
- flutter test: 281 pass / 0 fail (baseline 281/0, regression zero)

Hardcoded dark hex in profile_screen and swipe_card_widget remains —
deliberately scoped out (PR 2 + PR 3).
```

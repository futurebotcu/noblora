# Verification Gate Popup Regression Fix

**Tarih:** 2026-05-13
**Yöntem:** Kanıt-dayalı tek-pass tespit + minimal fix. Tahmin yok.
**Sonuç:** 2 dosya, 281/0 test, regresyon sıfır.

---

## 1. Root Cause — Net

Kullanıcı yeni hesapla onboarding'i bitirip Discover'a girdiğinde "gold + siyah" popup gördü. Mesaj kullanıcı dilinde **"Fotoğraf doğrulanmadı / doğrulama olmadan match yapamazsın"** olarak paraphrased; gerçek metin **"Add a photo first / Upload at least one photo to start connecting with people"**.

Kaynak: **`lib/providers/interaction_gate_provider.dart:70-117` — `showGatingPopup`** widget'ı. PR1 rebrand'ında token-driven yapılmadığı için hardcoded eski renkler kalmıştı:

| Eski (gold + black, pre-rebrand) | Yeni (light + burgundy) |
|---|---|
| bg `Color(0xFF111113)` (near-black) | `context.surfaceColor` (#FAFAFA) |
| handle `Color(0xFF222225)` (dark gray) | `AppColors.border` (#E3E5E8) |
| icon circle `AppColors.gold 0.06 + 0.15` | `AppColors.burgundy600 0.08 + 0.20` |
| icon color `AppColors.gold` (#B8862C) | `AppColors.burgundy600` (#8B3A4A) |
| title text `Color(0xFFF2F2F2)` (off-white) | `context.textPrimary` (#14181A) |
| message text `AppColors.gold` (gold!) | `context.textMuted` (#7A8088) |
| button bg `AppColors.gold` + fg `Color(0xFF080808)` (black) | bg `AppColors.burgundy600` + fg white |

Tetikleyici: `feed_screen._checkGate` → `gate.canInteract('date')` false → `hasPhoto=false` → bu popup. Yeni kullanıcı henüz fotoğrafsız olduğu için fire ediyor. Mantığı **valid** (foto gate gerekli), ama görsel "ilk dönem tasarımı" gibi kalmış.

---

## 2. Yan Tespit — `swipe_toast.dart` PR1 Miss

`lib/shared/widgets/swipe_toast.dart:75-78`:

```dart
// ÖNCE
Color get _toastBackground => switch (widget.type) {
  ToastType.success => const Color(0xFF152018),  // ← hardcoded dark sage
  _ => AppColors.surface,
};
```

Light scaffold'da success toast'ı near-black pill olarak rendere veriyordu. PR1 token flip'inin **kaçırdığı tek inline hex**. Aynı PR'da kapatıldı.

---

## 3. Fix — 2 Dosya

### 3.1 `lib/providers/interaction_gate_provider.dart`

**Değişiklikler:**

| # | Aksiyon |
|---|---|
| 1 | Bottom sheet bg, handle, icon circle, text, button: hepsi `context.*` token + `AppColors.burgundy600`'a bağlandı |
| 2 | Inline `ScaffoldMessenger.showSnackBar` → `ToastService.show(..., type: ToastType.system)` (toast standardı app-wide tutarlı) |
| 3 | `enum GatePopupType { addPhoto, verifyPhoto }` **kaldırıldı** — `verifyPhoto` variant'ının lib/ altında **0 caller'ı** vardı (grep ile doğrulandı); M0 verification lockdown nedeniyle bu CTA "Get Verified" disabled flow'a yönlendirecekti, scope-creep / containment ihlali olurdu. |
| 4 | `Navigator.pop(context)` → `Navigator.pop(sheetCtx)` (sheet kendi context'inden pop) + `if (!context.mounted) return` async toast öncesi |
| 5 | Imports: `app_spacing.dart`, `app_tokens.dart`, `toast_service.dart` eklendi; `premium.dart` import edilmedi (kullanılmıyordu) |
| 6 | Multi-line yorum (V1 history): neden gold→burgundy + neden verifyPhoto kaldırıldı + neden ScaffoldMessenger→ToastService — DRIFT engelleyici |

**Verification kapalı kararı korundu:** Bu popup ARTIK SADECE `addPhoto` (fotoğraf yok) durumunda render ediyor. Verification-blocking durumda fire eden bir caller yok. Eğer ileride verification yeniden açılırsa, ayrı bir surface eklenecek (broken flow re-route'u engellemek için).

### 3.2 `lib/shared/widgets/swipe_toast.dart`

**Değişiklik:** Line 75-78 — `_toastBackground` getter sadeleşti:

```dart
// SONRA
Color get _toastBackground => AppColors.surface;
```

Success'in görsel ayrımı `_dotColor` (= `AppColors.emerald500` → burgundy500 via alias) + border alpha + shadow halo üzerinden zaten geliyor — bg ayrımı gereksizdi, sadece eski koyu temadan kalıntıydı.

---

## 4. Files Changed

| Dosya | Δ |
|---|---|
| `lib/providers/interaction_gate_provider.dart` | `showGatingPopup` rewrite + `GatePopupType` enum kaldırıldı + import eklemeleri (~70 satır net değişim) |
| `lib/shared/widgets/swipe_toast.dart` | 4 satırlık getter sadeleşti, hardcoded `Color(0xFF152018)` kaldırıldı |

Migration **YOK**. Yeni widget eklenmedi. Yeni feature eklenmedi. Verification sistemi geri açılmadı.

---

## 5. Quality Gates

### 5.1 flutter analyze --fatal-infos

```
Analyzing noblara...
No issues found! (ran in 133.4s)
```

### 5.2 flutter test

| Metrik | Baseline | After |
|---|---:|---:|
| pass | 281 | **281** |
| fail | 0 | **0** |

Regresyon **sıfır**.

---

## 6. Manual Smoke Checklist (cihazda)

1. **Yeni hesap aç** (auth wipe sonrası 0 user, taze başlangıç)
2. Onboarding'i bitir — **fotoğraf step'inde foto SEÇME** (skip et veya boş bırak) — gate'i tetiklemek için
3. Discover'a in → sağ swipe (like) yap
4. **Popup açılır** — **BU SEFER:**
   - Beyaz/açık zemin
   - Bordo icon (kamera + circle)
   - Dark text title ("Add a photo first")
   - Gri muted message ("Upload at least one photo...")
   - Bordo dolgulu "Add Photo" butonu + beyaz metin
   - **Gold ve siyah YOK**
5. "Add Photo" butonuna bas → modal kapanır → **light toast** ("Go to Profile tab to add or update your photo.")
   - Eski snackbar (alttan beyaz Material default) yerine swipe_toast (üstten, bordo accent)
6. **Success toast testi** (ayrı test): herhangi bir success action'la (örn pause/resume Settings) toast tetikle → bg artık koyu sage değil light pill

---

## 7. Kalan Riskler & Sonraki Sprintler

1. **Verification kapalı kalmaya devam ediyor** — M0 trust lockdown korunuyor. Bu PR sadece yanlış renkteki popup'ı düzeltti, sistemi açmadı.
2. **TRAVEL audit raporu hâlâ uncommitted** — R-new(a) full-name vs ISO country bug'ı açık. Ayrı sprint.
3. **`feed_screen._checkGate` çağrı yeri** — popup açılma logic'i intact, sadece widget repaint edildi. Test: `flutter test` 281/0 → davranışsal regresyon yok.
4. **`Navigator.pop(context)` vs `pop(sheetCtx)` fix'i** — gerçek dünyada brittle race condition'ı azaltır, ama eski davranış da pratikte çalışıyordu. Defensive cleanup.

---

## 8. Commit Önerisi

Tek commit, tek concern:

```
fix(noblora): repaint gating popup + success toast (PR1 rebrand misses)

PR1 rebrand left two pre-rebrand visuals on light surfaces:
1. interaction_gate_provider.showGatingPopup — near-black bg + gold
   accents (matched what users described as "the first-phase design
   popup")
2. swipe_toast success toast — hardcoded dark sage Color(0xFF152018)
   on a now-white scaffold (near-black pill on light bg)

Fixes:
- showGatingPopup: full repaint to light surface + burgundy accent +
  Premium dialog idioms; uses context.* tokens so future theme moves
  carry; pop(sheetCtx) instead of pop(context); inline ScaffoldMessenger
  snackbar replaced with ToastService.show for app-wide toast style
  consistency.
- Removed dead GatePopupType.verifyPhoto enum variant (no callers
  remained after M0 verification lockdown; surfacing "Get Verified"
  would re-route into the disabled flow).
- swipe_toast _toastBackground: removed hardcoded #152018 success
  arm; theme surface for all types, success arm distinguished by
  dot/border/halo already.

Quality gates:
- flutter analyze --fatal-infos: No issues found
- flutter test: 281 pass / 0 fail (regression zero)

Out of scope: verification system stays closed (M0 containment);
no Travel/monetization changes.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

Commit + push komutunu verirsen tek commit yaparım.

# Auth + Popup Stabilization — Sprint Report

**Tarih:** 2026-05-13
**Sprint adı:** Noblora Auth + Popup Stabilization
**Branch:** `main` (PR commit/push kullanıcı onayı bekliyor)
**Quality gates:** analyze ✅ · test 281/0 ✅ (regresyon sıfır)

---

## 1. Root Cause

### P0 — Change Password gerçek anlamda çalışmıyor

`lib/features/settings/settings_screen.dart` eski `_changePassword`:

```dart
Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
  if (isMockMode) return;
  final repo = ref.read(authRepositoryProvider);
  final email = await repo.getCurrentUserEmail() ?? '';
  await repo.resetPasswordForEmail(email);   // <-- sadece reset mail!
  if (context.mounted) {
    ToastService.show(context,
        message: 'Password reset email sent', type: ToastType.success);
  }
}
```

Kullanıcı vaadi: "Change Password" → in-app yeni şifre formu.
Gerçek davranış: Supabase `resetPasswordForEmail` çağrılıp **email** atılıyor.
UX-implementation mismatch. Store reviewer "Change Password works" kontrolünde
fail. Kullanıcı email'i göremezse veya deep-link mevcut değilse şifre asla
değişmiyor.

`lib/data/repositories/auth_repository.dart` içinde `supabase.auth.updateUser(
UserAttributes(password: ...))` çağrısı **hiç yoktu**. Dolayısıyla
authenticated user için in-app şifre değiştirme **kod tabanında mevcut değildi**.

### P1 — Sign Out onaysız direkt sign-out

`settings_screen.dart` eski Sign Out satırı:

```dart
_Row(Icons.logout_rounded, 'Sign Out',
    iconColor: AppColors.error,
    titleColor: AppColors.error,
    showChevron: false,
    onTap: () {
      Navigator.of(context).popUntil((route) => route.isFirst);
      ref.read(authProvider.notifier).signOut();
    }),
```

Yanlışlıkla tıkla → oturum koparıyor, hiçbir uyarı yok. Pause/Delete'in
hepsi onay diyaloğu istiyor ama Sign Out istemiyordu — tutarsız UX,
mağazada güven kıran sürpriz davranış.

---

## 2. Fix — Change Password Flow

### 2.1 Backend katmanı

**`lib/data/repositories/auth_repository.dart`** — yeni method:

```dart
/// In-app password change for an already-signed-in user. The active
/// session token authorizes the change (Supabase does not require the
/// current password here). Caller is responsible for length/strength
/// validation; this method surfaces any backend error.
Future<void> updatePassword(String newPassword) async {
  if (isMockMode) return;
  await _supabase!.auth.updateUser(UserAttributes(password: newPassword));
}
```

Supabase contract:
- Authenticated session → token auth yeterli, current password sorulmaz.
- Min 6 char default (Supabase server policy); biz client tarafında 8'e
  çekiyoruz (sign-up ile aynı standart).

### 2.2 Provider katmanı

**`lib/providers/auth_provider.dart`** — `AuthNotifier.updatePassword`:

```dart
/// Returns `null` on success or a user-facing error string. Caller
/// (the Settings modal) validates strength before calling; this is the
/// last line of defense so it also rejects anything shorter than 8 chars.
Future<String?> updatePassword(String newPassword) async {
  if (newPassword.length < 8) {
    return 'Password must be at least 8 characters.';
  }
  try {
    await _repo.updatePassword(newPassword);
    return null;
  } catch (e) {
    return _friendlyError(e);
  }
}
```

`_friendlyError` zaten password/network/rate-limit Supabase exception'ları
için varolan mapping'i kullanıyor — yeni mapping eklenmedi.

### 2.3 UI katmanı

**`lib/features/settings/settings_screen.dart`** — yeni `_ChangePasswordDialog`
(StatefulWidget, dosya sonunda `_ReqRow` yardımcısıyla):

| Alan | Davranış |
|---|---|
| New password TextField | obscure default, show/hide toggle, onChanged → error clear |
| Confirm password TextField | aynı |
| Strength checklist (real-time) | ≥8 char · 1 uppercase · 1 number · match |
| Submit | 4 kuralın hepsi geçmeden disabled; loading state CircularProgressIndicator |
| Cancel | loading sırasında disabled |
| Error | inline kırmızı metin, modal kapatmaz |
| Success | `Navigator.pop(context, true)` → Settings'te success toast |

Modal `barrierDismissible: false` — kullanıcı yanlışlıkla dışarı tıklayıp
yarım bıraktığında kayıp veri yok.

`mounted` guard `_submit` içinde async sonrası → state çağrısı disposed
context'e gitmiyor.

---

## 3. Fix — Sign Out Confirmation

**`settings_screen.dart`** — yeni `_confirmSignOut`:

```dart
void _confirmSignOut(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: context.surfaceColor,
      shape: Premium.dialogShape(),
      title: Text('Sign out?', ...),
      content: Text('You can sign back in anytime with the same email...'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
        TextButton(
            onPressed: () {
              Navigator.pop(ctx);                                  // 1. dialog
              Navigator.of(context).popUntil((r) => r.isFirst);   // 2. route stack
              ref.read(authProvider.notifier).signOut();           // 3. session
            },
            child: const Text('Sign Out', style: TextStyle(color: AppColors.error))),
      ],
    ),
  );
}
```

Pause/Delete dialog kalıbıyla aynı: light bg, `Premium.dialogShape()`, mu-
ted Cancel + destructive primary action.

---

## 4. Audit — Diğer Popup'lar (Dokunulmadı, çünkü sağlam)

Aşağıdaki dialog/sheet/snackbar'lar test/grep ile incelendi; bilinen
hatalı pattern (double-pop, missing `context.mounted`, off-screen
keyboard) **bulunamadı**. CLAUDE.md §5 scope creep yasağı gereği
çalışan koda dokunulmadı.

| Lokasyon | Tür | Durum |
|---|---|---|
| `settings_screen._confirmPause` | AlertDialog | `if (context.mounted)` async sonrası ✓ |
| `settings_screen._confirmResume` | AlertDialog | aynı ✓ |
| `settings_screen._confirmDelete` | StatefulBuilder + TextField | `Navigator.pop(ctx)` doğru kullanım + mounted check ✓ |
| `main_tab_navigator._showSecureTabGate` | ModalBottomSheet | `Navigator.pop(sheetCtx)` doğru + sonraki push sync ✓ |
| `sign_up_screen._showBlockDialog` | AlertDialog | `Navigator.pop(ctx)` ✓ |
| `sign_up_screen._showAccountExistsDialog` | AlertDialog | iki-step pop kasıtlı (dialog + sign-up screen) — Sign In'e dönüş ✓ |
| `sign_in_screen._handleForgotPassword` | Toast | regex validation + try/catch + mounted ✓ |
| `feed_screen._showNoteDialog` | AlertDialog | `Navigator.pop(ctx)` + try/catch + mounted ✓ |
| `feed_screen.showGatingPopup` | ? (cross-file helper) | grep ile incelenmedi (scope dışı) |

**Network error popup / profile save error popup:** kod tabanında dedicated
modal yok — error'lar ToastService veya inline form text ile sunuluyor.
Bu doğru kalıp; kötü pattern değil. Yeni popup eklenmedi.

---

## 5. Popup UI Standardı

PR 1 rebrand zaten popup'ların görsel dilini token'a bağladı. Bu sprintte
yeni dialog (`_ChangePasswordDialog`, `_confirmSignOut`) aynı standardı
takip ediyor:

- **Background:** `context.surfaceColor` (light `#FAFAFA`)
- **Shape:** `Premium.dialogShape()` (rounded 24 + burgundy 10% border)
- **Primary action:** burgundy600 weight 700
- **Destructive action:** `AppColors.error` weight 600
- **Cancel:** `context.textMuted` weight default
- **Title:** 18px w700, dark text
- **Content:** 14px regular, muted text
- **No double-pop:** her popup tek `Navigator.pop(ctx)` ile kapanır;
  ardışık navigation ihtiyacı olan `_confirmSignOut` & `_showAccountExistsDialog`
  bunu **kasıtlı + yorum açıklamasıyla** yapıyor.

---

## 6. Files Changed

| Dosya | Δ |
|---|---|
| `lib/data/repositories/auth_repository.dart` | +`updatePassword(String)` (Supabase `auth.updateUser`) |
| `lib/providers/auth_provider.dart` | +`AuthNotifier.updatePassword(String) → Future<String?>` (validation + error mapping) |
| `lib/features/settings/settings_screen.dart` | `_changePassword` → modal launcher; +`_confirmSignOut`; +`_ChangePasswordDialog` (ConsumerStatefulWidget, ~170 satır); +`_ReqRow` helper; Sign Out row onTap → confirm |

**Net diff:** ~210 insertion, ~10 deletion. Yeni dosya yok.

---

## 7. Manual Test Checklist (gerçek cihaz)

### 7.1 Change Password — happy path

1. Settings → "Change Password" tap
2. Modal açılır: New password + Confirm + 4 strength req checklist + Cancel + Update
3. New password: `Test1234` yaz → checklist: 8 char ✓, upper ✓, number ✓, match ✗
4. Confirm: `Test1234` yaz → match ✓
5. Update tap → CircularProgressIndicator → modal kapanır → "Password updated" success toast
6. Sign out → yeni şifre ile sign in → başarılı

### 7.2 Change Password — error paths

- Boş alanlar → Update disabled (button gri)
- 7 char password → "8 chars" req kırmızı, Update disabled
- Eşleşmeyen confirm → "Passwords match" kırmızı, Update disabled
- Aynı şifre (Supabase "same_password" reject) → inline error kırmızı, modal açık kalır
- Network kesik → "Network error. Check your connection..." inline error
- Rate limit → "Too many attempts. Please wait..." inline error
- Modal dışına tıkla → barrier dismissible kapalı, modal kalır
- Cancel → modal kapanır, hiçbir değişiklik yok

### 7.3 Sign Out

1. Settings → "Sign Out" tap (kırmızı satır)
2. Onay diyaloğu açılır: "Sign out?" + "You can sign back in anytime..."
3. Cancel → diyalog kapanır, oturum sürer
4. Tekrar Sign Out → Sign Out tap → Welcome screen'e dön

### 7.4 Diğer flow'ların regresyon yokluğu

- Pause Account → confirm dialog → pause → success toast → resume row görünür
- Resume Account → confirm dialog → resume → success toast → pause row görünür
- Delete Account → type "DELETE" → enabled Delete button → Pause + verification_status:'deletion_requested' set → sign out + welcome
- Deletion recovery banner → "Cancel Deletion" → status reset
- Sign In → Forgot password? → email valid → reset email sent toast
- Secure tab gate (verification incomplete) → Discover/Chats tap → sheet açılır → OK kapatır

---

## 8. Quality Gates

### 8.1 flutter analyze --fatal-infos

```
Analyzing noblara...
No issues found! (ran in 10.5s)
```

### 8.2 flutter test

| Metrik | Baseline | After |
|---|---:|---:|
| pass | 281 | **281** |
| fail | 0 | **0** |

Regresyon **sıfır**. Yeni testler eklenmedi (widget test for password
dialog ileride önerilebilir, ama bu sprint kapsamı dışı).

---

## 9. Remaining Risks

1. **Manuel cihaz smoke yapılmadı** — yeni modal'ın keyboard üstünde
   davranışı, küçük ekranda strength req checklist scrolling, text scale
   1.2'de overflow — cihazda doğrulanmalı.
2. **Supabase password policy uyumu** — Supabase tarafında bir password
   strength rule (örneğin "min 6, no requirements") varsa client 8-char
   kuralı sıkı taraf olur, sorun değil. Ama policy değiştirilirse
   `_allValid` kuralı da güncellenmeli.
3. **Mock mode davranışı** — `isMockMode` ise modal launcher erkenden
   `return`; modal hiç açılmaz. Mock test sırasında "Change Password"
   tap'i no-op olur. Sign Out confirmation ise mock'ta da açılır (sadece
   `signOut()` mock'ta no-op döner). Tutarsızlık değil ama not.
4. **Forgot password fallback** — Authenticated user şifresini hatırlamasa
   bile yine in-app form gösteriliyor (current password sorulmuyor). Tek
   önlem: kullanıcı session'ı geçersizse `updateUser` Supabase tarafında
   401 döner, `_friendlyError` "Network error..." veya generic error
   verir. Bu durumda kullanıcı sign out → sign in → forgot password
   akışına gitmeli. Modal içinde "Forgot password?" link **kasıtlı yok**
   — çünkü authenticated user için anlamlı değil. Bu kararı tartışmak
   istersen söyle, link eklerim.
5. **`_confirmPause` / `_confirmResume` outer `context` ile pop ediyor**
   (sign_up pattern'i değil). Çalışıyor ama brittle. Sprint kapsamı
   dışı bırakıldı (CLAUDE.md §5).

---

## 10. Sonraki Adım

Bu sprintin commit + push'undan sonra:

- Cihaza yeni APK kur, §7 manuel checklist'i tara
- Yeşil → store-ready (PR 5 olarak commit edilir)
- Kırmızı → bulguları paylaş, mini PR 6 ile fix

**Bu sprint kapsamı dışında bırakılanlar (kullanıcı talimatı):**
yeni feature, monetization, Liked You, billing, redesign — hiçbiri
dokunulmadı.

---

## 11. Commit Önerisi

Tek commit, tek concern (auth/popup stabilization):

```
fix(noblora): in-app change password + sign out confirmation

P0 - Change Password row in Settings called resetPasswordForEmail,
sending the user a reset email instead of letting them change the
password in-app. Replaced with a proper modal that validates strength
(8 chars + uppercase + number + match), calls Supabase auth.updateUser
via the existing session token, and surfaces friendly errors via the
existing _friendlyError mapping.

P1 - Sign Out row triggered signOut() directly with no confirmation.
Added a confirm dialog (same shape as Pause/Delete) so an accidental
tap no longer drops the user back to Welcome.

Added:
- auth_repository.updatePassword(String) -> Supabase updateUser
- AuthNotifier.updatePassword(String) -> Future<String?> with the
  existing friendly-error mapping
- _ChangePasswordDialog (ConsumerStatefulWidget) + _ReqRow helper
- _confirmSignOut(BuildContext, WidgetRef)

Quality gates:
- flutter analyze --fatal-infos: No issues found
- flutter test: 281 pass / 0 fail (regression zero)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

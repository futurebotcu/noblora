import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/premium.dart';
import '../../core/utils/legal_urls.dart';
import '../../core/utils/mock_mode.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../core/services/toast_service.dart';
import 'help_center_screen.dart';

// ═══════════════════════════════════════════════════════════════════
// Settings — V1 minimal (R17B root cleanup + R17B-fix safety surface)
//
// Surface contract: only rows whose underlying behavior is wired
// end-to-end (UI ↔ provider ↔ Supabase ↔ enforcement) remain visible.
//
//   Account            — email · change password
//   Privacy & Safety   — photo verify · selfie verify · message previews
//   Help & Legal       — help center · privacy policy
//   (deletion recovery banner — only when verification_status = deletion_requested)
//   Danger zone        — pause/resume · delete account · sign out
//
// R17B-fix product decision: Block is a one-way action in V1.
// The Settings "Blocked Users" list/unblock surface was removed because
// surfacing "who you no longer want to see" creates a re-engagement
// loop that V1 dating UX does not want. Block enforcement (chat menu
// + match-detail menu → addToBlockList → feed_repository discovery
// exclusion) is intact. The Hide User flow is gone everywhere in V1
// (Settings + chat + match-detail) — see companion commit.
//
// R17B removed root-to-leaf:
//   - Calm Mode (no enforced gating logic)
//   - Show last active / Show status badge (model fields kept on backend
//     and read by profile_card; only the toggle UI is gone — users land
//     on schema defaults `true`)
//   - Reach / Signal / Note permission rows (read nowhere; phantom UI)
//   - Notifications card entirely (only `new_match` and `bff_connected`
//     types were ever server-enforced — Cleanup PR #50 already trimmed
//     this card to 2 rows; V1 simplification drops it completely)
//   - AI Preferences card (Nob Text Cleanup + Message Softening) — the
//     individual_chat_screen still reads `ai_writing_help.message_softening`
//     so existing rows keep working; users land on default `true` and
//     can't toggle for V1
//   - Hidden Users — R17B-fix: removed everywhere user-facing. The
//     Settings row, the chat-menu "Hide user" entry, and the
//     match-detail "Hide user" entry are all gone. Backend `hidden_users`
//     array stays (feed_repository discovery filter still excludes any
//     existing entries, so legacy data is respected), but no new hide
//     can be created from V1 UI. Block is the only one-way safety
//     action that V1 surfaces.
//   - Incognito Mode toggle — backend `incognito_mode` column stays
//     (feed_repository discoverability filter reads it); the toggle UI
//     is gone, so users land on schema default `false`
//   - Account static rows (ID Verification placeholder, "Safety Tips" /
//     "Community Rules" / "Contact Support" / "Request My Data" /
//     "Community Guidelines" / "Report a Bug" / "AI privacy note") —
//     already removed in Cleanup PR #50 / R17B confirms structure
// ═══════════════════════════════════════════════════════════════════

final _settingsProvider =
    StateNotifierProvider<_SettingsNotifier, Map<String, dynamic>>((ref) {
  return _SettingsNotifier(ref);
});

class _SettingsNotifier extends StateNotifier<Map<String, dynamic>> {
  final Ref _ref;

  _SettingsNotifier(this._ref) : super({}) {
    _load();
  }

  Future<void> _load() async {
    if (isMockMode) {
      state = _defaults();
      return;
    }
    final uid = _ref.read(authProvider).userId;
    if (uid == null) return;
    try {
      final row =
          await _ref.read(profileRepositoryProvider).fetchSettingsRow(uid);
      if (row != null) state = row;
    } catch (e) {
      debugPrint('[settings] load failed: $e');
      state = _defaults();
    }
  }

  Map<String, dynamic> _defaults() => {
        'message_preview': true,
        'is_verified': false,
        'selfie_verified': false,
        'photos_verified': false,
        'verification_status': 'not_started',
        'is_paused': false,
      };

  Future<void> _save(String column, dynamic value) async {
    final previous = state[column];
    state = {...state, column: value};
    if (isMockMode) return;
    final uid = _ref.read(authProvider).userId;
    if (uid == null) return;
    try {
      await _ref.read(profileRepositoryProvider).updateProfile(uid, {column: value});
    } catch (e) {
      debugPrint('[settings] save failed for $column: $e');
      state = {...state, column: previous};
    }
  }

  void toggleBool(String key) {
    final c = state[key] as bool? ?? false;
    _save(key, !c);
  }

  void setString(String key, String value) => _save(key, value);

  bool getBool(String key) => state[key] as bool? ?? false;

  String getString(String key) => state[key] as String? ?? '';
}

// ═══════════════════════════════════════════════════════════════════
// Settings Screen
// ═══════════════════════════════════════════════════════════════════

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(_settingsProvider);
    final n = ref.read(_settingsProvider.notifier);
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        surfaceTintColor: Colors.transparent,
        title: Text('Settings',
            style: TextStyle(
                color: context.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3)),
        iconTheme: IconThemeData(color: context.textPrimary),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: 80),
        children: [
          // ── Deletion recovery banner ────────────────────────────
          if ((s['verification_status'] as String?) == 'deletion_requested')
            _DeletionRecoveryBanner(notifier: n),

          // ── 1. ACCOUNT ──────────────────────────────────────────
          const _Section('Account'),
          _Card(children: [
            _Row(Icons.email_outlined, 'Email', value: auth.email ?? 'Not set'),
            _Row(Icons.lock_outlined, 'Change Password',
                onTap: () => _changePassword(context, ref)),
          ]),

          // ── 2. PRIVACY & SAFETY ─────────────────────────────────
          // Blocked Users list/unblock UI removed in R17B-fix — Block is
          // a one-way action in V1 (chat / match-detail Block menu still
          // calls addToBlockList → discovery exclusion). Surfacing the
          // list creates a re-engagement loop V1 explicitly avoids.
          //
          // Photo / Selfie Verification status rows hidden in the
          // verification containment sprint — the upgrade path is
          // temporarily disabled (see main_tab_navigator gate copy), so
          // surfacing per-user "Not verified" status without a way to
          // act on it is misleading. Existing verified users keep their
          // badge in Discover via profiles.is_verified.
          const _Section('Privacy & Safety'),
          _Card(children: [
            _Toggle(Icons.preview_rounded, 'Message Previews',
                s['message_preview'] as bool? ?? true,
                (_) => n.toggleBool('message_preview'),
                sub: 'Show content in inbox list'),
          ]),

          // ── 3. HELP & LEGAL ─────────────────────────────────────
          const _Section('Help & Legal'),
          _Card(children: [
            _Row(Icons.help_outline_rounded, 'Help Center',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const HelpCenterScreen()))),
            _Row(Icons.privacy_tip_outlined, 'Privacy Policy',
                onTap: () async {
                  final ok = await launchLegalUrl(kPrivacyPolicyUrl);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Could not open Privacy Policy')),
                    );
                  }
                }),
          ]),

          // ── Version footer ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            child: Center(
              child: Text('Noblara v1.0.0',
                  style: TextStyle(
                      color: context.textDisabled,
                      fontSize: 12,
                      letterSpacing: 0.3)),
            ),
          ),

          // ── 4. DANGER ZONE ──────────────────────────────────────
          const SizedBox(height: AppSpacing.xxxl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.4), width: 0.5),
              ),
              child: Column(
                children: [
                  if (s['is_paused'] as bool? ?? false)
                    _Row(Icons.play_circle_outline, 'Resume Account',
                        sub: 'Your account is paused — tap to reactivate',
                        iconColor: AppColors.success,
                        onTap: () => _confirmResume(context, ref))
                  else
                    _Row(Icons.pause_circle_outline, 'Pause Account',
                        sub: 'Hide from discovery, keep your data',
                        iconColor: AppColors.warning,
                        onTap: () => _confirmPause(context, ref)),
                  _divider(context),
                  _Row(Icons.delete_outline, 'Delete Account',
                      sub: 'Permanently deleted after 30 days',
                      iconColor: AppColors.error,
                      titleColor: AppColors.error,
                      onTap: () => _confirmDelete(context, ref)),
                  _divider(context),
                  _Row(Icons.logout_rounded, 'Sign Out',
                      iconColor: AppColors.error,
                      titleColor: AppColors.error,
                      showChevron: false,
                      onTap: () => _confirmSignOut(context, ref)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────

  /// Opens the in-app change-password modal. Mock mode short-circuits
  /// (no backend call). The modal owns its own loading + error state via
  /// the [_ChangePasswordDialog] StatefulWidget below, then on success
  /// pops itself and shows a confirmation toast on the Settings screen.
  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    if (isMockMode) return;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (ok == true && context.mounted) {
      ToastService.show(context,
          message: 'Password updated', type: ToastType.success);
    }
  }

  void _confirmPause(BuildContext context, WidgetRef ref) {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              backgroundColor: context.surfaceColor,
              shape: Premium.dialogShape(),
              title: Text('Pause Account',
                  style: TextStyle(
                      color: AppColors.warning, fontWeight: FontWeight.w600)),
              content: Text(
                  'Your profile will be hidden from discovery. Your data stays safe and you can return anytime.',
                  style: TextStyle(
                      color: context.textMuted, fontSize: 14, height: 1.5)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel',
                        style: TextStyle(color: context.textMuted))),
                TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      final uid = ref.read(authProvider).userId;
                      if (uid != null && !isMockMode) {
                        await ref
                            .read(profileRepositoryProvider)
                            .updateProfile(uid, {'is_paused': true});
                      }
                      ref
                          .read(_settingsProvider.notifier)
                          .toggleBool('is_paused');
                      if (context.mounted) {
                        ToastService.show(context,
                            message: 'Account paused', type: ToastType.system);
                      }
                    },
                    child: const Text('Pause',
                        style: TextStyle(color: AppColors.warning))),
              ],
            ));
  }

  void _confirmResume(BuildContext context, WidgetRef ref) {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              backgroundColor: context.surfaceColor,
              shape: Premium.dialogShape(),
              title: Text('Resume Account',
                  style: TextStyle(
                      color: AppColors.success, fontWeight: FontWeight.w600)),
              content: Text(
                  'Your profile will be visible again in discovery. Welcome back!',
                  style: TextStyle(
                      color: context.textMuted, fontSize: 14, height: 1.5)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel',
                        style: TextStyle(color: context.textMuted))),
                TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      final uid = ref.read(authProvider).userId;
                      if (uid != null && !isMockMode) {
                        await ref
                            .read(profileRepositoryProvider)
                            .updateProfile(uid, {'is_paused': false});
                      }
                      ref
                          .read(_settingsProvider.notifier)
                          .toggleBool('is_paused');
                      if (context.mounted) {
                        ToastService.show(context,
                            message: 'Account resumed',
                            type: ToastType.success);
                      }
                    },
                    child: const Text('Resume',
                        style: TextStyle(color: AppColors.success))),
              ],
            ));
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
        context: context,
        builder: (_) => StatefulBuilder(
              builder: (ctx, setState) => AlertDialog(
                backgroundColor: context.surfaceColor,
                shape: Premium.dialogShape(),
                title: Text('Delete Account',
                    style: TextStyle(
                        color: AppColors.error, fontWeight: FontWeight.w600)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Your account will be paused immediately and permanently deleted after 30 days. Sign back in within 30 days to cancel. You will be signed out now.',
                        style: TextStyle(
                            color: context.textMuted,
                            fontSize: 14,
                            height: 1.5)),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Type DELETE to confirm:',
                        style: TextStyle(
                            color: context.textMuted, fontSize: 12)),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                        controller: ctrl,
                        style: TextStyle(color: context.textPrimary),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                            hintText: 'DELETE',
                            hintStyle:
                                TextStyle(color: context.textDisabled),
                            filled: true,
                            fillColor: context.bgColor,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusXs)))),
                  ],
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Cancel',
                          style: TextStyle(color: context.textMuted))),
                  TextButton(
                    onPressed: ctrl.text == 'DELETE'
                        ? () async {
                            Navigator.pop(ctx);
                            // M0 follow-up — route through the SECDEF RPC so
                            // the verification_status write passes the
                            // trust-lockdown trigger. Direct UPDATE is now
                            // blocked.
                            await ref
                                .read(profileRepositoryProvider)
                                .requestAccountDeletion();
                            if (context.mounted) {
                              Navigator.of(context)
                                  .popUntil((route) => route.isFirst);
                            }
                            await ref.read(authProvider.notifier).signOut();
                          }
                        : null,
                    child: Text('Delete',
                        style: TextStyle(
                            color: ctrl.text == 'DELETE'
                                ? AppColors.error
                                : context.textDisabled)),
                  ),
                ],
              ),
            )).then((_) => ctrl.dispose());
  }

  /// Confirms sign-out before tearing down the session. Without this an
  /// accidental tap on the Sign Out row would drop the user back to the
  /// Welcome screen — a frequent source of trust loss right before a
  /// store review.
  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: Premium.dialogShape(),
        title: Text('Sign out?',
            style: TextStyle(
                color: context.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        content: Text(
            'You can sign back in anytime with the same email and password.',
            style: TextStyle(
                color: context.textMuted, fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text('Cancel', style: TextStyle(color: context.textMuted))),
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).popUntil((route) => route.isFirst);
                ref.read(authProvider.notifier).signOut();
              },
              child: const Text('Sign Out',
                  style: TextStyle(
                      color: AppColors.error, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  static Widget _divider(BuildContext context) => Divider(
        height: 0.5,
        thickness: 0.5,
        indent: 52,
        color: context.borderSubtleColor,
      );
}

// ═══════════════════════════════════════════════════════════════════
// Deletion recovery banner
// ═══════════════════════════════════════════════════════════════════

class _DeletionRecoveryBanner extends ConsumerWidget {
  final _SettingsNotifier notifier;
  const _DeletionRecoveryBanner({required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm,
          AppSpacing.lg, AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.warning_rounded, color: AppColors.error, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                  child: Text('Account deletion requested',
                      style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                          fontSize: 14))),
            ]),
            const SizedBox(height: AppSpacing.sm),
            Text(
                'Your account will be permanently deleted 30 days after your request. Cancel now to keep your account.',
                style: TextStyle(
                    color: context.textMuted, fontSize: 12, height: 1.4)),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(40),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                ),
                onPressed: () async {
                  final uid = ref.read(authProvider).userId;
                  if (uid != null && !isMockMode) {
                    await ref
                        .read(profileRepositoryProvider)
                        .updateProfile(uid, {
                      'is_paused': false,
                      'verification_status': 'not_started',
                    });
                  }
                  notifier.setString('verification_status', 'not_started');
                  if (notifier.getBool('is_paused')) {
                    notifier.toggleBool('is_paused');
                  }
                  if (context.mounted) {
                    ToastService.show(context,
                        message: 'Deletion cancelled — welcome back!',
                        type: ToastType.success);
                  }
                },
                child: const Text('Cancel Deletion',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Reusable rows
// ═══════════════════════════════════════════════════════════════════

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl, AppSpacing.xxxl, AppSpacing.xxl, AppSpacing.sm),
        child: Text(title.toUpperCase(),
            style: Premium.sectionHeader(context.textMuted)),
      );
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    final filtered = children.where((c) => c is! SizedBox).toList();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: Premium.surfaceGradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
            color: context.borderSubtleColor.withValues(alpha: 0.3)),
        boxShadow: Premium.shadowSm,
      ),
      child: Column(
        children: [
          for (int i = 0; i < filtered.length; i++) ...[
            filtered[i],
            if (i < filtered.length - 1)
              Divider(
                  height: 0.5,
                  thickness: 0.5,
                  indent: 52,
                  color: context.borderSubtleColor),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? sub;
  final String? value;
  final Color? iconColor;
  final Color? titleColor;
  final bool showChevron;
  final VoidCallback? onTap;

  const _Row(
    this.icon,
    this.title, {
    this.sub,
    this.value,
    this.iconColor,
    this.titleColor,
    this.showChevron = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = titleColor ?? context.textPrimary;
    final ic = iconColor ?? context.textMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: 13),
          child: Row(
            children: [
              Icon(icon, color: ic, size: 20),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: tc,
                            fontSize: 14,
                            fontWeight: FontWeight.w400)),
                    if (sub != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(sub!,
                            style: TextStyle(
                                color: context.textDisabled, fontSize: 12)),
                      ),
                  ],
                ),
              ),
              if (value != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(value!,
                      style:
                          TextStyle(color: context.textMuted, fontSize: 13)),
                ),
              if (showChevron && onTap != null)
                Icon(Icons.chevron_right_rounded,
                    color: context.textDisabled, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? sub;

  const _Toggle(this.icon, this.title, this.value, this.onChanged, {this.sub});

  @override
  Widget build(BuildContext context) => Padding(
        padding:
            const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.sm),
        child: Row(
          children: [
            Icon(icon, color: context.textMuted, size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: context.textPrimary, fontSize: 14)),
                  if (sub != null)
                    Text(sub!,
                        style: TextStyle(
                            color: context.textDisabled, fontSize: 11)),
                ],
              ),
            ),
            SizedBox(
              height: 48,
              child: Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.emerald600,
                inactiveThumbColor: AppColors.textMuted,
                inactiveTrackColor: AppColors.borderStrong,
              ),
            ),
          ],
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════
// Change Password Dialog — in-app, authenticated user.
//
// Replaces the prior "Change Password" row, which silently sent a
// password-reset email (UX-implementation mismatch flagged as a P0
// store-readiness issue). The active Supabase session token authorizes
// the password change; no current-password input is needed.
//
// Strength rules mirror Sign Up: >=8 chars, >=1 uppercase, >=1 digit,
// confirm match. Submit is disabled until the four checks pass.
// ═══════════════════════════════════════════════════════════════════

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _showNew = false;
  bool _showConfirm = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool get _has8 => _newCtrl.text.length >= 8;
  bool get _hasUpper => _newCtrl.text.contains(RegExp(r'[A-Z]'));
  bool get _hasNumber => _newCtrl.text.contains(RegExp(r'[0-9]'));
  bool get _passMatch =>
      _newCtrl.text == _confirmCtrl.text && _confirmCtrl.text.isNotEmpty;
  bool get _allValid => _has8 && _hasUpper && _hasNumber && _passMatch;

  Future<void> _submit() async {
    if (!_allValid || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final err =
        await ref.read(authProvider.notifier).updatePassword(_newCtrl.text);
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _loading = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.surfaceColor,
      shape: Premium.dialogShape(),
      // Keyboard-safe: AlertDialog adapts to MediaQuery.viewInsets by
      // default in Flutter, so the modal stays above the keyboard. The
      // content is wrapped in SingleChildScrollView so the strength
      // checklist + error never push the buttons off-screen on small
      // devices with the keyboard open.
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
      title: Text('Change password',
          style: TextStyle(
              color: context.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _newCtrl,
              obscureText: !_showNew,
              onChanged: (_) => setState(() => _error = null),
              style: TextStyle(color: context.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                labelText: 'New password',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                      _showNew
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: context.textMuted),
                  onPressed: () => setState(() => _showNew = !_showNew),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _confirmCtrl,
              obscureText: !_showConfirm,
              onChanged: (_) => setState(() => _error = null),
              style: TextStyle(color: context.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                labelText: 'Confirm new password',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                      _showConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: context.textMuted),
                  onPressed: () =>
                      setState(() => _showConfirm = !_showConfirm),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _ReqRow('At least 8 characters', _has8),
            const SizedBox(height: 4),
            _ReqRow('One uppercase letter', _hasUpper),
            const SizedBox(height: 4),
            _ReqRow('One number', _hasNumber),
            const SizedBox(height: 4),
            _ReqRow('Passwords match', _passMatch),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_error!,
                  style: const TextStyle(
                      color: AppColors.error, fontSize: 13, height: 1.4)),
            ],
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: Text('Cancel', style: TextStyle(color: context.textMuted)),
        ),
        TextButton(
          onPressed: (_allValid && !_loading) ? _submit : null,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update',
                  style: TextStyle(
                      color: AppColors.burgundy600,
                      fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _ReqRow extends StatelessWidget {
  final String label;
  final bool met;
  const _ReqRow(this.label, this.met);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(met ? Icons.check_circle_rounded : Icons.circle_outlined,
          color: met ? AppColors.success : context.textDisabled, size: 14),
      const SizedBox(width: 8),
      Text(label,
          style: TextStyle(
              color: met ? AppColors.success : context.textMuted,
              fontSize: 12)),
    ]);
  }
}

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
// Settings — V1 minimal (R17B root cleanup)
//
// Surface contract: only rows whose underlying behavior is wired
// end-to-end (UI ↔ provider ↔ Supabase ↔ enforcement) remain visible.
//
//   Account            — email · change password
//   Privacy & Safety   — photo verify · selfie verify · blocked users · message previews
//   Help & Legal       — help center · privacy policy
//   (deletion recovery banner — only when verification_status = deletion_requested)
//   Danger zone        — pause/resume · delete account · sign out
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
        'blocked_users': <dynamic>[],
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
          const _Section('Privacy & Safety'),
          _Card(children: [
            _Row(Icons.camera_alt_outlined, 'Photo Verification',
                value: (s['photos_verified'] as bool? ?? false)
                    ? 'Verified'
                    : _verifLabel(s)),
            _Row(Icons.face_rounded, 'Selfie Verification',
                value: (s['selfie_verified'] as bool? ?? false)
                    ? 'Verified'
                    : 'Not verified'),
            _Row(Icons.block_rounded, 'Blocked Users',
                value: '${(s['blocked_users'] as List<dynamic>?)?.length ?? 0}',
                onTap: () => _showBlockedSheet(context, s, ref)),
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
                      onTap: () {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                        ref.read(authProvider.notifier).signOut();
                      }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────

  static String _verifLabel(Map<String, dynamic> s) {
    final status = s['verification_status'] as String? ?? 'not_started';
    return switch (status) {
      'pending' => 'Pending',
      'manual_review' => 'In review',
      _ => 'Not started',
    };
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    if (isMockMode) return;
    final repo = ref.read(authRepositoryProvider);
    final email = await repo.getCurrentUserEmail() ?? '';
    await repo.resetPasswordForEmail(email);
    if (context.mounted) {
      ToastService.show(context,
          message: 'Password reset email sent', type: ToastType.success);
    }
  }

  void _showBlockedSheet(BuildContext context, Map<String, dynamic> s, WidgetRef ref) {
    final items = s['blocked_users'] as List<dynamic>?;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BlockedListSheet(items: items, ref: ref),
    );
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
                            if (!isMockMode) {
                              final uid = ref.read(authProvider).userId;
                              if (uid != null) {
                                await ref
                                    .read(profileRepositoryProvider)
                                    .updateProfile(uid, {
                                  'is_paused': true,
                                  'verification_status': 'deletion_requested'
                                });
                              }
                            }
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
// Blocked users sheet — list + unblock action
// ═══════════════════════════════════════════════════════════════════

class _BlockedListSheet extends StatefulWidget {
  final List<dynamic>? items;
  final WidgetRef ref;

  const _BlockedListSheet({this.items, required this.ref});

  @override
  State<_BlockedListSheet> createState() => _BlockedListSheetState();
}

class _BlockedListSheetState extends State<_BlockedListSheet> {
  late List<dynamic> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items ?? []);
  }

  Future<void> _unblock(String userId) async {
    final uid = widget.ref.read(authProvider).userId;
    if (uid == null || isMockMode) return;
    final updated = List<dynamic>.from(_items)..remove(userId);
    try {
      await widget.ref
          .read(profileRepositoryProvider)
          .updateProfile(uid, {'blocked_users': updated});
      setState(() => _items = updated);
      if (mounted) {
        ToastService.show(context,
            message: 'User unblocked', type: ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        ToastService.show(context,
            message: 'Failed to update', type: ToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
              child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: AppSpacing.sm),
                  decoration: BoxDecoration(
                      color: context.borderColor,
                      borderRadius: BorderRadius.circular(999)))),
          const SizedBox(height: AppSpacing.lg),
          Text('Blocked Users',
              style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.lg),
          if (_items.isEmpty)
            Text('None yet',
                style: TextStyle(color: context.textMuted, fontSize: 13))
          else
            ..._items.take(20).map((id) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text('$id',
                              style: TextStyle(
                                  color: context.textMuted,
                                  fontSize: 12,
                                  fontFamily: 'monospace'))),
                      TextButton(
                        onPressed: () => _unblock(id as String),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.emerald500,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8)),
                        child: const Text('Unblock',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                )),
          const SizedBox(height: AppSpacing.xxl),
        ],
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

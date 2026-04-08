import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/premium.dart';
import '../../core/utils/mock_mode.dart';
import '../../providers/auth_provider.dart';
import '../../core/services/toast_service.dart';

// ═══════════════════════════════════════════════════════════════════
// Settings provider — loads/saves ALL settings from profiles
// ═══════════════════════════════════════════════════════════════════

final _settingsProvider =
    StateNotifierProvider<_SettingsNotifier, Map<String, dynamic>>((ref) {
  return _SettingsNotifier(ref);
});

class _SettingsNotifier extends StateNotifier<Map<String, dynamic>> {
  final Ref _ref;

  _SettingsNotifier(this._ref) : super({}) { _load(); }

  Future<void> _load() async {
    if (isMockMode) { state = _defaults(); return; }
    final uid = _ref.read(authProvider).userId;
    if (uid == null) return;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('notification_preferences, incognito_mode, calm_mode, '
              'dating_visible, bff_visible, social_visible, '
              'show_last_active, show_status_badge, message_preview, '
              'reach_permission, signal_permission, note_permission, '
              'city, is_paused, leave_event_chat_auto, '
              'ai_writing_help, '
              'is_verified, selfie_verified, photos_verified, verification_status, '
              'blocked_users, hidden_users')
          .eq('id', uid)
          .maybeSingle();
      if (row != null) state = row;
    } catch (_) { state = _defaults(); }
  }

  Map<String, dynamic> _defaults() => {
    'notification_preferences': {'new_match': true, 'new_message': true,
      'bff_suggestion': true, 'event_activity': true, 'safety': true, 'signals': true,
      'notes': true, 'event_chat': true, 'verification': true, 'updates': true},
    'incognito_mode': false, 'calm_mode': false, 'is_paused': false,
    'dating_visible': true, 'bff_visible': true, 'social_visible': true,
    'show_last_active': true, 'show_status_badge': true, 'message_preview': true,
    'reach_permission': 'everyone', 'signal_permission': 'everyone', 'note_permission': 'everyone',
    'leave_event_chat_auto': true,
    'ai_writing_help': {'nob_cleanup': true, 'message_softening': true},
    'is_verified': false, 'selfie_verified': false, 'photos_verified': false,
    'verification_status': 'not_started',
    'blocked_users': <dynamic>[], 'hidden_users': <dynamic>[],
  };

  Future<void> _save(String column, dynamic value) async {
    final previous = state[column];
    state = {...state, column: value};
    if (isMockMode) return;
    final uid = _ref.read(authProvider).userId;
    if (uid == null) return;
    try {
      await Supabase.instance.client.from('profiles').update({column: value}).eq('id', uid);
    } catch (e) {
      debugPrint('[settings] save failed for $column: $e');
      state = {...state, column: previous};
    }
  }

  void toggleBool(String key) { final c = state[key] as bool? ?? false; _save(key, !c); }
  void setString(String key, String value) => _save(key, value);
  void toggleNotif(String key) {
    final p = Map<String, dynamic>.from(state['notification_preferences'] as Map<String, dynamic>? ?? {});
    p[key] = !(p[key] as bool? ?? true);
    _save('notification_preferences', p);
  }
  bool notif(String key) => (state['notification_preferences'] as Map<String, dynamic>?)?[key] as bool? ?? true;
  bool getBool(String key) => state[key] as bool? ?? false;
  String getString(String key) => state[key] as String? ?? '';

  void toggleAi(String group, String key) {
    final g = Map<String, dynamic>.from(state[group] as Map<String, dynamic>? ?? {});
    g[key] = !(g[key] as bool? ?? true);
    _save(group, g);
  }
  bool aiVal(String group, String key) => (state[group] as Map<String, dynamic>?)?[key] as bool? ?? true;
}

// ═══════════════════════════════════════════════════════════════════
// Settings Screen — premium card-grouped layout
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
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
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
                      Expanded(child: Text('Account deletion requested',
                          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 14))),
                    ]),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Your account is flagged for deletion. Cancel anytime to keep your account.',
                        style: TextStyle(color: context.textMuted, fontSize: 12, height: 1.4)),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(width: double.infinity, child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                      ),
                      onPressed: () async {
                        final uid = ref.read(authProvider).userId;
                        if (uid != null && !isMockMode) {
                          await Supabase.instance.client.from('profiles').update({
                            'is_paused': false,
                            'verification_status': 'not_started',
                          }).eq('id', uid);
                        }
                        n.setString('verification_status', 'not_started');
                        if (n.getBool('is_paused')) n.toggleBool('is_paused');
                        if (context.mounted) ToastService.show(context, message: 'Deletion cancelled — welcome back!', type: ToastType.success);
                      },
                      child: const Text('Cancel Deletion', style: TextStyle(fontWeight: FontWeight.w600)),
                    )),
                  ],
                ),
              ),
            ),

          // ── 1. ACCOUNT ──────────────────────────────────────────
          const _Section('Account'),
          _Card(children: [
            _Row(Icons.email_outlined, 'Email', value: auth.email ?? 'Not set'),
            _Row(Icons.lock_outlined, 'Change Password',
                onTap: () => _changePassword(context)),
          ]),

          // ── 4. PRIVACY & VISIBILITY ─────────────────────────────
          const _Section('Privacy & Visibility'),
          _Card(children: [
            _Toggle(Icons.visibility_off_rounded, 'Incognito Mode',
                s['incognito_mode'] as bool? ?? false,
                (_) => n.toggleBool('incognito_mode'),
                sub: 'Only connections can discover you'),
            _Toggle(Icons.shield_rounded, 'Calm Mode',
                s['calm_mode'] as bool? ?? false,
                (_) => n.toggleBool('calm_mode'),
                sub: 'Verified + Explorer+ only'),
            _Toggle(Icons.access_time_rounded, 'Show last active',
                s['show_last_active'] as bool? ?? true,
                (_) => n.toggleBool('show_last_active')),
            _Toggle(Icons.workspace_premium_rounded, 'Show status badge',
                s['show_status_badge'] as bool? ?? true,
                (_) => n.toggleBool('show_status_badge')),
          ]),
          const SizedBox(height: AppSpacing.xs),
          _Card(children: [
            _PermRow(Icons.person_search_rounded, 'Who can reach me',
                s['reach_permission'] as String? ?? 'everyone',
                (v) => n.setString('reach_permission', v)),
            _PermRow(Icons.bolt_rounded, 'Who can send Signals',
                s['signal_permission'] as String? ?? 'everyone',
                (v) => n.setString('signal_permission', v)),
            _PermRow(Icons.mail_outline_rounded, 'Who can leave Notes',
                s['note_permission'] as String? ?? 'everyone',
                (v) => n.setString('note_permission', v)),
          ]),

          // ── 5. NOTIFICATIONS ────────────────────────────────────
          const _Section('Notifications'),
          _Card(children: [
            _Toggle(Icons.chat_bubble_outline, 'Messages',
                n.notif('new_message'), (_) => n.toggleNotif('new_message')),
            _Toggle(Icons.favorite_outline, 'Connections',
                n.notif('new_match'), (_) => n.toggleNotif('new_match')),
            _Toggle(Icons.bolt_outlined, 'Signals',
                n.notif('signals'), (_) => n.toggleNotif('signals')),
            _Toggle(Icons.mail_outline, 'Notes',
                n.notif('notes'), (_) => n.toggleNotif('notes')),
            _Toggle(Icons.people_outline, 'BFF Suggestions',
                n.notif('bff_suggestion'), (_) => n.toggleNotif('bff_suggestion')),
            if (kSocialEnabled) ...[
              _Toggle(Icons.event_outlined, 'Event Activity',
                  n.notif('event_activity'), (_) => n.toggleNotif('event_activity')),
              _Toggle(Icons.forum_outlined, 'Event Chat',
                  n.notif('event_chat'), (_) => n.toggleNotif('event_chat')),
            ],
            _Toggle(Icons.verified_outlined, 'Verification',
                n.notif('verification'), (_) => n.toggleNotif('verification')),
            _Toggle(Icons.shield_outlined, 'Safety Alerts',
                n.notif('safety'), (_) => n.toggleNotif('safety')),
            _Toggle(Icons.system_update_outlined, 'Product Updates',
                n.notif('updates'), (_) => n.toggleNotif('updates')),
          ]),

          // ── 6. SAFETY & VERIFICATION ────────────────────────────
          const _Section('Safety & Verification'),
          _Card(children: [
            _Row(Icons.camera_alt_outlined, 'Photo Verification',
                value: (s['photos_verified'] as bool? ?? false) ? 'Verified' : _verifLabel(s)),
            _Row(Icons.face_rounded, 'Selfie Verification',
                value: (s['selfie_verified'] as bool? ?? false) ? 'Verified' : 'Not verified'),
            _Row(Icons.badge_outlined, 'ID Verification',
                value: 'Coming soon', disabled: true),
          ]),
          const SizedBox(height: AppSpacing.xs),
          _Card(children: [
            _Row(Icons.block_rounded, 'Blocked Users',
                value: '${(s['blocked_users'] as List<dynamic>?)?.length ?? 0}',
                onTap: () => _showListSheet(context, 'Blocked Users', s['blocked_users'] as List<dynamic>?, ref, 'blocked_users')),
            _Row(Icons.visibility_off_outlined, 'Hidden Users',
                value: '${(s['hidden_users'] as List<dynamic>?)?.length ?? 0}',
                onTap: () => _showListSheet(context, 'Hidden Users', s['hidden_users'] as List<dynamic>?, ref, 'hidden_users')),
          ]),
          const SizedBox(height: AppSpacing.xs),
          _Card(children: [
            _Row(Icons.security_rounded, 'Safety Tips',
                onTap: () => _showContent(context, 'Safety Tips',
                    'Trust your instincts. Meet in public places. Tell someone where you\'re going. '
                    'Don\'t share personal info too early. Report any suspicious behavior.')),
            _Row(Icons.rule_rounded, 'Community Rules',
                onTap: () => _showContent(context, 'Community Rules',
                    'Be respectful. No harassment. No spam. No fake profiles. No commercial content. '
                    'Noblara is a space for genuine human connections.')),
          ]),

          // ── 7. CHATS ────────────────────────────────────────────
          const _Section('Chats'),
          _Card(children: [
            _Toggle(Icons.preview_rounded, 'Message Previews',
                s['message_preview'] as bool? ?? true,
                (_) => n.toggleBool('message_preview'),
                sub: 'Show content in inbox list'),
            if (kSocialEnabled)
              _Toggle(Icons.exit_to_app_rounded, 'Leave Event Chat After End',
                  s['leave_event_chat_auto'] as bool? ?? true,
                  (_) => n.toggleBool('leave_event_chat_auto')),
          ]),

          // ── 8. AI PREFERENCES ───────────────────────────────────
          const _Section('AI Preferences'),
          _Card(children: [
            _Toggle(Icons.auto_fix_high_rounded, 'Nob Text Cleanup',
                n.aiVal('ai_writing_help', 'nob_cleanup'),
                (_) => n.toggleAi('ai_writing_help', 'nob_cleanup')),
            _Toggle(Icons.chat_outlined, 'Message Softening',
                n.aiVal('ai_writing_help', 'message_softening'),
                (_) => n.toggleAi('ai_writing_help', 'message_softening')),
          ]),
          // AI privacy note
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.emerald600.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(color: AppColors.emerald600.withValues(alpha: 0.08)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(Icons.shield_outlined,
                        color: AppColors.emerald500, size: 13),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'AI uses profile text and behavior patterns. Never accesses private messages or calls.',
                      style: TextStyle(
                          color: context.textMuted,
                          fontSize: 11,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 9. SUPPORT & LEGAL ──────────────────────────────────
          const _Section('Support'),
          _Card(children: [
            _Row(Icons.help_outline_rounded, 'Help Center',
                onTap: () => _showContent(context, 'Help Center',
                    'Noblara Guide is a context-aware help system. For now, contact support for any questions.')),
            _Row(Icons.email_outlined, 'Contact Support',
                onTap: () => _showContent(context, 'Contact', 'Email: support@noblara.com')),
            _Row(Icons.bug_report_outlined, 'Report a Bug',
                onTap: () => _showBugReport(context, ref)),
            _Row(Icons.download_outlined, 'Request My Data',
                onTap: () => _showContent(context, 'Data Request',
                    'Under GDPR/KVKK, you have the right to request your data. Send an email to privacy@noblara.com with your account email.')),
          ]),
          const SizedBox(height: AppSpacing.xs),
          _Card(children: [
            _Row(Icons.rule_rounded, 'Community Guidelines',
                onTap: () => _showContent(context, 'Community Guidelines',
                    'Be real. Be respectful. No spam, no ads, no fake profiles. Noblara is built for genuine connections.')),
            _Row(Icons.privacy_tip_outlined, 'Privacy Policy',
                onTap: () => _showContent(context, 'Privacy Policy',
                    'Your privacy matters. We collect only what\'s needed. We never sell data. Full policy at noblara.com/privacy.')),
            _Row(Icons.article_outlined, 'Terms of Service',
                onTap: () => _showContent(context, 'Terms of Service',
                    'By using Noblara you agree to our community standards. Full terms at noblara.com/terms.')),
          ]),
          // Version
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

          // ── 11. DANGER ZONE ─────────────────────────────────────
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

  void _changePassword(BuildContext context) {
    if (isMockMode) return;
    Supabase.instance.client.auth.resetPasswordForEmail(
      Supabase.instance.client.auth.currentUser?.email ?? '',
    );
    ToastService.show(context, message: 'Password reset email sent', type: ToastType.success);
  }

  void _showContent(BuildContext context, String title, String body) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55, expand: false,
        builder: (ctx, scroll) => Container(
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: AppColors.emerald600.withValues(alpha: 0.08))),
          ),
          child: ListView(controller: scroll, padding: const EdgeInsets.all(AppSpacing.xxl), children: [
            _sheetHandle(context),
            const SizedBox(height: AppSpacing.xxl),
            Text(title,
                style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3)),
            const SizedBox(height: AppSpacing.lg),
            Text(body,
                style: TextStyle(
                    color: context.textMuted,
                    fontSize: 14,
                    height: 1.6)),
          ]),
        ),
      ),
    );
  }

  void _showListSheet(BuildContext context, String title, List<dynamic>? items, WidgetRef ref, String column) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BlockedListSheet(title: title, items: items, ref: ref, column: column),
    );
  }

  void _showBugReport(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: Premium.dialogShape(),
        title: Text('Report a Bug', style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        content: TextField(controller: ctrl, maxLines: 4, style: TextStyle(color: context.textPrimary),
            decoration: InputDecoration(hintText: 'Describe the issue...',
                hintStyle: TextStyle(color: context.textDisabled),
                filled: true, fillColor: context.bgColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusXs)))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: context.textMuted))),
          TextButton(onPressed: () {
            Navigator.pop(ctx);
            Clipboard.setData(ClipboardData(text: 'Bug report: ${ctrl.text.trim()}'));
            ToastService.show(context, message: 'Bug report copied to clipboard', type: ToastType.success);
          }, child: const Text('Copy & Send', style: TextStyle(color: AppColors.emerald500))),
        ],
      ),
    ).then((_) => ctrl.dispose());
  }

  void _confirmPause(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: context.surfaceColor,
      shape: Premium.dialogShape(),
      title: Text('Pause Account', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600)),
      content: Text('Your profile will be hidden from discovery. Your data stays safe and you can return anytime.',
          style: TextStyle(color: context.textMuted, fontSize: 14, height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: context.textMuted))),
        TextButton(onPressed: () async {
          Navigator.pop(context);
          final uid = ref.read(authProvider).userId;
          if (uid != null && !isMockMode) {
            await Supabase.instance.client.from('profiles').update({'is_paused': true}).eq('id', uid);
          }
          ref.read(_settingsProvider.notifier).toggleBool('is_paused');
          if (context.mounted) ToastService.show(context, message: 'Account paused', type: ToastType.system);
        }, child: const Text('Pause', style: TextStyle(color: AppColors.warning))),
      ],
    ));
  }

  void _confirmResume(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: context.surfaceColor,
      shape: Premium.dialogShape(),
      title: Text('Resume Account', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
      content: Text('Your profile will be visible again in discovery. Welcome back!',
          style: TextStyle(color: context.textMuted, fontSize: 14, height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: context.textMuted))),
        TextButton(onPressed: () async {
          Navigator.pop(context);
          final uid = ref.read(authProvider).userId;
          if (uid != null && !isMockMode) {
            await Supabase.instance.client.from('profiles').update({'is_paused': false}).eq('id', uid);
          }
          ref.read(_settingsProvider.notifier).toggleBool('is_paused');
          if (context.mounted) ToastService.show(context, message: 'Account resumed', type: ToastType.success);
        }, child: const Text('Resume', style: TextStyle(color: AppColors.success))),
      ],
    ));
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (_) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: Premium.dialogShape(),
        title: Text('Delete Account', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your account will be paused and flagged for deletion. You can sign back in anytime to cancel. You will be signed out immediately.',
              style: TextStyle(color: context.textMuted, fontSize: 14, height: 1.5)),
          const SizedBox(height: AppSpacing.lg),
          Text('Type DELETE to confirm:', style: TextStyle(color: context.textMuted, fontSize: 12)),
          const SizedBox(height: AppSpacing.sm),
          TextField(controller: ctrl, style: TextStyle(color: context.textPrimary), onChanged: (_) => setState(() {}),
              decoration: InputDecoration(hintText: 'DELETE', hintStyle: TextStyle(color: context.textDisabled),
                  filled: true, fillColor: context.bgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusXs)))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: context.textMuted))),
          TextButton(
            onPressed: ctrl.text == 'DELETE' ? () async {
              Navigator.pop(ctx); // close dialog
              if (!isMockMode) {
                final uid = ref.read(authProvider).userId;
                if (uid != null) {
                  await Supabase.instance.client.from('profiles').update({'is_paused': true, 'verification_status': 'deletion_requested'}).eq('id', uid);
                }
              }
              if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
              await ref.read(authProvider.notifier).signOut();
            } : null,
            child: Text('Delete', style: TextStyle(color: ctrl.text == 'DELETE' ? AppColors.error : context.textDisabled)),
          ),
        ],
      ),
    )).then((_) => ctrl.dispose());
  }

  // ── Sheet helpers ──

  static Widget _sheetHandle(BuildContext context) => Center(
    child: Container(
      width: 36, height: 4,
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.borderColor,
        borderRadius: BorderRadius.circular(999),
      ),
    ),
  );

  static Widget _divider(BuildContext context) => Divider(
    height: 0.5, thickness: 0.5, indent: 52,
    color: context.borderSubtleColor,
  );
}

// ═══════════════════════════════════════════════════════════════════
// Reusable widgets — premium card-grouped design
// ═══════════════════════════════════════════════════════════════════

// Blocked / Hidden users sheet with unblock/unhide actions
class _BlockedListSheet extends StatefulWidget {
  final String title;
  final List<dynamic>? items;
  final WidgetRef ref;
  final String column; // 'blocked_users' or 'hidden_users'

  const _BlockedListSheet({required this.title, this.items, required this.ref, required this.column});

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

  Future<void> _remove(String userId) async {
    final uid = widget.ref.read(authProvider).userId;
    if (uid == null || isMockMode) return;
    final updated = List<dynamic>.from(_items)..remove(userId);
    try {
      await Supabase.instance.client.from('profiles')
          .update({widget.column: updated}).eq('id', uid);
      setState(() => _items = updated);
      if (mounted) {
        ToastService.show(context,
            message: widget.column == 'blocked_users' ? 'User unblocked' : 'User unhidden',
            type: ToastType.success);
      }
    } catch (e) {
      if (mounted) ToastService.show(context, message: 'Failed to update', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionLabel = widget.column == 'blocked_users' ? 'Unblock' : 'Unhide';
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        SettingsScreen._sheetHandle(context),
        const SizedBox(height: AppSpacing.lg),
        Text(widget.title, style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.lg),
        if (_items.isEmpty)
          Text('None yet', style: TextStyle(color: context.textMuted, fontSize: 13))
        else
          ..._items.take(20).map((id) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(child: Text('$id', style: TextStyle(color: context.textMuted, fontSize: 12, fontFamily: 'monospace'))),
                TextButton(
                  onPressed: () => _remove(id as String),
                  style: TextButton.styleFrom(foregroundColor: AppColors.emerald500, padding: const EdgeInsets.symmetric(horizontal: 8)),
                  child: Text(actionLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          )),
        const SizedBox(height: AppSpacing.xxl),
      ]),
    );
  }
}

// Section header (above card)
class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.xxl, AppSpacing.xxl, AppSpacing.sm),
    child: Text(
      title.toUpperCase(),
      style: TextStyle(
        color: context.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    ),
  );
}

// Card group container
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
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: context.borderSubtleColor, width: 0.5),
      ),
      child: Column(
        children: [
          for (int i = 0; i < filtered.length; i++) ...[
            filtered[i],
            if (i < filtered.length - 1)
              Divider(
                height: 0.5, thickness: 0.5, indent: 52,
                color: context.borderSubtleColor,
              ),
          ],
        ],
      ),
    );
  }
}

// Standard menu row
class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? sub;
  final String? value;
  final Color? iconColor;
  final Color? titleColor;
  final bool disabled;
  final bool showChevron;
  final VoidCallback? onTap;

  const _Row(this.icon, this.title, {
    this.sub,
    this.value,
    this.iconColor,
    this.titleColor,
    this.disabled = false,
    this.showChevron = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = disabled ? context.textDisabled : (titleColor ?? context.textPrimary);
    final ic = disabled ? context.textDisabled : (iconColor ?? context.textMuted);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onTap,
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
                                color: context.textDisabled,
                                fontSize: 12)),
                      ),
                  ],
                ),
              ),
              if (value != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(value!,
                      style: TextStyle(
                          color: context.textMuted,
                          fontSize: 13)),
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

// Toggle row with switch
class _Toggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? sub;

  const _Toggle(this.icon, this.title, this.value, this.onChanged, {this.sub});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.sm),
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
                      color: context.textPrimary,
                      fontSize: 14)),
              if (sub != null)
                Text(sub!,
                    style: TextStyle(
                        color: context.textDisabled,
                        fontSize: 11)),
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

// Permission selector — tap to open sheet
class _PermRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  const _PermRow(this.icon, this.label, this.value, this.onChanged);

  static const _labels = {
    'everyone': 'Everyone',
    'verified': 'Verified only',
    'explorer_plus': 'Explorer+',
    'noble_only': 'Noble only',
    'nobody': 'Nobody',
  };

  @override
  Widget build(BuildContext context) {
    return _Row(icon, label,
      value: _labels[value] ?? 'Everyone',
      onTap: () => _showSheet(context),
    );
  }

  void _showSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: AppColors.emerald600.withValues(alpha: 0.08))),
        ),
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.lg),
              decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(999)),
            )),
            Text(label,
                style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.lg),
            for (final e in _labels.entries)
              _SheetOption(e.value, selected: e.key == value,
                  onTap: () { Navigator.pop(ctx); onChanged(e.key); }),
            const SizedBox(height: AppSpacing.lg),
          ]),
        ),
      ),
    );
  }
}

// Sheet option row (checkmark-style)
class _SheetOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SheetOption(this.label, {required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: selected ? AppColors.emerald500 : context.textPrimary,
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
            ),
            if (selected)
              Icon(Icons.check_rounded, color: AppColors.emerald500, size: 20),
          ],
        ),
      ),
    ),
  );
}


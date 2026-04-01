import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/mock_mode.dart';
import '../../providers/appearance_provider.dart';
import '../../providers/auth_provider.dart';

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
              'dating_active, dating_visible, bff_active, bff_visible, '
              'social_active, social_visible, show_city_only, hide_exact_distance, '
              'show_last_active, show_status_badge, message_preview, '
              'reach_permission, signal_permission, note_permission, '
              'city, travel_mode, travel_city, is_paused, '
              'auto_save_media, call_reminders, leave_event_chat_auto, language, '
              'ai_writing_help, ai_suggestions, ai_insights, '
              'is_verified, selfie_verified, photos_verified, verification_status, '
              'blocked_users, hidden_users')
          .eq('id', uid)
          .maybeSingle();
      if (row != null) state = row;
    } catch (_) { state = _defaults(); }
  }

  Map<String, dynamic> _defaults() => {
    'notification_preferences': {'new_match': true, 'new_message': true, 'video_proposed': true,
      'bff_suggestion': true, 'event_activity': true, 'safety': true, 'signals': true,
      'notes': true, 'event_chat': true, 'verification': true, 'updates': true},
    'incognito_mode': false, 'calm_mode': false, 'is_paused': false,
    'dating_active': true, 'dating_visible': true, 'bff_active': true, 'bff_visible': true,
    'social_active': true, 'social_visible': true,
    'show_city_only': false, 'hide_exact_distance': false,
    'show_last_active': true, 'show_status_badge': true, 'message_preview': true,
    'reach_permission': 'everyone', 'signal_permission': 'everyone', 'note_permission': 'everyone',
    'auto_save_media': false, 'call_reminders': true, 'leave_event_chat_auto': true,
    'language': 'en',
    'ai_writing_help': {'nob_cleanup': true, 'bio_cleanup': true, 'event_cleanup': true, 'message_softening': true},
    'ai_suggestions': {'bff_explanations': true, 'event_recommendations': true, 'profile_resonance': true, 'filter_suggestions': true},
    'ai_insights': {'show_resonance': true, 'show_standout': true, 'show_performance': true},
    'is_verified': false, 'selfie_verified': false, 'photos_verified': false,
    'verification_status': 'not_started',
    'blocked_users': <dynamic>[], 'hidden_users': <dynamic>[],
  };

  Future<void> _save(String column, dynamic value) async {
    state = {...state, column: value};
    if (isMockMode) return;
    final uid = _ref.read(authProvider).userId;
    if (uid == null) return;
    try { await Supabase.instance.client.from('profiles').update({column: value}).eq('id', uid); } catch (_) {}
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
// Settings Screen — 10 sections
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
        backgroundColor: context.bgColor, surfaceTintColor: Colors.transparent,
        title: Text('Settings', style: TextStyle(color: context.textPrimary)),
        iconTheme: IconThemeData(color: context.textPrimary),
      ),
      body: ListView(
        children: [
          // ════════════════════════════════════════════════════════════
          // 1. ACCOUNT
          // ════════════════════════════════════════════════════════════
          _H('Account'),
          _Tile(Icons.email_outlined, 'Email', sub: auth.email ?? 'Not set'),
          _Tile(Icons.lock_outlined, 'Change Password', onTap: () => _changePassword(context)),
          _Tile(Icons.language_rounded, 'Language', sub: (s['language'] as String? ?? 'en') == 'en' ? 'English' : 'Türkçe',
              onTap: () => _pickLanguage(context, ref, n)),
          _Tile(Icons.logout_rounded, 'Sign Out', color: AppColors.error,
              onTap: () => ref.read(authProvider.notifier).signOut()),

          // ════════════════════════════════════════════════════════════
          // 2. APPEARANCE
          // ════════════════════════════════════════════════════════════
          _H('Appearance'),
          _AppearanceThemeSelector(ref: ref),
          const SizedBox(height: AppSpacing.sm),
          _AppearanceAccentSelector(ref: ref),

          // ════════════════════════════════════════════════════════════
          // 3. MODES
          // ════════════════════════════════════════════════════════════
          _H('Modes'),
          _T(Icons.favorite_rounded, 'Dating Active', s['dating_active'] as bool? ?? true, (_) => n.toggleBool('dating_active')),
          _T(Icons.favorite_outline, 'Dating Visible', s['dating_visible'] as bool? ?? true, (_) => n.toggleBool('dating_visible')),
          _T(Icons.people_rounded, 'BFF Active', s['bff_active'] as bool? ?? true, (_) => n.toggleBool('bff_active')),
          _T(Icons.people_outline, 'BFF Visible', s['bff_visible'] as bool? ?? true, (_) => n.toggleBool('bff_visible')),
          _T(Icons.explore_rounded, 'Social Active', s['social_active'] as bool? ?? true, (_) => n.toggleBool('social_active')),
          _T(Icons.explore_outlined, 'Social Visible', s['social_visible'] as bool? ?? true, (_) => n.toggleBool('social_visible')),

          // ════════════════════════════════════════════════════════════
          // 4. PRIVACY & VISIBILITY
          // ════════════════════════════════════════════════════════════
          _H('Privacy & Visibility'),
          _T(Icons.visibility_off_rounded, 'Incognito Mode', s['incognito_mode'] as bool? ?? false, (_) => n.toggleBool('incognito_mode'),
              sub: 'Only connections can discover you'),
          _T(Icons.shield_rounded, 'Calm Mode', s['calm_mode'] as bool? ?? false, (_) => n.toggleBool('calm_mode'),
              sub: 'Only Verified + Complete + Explorer+ can reach you'),
          _T(Icons.location_city_rounded, 'Show city only', s['show_city_only'] as bool? ?? false, (_) => n.toggleBool('show_city_only')),
          _T(Icons.straighten_rounded, 'Hide exact distance', s['hide_exact_distance'] as bool? ?? false, (_) => n.toggleBool('hide_exact_distance')),
          _T(Icons.access_time_rounded, 'Show last active', s['show_last_active'] as bool? ?? true, (_) => n.toggleBool('show_last_active'),
              sub: 'Let others see when you were last online'),
          _T(Icons.workspace_premium_rounded, 'Show status badge', s['show_status_badge'] as bool? ?? true, (_) => n.toggleBool('show_status_badge'),
              sub: 'Show your tier badge on your profile card'),
          _PermSelector(icon: Icons.person_search_rounded, label: 'Who can reach me',
              value: s['reach_permission'] as String? ?? 'everyone', onChanged: (v) => n.setString('reach_permission', v)),
          _PermSelector(icon: Icons.bolt_rounded, label: 'Who can send Signals',
              value: s['signal_permission'] as String? ?? 'everyone', onChanged: (v) => n.setString('signal_permission', v)),
          _PermSelector(icon: Icons.mail_outline_rounded, label: 'Who can leave Notes',
              value: s['note_permission'] as String? ?? 'everyone', onChanged: (v) => n.setString('note_permission', v)),

          // ════════════════════════════════════════════════════════════
          // 5. NOTIFICATIONS
          // ════════════════════════════════════════════════════════════
          _H('Notifications'),
          _T(Icons.chat_bubble_outline, 'Messages', n.notif('new_message'), (_) => n.toggleNotif('new_message')),
          _T(Icons.favorite_outline, 'Connections', n.notif('new_match'), (_) => n.toggleNotif('new_match')),
          _T(Icons.bolt_outlined, 'Signals', n.notif('signals'), (_) => n.toggleNotif('signals')),
          _T(Icons.mail_outline, 'Notes', n.notif('notes'), (_) => n.toggleNotif('notes')),
          _T(Icons.people_outline, 'BFF Suggestions', n.notif('bff_suggestion'), (_) => n.toggleNotif('bff_suggestion')),
          _T(Icons.event_outlined, 'Event Activity', n.notif('event_activity'), (_) => n.toggleNotif('event_activity')),
          _T(Icons.forum_outlined, 'Event Chat', n.notif('event_chat'), (_) => n.toggleNotif('event_chat')),
          _T(Icons.verified_outlined, 'Verification Alerts', n.notif('verification'), (_) => n.toggleNotif('verification')),
          _T(Icons.shield_outlined, 'Safety Alerts', n.notif('safety'), (_) => n.toggleNotif('safety')),
          _T(Icons.system_update_outlined, 'Product Updates', n.notif('updates'), (_) => n.toggleNotif('updates')),

          // ════════════════════════════════════════════════════════════
          // 6. SAFETY & VERIFICATION
          // ════════════════════════════════════════════════════════════
          _H('Safety & Verification'),
          _Tile(Icons.camera_alt_outlined, 'Photo Verification',
              sub: (s['photos_verified'] as bool? ?? false) ? 'Verified' : (s['verification_status'] as String? ?? 'Not started')),
          _Tile(Icons.face_rounded, 'Selfie Verification',
              sub: (s['selfie_verified'] as bool? ?? false) ? 'Verified' : 'Not verified'),
          _Tile(Icons.badge_outlined, 'ID Verification', sub: 'Coming soon', color: context.textDisabled),
          _Tile(Icons.block_rounded, 'Blocked Users',
              sub: '${(s['blocked_users'] as List<dynamic>?)?.length ?? 0} blocked',
              onTap: () => _showListSheet(context, 'Blocked Users', s['blocked_users'] as List<dynamic>?)),
          _Tile(Icons.visibility_off_outlined, 'Hidden Users',
              sub: '${(s['hidden_users'] as List<dynamic>?)?.length ?? 0} hidden',
              onTap: () => _showListSheet(context, 'Hidden Users', s['hidden_users'] as List<dynamic>?)),
          _Tile(Icons.security_rounded, 'Safety Tips', onTap: () => _showStaticContent(context, 'Safety Tips',
              'Trust your instincts. Meet in public places. Tell someone where you\'re going. '
              'Don\'t share personal info too early. Report any suspicious behavior.')),
          _Tile(Icons.rule_rounded, 'Community Rules', onTap: () => _showStaticContent(context, 'Community Rules',
              'Be respectful. No harassment. No spam. No fake profiles. No commercial content. '
              'Noblara is a space for genuine human connections.')),

          // ════════════════════════════════════════════════════════════
          // 7. CHATS & CALLS
          // ════════════════════════════════════════════════════════════
          _H('Chats & Calls'),
          _T(Icons.preview_rounded, 'Message Previews', s['message_preview'] as bool? ?? true, (_) => n.toggleBool('message_preview'),
              sub: 'Show message content in inbox list'),
          _Tile(Icons.save_alt_rounded, 'Auto-save Media', sub: 'Available in a future update', color: context.textDisabled),
          _Tile(Icons.alarm_rounded, 'Call Reminders', sub: 'Available in a future update', color: context.textDisabled),
          _T(Icons.exit_to_app_rounded, 'Leave Event Chat After End', s['leave_event_chat_auto'] as bool? ?? true, (_) => n.toggleBool('leave_event_chat_auto')),

          // ════════════════════════════════════════════════════════════
          // 8. AI PREFERENCES
          // ════════════════════════════════════════════════════════════
          _H('AI Writing Help'),
          _T(Icons.auto_fix_high_rounded, 'Nob Text Cleanup', n.aiVal('ai_writing_help', 'nob_cleanup'), (_) => n.toggleAi('ai_writing_help', 'nob_cleanup')),
          _Tile(Icons.person_outline, 'Bio Cleanup', sub: 'Available in a future update', color: context.textDisabled),
          _Tile(Icons.event_note_rounded, 'Event Description Cleanup', sub: 'Available in a future update', color: context.textDisabled),
          _T(Icons.chat_outlined, 'First Message Softening', n.aiVal('ai_writing_help', 'message_softening'), (_) => n.toggleAi('ai_writing_help', 'message_softening')),
          _H('AI Suggestions'),
          _T(Icons.people_outline, 'BFF Suggestion Explanations', n.aiVal('ai_suggestions', 'bff_explanations'), (_) => n.toggleAi('ai_suggestions', 'bff_explanations')),
          _Tile(Icons.event_outlined, 'Event Recommendations', sub: 'Available in a future update', color: context.textDisabled),
          _Tile(Icons.insights_rounded, 'Profile Resonance', sub: 'Available in a future update', color: context.textDisabled),
          _Tile(Icons.tune_rounded, 'Filter Suggestions', sub: 'Available in a future update', color: context.textDisabled),
          _H('AI Insights'),
          _Tile(Icons.visibility_rounded, 'Show Resonance', sub: 'Coming in a future update', color: context.textDisabled),
          _Tile(Icons.star_outline_rounded, 'Show Highlights', sub: 'Coming in a future update', color: context.textDisabled),
          _Tile(Icons.bar_chart_rounded, 'Show Performance', sub: 'Coming in a future update', color: context.textDisabled),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(AppSpacing.radiusSm), border: Border.all(color: context.borderColor)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Privacy', style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpacing.sm),
                  Text('AI uses: profile text, behavior patterns, interaction quality.\n'
                      'AI never uses: private messages, call audio/video.\n'
                      'Text cleanup: sent for processing, not stored.\n'
                      'Resonance: anonymous pattern matching only.',
                      style: TextStyle(color: context.textMuted, fontSize: 12, height: 1.5)),
                ],
              ),
            ),
          ),

          // ════════════════════════════════════════════════════════════
          // 9. TRAVEL & LOCATION
          // ════════════════════════════════════════════════════════════
          _H('Travel & Location'),
          _EditCity(city: s['city'] as String? ?? '', onChanged: (v) => n.setString('city', v)),
          _T(Icons.flight_rounded, 'Travel Mode', s['travel_mode'] as bool? ?? false, (_) => n.toggleBool('travel_mode'),
              sub: 'Show profiles from destination city'),
          if (s['travel_mode'] as bool? ?? false)
            _EditCity(label: 'Destination city', city: s['travel_city'] as String? ?? '', onChanged: (v) => n.setString('travel_city', v)),

          // ════════════════════════════════════════════════════════════
          // 10. SUPPORT & LEGAL
          // ════════════════════════════════════════════════════════════
          _H('Support & Legal'),
          _Tile(Icons.help_outline_rounded, 'Help Center', sub: 'Noblara Guide',
              onTap: () => _showStaticContent(context, 'Help Center', 'Noblara Guide is a context-aware help system. For now, contact support for any questions.')),
          _Tile(Icons.email_outlined, 'Contact Support', onTap: () => _showStaticContent(context, 'Contact', 'Email: support@noblara.com')),
          _Tile(Icons.bug_report_outlined, 'Report a Bug', onTap: () => _showBugReport(context, ref)),
          _Tile(Icons.download_outlined, 'Request My Data', onTap: () => _showStaticContent(context, 'Data Request',
              'Under GDPR/KVKK, you have the right to request your data. Send an email to privacy@noblara.com with your account email.')),
          _Tile(Icons.rule_rounded, 'Community Guidelines', onTap: () => _showStaticContent(context, 'Community Guidelines',
              'Be real. Be respectful. No spam, no ads, no fake profiles. Noblara is built for genuine connections.')),
          _Tile(Icons.privacy_tip_outlined, 'Privacy Policy', onTap: () => _showStaticContent(context, 'Privacy Policy',
              'Your privacy matters. We collect only what\'s needed. We never sell data. Full policy at noblara.com/privacy.')),
          _Tile(Icons.article_outlined, 'Terms of Service', onTap: () => _showStaticContent(context, 'Terms of Service',
              'By using Noblara you agree to our community standards. Full terms at noblara.com/terms.')),
          const _Tile(Icons.info_outline_rounded, 'Version', sub: '1.0.0'),

          // ════════════════════════════════════════════════════════════
          // DANGER ZONE
          // ════════════════════════════════════════════════════════════
          _H('Danger Zone'),
          _Tile(Icons.pause_circle_outline, 'Pause Account', sub: 'Hide from discovery, keep your data', color: AppColors.warning,
              onTap: () => _confirmPause(context, ref)),
          _Tile(Icons.delete_outline, 'Delete Account', color: AppColors.error,
              onTap: () => _confirmDelete(context, ref)),

          const SizedBox(height: AppSpacing.xxxxl),
        ],
      ),
    );
  }

  // ── Helpers ──

  void _changePassword(BuildContext context) {
    if (isMockMode) return;
    Supabase.instance.client.auth.resetPasswordForEmail(
      Supabase.instance.client.auth.currentUser?.email ?? '',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password reset email sent')),
    );
  }

  void _pickLanguage(BuildContext context, WidgetRef ref, _SettingsNotifier n) {
    showModalBottomSheet(
      context: context, backgroundColor: context.surfaceColor,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(title: Text('English', style: TextStyle(color: context.textPrimary)),
            onTap: () { Navigator.pop(ctx); n.setString('language', 'en'); }),
        ListTile(title: Text('Türkçe', style: TextStyle(color: context.textPrimary)),
            onTap: () { Navigator.pop(ctx); n.setString('language', 'tr'); }),
        const SizedBox(height: AppSpacing.xxl),
      ]),
    );
  }

  void _showStaticContent(BuildContext context, String title, String body) {
    showModalBottomSheet(
      context: context, backgroundColor: context.surfaceColor, isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6, expand: false,
        builder: (ctx, scroll) => ListView(controller: scroll, padding: const EdgeInsets.all(AppSpacing.xxl), children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(999)))),
          const SizedBox(height: AppSpacing.xxl),
          Text(title, style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.lg),
          Text(body, style: TextStyle(color: context.textMuted, fontSize: 14, height: 1.6)),
        ]),
      ),
    );
  }

  void _showListSheet(BuildContext context, String title, List<dynamic>? items) {
    showModalBottomSheet(
      context: context, backgroundColor: context.surfaceColor,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.lg),
          if (items == null || items.isEmpty)
            Text('None', style: TextStyle(color: context.textMuted))
          else
            ...items.take(20).map((id) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('$id', style: TextStyle(color: context.textMuted, fontSize: 12, fontFamily: 'monospace')),
            )),
          const SizedBox(height: AppSpacing.xxl),
        ]),
      ),
    );
  }

  void _showBugReport(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text('Report a Bug', style: TextStyle(color: context.textPrimary, fontSize: 16)),
        content: TextField(controller: ctrl, maxLines: 4, style: TextStyle(color: context.textPrimary),
            decoration: InputDecoration(hintText: 'Describe the issue...', hintStyle: TextStyle(color: context.textDisabled),
                filled: true, fillColor: context.bgColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: context.textMuted))),
          TextButton(onPressed: () {
            Navigator.pop(ctx);
            Clipboard.setData(ClipboardData(text: 'Bug report: ${ctrl.text.trim()}'));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bug report copied. Send to support@noblara.com')));
          }, child: const Text('Copy & Send', style: TextStyle(color: AppColors.gold))),
        ],
      ),
    );
  }

  void _confirmPause(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: context.surfaceColor,
      title: const Text('Pause Account', style: TextStyle(color: AppColors.warning)),
      content: Text('Your profile will be hidden. Your data stays safe. You can return anytime.', style: TextStyle(color: context.textMuted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: context.textMuted))),
        TextButton(onPressed: () async {
          Navigator.pop(context);
          final uid = ref.read(authProvider).userId;
          if (uid != null && !isMockMode) {
            await Supabase.instance.client.from('profiles').update({'is_paused': true}).eq('id', uid);
          }
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account paused')));
        }, child: const Text('Pause', style: TextStyle(color: AppColors.warning))),
      ],
    ));
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (_) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: const Text('Delete Account', style: TextStyle(color: AppColors.error)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('This will permanently delete your account and all data. This cannot be undone.', style: TextStyle(color: context.textMuted)),
          const SizedBox(height: AppSpacing.lg),
          Text('Type DELETE to confirm:', style: TextStyle(color: context.textMuted, fontSize: 12)),
          const SizedBox(height: AppSpacing.sm),
          TextField(controller: ctrl, style: TextStyle(color: context.textPrimary), onChanged: (_) => setState(() {}),
              decoration: InputDecoration(hintText: 'DELETE', hintStyle: TextStyle(color: context.textDisabled),
                  filled: true, fillColor: context.bgColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: context.textMuted))),
          TextButton(
            onPressed: ctrl.text == 'DELETE' ? () async {
              Navigator.pop(ctx);
              if (!isMockMode) {
                final uid = ref.read(authProvider).userId;
                if (uid != null) {
                  // Mark for deletion + sign out (admin completes actual deletion)
                  await Supabase.instance.client.from('profiles').update({'is_paused': true, 'verification_status': 'deletion_requested'}).eq('id', uid);
                }
              }
              await ref.read(authProvider.notifier).signOut();
            } : null,
            child: Text('Delete', style: TextStyle(color: ctrl.text == 'DELETE' ? AppColors.error : context.textDisabled)),
          ),
        ],
      ),
    ));
  }
}

// ═══════════════════════════════════════════════════════════════════
// Reusable widgets
// ═══════════════════════════════════════════════════════════════════

class _H extends StatelessWidget {
  final String t;
  const _H(this.t);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xxxl, AppSpacing.lg, AppSpacing.sm),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 24, height: 1.5, decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(1))),
      const SizedBox(height: AppSpacing.sm),
      Text(t.toUpperCase(), style: TextStyle(color: context.textDisabled, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.8)),
    ]),
  );
}

class _Tile extends StatelessWidget {
  final IconData icon; final String title; final String? sub; final Color? color; final VoidCallback? onTap;
  const _Tile(this.icon, this.title, {this.sub, this.color, this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = color ?? context.textPrimary;
    return ListTile(tileColor: Colors.transparent, leading: Icon(icon, color: c, size: 20),
      title: Text(title, style: TextStyle(color: c, fontSize: 14)),
      subtitle: sub != null ? Text(sub!, style: TextStyle(color: context.textDisabled, fontSize: 12)) : null,
      trailing: onTap != null ? Icon(Icons.chevron_right_rounded, color: context.textDisabled, size: 18) : null,
      onTap: onTap);
  }
}

class _T extends StatelessWidget {
  final IconData icon; final String title; final bool value; final ValueChanged<bool> onChanged; final String? sub;
  const _T(this.icon, this.title, this.value, this.onChanged, {this.sub});
  @override
  Widget build(BuildContext context) => ListTile(tileColor: Colors.transparent,
    leading: Icon(icon, color: context.textPrimary, size: 20),
    title: Text(title, style: TextStyle(color: context.textPrimary, fontSize: 14)),
    subtitle: sub != null ? Text(sub!, style: TextStyle(color: context.textDisabled, fontSize: 11)) : null,
    trailing: Switch.adaptive(value: value, onChanged: onChanged, activeTrackColor: AppColors.gold.withValues(alpha: 0.4)));
}

class _PermSelector extends StatelessWidget {
  final IconData icon; final String label; final String value; final ValueChanged<String> onChanged;
  const _PermSelector({required this.icon, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final options = ['everyone', 'verified', 'explorer_plus', 'noble_only', 'nobody'];
    final labels = {'everyone': 'Everyone', 'verified': 'Verified only', 'explorer_plus': 'Explorer+ only', 'noble_only': 'Noble only', 'nobody': 'Nobody'};
    return ListTile(tileColor: Colors.transparent,
      leading: Icon(icon, color: context.textPrimary, size: 20),
      title: Text(label, style: TextStyle(color: context.textPrimary, fontSize: 14)),
      trailing: DropdownButton<String>(
        value: options.contains(value) ? value : 'everyone',
        dropdownColor: context.surfaceColor,
        style: const TextStyle(color: AppColors.gold, fontSize: 12),
        underline: const SizedBox.shrink(),
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(labels[o] ?? o))).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      ),
    );
  }
}

class _EditCity extends StatefulWidget {
  final String city; final ValueChanged<String> onChanged; final String label;
  const _EditCity({required this.city, required this.onChanged, this.label = 'Current city'});
  @override
  State<_EditCity> createState() => _EditCityState();
}

class _EditCityState extends State<_EditCity> {
  late final TextEditingController _c;
  @override void initState() { super.initState(); _c = TextEditingController(text: widget.city); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => ListTile(tileColor: Colors.transparent,
    leading: Icon(Icons.location_on_rounded, color: context.textPrimary, size: 20),
    title: Text(widget.label, style: TextStyle(color: context.textPrimary, fontSize: 14)),
    subtitle: SizedBox(height: 34, child: TextField(controller: _c,
      style: TextStyle(color: context.textPrimary, fontSize: 13),
      decoration: InputDecoration(hintText: 'e.g. Istanbul', hintStyle: TextStyle(color: context.textDisabled, fontSize: 13),
        isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: context.borderColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: context.borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.gold))),
      onSubmitted: widget.onChanged, onEditingComplete: () => widget.onChanged(_c.text.trim()))));
}

// ═══════════════════════════════════════════════════════════════════
// Appearance widgets (preserved from earlier implementation)
// ═══════════════════════════════════════════════════════════════════

class _AppearanceThemeSelector extends StatelessWidget {
  final WidgetRef ref;
  const _AppearanceThemeSelector({required this.ref});
  @override
  Widget build(BuildContext context) {
    final current = ref.watch(appearanceProvider).themeMode;
    return Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg), child: Row(children: [
      Icon(Icons.brightness_6_rounded, color: context.textPrimary, size: 20),
      const SizedBox(width: AppSpacing.md),
      Expanded(child: Text('Theme', style: TextStyle(color: context.textPrimary, fontSize: 14))),
      SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded, size: 16)),
          ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded, size: 16)),
          ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.settings_brightness_rounded, size: 16)),
        ],
        selected: {current},
        onSelectionChanged: (s) => ref.read(appearanceProvider.notifier).setThemeMode(s.first),
        style: SegmentedButton.styleFrom(backgroundColor: context.surfaceColor,
            selectedBackgroundColor: AppColors.gold.withValues(alpha: 0.2), selectedForegroundColor: AppColors.gold, foregroundColor: context.textMuted),
      ),
    ]));
  }
}

class _AppearanceAccentSelector extends StatelessWidget {
  final WidgetRef ref;
  const _AppearanceAccentSelector({required this.ref});
  @override
  Widget build(BuildContext context) {
    final current = ref.watch(appearanceProvider).accent;
    return Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg), child: Row(children: [
      Icon(Icons.palette_rounded, color: context.textPrimary, size: 20),
      const SizedBox(width: AppSpacing.md),
      Expanded(child: Text('Accent', style: TextStyle(color: context.textPrimary, fontSize: 14))),
      Row(children: AppAccent.values.map((a) {
        final sel = a == current;
        return GestureDetector(onTap: () => ref.read(appearanceProvider.notifier).setAccent(a),
          child: Container(width: 28, height: 28, margin: const EdgeInsets.only(left: 6),
            decoration: BoxDecoration(color: a.color, shape: BoxShape.circle,
              border: Border.all(color: sel ? Colors.white : Colors.transparent, width: sel ? 2.5 : 0),
              boxShadow: sel ? [BoxShadow(color: a.color.withValues(alpha: 0.4), blurRadius: 8)] : null),
            child: sel ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null));
      }).toList()),
    ]));
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/mock_mode.dart';
import '../../providers/auth_provider.dart';

// ---------------------------------------------------------------------------
// Settings provider — loads/saves notification_preferences from profiles
// ---------------------------------------------------------------------------

final _notifPrefsProvider =
    StateNotifierProvider<_NotifPrefsNotifier, Map<String, bool>>((ref) {
  return _NotifPrefsNotifier(ref);
});

class _NotifPrefsNotifier extends StateNotifier<Map<String, bool>> {
  final Ref _ref;
  static const _defaults = {
    'new_match': true,
    'new_message': true,
    'video_proposed': true,
    'video_confirmed': true,
    'post_comment': true,
  };

  _NotifPrefsNotifier(this._ref) : super(_defaults) {
    _load();
  }

  Future<void> _load() async {
    if (isMockMode) return;
    final userId = _ref.read(authProvider).userId;
    if (userId == null) return;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('notification_preferences')
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return;
      final prefs = row['notification_preferences'] as Map<String, dynamic>?;
      if (prefs != null) {
        state = {
          for (final k in _defaults.keys) k: prefs[k] as bool? ?? true,
        };
      }
    } catch (_) {}
  }

  Future<void> toggle(String key) async {
    final next = Map<String, bool>.from(state);
    next[key] = !(next[key] ?? true);
    state = next;
    if (isMockMode) return;
    final userId = _ref.read(authProvider).userId;
    if (userId == null) return;
    try {
      await Supabase.instance.client.from('profiles').update({
        'notification_preferences': state,
      }).eq('id', userId);
    } catch (_) {}
  }
}

// ---------------------------------------------------------------------------
// Settings Screen
// ---------------------------------------------------------------------------

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(_notifPrefsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text('Settings',
            style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: ListView(
        children: [
          // ── Account ──────────────────────────────────────────────────────
          _SectionHeader('Account'),
          _SettingsTile(
            icon: Icons.person_outline_rounded,
            title: 'Edit Profile',
            onTap: () => Navigator.pop(context),
          ),
          _SettingsTile(
            icon: Icons.lock_outline_rounded,
            title: 'Change Password',
            onTap: () => _showComingSoon(context),
          ),
          _SettingsTile(
            icon: Icons.logout_rounded,
            title: 'Sign Out',
            color: AppColors.error,
            onTap: () => ref.read(authProvider.notifier).signOut(),
          ),

          // ── Notifications ─────────────────────────────────────────────
          _SectionHeader('Notifications'),
          _ToggleTile(
            icon: Icons.favorite_outline_rounded,
            title: 'New Match',
            value: prefs['new_match'] ?? true,
            onChanged: (_) =>
                ref.read(_notifPrefsProvider.notifier).toggle('new_match'),
          ),
          _ToggleTile(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'New Message',
            value: prefs['new_message'] ?? true,
            onChanged: (_) =>
                ref.read(_notifPrefsProvider.notifier).toggle('new_message'),
          ),
          _ToggleTile(
            icon: Icons.videocam_outlined,
            title: 'Video Call Proposed',
            value: prefs['video_proposed'] ?? true,
            onChanged: (_) =>
                ref.read(_notifPrefsProvider.notifier).toggle('video_proposed'),
          ),
          _ToggleTile(
            icon: Icons.check_circle_outline_rounded,
            title: 'Video Call Confirmed',
            value: prefs['video_confirmed'] ?? true,
            onChanged: (_) => ref
                .read(_notifPrefsProvider.notifier)
                .toggle('video_confirmed'),
          ),
          _ToggleTile(
            icon: Icons.comment_outlined,
            title: 'Post Comments',
            value: prefs['post_comment'] ?? true,
            onChanged: (_) =>
                ref.read(_notifPrefsProvider.notifier).toggle('post_comment'),
          ),

          // ── Privacy ───────────────────────────────────────────────────
          _SectionHeader('Privacy'),
          _SettingsTile(
            icon: Icons.visibility_outlined,
            title: 'Profile Visibility',
            subtitle: 'Visible to verified members',
            onTap: () => _showComingSoon(context),
          ),
          _SettingsTile(
            icon: Icons.block_rounded,
            title: 'Blocked Users',
            onTap: () => _showComingSoon(context),
          ),
          _SettingsTile(
            icon: Icons.delete_outline_rounded,
            title: 'Delete Account',
            color: AppColors.error,
            onTap: () => _confirmDelete(context, ref),
          ),

          // ── About ─────────────────────────────────────────────────────
          _SectionHeader('About'),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'Version',
            subtitle: '1.0.0',
            onTap: null,
          ),
          _SettingsTile(
            icon: Icons.article_outlined,
            title: 'Terms of Service',
            onTap: () => _showComingSoon(context),
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () => _showComingSoon(context),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon')),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Account',
            style: TextStyle(color: AppColors.error)),
        content: const Text(
          'This will permanently delete your account and all data. This cannot be undone.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showComingSoon(context);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.xs),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textDisabled,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? color;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return ListTile(
      tileColor: Colors.transparent,
      leading: Icon(icon, color: c, size: 20),
      title: Text(title, style: TextStyle(color: c, fontSize: 14)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: const TextStyle(
                  color: AppColors.textDisabled, fontSize: 12))
          : null,
      trailing: onTap != null
          ? const Icon(Icons.chevron_right_rounded,
              color: AppColors.textDisabled, size: 18)
          : null,
      onTap: onTap,
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: Colors.transparent,
      leading: Icon(icon, color: AppColors.textPrimary, size: 20),
      title: Text(title,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.gold,
        activeTrackColor: AppColors.gold.withValues(alpha: 0.4),
        inactiveTrackColor: AppColors.border,
      ),
    );
  }
}

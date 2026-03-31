import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/mock_mode.dart';
import '../../providers/appearance_provider.dart';
import '../../providers/auth_provider.dart';

// ---------------------------------------------------------------------------
// Settings provider — loads/saves settings from profiles
// ---------------------------------------------------------------------------

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
    final userId = _ref.read(authProvider).userId;
    if (userId == null) return;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('notification_preferences, incognito_mode, calm_mode, '
              'dating_active, dating_visible, bff_active, bff_visible, '
              'social_active, social_visible, show_city_only, hide_exact_distance, '
              'show_last_active, show_status_badge, message_preview, '
              'reach_permission, signal_permission, note_permission, '
              'city, travel_mode, travel_city')
          .eq('id', userId)
          .maybeSingle();
      if (row != null) state = row;
    } catch (_) {
      state = _defaults();
    }
  }

  Map<String, dynamic> _defaults() => {
    'notification_preferences': {
      'new_match': true, 'new_message': true, 'video_proposed': true,
      'video_confirmed': true, 'post_comment': true, 'bff_suggestion': true,
      'event_activity': true, 'safety': true,
    },
    'incognito_mode': false, 'calm_mode': false,
    'dating_active': true, 'dating_visible': true,
    'bff_active': true, 'bff_visible': true,
    'social_active': true, 'social_visible': true,
    'show_city_only': false, 'hide_exact_distance': false,
    'show_last_active': true, 'show_status_badge': true,
    'message_preview': true,
    'reach_permission': 'everyone', 'signal_permission': 'everyone', 'note_permission': 'everyone',
  };

  Future<void> _save(String column, dynamic value) async {
    state = {...state, column: value};
    if (isMockMode) return;
    final userId = _ref.read(authProvider).userId;
    if (userId == null) return;
    try {
      await Supabase.instance.client.from('profiles')
          .update({column: value}).eq('id', userId);
    } catch (_) {}
  }

  void toggleBool(String key) {
    final current = state[key] as bool? ?? false;
    _save(key, !current);
  }

  void setString(String key, String value) => _save(key, value);

  void toggleNotif(String key) {
    final prefs = Map<String, dynamic>.from(
        state['notification_preferences'] as Map<String, dynamic>? ?? {});
    prefs[key] = !(prefs[key] as bool? ?? true);
    _save('notification_preferences', prefs);
  }

  bool notif(String key) {
    final prefs = state['notification_preferences'] as Map<String, dynamic>?;
    return prefs?[key] as bool? ?? true;
  }

  bool getBool(String key) => state[key] as bool? ?? false;
  String getString(String key) => state[key] as String? ?? 'everyone';
}

// ---------------------------------------------------------------------------
// Settings Screen
// ---------------------------------------------------------------------------

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(_settingsProvider);
    final n = ref.read(_settingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text('Settings', style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: ListView(
        children: [
          // ── Account ──
          _SectionHeader('Account'),
          _SettingsTile(icon: Icons.logout_rounded, title: 'Sign Out', color: AppColors.error,
              onTap: () => ref.read(authProvider.notifier).signOut()),

          // ── Appearance ──
          _SectionHeader('Appearance'),
          _AppearanceThemeSelector(ref: ref),
          const SizedBox(height: AppSpacing.sm),
          _AppearanceAccentSelector(ref: ref),

          // ── Modes ──
          _SectionHeader('Modes'),
          _ToggleTile(icon: Icons.favorite_rounded, title: 'Dating Active',
              value: s['dating_active'] as bool? ?? true, onChanged: (_) => n.toggleBool('dating_active')),
          _ToggleTile(icon: Icons.favorite_outline, title: 'Dating Visible',
              value: s['dating_visible'] as bool? ?? true, onChanged: (_) => n.toggleBool('dating_visible')),
          _ToggleTile(icon: Icons.people_rounded, title: 'BFF Active',
              value: s['bff_active'] as bool? ?? true, onChanged: (_) => n.toggleBool('bff_active')),
          _ToggleTile(icon: Icons.people_outline, title: 'BFF Visible',
              value: s['bff_visible'] as bool? ?? true, onChanged: (_) => n.toggleBool('bff_visible')),
          _ToggleTile(icon: Icons.explore_rounded, title: 'Social Active',
              value: s['social_active'] as bool? ?? true, onChanged: (_) => n.toggleBool('social_active')),
          _ToggleTile(icon: Icons.explore_outlined, title: 'Social Visible',
              value: s['social_visible'] as bool? ?? true, onChanged: (_) => n.toggleBool('social_visible')),

          // ── Privacy ──
          _SectionHeader('Privacy & Visibility'),
          _ToggleTile(icon: Icons.visibility_off_rounded, title: 'Incognito Mode',
              subtitle: 'Browse invisibly. Only connections can see you.',
              value: s['incognito_mode'] as bool? ?? false, onChanged: (_) => n.toggleBool('incognito_mode')),
          _ToggleTile(icon: Icons.shield_rounded, title: 'Calm Mode',
              subtitle: 'Only Verified + Complete + Explorer+ can reach you.',
              value: s['calm_mode'] as bool? ?? false, onChanged: (_) => n.toggleBool('calm_mode')),
          _ToggleTile(icon: Icons.location_city_rounded, title: 'Show city only',
              value: s['show_city_only'] as bool? ?? false, onChanged: (_) => n.toggleBool('show_city_only')),
          _ToggleTile(icon: Icons.straighten_rounded, title: 'Hide exact distance',
              value: s['hide_exact_distance'] as bool? ?? false, onChanged: (_) => n.toggleBool('hide_exact_distance')),
          _ToggleTile(icon: Icons.access_time_rounded, title: 'Show when last active',
              value: s['show_last_active'] as bool? ?? true, onChanged: (_) => n.toggleBool('show_last_active')),
          _ToggleTile(icon: Icons.workspace_premium_rounded, title: 'Show status badge',
              value: s['show_status_badge'] as bool? ?? true, onChanged: (_) => n.toggleBool('show_status_badge')),

          // ── Travel & Location ──
          _SectionHeader('Travel & Location'),
          _EditableCityTile(
            currentCity: s['city'] as String? ?? '',
            onChanged: (v) => n.setString('city', v),
          ),
          _ToggleTile(icon: Icons.flight_rounded, title: 'Travel Mode',
              subtitle: 'Show profiles from your destination city.',
              value: s['travel_mode'] as bool? ?? false, onChanged: (_) => n.toggleBool('travel_mode')),
          if (s['travel_mode'] as bool? ?? false)
            _EditableCityTile(
              label: 'Destination city',
              currentCity: s['travel_city'] as String? ?? '',
              onChanged: (v) => n.setString('travel_city', v),
            ),
          _SettingsTile(
            icon: Icons.tune_rounded,
            title: 'Distance preference',
            subtitle: 'Opens filter panel',
            onTap: () {
              Navigator.pop(context);
              // Filter panel is accessible from feed
            },
          ),

          // ── Notifications ──
          _SectionHeader('Notifications'),
          _ToggleTile(icon: Icons.favorite_outline_rounded, title: 'Connections',
              value: n.notif('new_match'), onChanged: (_) => n.toggleNotif('new_match')),
          _ToggleTile(icon: Icons.chat_bubble_outline_rounded, title: 'Messages',
              value: n.notif('new_message'), onChanged: (_) => n.toggleNotif('new_message')),
          _ToggleTile(icon: Icons.videocam_outlined, title: 'Video Calls',
              value: n.notif('video_proposed'), onChanged: (_) => n.toggleNotif('video_proposed')),
          _ToggleTile(icon: Icons.people_outline, title: 'BFF Suggestions',
              value: n.notif('bff_suggestion'), onChanged: (_) => n.toggleNotif('bff_suggestion')),
          _ToggleTile(icon: Icons.event_rounded, title: 'Event Activity',
              value: n.notif('event_activity'), onChanged: (_) => n.toggleNotif('event_activity')),
          _ToggleTile(icon: Icons.shield_outlined, title: 'Safety Alerts',
              value: n.notif('safety'), onChanged: (_) => n.toggleNotif('safety')),
          _ToggleTile(icon: Icons.preview_rounded, title: 'Message Previews',
              value: s['message_preview'] as bool? ?? true, onChanged: (_) => n.toggleBool('message_preview')),

          // ── Danger Zone ──
          _SectionHeader('Danger Zone'),
          _SettingsTile(icon: Icons.pause_circle_outline_rounded, title: 'Pause Account',
              subtitle: 'Your profile will be hidden. You can return anytime.',
              color: AppColors.warning,
              onTap: () => _confirmPause(context, ref)),
          _SettingsTile(icon: Icons.delete_outline_rounded, title: 'Delete Account',
              color: AppColors.error,
              onTap: () => _confirmDelete(context, ref)),

          // ── About ──
          _SectionHeader('About'),
          const _SettingsTile(icon: Icons.info_outline_rounded, title: 'Version', subtitle: '1.0.0'),

          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  void _confirmPause(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Pause Account', style: TextStyle(color: AppColors.warning)),
        content: const Text(
          'Your profile will be hidden from discovery. Your data stays safe. You can return anytime.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final uid = ref.read(authProvider).userId;
              if (uid != null && !isMockMode) {
                await Supabase.instance.client.from('profiles')
                    .update({'is_paused': true}).eq('id', uid);
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Account paused. You can reactivate anytime.')),
                );
              }
            },
            child: const Text('Pause', style: TextStyle(color: AppColors.warning)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    final deleteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Delete Account', style: TextStyle(color: AppColors.error)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This will permanently delete your account and all data. This cannot be undone.',
                  style: TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: AppSpacing.lg),
              const Text('Type DELETE to confirm:', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: deleteCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'DELETE',
                  hintStyle: const TextStyle(color: AppColors.textDisabled),
                  filled: true, fillColor: AppColors.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
            TextButton(
              onPressed: deleteCtrl.text == 'DELETE'
                  ? () async {
                      Navigator.pop(ctx);
                      await ref.read(authProvider.notifier).signOut();
                      // In production: call Supabase admin delete user endpoint
                    }
                  : null,
              child: Text('Delete', style: TextStyle(
                  color: deleteCtrl.text == 'DELETE' ? AppColors.error : AppColors.textDisabled)),
            ),
          ],
        ),
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
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.xs),
      child: Text(title.toUpperCase(),
          style: const TextStyle(color: AppColors.textDisabled, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? color;
  final VoidCallback? onTap;

  const _SettingsTile({required this.icon, required this.title, this.subtitle, this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return ListTile(
      tileColor: Colors.transparent,
      leading: Icon(icon, color: c, size: 20),
      title: Text(title, style: TextStyle(color: c, fontSize: 14)),
      subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(color: AppColors.textDisabled, fontSize: 12)) : null,
      trailing: onTap != null ? const Icon(Icons.chevron_right_rounded, color: AppColors.textDisabled, size: 18) : null,
      onTap: onTap,
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({required this.icon, required this.title, this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: Colors.transparent,
      leading: Icon(icon, color: AppColors.textPrimary, size: 20),
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
      subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(color: AppColors.textDisabled, fontSize: 11)) : null,
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.gold.withValues(alpha: 0.4),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Appearance: Theme Mode selector
// ---------------------------------------------------------------------------

class _AppearanceThemeSelector extends StatelessWidget {
  final WidgetRef ref;
  const _AppearanceThemeSelector({required this.ref});

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(appearanceProvider).themeMode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          const Icon(Icons.brightness_6_rounded, color: AppColors.textPrimary, size: 20),
          const SizedBox(width: AppSpacing.md),
          const Expanded(child: Text('Theme', style: TextStyle(color: AppColors.textPrimary, fontSize: 14))),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded, size: 16)),
              ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded, size: 16)),
              ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.settings_brightness_rounded, size: 16)),
            ],
            selected: {current},
            onSelectionChanged: (s) => ref.read(appearanceProvider.notifier).setThemeMode(s.first),
            style: SegmentedButton.styleFrom(
              backgroundColor: AppColors.surface,
              selectedBackgroundColor: AppColors.gold.withValues(alpha: 0.2),
              selectedForegroundColor: AppColors.gold,
              foregroundColor: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Appearance: Accent Color selector
// ---------------------------------------------------------------------------

class _AppearanceAccentSelector extends StatelessWidget {
  final WidgetRef ref;
  const _AppearanceAccentSelector({required this.ref});

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(appearanceProvider).accent;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          const Icon(Icons.palette_rounded, color: AppColors.textPrimary, size: 20),
          const SizedBox(width: AppSpacing.md),
          const Expanded(child: Text('Accent', style: TextStyle(color: AppColors.textPrimary, fontSize: 14))),
          Row(
            children: AppAccent.values.map((a) {
              final selected = a == current;
              return GestureDetector(
                onTap: () => ref.read(appearanceProvider.notifier).setAccent(a),
                child: Container(
                  width: 28, height: 28,
                  margin: const EdgeInsets.only(left: 6),
                  decoration: BoxDecoration(
                    color: a.color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? Colors.white : Colors.transparent,
                      width: selected ? 2.5 : 0,
                    ),
                    boxShadow: selected ? [BoxShadow(color: a.color.withValues(alpha: 0.4), blurRadius: 8)] : null,
                  ),
                  child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Editable city field
// ---------------------------------------------------------------------------

class _EditableCityTile extends StatefulWidget {
  final String currentCity;
  final ValueChanged<String> onChanged;
  final String label;

  const _EditableCityTile({required this.currentCity, required this.onChanged, this.label = 'Current city'});

  @override
  State<_EditableCityTile> createState() => _EditableCityTileState();
}

class _EditableCityTileState extends State<_EditableCityTile> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentCity);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: Colors.transparent,
      leading: const Icon(Icons.location_on_rounded, color: AppColors.textPrimary, size: 20),
      title: Text(widget.label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
      subtitle: SizedBox(
        height: 36,
        child: TextField(
          controller: _ctrl,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'e.g. Istanbul',
            hintStyle: const TextStyle(color: AppColors.textDisabled, fontSize: 13),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.gold)),
          ),
          onSubmitted: widget.onChanged,
          onEditingComplete: () => widget.onChanged(_ctrl.text.trim()),
        ),
      ),
    );
  }
}

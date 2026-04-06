import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/mock_mode.dart';
import 'auth_provider.dart';

// ─── State ───────────────────────────────────────────────────────────

class AppearanceState {
  final ThemeMode themeMode;
  final String accentId;

  const AppearanceState({
    this.themeMode = ThemeMode.dark,
    this.accentId = 'emerald',
  });

  AccentColor get accent => AppColors.accentById(accentId);
  bool get isGold => accentId == 'gold';
  bool get isDarkMode => themeMode == ThemeMode.dark;

  AppearanceState copyWith({ThemeMode? themeMode, String? accentId}) =>
      AppearanceState(
        themeMode: themeMode ?? this.themeMode,
        accentId: accentId ?? this.accentId,
      );
}

// ─── Notifier ────────────────────────────────────────────────────────

const _prefThemeKey = 'noblara_theme_mode';
const _prefAccentKey = 'noblara_accent_color';

class AppearanceNotifier extends StateNotifier<AppearanceState> {
  final Ref _ref;

  AppearanceNotifier(this._ref) : super(const AppearanceState()) {
    _loadLocal();
  }

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString(_prefThemeKey);
    final accentStr = prefs.getString(_prefAccentKey);

    state = AppearanceState(
      themeMode: _parseThemeMode(themeStr),
      accentId: accentStr ?? 'emerald',
    );
  }

  /// Called after auth to sync from Supabase (cross-device restore)
  Future<void> syncFromSupabase() async {
    if (isMockMode) return;
    final uid = _ref.read(authProvider).userId;
    if (uid == null) return;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('theme_mode, accent_color')
          .eq('id', uid)
          .maybeSingle();
      if (row == null) return;
      final theme = _parseThemeMode(row['theme_mode'] as String?);
      final accentId = (row['accent_color'] as String?) ?? 'emerald';
      state = AppearanceState(themeMode: theme, accentId: accentId);
      // Update local cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefThemeKey, _themeModeToString(theme));
      await prefs.setString(_prefAccentKey, accentId);
    } catch (e) { debugPrint('[appearance] Supabase sync failed: $e'); }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _persist();
  }

  Future<void> setAccent(String id, {bool isNoble = false}) async {
    final accent = AppColors.accentById(id);
    // Noble-only accents require Noble tier
    if (accent.nobleOnly && !isNoble) return;
    state = state.copyWith(accentId: id);
    await _persist();
  }

  Future<void> _persist() async {
    // Local
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefThemeKey, _themeModeToString(state.themeMode));
    await prefs.setString(_prefAccentKey, state.accentId);

    // Supabase
    if (isMockMode) return;
    final uid = _ref.read(authProvider).userId;
    if (uid == null) return;
    try {
      await Supabase.instance.client.from('profiles').update({
        'theme_mode': _themeModeToString(state.themeMode),
        'accent_color': state.accentId,
      }).eq('id', uid);
    } catch (e) { debugPrint('[appearance] Supabase persist failed: $e'); }
  }

  static ThemeMode _parseThemeMode(String? s) => switch (s) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };

  static String _themeModeToString(ThemeMode m) => switch (m) {
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
        ThemeMode.dark => 'dark',
      };
}

// ─── Provider ────────────────────────────────────────────────────────

final appearanceProvider =
    StateNotifierProvider<AppearanceNotifier, AppearanceState>((ref) {
  return AppearanceNotifier(ref);
});

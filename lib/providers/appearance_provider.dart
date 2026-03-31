import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/mock_mode.dart';
import 'auth_provider.dart';

// ─── Accent color definitions ────────────────────────────────────────

enum AppAccent {
  gold('Gold', Color(0xFFC9A84C)),
  midnightBlue('Midnight Blue', Color(0xFF1A237E)),
  violet('Violet', Color(0xFF7C3AED)),
  silver('Silver', Color(0xFF9E9E9E)),
  forest('Forest', Color(0xFF2E7D32));

  final String label;
  final Color color;
  const AppAccent(this.label, this.color);

  static AppAccent fromString(String? s) {
    return AppAccent.values.firstWhere(
      (a) => a.name == s,
      orElse: () => AppAccent.gold,
    );
  }
}

// ─── State ───────────────────────────────────────────────────────────

class AppearanceState {
  final ThemeMode themeMode;
  final AppAccent accent;

  const AppearanceState({
    this.themeMode = ThemeMode.dark,
    this.accent = AppAccent.gold,
  });

  AppearanceState copyWith({ThemeMode? themeMode, AppAccent? accent}) =>
      AppearanceState(
        themeMode: themeMode ?? this.themeMode,
        accent: accent ?? this.accent,
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
      accent: AppAccent.fromString(accentStr),
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
      final accent = AppAccent.fromString(row['accent_color'] as String?);
      state = AppearanceState(themeMode: theme, accent: accent);
      // Update local cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefThemeKey, _themeModeToString(theme));
      await prefs.setString(_prefAccentKey, accent.name);
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _persist();
  }

  Future<void> setAccent(AppAccent accent) async {
    state = state.copyWith(accent: accent);
    await _persist();
  }

  Future<void> _persist() async {
    // Local
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefThemeKey, _themeModeToString(state.themeMode));
    await prefs.setString(_prefAccentKey, state.accent.name);

    // Supabase
    if (isMockMode) return;
    final uid = _ref.read(authProvider).userId;
    if (uid == null) return;
    try {
      await Supabase.instance.client.from('profiles').update({
        'theme_mode': _themeModeToString(state.themeMode),
        'accent_color': state.accent.name,
      }).eq('id', uid);
    } catch (_) {}
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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/mock_mode.dart';
import 'auth_provider.dart';

// ---------------------------------------------------------------------------
// State — set of mode strings the user has opted into
// ---------------------------------------------------------------------------

class ActiveModesState {
  final Set<String> modes;
  final bool isLoading;
  final String? error;

  const ActiveModesState({
    this.modes = const {'date'},
    this.isLoading = false,
    this.error,
  });

  ActiveModesState copyWith({
    Set<String>? modes,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ActiveModesState(
      modes: modes ?? this.modes,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  bool has(String mode) => modes.contains(mode);
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class ActiveModesNotifier extends StateNotifier<ActiveModesState> {
  final Ref _ref;

  ActiveModesNotifier(this._ref) : super(const ActiveModesState()) {
    _load();
  }

  Future<void> _load() async {
    if (isMockMode) return;
    final userId = _ref.read(authProvider).userId;
    if (userId == null) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('active_modes')
          .eq('id', userId)
          .maybeSingle();

      final raw = row?['active_modes'];
      final Set<String> loaded;
      if (raw is List && raw.isNotEmpty) {
        loaded = raw.cast<String>().toSet();
      } else {
        // Default: date mode enabled
        loaded = {'date'};
      }
      state = state.copyWith(modes: loaded, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> toggle(String mode) async {
    final current = {...state.modes};
    if (current.contains(mode)) {
      // Prevent deselecting all — at least one must remain
      if (current.length == 1) return;
      current.remove(mode);
    } else {
      current.add(mode);
    }

    // Optimistic update
    state = state.copyWith(modes: current);

    if (isMockMode) return;
    final userId = _ref.read(authProvider).userId;
    if (userId == null) return;

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'active_modes': current.toList()})
          .eq('id', userId);
    } catch (e) {
      // Rollback on error
      state = state.copyWith(error: e.toString());
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final activeModesProvider =
    StateNotifierProvider<ActiveModesNotifier, ActiveModesState>((ref) {
  return ActiveModesNotifier(ref);
});

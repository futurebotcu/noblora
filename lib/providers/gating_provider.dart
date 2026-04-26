import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/mock_mode.dart';
import '../data/models/gating_status.dart';
import '../data/repositories/gating_repository.dart';
import 'auth_provider.dart';
import 'supabase_client_provider.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class GatingState {
  final GatingStatus? status;
  final bool isLoading;
  final String? error;

  const GatingState({
    this.status,
    this.isLoading = false,
    this.error,
  });

  bool get isVerified => status?.isVerified ?? false;
  bool get isEntryApproved => status?.isEntryApproved ?? false;

  GatingState copyWith({
    GatingStatus? status,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return GatingState(
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class GatingNotifier extends StateNotifier<GatingState> {
  final GatingRepository _repo;
  final Ref _ref;
  StreamSubscription<GatingStatus>? _sub;

  GatingNotifier(this._repo, this._ref) : super(const GatingState());

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> loadStatus() async {
    final userId = _ref.read(authProvider).userId;
    if (userId == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // Initial fetch (awaitable — used by AppRouter bootstrap)
      final status = await _repo.fetchStatus(userId);
      state = state.copyWith(status: status, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return; // Don't subscribe if initial fetch failed
    }

    // Live subscription — admin flips is_entry_approved → state updates
    // → AppRouter rebuilds automatically → user lands on main screen
    _sub?.cancel();
    _sub = _repo.watchStatus(userId).listen((status) {
      if (mounted) state = state.copyWith(status: status);
    });
  }

  Future<void> markVerified(String userId) async {
    if (isMockMode) {
      state = state.copyWith(
        status: const GatingStatus(isVerified: true, isEntryApproved: true),
      );
      return;
    }
    try {
      await _repo.markVerified(userId);
      // Update local state immediately — don't rely solely on realtime
      state = state.copyWith(
        status: GatingStatus(
          isVerified: true,
          isEntryApproved: true,
          verificationMessage: state.status?.verificationMessage,
          entryMessage: state.status?.entryMessage,
        ),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void clear() {
    _sub?.cancel();
    _sub = null;
    state = const GatingState();
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final gatingRepositoryProvider = Provider<GatingRepository>((ref) {
  if (isMockMode) return GatingRepository();
  return GatingRepository(supabase: ref.watch(supabaseClientProvider));
});

final gatingProvider =
    StateNotifierProvider<GatingNotifier, GatingState>((ref) {
  final repo = ref.watch(gatingRepositoryProvider);
  return GatingNotifier(repo, ref);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/mock_mode.dart';
import '../data/models/match.dart';
import '../data/repositories/match_repository.dart';
import '../data/repositories/swipe_repository.dart';
import 'auth_provider.dart';

// ---------------------------------------------------------------------------
// Repositories
// ---------------------------------------------------------------------------

final matchRepositoryProvider = Provider<MatchRepository>((ref) {
  if (isMockMode) return MatchRepository();
  return MatchRepository(supabase: Supabase.instance.client);
});

final swipeRepositoryProvider = Provider<SwipeRepository>((ref) {
  if (isMockMode) return SwipeRepository();
  return SwipeRepository(supabase: Supabase.instance.client);
});

// ---------------------------------------------------------------------------
// Match list state
// ---------------------------------------------------------------------------

class MatchListState {
  final List<NobleMatch> matches;
  final bool isLoading;
  final String? error;
  final NobleMatch? newMatch; // set when a fresh match is detected

  const MatchListState({
    this.matches = const [],
    this.isLoading = false,
    this.error,
    this.newMatch,
  });

  MatchListState copyWith({
    List<NobleMatch>? matches,
    bool? isLoading,
    String? error,
    bool clearError = false,
    NobleMatch? newMatch,
    bool clearNewMatch = false,
  }) {
    return MatchListState(
      matches: matches ?? this.matches,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      newMatch: clearNewMatch ? null : (newMatch ?? this.newMatch),
    );
  }
}

class MatchNotifier extends StateNotifier<MatchListState> {
  final MatchRepository _repo;
  final SwipeRepository _swipeRepo;
  final Ref _ref;

  MatchNotifier(this._repo, this._swipeRepo, this._ref)
      : super(const MatchListState()) {
    load();
  }

  Future<void> load() async {
    final userId = _ref.read(authProvider).userId;
    if (userId == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final matches = await _repo.fetchMatches(userId);
      state = state.copyWith(matches: matches, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Called after a swipe-right — returns a new match if mutual
  Future<NobleMatch?> swipe({
    required String targetId,
    required String direction,
    required String mode,
  }) async {
    final userId = _ref.read(authProvider).userId;
    if (userId == null) return null;
    try {
      final match = await _swipeRepo.swipe(
        swiperId: userId,
        targetId: targetId,
        direction: direction,
        mode: mode,
      );
      if (match != null) {
        state = state.copyWith(
          matches: [match, ...state.matches],
          newMatch: match,
        );
      }
      return match;
    } catch (e) {
      return null;
    }
  }

  void clearNewMatch() {
    state = state.copyWith(clearNewMatch: true);
  }

  void updateMatch(NobleMatch updated) {
    state = state.copyWith(
      matches: state.matches.map((m) => m.id == updated.id ? updated : m).toList(),
    );
  }
}

final matchProvider =
    StateNotifierProvider<MatchNotifier, MatchListState>((ref) {
  final repo = ref.watch(matchRepositoryProvider);
  final swipeRepo = ref.watch(swipeRepositoryProvider);
  return MatchNotifier(repo, swipeRepo, ref);
});

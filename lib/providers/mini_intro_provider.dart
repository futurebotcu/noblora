import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/mock_mode.dart';
import '../data/models/mini_intro.dart';
import '../data/repositories/mini_intro_repository.dart';
import 'supabase_client_provider.dart';

final miniIntroRepositoryProvider = Provider<MiniIntroRepository>((ref) {
  if (isMockMode) return MiniIntroRepository();
  return MiniIntroRepository(supabase: ref.watch(supabaseClientProvider));
});

class MiniIntroState {
  final List<MiniIntro> intros;
  final bool isLoading;
  final String? error;

  const MiniIntroState({
    this.intros = const [],
    this.isLoading = false,
    this.error,
  });

  MiniIntro? introBy(String userId) =>
      intros.where((i) => i.senderId == userId).firstOrNull;

  bool hasBothIntros(String user1Id, String user2Id) =>
      intros.any((i) => i.senderId == user1Id) &&
      intros.any((i) => i.senderId == user2Id);
}

class MiniIntroNotifier extends StateNotifier<MiniIntroState> {
  final MiniIntroRepository _repo;
  StreamSubscription<List<MiniIntro>>? _sub;

  MiniIntroNotifier(this._repo) : super(const MiniIntroState());

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> loadForMatch(String matchId) async {
    state = const MiniIntroState(isLoading: true);
    try {
      final intros = await _repo.fetchForMatch(matchId);
      state = MiniIntroState(intros: intros);
    } catch (e) {
      state = MiniIntroState(error: e.toString());
    }

    _sub?.cancel();
    _sub = _repo.watchForMatch(matchId).listen(
      (intros) {
        if (mounted) state = MiniIntroState(intros: intros);
      },
      onError: (Object e) {
        // Realtime stream error — keep initial fetch data visible.
        debugPrint('[mini_intro] realtime stream error: $e');
      },
    );
  }

  Future<MiniIntro?> sendIntro({
    required String matchId,
    required String senderId,
    required String message,
  }) async {
    try {
      final intro = await _repo.sendIntro(
        matchId: matchId,
        senderId: senderId,
        message: message,
      );
      state = MiniIntroState(intros: [...state.intros, intro]);
      return intro;
    } catch (e) {
      state = MiniIntroState(intros: state.intros, error: e.toString());
      return null;
    }
  }

  /// Advance match to pending_video status (after intro sent).
  Future<void> advanceToVideo(String matchId, String userId) async {
    await _repo.advanceToVideo(matchId, userId);
  }
}

final miniIntroProvider =
    StateNotifierProvider.family<MiniIntroNotifier, MiniIntroState, String>(
  (ref, matchId) {
    final repo = ref.watch(miniIntroRepositoryProvider);
    final notifier = MiniIntroNotifier(repo);
    notifier.loadForMatch(matchId);
    return notifier;
  },
);

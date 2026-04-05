import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/mock_mode.dart';
import '../data/models/video_session.dart';
import '../data/repositories/video_session_repository.dart';

final videoSessionRepositoryProvider = Provider<VideoSessionRepository>((ref) {
  if (isMockMode) return VideoSessionRepository();
  return VideoSessionRepository(supabase: Supabase.instance.client);
});

// ---------------------------------------------------------------------------
// Video session state
// ---------------------------------------------------------------------------

class VideoSessionState {
  final VideoSession? session;
  final bool isLoading;
  final bool isCallActive;
  final Duration? callTimeRemaining;
  final String? decisionResult; // 'chat_opened' | 'expired' | 'waiting'
  final String? error;

  const VideoSessionState({
    this.session,
    this.isLoading = false,
    this.isCallActive = false,
    this.callTimeRemaining,
    this.decisionResult,
    this.error,
  });

  VideoSessionState copyWith({
    VideoSession? session,
    bool? isLoading,
    bool? isCallActive,
    Duration? callTimeRemaining,
    String? decisionResult,
    String? error,
    bool clearError = false,
  }) {
    return VideoSessionState(
      session: session ?? this.session,
      isLoading: isLoading ?? this.isLoading,
      isCallActive: isCallActive ?? this.isCallActive,
      callTimeRemaining: callTimeRemaining ?? this.callTimeRemaining,
      decisionResult: decisionResult ?? this.decisionResult,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class VideoSessionNotifier extends StateNotifier<VideoSessionState> {
  final VideoSessionRepository _repo;
  Timer? _callTimer;
  StreamSubscription<VideoSession?>? _realtimeSub;

  VideoSessionNotifier(this._repo) : super(const VideoSessionState());

  @override
  void dispose() {
    _callTimer?.cancel();
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<void> loadForMatch(String matchId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final session = await _repo.fetchForMatch(matchId);
      state = state.copyWith(session: session, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return;
    }
    // Live subscription — karşı öneri veya onay anında görünsün
    _realtimeSub?.cancel();
    _realtimeSub = _repo.watchForMatch(matchId).listen(
      (session) {
        if (mounted) state = state.copyWith(session: session);
      },
      onError: (Object e) {
        // Realtime stream error — keep initial fetch data visible.
        debugPrint('[video] realtime stream error: $e');
      },
    );
  }

  Future<VideoSession?> proposeTime({
    required String matchId,
    required String proposedBy,
    required String recipientId,
    required DateTime scheduledAt,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final session = await _repo.proposeTime(
        matchId: matchId,
        proposedBy: proposedBy,
        recipientId: recipientId,
        scheduledAt: scheduledAt,
      );
      state = state.copyWith(session: session, isLoading: false);
      return session;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<void> decline({
    required String sessionId,
    required String responderId,
    required String reason,
    DateTime? counterTime,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final session = await _repo.decline(
        sessionId: sessionId,
        responderId: responderId,
        reason: reason,
        counterTime: counterTime,
      );
      state = state.copyWith(session: session, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> respond({
    required String sessionId,
    required String responderId,
    required bool accepted,
    DateTime? counterTime,
    String? proposerUserId,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final session = await _repo.respond(
        sessionId: sessionId,
        responderId: responderId,
        accepted: accepted,
        counterTime: counterTime,
        proposerUserId: proposerUserId,
      );
      state = state.copyWith(session: session, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Start the Short Intro call timer (3-5 min based on session setting)
  void startCallTimer(String sessionId) {
    _callTimer?.cancel();
    final minutes = state.session?.callDurationMinutes ?? 4;
    final duration = Duration(minutes: minutes);
    final totalSeconds = minutes * 60;
    var elapsed = 0;
    state = state.copyWith(
      isCallActive: true,
      callTimeRemaining: duration,
    );

    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      elapsed++;
      final current = state.callTimeRemaining ?? duration;
      final next = current - const Duration(seconds: 1);
      if (next.inSeconds <= 0) {
        timer.cancel();
        _repo.markCompleted(sessionId, elapsed.clamp(0, totalSeconds));
        state = state.copyWith(
          isCallActive: false,
          callTimeRemaining: Duration.zero,
        );
      } else {
        state = state.copyWith(callTimeRemaining: next);
      }
    });
  }

  void stopCallTimer() {
    _callTimer?.cancel();
    state = state.copyWith(isCallActive: false);
  }

  Future<void> markStarted(String sessionId) async {
    await _repo.markStarted(sessionId);
  }

  Future<String> submitDecision({
    required String userId,
    required bool enjoyed,
  }) async {
    final session = state.session;
    if (session == null) return 'waiting';
    try {
      final result = await _repo.submitDecision(
        sessionId: session.id,
        userId: userId,
        enjoyed: enjoyed,
      );
      state = state.copyWith(decisionResult: result);
      return result;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return 'waiting';
    }
  }

  Future<String> finalizeDecision({
    required String userId,
    required bool enjoyed,
  }) async {
    final session = state.session;
    if (session == null) return 'waiting';
    try {
      final result = await _repo.finalizeDecision(
        sessionId: session.id,
        userId: userId,
        enjoyed: enjoyed,
      );
      state = state.copyWith(decisionResult: result);
      return result;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return 'waiting';
    }
  }
}

final videoProvider =
    StateNotifierProvider.family<VideoSessionNotifier, VideoSessionState, String>(
  (ref, matchId) {
    final repo = ref.watch(videoSessionRepositoryProvider);
    final notifier = VideoSessionNotifier(repo);
    notifier.loadForMatch(matchId);
    return notifier;
  },
);

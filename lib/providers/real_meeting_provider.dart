import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/mock_mode.dart';
import '../data/models/real_meeting.dart';
import '../data/repositories/real_meeting_repository.dart';

final realMeetingRepositoryProvider = Provider<RealMeetingRepository>((ref) {
  if (isMockMode) return RealMeetingRepository();
  return RealMeetingRepository(supabase: Supabase.instance.client);
});

class RealMeetingState {
  final RealMeeting? meeting;
  final bool isLoading;
  final String? error;

  const RealMeetingState({
    this.meeting,
    this.isLoading = false,
    this.error,
  });

  RealMeetingState copyWith({
    RealMeeting? meeting,
    bool? isLoading,
    String? error,
    bool clearMeeting = false,
    bool clearError = false,
  }) {
    return RealMeetingState(
      meeting: clearMeeting ? null : (meeting ?? this.meeting),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class RealMeetingNotifier extends StateNotifier<RealMeetingState> {
  final RealMeetingRepository _repo;
  StreamSubscription<RealMeeting?>? _sub;

  RealMeetingNotifier(this._repo) : super(const RealMeetingState());

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> loadForMatch(String matchId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final meeting = await _repo.fetchForMatch(matchId);
      state = state.copyWith(meeting: meeting, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return;
    }
    _sub?.cancel();
    _sub = _repo.watchForMatch(matchId).listen((meeting) {
      if (mounted) state = state.copyWith(meeting: meeting);
    });
  }

  Future<bool> propose({
    required String matchId,
    required String proposedBy,
    required DateTime scheduledAt,
    required String locationText,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final meeting = await _repo.propose(
        matchId: matchId,
        proposedBy: proposedBy,
        scheduledAt: scheduledAt,
        locationText: locationText,
      );
      state = state.copyWith(meeting: meeting, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> confirm(String meetingId, String userId) async {
    state = state.copyWith(isLoading: true);
    try {
      final meeting = await _repo.respond(
          meetingId: meetingId, responderId: userId, accepted: true);
      state = state.copyWith(meeting: meeting, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> decline(String meetingId, String userId) async {
    state = state.copyWith(isLoading: true);
    try {
      final meeting = await _repo.respond(
          meetingId: meetingId, responderId: userId, accepted: false);
      state = state.copyWith(meeting: meeting, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> cancel(String meetingId) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repo.cancel(meetingId);
      state = state.copyWith(isLoading: false, clearMeeting: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final realMeetingProvider = StateNotifierProvider.family<
    RealMeetingNotifier, RealMeetingState, String>(
  (ref, matchId) {
    final repo = ref.watch(realMeetingRepositoryProvider);
    final notifier = RealMeetingNotifier(repo);
    notifier.loadForMatch(matchId);
    return notifier;
  },
);

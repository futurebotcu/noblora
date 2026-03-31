import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/mock_mode.dart';
import '../data/repositories/check_in_repository.dart';

final checkInRepositoryProvider = Provider<CheckInRepository>((ref) {
  if (isMockMode) return CheckInRepository();
  return CheckInRepository(supabase: Supabase.instance.client);
});

class CheckInState {
  final bool isLoading;
  final bool isSubmitted;
  final String? error;

  const CheckInState({
    this.isLoading = false,
    this.isSubmitted = false,
    this.error,
  });
}

class CheckInNotifier extends StateNotifier<CheckInState> {
  final CheckInRepository _repo;

  CheckInNotifier(this._repo) : super(const CheckInState());

  Future<void> submitCheckIn({
    required String meetingId,
    required String userId,
    required String response,
  }) async {
    state = const CheckInState(isLoading: true);
    try {
      await _repo.submitCheckIn(
        meetingId: meetingId,
        userId: userId,
        response: response,
      );
      state = const CheckInState(isSubmitted: true);
    } catch (e) {
      state = CheckInState(error: e.toString());
    }
  }
}

final checkInProvider =
    StateNotifierProvider.family<CheckInNotifier, CheckInState, String>(
  (ref, meetingId) {
    final repo = ref.watch(checkInRepositoryProvider);
    return CheckInNotifier(repo);
  },
);

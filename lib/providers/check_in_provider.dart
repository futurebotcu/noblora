import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/mock_mode.dart';
import '../data/repositories/check_in_repository.dart';
import 'supabase_client_provider.dart';

final checkInRepositoryProvider = Provider<CheckInRepository>((ref) {
  if (isMockMode) return CheckInRepository();
  return CheckInRepository(supabase: ref.watch(supabaseClientProvider));
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

/// Provider that checks for pending check-ins (meetings >2h ago without check-in).
/// autoDispose.family so each userId's cache is freed when no listener remains.
final pendingCheckInsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, userId) async {
  if (isMockMode) return [];
  final repo = ref.read(checkInRepositoryProvider);
  return repo.fetchPendingCheckIns(userId);
});

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

/// autoDispose.family so per-meeting check-in state is freed when its dialog closes.
final checkInProvider = StateNotifierProvider.autoDispose
    .family<CheckInNotifier, CheckInState, String>(
  (ref, meetingId) {
    final repo = ref.watch(checkInRepositoryProvider);
    return CheckInNotifier(repo);
  },
);

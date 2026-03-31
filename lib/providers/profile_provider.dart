import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/mock_mode.dart';
import '../data/models/profile.dart';
import '../data/repositories/profile_repository.dart';
import 'auth_provider.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class ProfileState {
  final Profile? profile;
  final bool isLoading;
  final String? error;

  const ProfileState({
    this.profile,
    this.isLoading = false,
    this.error,
  });

  /// True when a profiles row exists AND display_name is set.
  /// A row with empty display_name still routes to onboarding.
  bool get hasProfile =>
      profile != null && profile!.displayName.trim().isNotEmpty;

  /// True when the user has declared a gender — required before verification.
  bool get hasGender =>
      profile?.gender != null && profile!.gender!.isNotEmpty;

  ProfileState copyWith({
    Profile? profile,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class ProfileNotifier extends StateNotifier<ProfileState> {
  final ProfileRepository _repo;
  final Ref _ref;

  ProfileNotifier(this._repo, this._ref) : super(const ProfileState());

  Future<void> loadProfile() async {
    final userId = _ref.read(authProvider).userId;
    if (userId == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final profile = await _repo.fetchProfile(userId);
      state = state.copyWith(profile: profile, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Creates a profiles row with full_name (and optional current_mode).
  Future<void> createProfile({
    required String fullName,
    String? currentMode,
  }) async {
    final userId = _ref.read(authProvider).userId;
    if (userId == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final profile = await _repo.createProfile(
        userId: userId,
        fullName: fullName,
        currentMode: currentMode,
      );
      state = state.copyWith(profile: profile, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Persists gender to the profiles row, then updates local state.
  /// AppRouter will automatically advance to VerificationHubScreen once
  /// profileState.hasGender becomes true.
  Future<void> updateGender(String gender) async {
    final userId = _ref.read(authProvider).userId;
    if (userId == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _repo.updateProfile(
          userId, {'gender': gender, 'is_onboarded': true});
      state = state.copyWith(profile: updated, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clear() {
    state = const ProfileState();
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  if (isMockMode) return ProfileRepository();
  return ProfileRepository(supabase: Supabase.instance.client);
});

final profileProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  final repo = ref.watch(profileRepositoryProvider);
  return ProfileNotifier(repo, ref);
});

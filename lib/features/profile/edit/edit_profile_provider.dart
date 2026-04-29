import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/mock_mode.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/interaction_gate_provider.dart';
import '../../../providers/profile_provider.dart';
import 'profile_draft.dart';

class EditProfileState {
  final ProfileDraft draft;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  const EditProfileState({
    required this.draft,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  EditProfileState copyWith({ProfileDraft? draft, bool? isLoading, bool? isSaving, String? error, bool clearError = false}) {
    return EditProfileState(
      draft: draft ?? this.draft,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class EditProfileNotifier extends StateNotifier<EditProfileState> {
  final Ref _ref;

  EditProfileNotifier(this._ref) : super(EditProfileState(draft: ProfileDraft())) {
    _load();
  }

  Future<void> _load() async {
    if (isMockMode) return;
    final uid = _ref.read(authProvider).userId;
    if (uid == null) return;
    state = state.copyWith(isLoading: true);
    try {
      final row = await _ref
          .read(profileRepositoryProvider)
          .fetchProfileDraftRow(uid);
      if (row != null) {
        state = state.copyWith(draft: ProfileDraft.fromDbRow(row), isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void updateDraft(ProfileDraft Function(ProfileDraft d) updater) {
    state = state.copyWith(draft: updater(state.draft));
  }

  Future<bool> save() async {
    if (isMockMode) return true;
    final uid = _ref.read(authProvider).userId;
    if (uid == null) return false;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _ref.read(profileRepositoryProvider).updateProfile(
        uid,
        state.draft.toUpdateMap(),
      );
      // Reload the main profile provider and interaction gate to sync
      await _ref.read(profileProvider.notifier).loadProfile();
      _ref.invalidate(interactionGateProvider);
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }

  Future<void> reload() => _load();
}

final editProfileProvider = StateNotifierProvider.autoDispose<EditProfileNotifier, EditProfileState>((ref) {
  return EditProfileNotifier(ref);
});

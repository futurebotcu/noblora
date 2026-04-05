import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/mock_mode.dart';
import '../data/models/photo_verification.dart';
import '../data/repositories/verification_repository.dart';
import 'auth_provider.dart';
import 'profile_provider.dart';

// ---------------------------------------------------------------------------
// Status enum — single source of truth for what the UI should render
// ---------------------------------------------------------------------------

enum VerificationStatus {
  idle,         // no submission yet, or after a rejected retry reset
  loading,      // edge function in flight
  approved,     // both selfie + profile accepted
  manualReview, // submitted, awaiting human review
  rejected,     // AI determined photos are invalid; user may retry
  error,        // unexpected exception (network, etc.)
}

// ---------------------------------------------------------------------------

final verificationRepositoryProvider = Provider<VerificationRepository>((ref) {
  if (isMockMode) return VerificationRepository();
  return VerificationRepository(supabase: Supabase.instance.client);
});

class VerificationState {
  final List<PhotoVerification> verifications;
  final bool isLoading;
  final String? error;
  final PhotoVerification? lastResult;

  // Staged bytes — held locally until the user taps "Verify Both Photos"
  final Uint8List? pendingSelfieBytes;
  final Uint8List? pendingProfileBytes;

  const VerificationState({
    this.verifications = const [],
    this.isLoading = false,
    this.error,
    this.lastResult,
    this.pendingSelfieBytes,
    this.pendingProfileBytes,
  });

  // ── Derived booleans ───────────────────────────────────────────────────────

  // Latest selfie / profile records (list is sorted descending by created_at).
  PhotoVerification? get _latestSelfie =>
      verifications.where((v) => v.photoType == 'selfie').firstOrNull;

  PhotoVerification? get _latestProfile =>
      verifications.where((v) => v.photoType == 'profile').firstOrNull;

  bool get selfieApproved => _latestSelfie?.isApproved ?? false;

  bool get hasApprovedPhoto => _latestProfile?.isApproved ?? false;

  bool get bothStaged =>
      pendingSelfieBytes != null && pendingProfileBytes != null;

  // ── Computed status ────────────────────────────────────────────────────────
  //
  // Ground truth: the single most-recent photo_verifications row.
  // Historical records are ignored — only the latest submission's status counts.
  //
  //  no rows        → idle          (never submitted → upload screen)
  //  approved       → approved      (fall through to entry gate / main app)
  //  pending /
  //  manual_review  → manualReview  (under-review screen)
  //  rejected       → rejected      (upload screen with retry banner)

  VerificationStatus get verificationStatus {
    if (isLoading) return VerificationStatus.loading;
    if (error != null) return VerificationStatus.error;

    // No records in DB → user has never submitted → show upload screen.
    if (verifications.isEmpty) return VerificationStatus.idle;

    // Use the most-recent record as the authoritative status.
    final latest = verifications.first;
    if (latest.isApproved) return VerificationStatus.approved;
    if (latest.isPending || latest.isManualReview) {
      return VerificationStatus.manualReview;
    }
    if (latest.isRejected) return VerificationStatus.rejected;
    return VerificationStatus.idle;
  }

  // ── copyWith ───────────────────────────────────────────────────────────────

  VerificationState copyWith({
    List<PhotoVerification>? verifications,
    bool? isLoading,
    String? error,
    bool clearError = false,
    PhotoVerification? lastResult,
    bool clearLastResult = false,
    Uint8List? pendingSelfieBytes,
    bool clearSelfie = false,
    Uint8List? pendingProfileBytes,
    bool clearProfile = false,
  }) {
    return VerificationState(
      verifications: verifications ?? this.verifications,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      lastResult:
          clearLastResult ? null : (lastResult ?? this.lastResult),
      pendingSelfieBytes:
          clearSelfie ? null : (pendingSelfieBytes ?? this.pendingSelfieBytes),
      pendingProfileBytes: clearProfile
          ? null
          : (pendingProfileBytes ?? this.pendingProfileBytes),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class VerificationNotifier extends StateNotifier<VerificationState> {
  final VerificationRepository _repo;
  final Ref _ref;
  StreamSubscription<List<PhotoVerification>>? _sub;

  VerificationNotifier(this._repo, this._ref)
      : super(const VerificationState());

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    if (state.isLoading) return; // prevent concurrent double-load
    final userId = _ref.read(authProvider).userId;
    if (userId == null) return;
    state = state.copyWith(isLoading: true);
    try {
      // Initial fetch (awaitable — used by AppRouter bootstrap)
      final verifs = await _repo.fetchVerifications(userId);
      state = state.copyWith(verifications: verifs, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return; // Don't subscribe if initial fetch failed
    }

    // Live subscription — admin updates a manual_review record to approved
    // → state updates → AppRouter rebuilds → user lands on entry_gate / main
    _sub?.cancel();
    _sub = _repo.watchVerifications(userId).listen(
      (verifs) {
        if (mounted) state = state.copyWith(verifications: verifs);
      },
      onError: (Object e) {
        // Realtime subscription failed (timeout, publication missing, etc.) —
        // initial data is already loaded. Keep showing it; just lose live updates.
        debugPrint('[verification] realtime stream error: $e');
      },
    );
  }

  void clear() {
    _sub?.cancel();
    _sub = null;
    state = const VerificationState();
  }

  /// Stage an image locally — no network call yet.
  void stageImage({required Uint8List bytes, required String photoType}) {
    if (photoType == 'selfie') {
      state = state.copyWith(pendingSelfieBytes: bytes, clearError: true);
    } else {
      state = state.copyWith(pendingProfileBytes: bytes, clearError: true);
    }
  }

  /// Submit both staged images to the Supabase Edge Function for AI verification.
  Future<void> verifyBoth() async {
    final selfie = state.pendingSelfieBytes;
    final profile = state.pendingProfileBytes;
    if (selfie == null || profile == null) return;

    final userId = _ref.read(authProvider).userId;
    if (userId == null) return;

    // Read claimed gender from profile — sent to DB as claimed_gender
    final claimedGender =
        _ref.read(profileProvider).profile?.gender ?? 'other';

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await _repo.verifyBothPhotos(
        userId: userId,
        selfieBytes: selfie,
        profileBytes: profile,
        profileGender: claimedGender,
      );

      // Selfie result carries same_person + probability — use it as the banner
      final selfieResult = results.firstWhere(
        (r) => r.photoType == 'selfie',
        orElse: () => results.first,
      );

      state = state.copyWith(
        verifications: [...results, ...state.verifications],
        isLoading: false,
        lastResult: selfieResult,
        clearSelfie: true,
        clearProfile: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Reset staged images so the user can pick new photos after a rejection.
  void clearStaged() {
    state = state.copyWith(
      clearSelfie: true,
      clearProfile: true,
      clearError: true,
      clearLastResult: true,
    );
  }
}

final verificationProvider =
    StateNotifierProvider<VerificationNotifier, VerificationState>((ref) {
  final repo = ref.watch(verificationRepositoryProvider);
  return VerificationNotifier(repo, ref);
});

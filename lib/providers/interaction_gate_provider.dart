import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_tokens.dart';
import '../core/services/toast_service.dart';
import '../core/utils/mock_mode.dart';
import 'auth_provider.dart';
import 'profile_provider.dart';

// kSocialEnabled controls whether Social actions can ever be permitted.

/// Interaction gating state — determines what user can do per mode
class InteractionGate {
  final int photoCount;
  final bool verifiedPhoto;

  const InteractionGate({this.photoCount = 0, this.verifiedPhoto = false});

  /// Permissive default while provider is loading. Real values apply once resolved.
  static const loading = InteractionGate(photoCount: 1, verifiedPhoto: false);

  bool get hasPhoto => photoCount > 0;

  // Dating: needs at least 1 photo. R18 — `canBffInteract` removed.
  bool get canDateInteract => hasPhoto;

  // Social: photo to join, verified to create (always false when layer disabled)
  bool get canSocialJoin => kSocialEnabled && hasPhoto;
  bool get canSocialCreate => kSocialEnabled && verifiedPhoto;

  // Nob feed: Noblara is the open expression layer — no photo gate here.
  // (M0: tier-based posting rights retired. Limits, if any, will be
  // re-introduced as plan_level-aware caps in M4.)
  bool get canPostNob => true;
  bool get canReactNob => true;

  bool canInteract(String mode) => switch (mode) {
    'date' => canDateInteract,
    // R18 — `'bff' => canBffInteract` removed.
    'social' => canSocialJoin,
    _ => false,
  };
}

/// Provider that loads gating state from real profile data
final interactionGateProvider = FutureProvider<InteractionGate>((ref) async {
  if (isMockMode) return const InteractionGate(photoCount: 5, verifiedPhoto: true);
  final uid = ref.watch(authProvider).userId;
  if (uid == null) return const InteractionGate();
  try {
    final gate =
        await ref.read(profileRepositoryProvider).fetchInteractionGate(uid);
    if (gate == null) return const InteractionGate();

    // M0: Noble tier bypass removed. Everyone goes through the same photo
    // gate regardless of nob_tier (kept on the model only for legacy data).

    return InteractionGate(
      photoCount: gate.photoCount,
      verifiedPhoto: gate.verifiedPhoto,
    );
  } catch (e) {
    debugPrint('[gate] row fetch failed: $e');
    return const InteractionGate();
  }
});

/// Show the gating popup when an action is blocked because the user
/// hasn't added a photo yet.
///
/// V1 history (2026-05-13):
///   - Repainted from dark + gold to light + burgundy so it matches the
///     rest of the rebrand. The prior visual (`#111113` near-black bg,
///     gold text + gold button) was the most visible PR1 miss — users
///     described it as "the old design popup".
///   - The `verifyPhoto` variant was removed: the M0 verification
///     lockdown closed the upgrade flow, no caller passes that type,
///     and surfacing a "Get Verified" CTA that routes to a disabled
///     flow would re-introduce the same misleading UX the M0 sprint
///     containmen't. If verification re-opens, add a new explicit
///     surface; do not re-add this branch.
///   - Replaced inline `ScaffoldMessenger.showSnackBar` with
///     `ToastService.show` so the follow-up confirmation matches the
///     rest of the app's toast styling.
void showGatingPopup(BuildContext context, String title, String message) {
  showModalBottomSheet(
    context: context,
    backgroundColor: context.surfaceColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetCtx) => Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.burgundy600.withValues(alpha: 0.08),
              border: Border.all(
                  color: AppColors.burgundy600.withValues(alpha: 0.20)),
            ),
            child: const Icon(Icons.add_a_photo_outlined,
                color: AppColors.burgundy600, size: 28),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.textMuted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.burgundy600,
                foregroundColor: AppColors.textOnEmerald,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
              ),
              onPressed: () {
                Navigator.pop(sheetCtx);
                if (!context.mounted) return;
                ToastService.show(
                  context,
                  message: 'Go to Profile tab to add or update your photo.',
                  type: ToastType.system,
                );
              },
              child: const Text('Add Photo',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, letterSpacing: 0.3)),
            ),
          ),
        ],
      ),
    ),
  );
}

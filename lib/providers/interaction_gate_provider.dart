import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
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

  // Dating & BFF: need at least 1 photo
  bool get canDateInteract => hasPhoto;
  bool get canBffInteract => hasPhoto;

  // Social: photo to join, verified to create (always false when layer disabled)
  bool get canSocialJoin => kSocialEnabled && hasPhoto;
  bool get canSocialCreate => kSocialEnabled && verifiedPhoto;

  // Nob feed: Noblara is the open expression layer — no photo gate here.
  // Tier (observer/explorer/noble) decides posting rights in the UI; the
  // backend rate-limits via check_nob_limit() tier + daily/weekly counters.
  bool get canPostNob => true;
  bool get canReactNob => true;

  bool canInteract(String mode) => switch (mode) {
    'date' => canDateInteract,
    'bff' => canBffInteract,
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

    // Noble tier users get full access — never blocked by gating
    if (gate.nobTier == 'noble') {
      return const InteractionGate(photoCount: 5, verifiedPhoto: true);
    }

    return InteractionGate(
      photoCount: gate.photoCount,
      verifiedPhoto: gate.verifiedPhoto,
    );
  } catch (e) {
    debugPrint('[gate] row fetch failed: $e');
    return const InteractionGate();
  }
});

/// Gating popup types
enum GatePopupType { addPhoto, verifyPhoto }

/// Show gating popup when action is blocked
void showGatingPopup(BuildContext context, String title, String message, {GatePopupType type = GatePopupType.addPhoto}) {
  final buttonLabel = type == GatePopupType.verifyPhoto ? 'Get Verified' : 'Add Photo';
  final icon = type == GatePopupType.verifyPhoto ? Icons.verified_outlined : Icons.add_a_photo_outlined;

  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF111113),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 3, decoration: BoxDecoration(
              color: const Color(0xFF222225), borderRadius: BorderRadius.circular(999))),
          const SizedBox(height: 32),
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gold.withValues(alpha: 0.06),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.15)),
            ),
            child: Icon(icon, color: AppColors.gold, size: 28),
          ),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(color: Color(0xFFF2F2F2), fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.gold, fontSize: 14, height: 1.5)),
          const SizedBox(height: 28),
          SizedBox(width: double.infinity, child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: const Color(0xFF080808),
                  minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Go to Profile tab to add or update your photo.')),
                );
              },
              child: Text(buttonLabel, style: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.3)))),
        ],
      ),
    ),
  );
}

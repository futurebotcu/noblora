import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/services/toast_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_tokens.dart';
import '../core/theme/premium.dart';
import '../core/utils/mock_mode.dart';
import 'auth_provider.dart';

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
    final row = await Supabase.instance.client.from('profiles')
        .select('photo_count, verified_profile_photo, nob_tier')
        .eq('id', uid).maybeSingle();
    if (row == null) return const InteractionGate();

    final tier = row['nob_tier'] as String?;
    final photoCount = (row['photo_count'] as int?) ?? 0;
    final verified = (row['verified_profile_photo'] as bool?) ?? false;

    // Noble tier users get full access — never blocked by gating
    if (tier == 'noble') {
      return const InteractionGate(photoCount: 5, verifiedPhoto: true);
    }

    return InteractionGate(
      photoCount: photoCount,
      verifiedPhoto: verified,
    );
  } catch (_) {
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
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [context.surfaceColor, context.bgColor],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
        border: Border(top: BorderSide(color: AppColors.emerald600.withValues(alpha: 0.1))),
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.md, AppSpacing.xxl, AppSpacing.xxxxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(
              color: AppColors.emerald600.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999))),
          const SizedBox(height: AppSpacing.xxxl),
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [AppColors.emerald600.withValues(alpha: 0.15), AppColors.emerald600.withValues(alpha: 0.05)],
              ),
              border: Border.all(color: AppColors.emerald600.withValues(alpha: 0.2)),
              boxShadow: [BoxShadow(color: AppColors.emerald600.withValues(alpha: 0.1), blurRadius: 24, spreadRadius: 2)],
            ),
            child: Icon(icon, color: AppColors.emerald500, size: 30),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(title, style: TextStyle(color: context.textPrimary, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: AppSpacing.md),
          Text(message, textAlign: TextAlign.center,
              style: TextStyle(color: context.textMuted, fontSize: 14, height: 1.6)),
          const SizedBox(height: AppSpacing.xxxl),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: Premium.emeraldGlow(intensity: 0.5),
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.emerald600, foregroundColor: AppColors.textOnEmerald,
                  minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: () {
                Navigator.pop(context);
                ToastService.show(context, message: 'Head to your Profile to add a photo', type: ToastType.system);
              },
              child: Text(buttonLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.3))),
          ),
        ],
      ),
    ),
  );
}

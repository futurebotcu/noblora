import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/mock_mode.dart';
import 'auth_provider.dart';

/// Interaction gating state — determines what user can do per mode
class InteractionGate {
  final int photoCount;
  final bool verifiedPhoto;

  const InteractionGate({this.photoCount = 0, this.verifiedPhoto = false});

  bool get canDateInteract => photoCount >= 3 && verifiedPhoto;
  bool get canBffInteract => photoCount >= 3 && verifiedPhoto;
  bool get canSocialInteract => verifiedPhoto;

  bool canInteract(String mode) => switch (mode) {
    'date' => canDateInteract,
    'bff' => canBffInteract,
    'social' => canSocialInteract,
    _ => false,
  };

  String blockReason(String mode) {
    if (mode == 'social') {
      if (!verifiedPhoto) return 'Verify your profile photo to join events and conversations.';
      return '';
    }
    // Dating + BFF
    final parts = <String>[];
    if (photoCount < 3) parts.add('add ${3 - photoCount} more photo${photoCount < 2 ? "s" : ""}');
    if (!verifiedPhoto) parts.add('verify your profile photo');
    if (parts.isEmpty) return '';
    return 'To start connecting, ${parts.join(" and ")}.';
  }
}

/// Provider that loads gating state from real profile data
final interactionGateProvider = FutureProvider<InteractionGate>((ref) async {
  if (isMockMode) return const InteractionGate(photoCount: 5, verifiedPhoto: true);
  final uid = ref.watch(authProvider).userId;
  if (uid == null) return const InteractionGate();
  try {
    final row = await Supabase.instance.client.from('profiles')
        .select('photo_count, verified_profile_photo')
        .eq('id', uid).maybeSingle();
    if (row == null) return const InteractionGate();
    return InteractionGate(
      photoCount: (row['photo_count'] as int?) ?? 0,
      verifiedPhoto: (row['verified_profile_photo'] as bool?) ?? false,
    );
  } catch (_) {
    return const InteractionGate();
  }
});

/// Show gating popup when action is blocked
void showGatingPopup(BuildContext context, String reason) {
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
              color: const Color(0xFFCBA135).withValues(alpha: 0.06),
              border: Border.all(color: const Color(0xFFCBA135).withValues(alpha: 0.15)),
            ),
            child: const Icon(Icons.lock_outline_rounded, color: Color(0xFFCBA135), size: 28),
          ),
          const SizedBox(height: 20),
          const Text('Browse mode', style: TextStyle(color: Color(0xFFF2F2F2), fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          const SizedBox(height: 8),
          Text('You can explore for now.', style: TextStyle(color: const Color(0xFFF2F2F2).withValues(alpha: 0.4), fontSize: 14)),
          const SizedBox(height: 20),
          Text(reason, textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFCBA135), fontSize: 14, height: 1.5)),
          const SizedBox(height: 28),
          SizedBox(width: double.infinity, child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCBA135), foregroundColor: const Color(0xFF080808),
                  minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.3)))),
        ],
      ),
    ),
  );
}

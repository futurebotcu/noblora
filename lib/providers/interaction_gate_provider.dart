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
    backgroundColor: const Color(0xFF1A1A1A),
    builder: (_) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(
              color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(999))),
          const SizedBox(height: 24),
          const Icon(Icons.lock_outline_rounded, color: Color(0xFFC9A84C), size: 36),
          const SizedBox(height: 16),
          const Text('Browse mode', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('You can look around for now.', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
          const SizedBox(height: 16),
          Text(reason, textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFC9A84C), fontSize: 14, height: 1.4)),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC9A84C), foregroundColor: const Color(0xFF0D0D0D),
                  minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.w600)))),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

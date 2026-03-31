import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/post.dart';

class TierBadge extends StatelessWidget {
  final NobTier tier;
  final double size;
  final bool showLabel;

  const TierBadge({
    super.key,
    required this.tier,
    this.size = 20,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon, String label) = switch (tier) {
      NobTier.noble => (AppColors.gold, Icons.workspace_premium_rounded, 'Noble'),
      NobTier.explorer => (const Color(0xFF26C6DA), Icons.explore_rounded, 'Explorer'),
      NobTier.observer => (AppColors.textMuted, Icons.visibility_rounded, 'Observer'),
    };

    if (!showLabel) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
        ),
        child: Icon(icon, color: color, size: size * 0.6),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

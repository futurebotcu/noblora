import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';

class ProfileSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double progress;
  final VoidCallback onTap;
  final String? preview; // real data preview chips text
  final bool isEmpty;

  const ProfileSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.onTap,
    this.preview,
    this.isEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasPreview = preview != null && preview!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: progress >= 1.0
                ? AppColors.gold.withValues(alpha: 0.2)
                : context.borderColor.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Warm icon — circle instead of square
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isEmpty
                        ? context.borderColor.withValues(alpha: 0.3)
                        : AppColors.gold.withValues(alpha: 0.10),
                  ),
                  child: Icon(icon,
                    color: isEmpty ? context.textDisabled : AppColors.gold,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      )),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(
                        color: isEmpty ? context.textDisabled : context.textMuted,
                        fontSize: 12,
                        height: 1.3,
                      )),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                  color: context.textMuted.withValues(alpha: 0.5),
                  size: 20,
                ),
              ],
            ),
            // Preview chips — real data
            if (hasPreview) ...[
              const SizedBox(height: 12),
              Text(
                preview!,
                style: TextStyle(
                  color: AppColors.gold.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            // Subtle progress
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 2.5,
                backgroundColor: context.borderColor.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 1.0
                      ? AppColors.gold
                      : AppColors.gold.withValues(alpha: 0.45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

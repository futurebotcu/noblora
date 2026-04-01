import 'package:flutter/material.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';

/// Premium empty state widget — calm, intentional stillness
class PremiumEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? accentColor;
  final Widget? action;

  const PremiumEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.accentColor,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? context.textDisabled;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.04),
                border: Border.all(color: color.withValues(alpha: 0.1)),
              ),
              child: Icon(icon, color: color.withValues(alpha: 0.4), size: 28),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(title,
                style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2),
                textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(subtitle!, textAlign: TextAlign.center,
                  style: TextStyle(color: context.textMuted, fontSize: 13, height: 1.5)),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

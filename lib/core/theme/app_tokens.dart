import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Context-aware theme tokens.
/// Usage: `context.bgColor`, `context.surfaceColor`, `context.textPrimary`, etc.
extension ThemeTokens on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // ── Backgrounds ──
  Color get bgColor => isDark ? AppColors.bg : AppColors.lightBg;
  Color get surfaceColor => isDark ? AppColors.surface : AppColors.lightSurface;
  Color get surfaceAltColor => isDark ? AppColors.surfaceAlt : AppColors.lightSurfaceAlt;
  Color get cardColor => isDark ? AppColors.card : AppColors.lightCard;
  Color get elevatedColor => isDark ? AppColors.elevated : AppColors.lightElevated;

  // ── Borders ──
  Color get borderColor => isDark ? AppColors.border : AppColors.lightBorder;
  Color get borderSubtleColor => isDark ? AppColors.borderSubtle : AppColors.lightBorderSubtle;

  // ── Text ──
  Color get textPrimary => isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
  Color get textSecondary => isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
  Color get textMuted => isDark ? AppColors.textMuted : AppColors.lightTextMuted;
  Color get textDisabled => isDark ? AppColors.textDisabled : AppColors.lightTextDisabled;

  // ── Accent ──
  Color get accent => Theme.of(this).colorScheme.primary;
  Color get accentLight => accent.withValues(alpha: 0.12);

  // ── Overlays ──
  Color get shimmerBase => isDark ? AppColors.surface : AppColors.lightSurfaceAlt;
  Color get shimmerHighlight => isDark ? AppColors.elevated : AppColors.lightSurface;
}

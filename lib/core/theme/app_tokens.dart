import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Context-aware theme tokens.
extension ThemeTokens on BuildContext {
  bool get isDark => true; // Always dark

  // ── SURFACES ──
  Color get bgColor         => AppColors.bg;
  Color get surfaceColor    => AppColors.surface;
  Color get surfaceAltColor => AppColors.surfaceAlt;
  Color get cardColor       => AppColors.card;
  Color get elevatedColor   => AppColors.elevated;

  // ── BORDERS ──
  Color get borderColor       => AppColors.border;
  Color get borderLightColor  => AppColors.borderLight;
  Color get borderSubtleColor => AppColors.borderSubtle;

  // ── TEXT ──
  Color get textPrimary   => AppColors.textPrimary;
  Color get textSecondary => AppColors.textSecondary;
  Color get textMuted     => AppColors.textMuted;
  Color get textDisabled  => AppColors.textDisabled;

  // ── ACCENT ──
  Color get accent      => Theme.of(this).colorScheme.primary;
  Color get accentDim   => Theme.of(this).colorScheme.secondary;
  Color get accentSoft  => accent.withValues(alpha: 0.12);
  Color get accentBorder => accent.withValues(alpha: 0.25);
  Color get accentGlow  => accent.withValues(alpha: 0.16);
  Color get onAccent    => Theme.of(this).colorScheme.onPrimary;
  Color get accentLight => accent.withValues(alpha: 0.14);

  // ── SEMANTIC ──
  Color get success => AppColors.success;
  Color get error   => AppColors.error;
  Color get warning => AppColors.warning;

  // ── OVERLAYS ──
  Color get shimmerBase      => AppColors.surfaceAlt;
  Color get shimmerHighlight => AppColors.elevated;
}

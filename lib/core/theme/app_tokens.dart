import 'package:flutter/material.dart';

/// Context-aware theme tokens.
/// Usage: `context.bgColor`, `context.surfaceColor`, `context.textPrimary`, etc.
extension ThemeTokens on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // ── BASE — never changes with accent ──
  Color get bgColor => isDark ? const Color(0xFF080808) : const Color(0xFFFAF9F6);
  Color get surfaceColor => isDark ? const Color(0xFF111113) : const Color(0xFFFFFFFF);
  Color get surfaceAltColor => isDark ? const Color(0xFF18181B) : const Color(0xFFF5F3EE);
  Color get cardColor => isDark ? const Color(0xFF141416) : const Color(0xFFF5F3EE);
  Color get elevatedColor => isDark ? const Color(0xFF1C1C1F) : const Color(0xFFEFEFEB);

  // ── Borders ──
  Color get borderColor => isDark ? const Color(0xFF222225) : const Color(0xFFE8E4DC);
  Color get borderSubtleColor => isDark ? const Color(0xFF1A1A1D) : const Color(0xFFF0EDE8);

  // ── Text ──
  Color get textPrimary => isDark ? const Color(0xFFF2F2F2) : const Color(0xFF1A1814);
  Color get textSecondary => isDark ? const Color(0xFFD4D4D4) : const Color(0xFF4A4640);
  Color get textMuted => isDark ? const Color(0xFF808080) : const Color(0xFF8C8680);
  Color get textDisabled => isDark ? const Color(0xFF4A4A4A) : const Color(0xFFBEB8AE);

  // ── ACCENT — role based (from theme colorScheme) ──
  Color get accent => Theme.of(this).colorScheme.primary;
  Color get accentDim => Theme.of(this).colorScheme.secondary;
  Color get accentSoft => accent.withValues(alpha: 0.08);
  Color get accentBorder => accent.withValues(alpha: 0.25);
  Color get accentGlow => accent.withValues(alpha: 0.12);
  Color get onAccent => Theme.of(this).colorScheme.onPrimary;
  Color get accentLight => accent.withValues(alpha: 0.12);

  // ── SEMANTIC — always fixed ──
  Color get success => const Color(0xFF3D9970);
  Color get error => const Color(0xFFD64545);
  Color get warning => const Color(0xFFE8A838);

  // ── Overlays ──
  Color get shimmerBase => isDark ? const Color(0xFF111113) : const Color(0xFFF5F3EE);
  Color get shimmerHighlight => isDark ? const Color(0xFF1C1C1F) : const Color(0xFFFFFFFF);
}

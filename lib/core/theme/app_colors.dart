import 'package:flutter/material.dart';

// ─── AccentColor — role-based accent system ─────────────────────────

class AccentColor {
  final String id;
  final String name;
  final Color primary;
  final Color dim;
  final Color onAccent;
  final bool isGold;

  const AccentColor({
    required this.id,
    required this.name,
    required this.primary,
    required this.dim,
    required this.onAccent,
    this.isGold = false,
  });

  Color get soft => primary.withValues(alpha: 0.08);
  Color get border => primary.withValues(alpha: 0.25);
  Color get glow => primary.withValues(alpha: 0.12);
  Color get strong => primary;
}

class AppColors {
  AppColors._();

  // ── Accent Palette ──
  static const List<AccentColor> accents = [
    AccentColor(
      id: 'gold',
      name: 'Gold',
      primary: Color(0xFFE9C349),
      dim: Color(0xFFCBA135),
      onAccent: Color(0xFF2D1F00),
      isGold: true,
    ),
    AccentColor(
      id: 'sapphire',
      name: 'Safir',
      primary: Color(0xFF1A3A6B),
      dim: Color(0xFF152E55),
      onAccent: Color(0xFFE8F0FB),
    ),
    AccentColor(
      id: 'emerald',
      name: 'Zümrüt',
      primary: Color(0xFF1A6B45),
      dim: Color(0xFF155A39),
      onAccent: Color(0xFFE0F5EA),
    ),
    AccentColor(
      id: 'bordeaux',
      name: 'Bordo',
      primary: Color(0xFF6B2D3E),
      dim: Color(0xFF572435),
      onAccent: Color(0xFFFFF0F3),
    ),
    AccentColor(
      id: 'anthracite',
      name: 'Antrasit',
      primary: Color(0xFF3A3A4A),
      dim: Color(0xFF2E2E3C),
      onAccent: Color(0xFFE8E8F0),
    ),
  ];

  static AccentColor accentById(String id) =>
      accents.firstWhere((a) => a.id == id, orElse: () => accents.first);

  // ── Primary Brand (gold default — used where gold is always needed) ──
  static const Color gold = Color(0xFFE9C349);
  static const Color goldLight = Color(0x22E9C349);
  static const Color goldDark = Color(0xFFCBA135);

  // ── Obsidian Surfaces (dark-first) ──
  static const Color bg = Color(0xFF080808);
  static const Color surface = Color(0xFF111113);
  static const Color surfaceAlt = Color(0xFF18181B);
  static const Color card = Color(0xFF141416);
  static const Color elevated = Color(0xFF1C1C1F);

  // ── Text Hierarchy ──
  static const Color textPrimary = Color(0xFFF2F2F2);
  static const Color textSecondary = Color(0xFFD4D4D4);
  static const Color textMuted = Color(0xFF808080);
  static const Color textDisabled = Color(0xFF4A4A4A);

  // ── Semantic ──
  static const Color success = Color(0xFF3D9970);
  static const Color error = Color(0xFFD64545);
  static const Color warning = Color(0xFFE8A838);
  static const Color info = Color(0xFF5B9BD5);

  // ── Swipe Overlays ──
  static const Color selectOverlay = Color(0x553D9970);
  static const Color passOverlay = Color(0x55D64545);

  // ── Borders ──
  static const Color border = Color(0xFF222225);
  static const Color borderGold = Color(0x44E9C349);
  static const Color borderSubtle = Color(0xFF1A1A1D);

  // ── Mode Accents ──
  static const Color teal = Color(0xFF26C6DA);
  static const Color violet = Color(0xFF9B6DFF);

  // ── Light Mode Surfaces ──
  static const Color lightBg = Color(0xFFFAF9F6);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF5F3EE);
  static const Color lightCard = Color(0xFFF5F3EE);
  static const Color lightElevated = Color(0xFFEFEFEB);
  static const Color lightBorder = Color(0xFFE8E4DC);
  static const Color lightBorderSubtle = Color(0xFFF0EDE8);

  // ── Light Mode Text ──
  static const Color lightTextPrimary = Color(0xFF1A1814);
  static const Color lightTextSecondary = Color(0xFF4A4640);
  static const Color lightTextMuted = Color(0xFF8C8680);
  static const Color lightTextDisabled = Color(0xFFBEB8AE);

  // ── Noblara Brand ──
  static const Color noblaraGold = Color(0xFFE9C349);
  static const Color nobBackground = Color(0xFF080808);
  static const Color nobSurface = Color(0xFF111113);
  static const Color nobSurfaceAlt = Color(0xFF18181B);
  static const Color nobBorder = Color(0xFF222225);
  static const Color nobObserver = Color(0xFF666666);
  static const Color nobExplorer = Color(0xFF5B9BD5);
  static const Color nobNoble = Color(0xFFE9C349);
}

import 'package:flutter/material.dart';

// ─── AccentColor — role-based accent system ─────────────────────────

class AccentColor {
  final String id;
  final String name;
  final Color primary;
  final Color dim;
  final Color onAccent;
  final bool isDefault;
  final bool nobleOnly;

  const AccentColor({
    required this.id,
    required this.name,
    required this.primary,
    required this.dim,
    required this.onAccent,
    this.isDefault = false,
    this.nobleOnly = false,
  });

  // Legacy: kept so old callsites that asked "is this the default accent?"
  // still compile; new code should compare via `isDefault`.
  bool get isGold => isDefault;

  Color get soft => primary.withValues(alpha: 0.10);
  Color get border => primary.withValues(alpha: 0.22);
  Color get glow => primary.withValues(alpha: 0.14);
  Color get strong => primary;
}

// ═══════════════════════════════════════════════════════════════════════════
// PR 1 — REBRAND FOUNDATION (2026-05-13)
// Theme flipped from dark-sage + emerald to light + burgundy.
// `emerald*` identifiers are kept as ALIASES that now resolve to burgundy
// values, so existing `AppColors.emerald600` callsites continue to compile
// and render the new primary accent. PR 2/3/4 will migrate callsites to
// the new `burgundy*` names; the emerald alias layer disappears once that
// migration finishes.
// ═══════════════════════════════════════════════════════════════════════════

class AppColors {
  AppColors._();

  // ══════════════════════════════════════════════════════════════
  // BURGUNDY SCALE — Noblara primary brand
  // ══════════════════════════════════════════════════════════════
  static const Color burgundy50  = Color(0xFFFDF2F4);  // pale blush bg tint
  static const Color burgundy100 = Color(0xFFFBE3E7);
  static const Color burgundy200 = Color(0xFFF6C2CB);
  static const Color burgundy300 = Color(0xFFE89AA9);
  static const Color burgundy350 = Color(0xFFDE7C90);  // bright pop accent
  static const Color burgundy400 = Color(0xFFD06A82);
  static const Color burgundy500 = Color(0xFFB05060);  // mid accent
  static const Color burgundy600 = Color(0xFF8B3A4A);  // PRIMARY ACCENT
  static const Color burgundy700 = Color(0xFF6F2D3A);
  static const Color burgundy800 = Color(0xFF55232E);
  static const Color burgundy900 = Color(0xFF3F1A22);

  // ══════════════════════════════════════════════════════════════
  // EMERALD ALIAS LAYER — semantic flip (now resolve to burgundy)
  // Existing callsites read `AppColors.emerald600`; they now render
  // burgundy600 without code changes. PR 2/3/4 will migrate names.
  // ══════════════════════════════════════════════════════════════
  static const Color emerald50  = burgundy50;
  static const Color emerald100 = burgundy100;
  static const Color emerald200 = burgundy200;
  static const Color emerald300 = burgundy300;
  static const Color emerald350 = burgundy350;
  static const Color emerald400 = burgundy400;
  static const Color emerald500 = burgundy500;
  static const Color emerald600 = burgundy600;
  static const Color emerald700 = burgundy700;
  static const Color emerald800 = burgundy800;
  static const Color emerald900 = burgundy900;

  // ══════════════════════════════════════════════════════════════
  // ACCENT PALETTE — Burgundy is the new default
  // ══════════════════════════════════════════════════════════════
  static const List<AccentColor> accents = [
    AccentColor(
      id: 'burgundy', name: 'Burgundy',
      primary: burgundy600, dim: burgundy800,
      onAccent: Color(0xFFFFFFFF), isDefault: true,
    ),
    AccentColor(
      id: 'gold', name: 'Gold',
      primary: Color(0xFFB8862C), dim: Color(0xFF8E681F),
      onAccent: Color(0xFFFFFFFF),
    ),
    AccentColor(
      id: 'sapphire', name: 'Sapphire',
      primary: Color(0xFF3468CC), dim: Color(0xFF254A92),
      onAccent: Color(0xFFFFFFFF),
    ),
    AccentColor(
      id: 'forest', name: 'Forest',
      primary: Color(0xFF2C8C68), dim: Color(0xFF1F6E53),
      onAccent: Color(0xFFFFFFFF),
    ),
    AccentColor(
      id: 'anthracite', name: 'Anthracite',
      primary: Color(0xFF3B4350), dim: Color(0xFF252B36),
      onAccent: Color(0xFFFFFFFF),
    ),
  ];

  // Legacy alias kept so `accentById('emerald')` and `'bordeaux'` still
  // resolve (they map to the new burgundy default).
  static AccentColor accentById(String id) {
    final normalized = (id == 'emerald' || id == 'bordeaux') ? 'burgundy' : id;
    return accents.firstWhere(
      (a) => a.id == normalized,
      orElse: () => accents.first,
    );
  }

  // ══════════════════════════════════════════════════════════════
  // BRAND SHORTHAND
  // ══════════════════════════════════════════════════════════════
  static const Color gold      = Color(0xFFB8862C);
  static const Color goldLight = Color(0x22B8862C);
  static const Color goldDark  = Color(0xFF8E681F);

  // ══════════════════════════════════════════════════════════════
  // FOUNDATION — light, warm, store-ready
  // ══════════════════════════════════════════════════════════════
  static const Color bg          = Color(0xFFFFFFFF);  // app background
  static const Color surface     = Color(0xFFFAFAFA);  // lifted card
  static const Color surfaceAlt  = Color(0xFFF4F4F5);  // section bg
  static const Color card        = Color(0xFFFFFFFF);  // primary card
  static const Color elevated    = Color(0xFFFFFFFF);  // elevated (shadow does the lift)
  static const Color softSurface = Color(0xFFFAF6F7);  // warm blush tint

  // ══════════════════════════════════════════════════════════════
  // TEXT — dark on light
  // ══════════════════════════════════════════════════════════════
  static const Color textPrimary   = Color(0xFF14181A);
  static const Color textSecondary = Color(0xFF4B5159);
  static const Color textMuted     = Color(0xFF7A8088);
  static const Color textDisabled  = Color(0xFFB0B5BB);
  // Name kept for backwards-compat; "onEmerald" semantically means
  // "text on primary accent (burgundy)".
  static const Color textOnEmerald = Color(0xFFFFFFFF);

  // ══════════════════════════════════════════════════════════════
  // SEMANTIC
  // ══════════════════════════════════════════════════════════════
  static const Color success = Color(0xFF2FA36C);
  static const Color error   = Color(0xFFC0392B);
  static const Color warning = Color(0xFFB8862C);
  static const Color info    = Color(0xFF3468CC);

  // ══════════════════════════════════════════════════════════════
  // BORDERS — subtle, layered, for light surfaces
  // ══════════════════════════════════════════════════════════════
  static const Color border       = Color(0xFFE3E5E8);
  static const Color borderLight  = Color(0xFFEEF0F2);
  static const Color borderSubtle = Color(0xFFF3F4F6);
  static const Color borderStrong = Color(0xFFCFD3D8);
  static const Color borderGold   = Color(0x33B8862C);

  // ══════════════════════════════════════════════════════════════
  // SWIPE OVERLAYS — softer for white card surfaces
  // ══════════════════════════════════════════════════════════════
  static const Color selectOverlay = Color(0x402FA36C);
  static const Color passOverlay   = Color(0x40C0392B);

  // ══════════════════════════════════════════════════════════════
  // MODE ACCENTS
  // ══════════════════════════════════════════════════════════════
  static const Color teal   = Color(0xFF0E8C9C);
  static const Color violet = Color(0xFF6E58D1);

  // ══════════════════════════════════════════════════════════════
  // BACKWARDS COMPAT ALIASES (older code paths)
  // ══════════════════════════════════════════════════════════════
  static const Color lightBg            = bg;
  static const Color lightSurface       = surface;
  static const Color lightSurfaceAlt    = surfaceAlt;
  static const Color lightCard          = card;
  static const Color lightElevated      = elevated;
  static const Color lightBorder        = border;
  static const Color lightBorderSubtle  = borderSubtle;
  static const Color lightTextPrimary   = textPrimary;
  static const Color lightTextSecondary = textSecondary;
  static const Color lightTextMuted     = textMuted;
  static const Color lightTextDisabled  = textDisabled;

  // ══════════════════════════════════════════════════════════════
  // NOBLARA BRAND SECTION
  // ══════════════════════════════════════════════════════════════
  static const Color noblaraGold   = burgundy600;
  static const Color nobBackground = bg;
  static const Color nobSurface    = surface;
  static const Color nobSurfaceAlt = surfaceAlt;
  static const Color nobBorder     = border;
  static const Color nobObserver   = textMuted;
  static const Color nobExplorer   = info;
  static const Color nobNoble      = burgundy600;
}

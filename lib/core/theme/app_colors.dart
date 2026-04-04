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

  bool get isGold => isDefault;

  Color get soft => primary.withValues(alpha: 0.12);
  Color get border => primary.withValues(alpha: 0.25);
  Color get glow => primary.withValues(alpha: 0.16);
  Color get strong => primary;
}

class AppColors {
  AppColors._();

  // ══════════════════════════════════════════════════════════════
  // EMERALD SCALE — tok, derin, premium zümrüt
  // ══════════════════════════════════════════════════════════════
  static const Color emerald50  = Color(0xFF1A2E25);
  static const Color emerald100 = Color(0xFF1F3D30);
  static const Color emerald200 = Color(0xFF245038);
  static const Color emerald300 = Color(0xFF2C6648);
  static const Color emerald400 = Color(0xFF357D58);
  static const Color emerald500 = Color(0xFF43A27A);  // mid accent
  static const Color emerald600 = Color(0xFF2C8C68);  // PRIMARY ACCENT
  static const Color emerald700 = Color(0xFF1F6E53);
  static const Color emerald800 = Color(0xFF15523E);
  static const Color emerald900 = Color(0xFF0F3D2F);

  // ══════════════════════════════════════════════════════════════
  // ACCENT PALETTE
  // ══════════════════════════════════════════════════════════════
  static const List<AccentColor> accents = [
    AccentColor(
      id: 'emerald', name: 'Emerald',
      primary: emerald600, dim: emerald800,
      onAccent: Color(0xFFFFFFFF), isDefault: true,
    ),
    AccentColor(
      id: 'gold', name: 'Gold',
      primary: Color(0xFFD4A843), dim: Color(0xFFB8922F),
      onAccent: Color(0xFF1A1400), nobleOnly: true,
    ),
    AccentColor(
      id: 'sapphire', name: 'Sapphire',
      primary: Color(0xFF4F89F6), dim: Color(0xFF3468CC),
      onAccent: Color(0xFFFFFFFF), nobleOnly: true,
    ),
    AccentColor(
      id: 'bordeaux', name: 'Bordeaux',
      primary: Color(0xFFB05060), dim: Color(0xFF8B3A4A),
      onAccent: Color(0xFFFFFFFF), nobleOnly: true,
    ),
    AccentColor(
      id: 'anthracite', name: 'Anthracite',
      primary: Color(0xFF6B7A8D), dim: Color(0xFF4A5568),
      onAccent: Color(0xFFFFFFFF), nobleOnly: true,
    ),
  ];

  static AccentColor accentById(String id) =>
      accents.firstWhere((a) => a.id == id, orElse: () => accents.first);

  // ══════════════════════════════════════════════════════════════
  // BRAND SHORTHAND
  // ══════════════════════════════════════════════════════════════
  static const Color gold     = emerald600;
  static const Color goldLight = Color(0x222C8C68);
  static const Color goldDark = emerald800;

  // ══════════════════════════════════════════════════════════════
  // FOUNDATION — near-black, yeşilimsi-kömür alt ton
  // ══════════════════════════════════════════════════════════════
  static const Color bg          = Color(0xFF0B0D0C);  // app background
  static const Color surface     = Color(0xFF181E1B);   // card
  static const Color surfaceAlt  = Color(0xFF151A18);   // section
  static const Color card        = Color(0xFF181E1B);   // card
  static const Color elevated    = Color(0xFF1D2420);   // elevated
  static const Color softSurface = Color(0xFF202723);   // soft

  // ══════════════════════════════════════════════════════════════
  // TEXT — yumuşak açık tonlar
  // ══════════════════════════════════════════════════════════════
  static const Color textPrimary   = Color(0xFFF3F5F2);
  static const Color textSecondary = Color(0xFFA7B1AB);
  static const Color textMuted     = Color(0xFF7E8882);
  static const Color textDisabled  = Color(0xFF616A65);
  static const Color textOnEmerald = Color(0xFFFFFFFF);

  // ══════════════════════════════════════════════════════════════
  // SEMANTIC
  // ══════════════════════════════════════════════════════════════
  static const Color success = Color(0xFF2FA36C);
  static const Color error   = Color(0xFFD1584A);
  static const Color warning = Color(0xFFC48A2C);
  static const Color info    = Color(0xFF4F89F6);

  // ══════════════════════════════════════════════════════════════
  // BORDERS — karanlık zeminde seçilebilir
  // ══════════════════════════════════════════════════════════════
  static const Color border       = Color(0xFF2D3932);
  static const Color borderLight  = Color(0xFF26312B);
  static const Color borderSubtle = Color(0xFF212B26);
  static const Color borderStrong = Color(0xFF37463E);
  static const Color borderGold   = Color(0x442C8C68);

  // ══════════════════════════════════════════════════════════════
  // SWIPE OVERLAYS
  // ══════════════════════════════════════════════════════════════
  static const Color selectOverlay = Color(0x552FA36C);
  static const Color passOverlay  = Color(0x55D1584A);

  // ══════════════════════════════════════════════════════════════
  // MODE ACCENTS
  // ══════════════════════════════════════════════════════════════
  static const Color teal   = Color(0xFF26C6DA);
  static const Color violet = Color(0xFF9B7DFF);

  // ══════════════════════════════════════════════════════════════
  // BACKWARDS COMPAT ALIASES
  // ══════════════════════════════════════════════════════════════
  static const Color lightBg           = bg;
  static const Color lightSurface      = surface;
  static const Color lightSurfaceAlt   = surfaceAlt;
  static const Color lightCard         = card;
  static const Color lightElevated     = elevated;
  static const Color lightBorder       = border;
  static const Color lightBorderSubtle = borderSubtle;
  static const Color lightTextPrimary  = textPrimary;
  static const Color lightTextSecondary = textSecondary;
  static const Color lightTextMuted    = textMuted;
  static const Color lightTextDisabled = textDisabled;

  // ══════════════════════════════════════════════════════════════
  // NOBLARA BRAND SECTION
  // ══════════════════════════════════════════════════════════════
  static const Color noblaraGold   = emerald600;
  static const Color nobBackground = Color(0xFF0B0D0C);
  static const Color nobSurface    = Color(0xFF181E1B);
  static const Color nobSurfaceAlt = Color(0xFF151A18);
  static const Color nobBorder     = Color(0xFF2D3932);
  static const Color nobObserver   = Color(0xFF7E8882);
  static const Color nobExplorer   = Color(0xFF4F89F6);
  static const Color nobNoble      = emerald600;
}

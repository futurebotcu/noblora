import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Premium design tokens — elevation, motion, glow, depth.
/// Use these across ALL screens for visual consistency.
class Premium {
  Premium._();

  // ══════════════════════════════════════════════════════════════
  // ELEVATION SYSTEM — multi-layer shadows for depth hierarchy
  // ══════════════════════════════════════════════════════════════

  /// Subtle lift — chips, badges, small elements
  static List<BoxShadow> get shadowSm => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  /// Card elevation — cards, list items, containers
  static List<BoxShadow> get shadowMd => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 32,
      offset: const Offset(0, 16),
    ),
  ];

  /// Heavy lift — modals, hero cards, swipe cards
  static List<BoxShadow> get shadowLg => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 48,
      offset: const Offset(0, 24),
    ),
  ];

  /// Emerald glow — CTA buttons, hero actions, active states
  static List<BoxShadow> emeraldGlow({double intensity = 1.0}) => [
    BoxShadow(
      color: AppColors.emerald600.withValues(alpha: 0.25 * intensity),
      blurRadius: 16,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: AppColors.emerald600.withValues(alpha: 0.12 * intensity),
      blurRadius: 32,
      spreadRadius: -2,
      offset: const Offset(0, 8),
    ),
  ];

  /// Accent glow — any color, for mode-specific CTA
  static List<BoxShadow> accentGlow(Color color, {double intensity = 1.0}) => [
    BoxShadow(
      color: color.withValues(alpha: 0.30 * intensity),
      blurRadius: 16,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: color.withValues(alpha: 0.15 * intensity),
      blurRadius: 32,
      spreadRadius: -2,
      offset: const Offset(0, 8),
    ),
  ];

  // ══════════════════════════════════════════════════════════════
  // SURFACE GRADIENTS — depth without flat monotone
  // ══════════════════════════════════════════════════════════════

  /// Subtle surface gradient — prevents flat dark blocks
  static LinearGradient get surfaceGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.surface,
      AppColors.surface.withValues(alpha: 0.95),
      const Color(0xFF1A211E), // slight emerald warmth
    ],
  );

  /// Card gradient — premium card surface
  static LinearGradient get cardGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      const Color(0xFF1C2320),
      AppColors.surface,
    ],
  );

  /// Hero gradient — profile, status hero sections
  static LinearGradient heroGradient({Color? tint}) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const [0.0, 0.5, 1.0],
    colors: [
      (tint ?? AppColors.emerald600).withValues(alpha: 0.08),
      AppColors.bg.withValues(alpha: 0.0),
      AppColors.bg,
    ],
  );

  /// Cinematic photo overlay — for card stack
  static LinearGradient get photoOverlay => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.35, 0.65, 1.0],
    colors: [
      Color(0x200B0D0C), // subtle vignette top
      Colors.transparent,
      Color(0x600B0D0C),
      Color(0xE00B0D0C), // strong bottom
    ],
  );

  /// Bottom nav fade — seamless nav integration
  static LinearGradient navFade(Color bg) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      bg.withValues(alpha: 0.0),
      bg.withValues(alpha: 0.85),
      bg,
    ],
    stops: const [0.0, 0.3, 1.0],
  );

  // ══════════════════════════════════════════════════════════════
  // BORDER SYSTEM — subtle, layered, premium
  // ══════════════════════════════════════════════════════════════

  /// Default card border
  static BorderSide get cardBorder => BorderSide(
    color: AppColors.border.withValues(alpha: 0.4),
    width: 0.5,
  );

  /// Accent-tinted border (for active/selected states)
  static BorderSide accentBorder(Color color) => BorderSide(
    color: color.withValues(alpha: 0.25),
    width: 1.0,
  );

  /// Glow border — emerald tint for premium containers
  static Border get glowBorder => Border.all(
    color: AppColors.emerald600.withValues(alpha: 0.12),
    width: 0.5,
  );

  // ══════════════════════════════════════════════════════════════
  // MOTION CONSTANTS — consistent feel across app
  // ══════════════════════════════════════════════════════════════

  /// Quick feedback (button press, chip select)
  static const Duration dFast = Duration(milliseconds: 150);
  /// Standard transition (tab switch, expand)
  static const Duration dMedium = Duration(milliseconds: 250);
  /// Smooth entrance (sheet, card appear)
  static const Duration dSlow = Duration(milliseconds: 400);
  /// Dramatic (celebration, match found)
  static const Duration dDramatic = Duration(milliseconds: 600);

  /// Premium ease — buttery smooth
  static const Curve cPremium = Curves.easeOutCubic;
  /// Snappy — quick feedback
  static const Curve cSnappy = Curves.easeOutQuart;
  /// Bouncy — playful elements
  static const Curve cBouncy = Curves.elasticOut;
  /// Dramatic — hero transitions
  static const Curve cDramatic = Curves.easeInOutCubic;

  // ══════════════════════════════════════════════════════════════
  // PREMIUM DECORATIONS — reusable box decorations
  // ══════════════════════════════════════════════════════════════

  /// Premium card decoration
  static BoxDecoration cardDecoration({
    double radius = 20,
    Color? bgColor,
    bool withGlow = false,
  }) => BoxDecoration(
    color: bgColor ?? AppColors.surface,
    borderRadius: BorderRadius.circular(radius),
    border: withGlow ? glowBorder : Border.all(color: cardBorder.color, width: 0.5),
    boxShadow: shadowMd,
  );

  /// Elevated container — for hero sections, modals
  static BoxDecoration elevatedDecoration({
    double radius = 24,
    Color? borderColor,
  }) => BoxDecoration(
    gradient: cardGradient,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: borderColor ?? AppColors.emerald600.withValues(alpha: 0.10),
      width: 0.5,
    ),
    boxShadow: shadowLg,
  );

  /// Chip decoration — for tags, badges, filters
  static BoxDecoration chipDecoration({
    Color? bgColor,
    Color? borderColor,
    bool selected = false,
  }) => BoxDecoration(
    color: bgColor ?? (selected
        ? AppColors.emerald600.withValues(alpha: 0.12)
        : AppColors.surfaceAlt),
    borderRadius: BorderRadius.circular(999),
    border: Border.all(
      color: borderColor ?? (selected
          ? AppColors.emerald600.withValues(alpha: 0.30)
          : AppColors.border.withValues(alpha: 0.4)),
      width: 0.5,
    ),
    boxShadow: selected ? shadowSm : null,
  );

  /// Empty state container
  static BoxDecoration emptyStateDecoration({double radius = 24}) =>
      BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.surface.withValues(alpha: 0.6),
            AppColors.surfaceAlt.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: AppColors.emerald600.withValues(alpha: 0.08),
          width: 0.5,
        ),
      );

  // ══════════════════════════════════════════════════════════════
  // TEXT STYLES — premium hierarchy
  // ══════════════════════════════════════════════════════════════

  /// Hero name on card (e.g., "Sophia, 26")
  static const TextStyle cardName = TextStyle(
    color: Colors.white,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.1,
  );

  /// Section header (e.g., "YOUR PERSONAS")
  static TextStyle sectionHeader(Color color) => TextStyle(
    color: color,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
  );

  /// Status label (e.g., "Verified", "Noble")
  static const TextStyle badgeLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
  );

  // ══════════════════════════════════════════════════════════════
  // DIALOG & SHEET — premium family styling
  // ══════════════════════════════════════════════════════════════

  /// Premium dialog shape with emerald-tinted border
  static ShapeBorder dialogShape({double radius = 24}) =>
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(
          color: AppColors.emerald600.withValues(alpha: 0.10),
          width: 0.5,
        ),
      );

  /// Premium sheet handle
  static BoxDecoration sheetHandle({Color? accent}) => BoxDecoration(
    color: (accent ?? AppColors.emerald600).withValues(alpha: 0.20),
    borderRadius: BorderRadius.circular(999),
  );
}

/// Animated press effect — scale down on tap, spring back on release.
/// Wrap any widget: `PressEffect(child: MyButton())`
class PressEffect extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  const PressEffect({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.96,
  });

  @override
  State<PressEffect> createState() => _PressEffectState();
}

class _PressEffectState extends State<PressEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Premium.dFast,
    );
    _scaleAnim = Tween(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _ctrl, curve: Premium.cSnappy),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: widget.child,
      ),
    );
  }
}

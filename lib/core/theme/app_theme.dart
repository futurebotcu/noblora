import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_spacing.dart';

class AppTheme {
  AppTheme._();

  // ── Accent-aware theme builders ──

  static ThemeData darkWithAccent(Color accent) {
    return dark.copyWith(
      colorScheme: dark.colorScheme.copyWith(primary: accent, secondary: accent),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: dark.elevatedButtonTheme.style?.copyWith(
          backgroundColor: WidgetStatePropertyAll(accent))),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: dark.outlinedButtonTheme.style?.copyWith(
          foregroundColor: WidgetStatePropertyAll(accent),
          side: WidgetStatePropertyAll(BorderSide(color: accent.withValues(alpha: 0.5))))),
      textButtonTheme: TextButtonThemeData(
        style: dark.textButtonTheme.style?.copyWith(
          foregroundColor: WidgetStatePropertyAll(accent))),
      bottomNavigationBarTheme: dark.bottomNavigationBarTheme.copyWith(selectedItemColor: accent),
    );
  }

  static ThemeData lightWithAccent(Color accent) {
    return light.copyWith(
      colorScheme: light.colorScheme.copyWith(primary: accent, secondary: accent),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: light.elevatedButtonTheme.style?.copyWith(
          backgroundColor: WidgetStatePropertyAll(accent))),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: light.outlinedButtonTheme.style?.copyWith(
          foregroundColor: WidgetStatePropertyAll(accent),
          side: WidgetStatePropertyAll(BorderSide(color: accent)))),
      textButtonTheme: TextButtonThemeData(
        style: light.textButtonTheme.style?.copyWith(
          foregroundColor: WidgetStatePropertyAll(accent))),
      bottomNavigationBarTheme: light.bottomNavigationBarTheme.copyWith(selectedItemColor: accent),
    );
  }

  // ── Light theme ──

  static ThemeData get light {
    return ThemeData.light().copyWith(
      colorScheme: const ColorScheme.light(
        primary: AppColors.gold, onPrimary: Colors.white,
        secondary: AppColors.goldDark,
        surface: AppColors.lightSurface, onSurface: AppColors.lightTextPrimary,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.lightBg,
      cardColor: AppColors.lightCard,
      dividerColor: AppColors.lightBorder,
      textTheme: _lightText(),
      inputDecorationTheme: _input().copyWith(
        fillColor: AppColors.lightSurfaceAlt,
        hintStyle: GoogleFonts.inter(color: AppColors.lightTextMuted, fontSize: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm), borderSide: const BorderSide(color: AppColors.lightBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm), borderSide: const BorderSide(color: AppColors.lightBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm), borderSide: const BorderSide(color: AppColors.gold, width: 1.5)),
      ),
      elevatedButtonTheme: _elevBtn(),
      outlinedButtonTheme: _outBtn(),
      textButtonTheme: _txtBtn(),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        selectedItemColor: AppColors.gold,
        unselectedItemColor: AppColors.lightTextMuted,
        showSelectedLabels: true, showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightBg, elevation: 0, centerTitle: false,
        titleTextStyle: GoogleFonts.inter(color: AppColors.lightTextPrimary, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        iconTheme: const IconThemeData(color: AppColors.lightTextPrimary)),
      pageTransitionsTheme: _transitions,
    );
  }

  // ── Dark theme (primary) ──

  static ThemeData get dark {
    return ThemeData.dark().copyWith(
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold, onPrimary: AppColors.bg,
        secondary: AppColors.goldDark,
        surface: AppColors.surface, onSurface: AppColors.textPrimary,
        error: AppColors.error, onError: AppColors.textPrimary,
      ),
      scaffoldBackgroundColor: AppColors.bg,
      cardColor: AppColors.card,
      dividerColor: AppColors.border,
      textTheme: _darkText(),
      inputDecorationTheme: _input(),
      elevatedButtonTheme: _elevBtn(),
      outlinedButtonTheme: _outBtn(),
      textButtonTheme: _txtBtn(),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.gold,
        unselectedItemColor: AppColors.textMuted,
        showSelectedLabels: true, showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg, elevation: 0, centerTitle: false,
        titleTextStyle: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        iconTheme: const IconThemeData(color: AppColors.textPrimary)),
      pageTransitionsTheme: _transitions,
    );
  }

  // ── Shared builders ──

  static TextTheme _darkText() {
    return TextTheme(
      displayLarge: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 48, fontWeight: FontWeight.w300, letterSpacing: -1),
      displayMedium: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 36, fontWeight: FontWeight.w300, letterSpacing: -0.5),
      headlineLarge: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      headlineMedium: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      headlineSmall: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
      titleLarge: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2),
      titleMedium: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
      titleSmall: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
      bodyLarge: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 15, height: 1.5),
      bodyMedium: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
      bodySmall: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12, height: 1.4),
      labelLarge: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3),
      labelMedium: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500),
    );
  }

  static TextTheme _lightText() {
    return TextTheme(
      displayLarge: GoogleFonts.inter(color: AppColors.lightTextPrimary, fontSize: 48, fontWeight: FontWeight.w300, letterSpacing: -1),
      displayMedium: GoogleFonts.inter(color: AppColors.lightTextPrimary, fontSize: 36, fontWeight: FontWeight.w300, letterSpacing: -0.5),
      headlineLarge: GoogleFonts.inter(color: AppColors.lightTextPrimary, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      headlineMedium: GoogleFonts.inter(color: AppColors.lightTextPrimary, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      headlineSmall: GoogleFonts.inter(color: AppColors.lightTextPrimary, fontSize: 20, fontWeight: FontWeight.w600),
      titleLarge: GoogleFonts.inter(color: AppColors.lightTextPrimary, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2),
      titleMedium: GoogleFonts.inter(color: AppColors.lightTextPrimary, fontSize: 15, fontWeight: FontWeight.w500),
      titleSmall: GoogleFonts.inter(color: AppColors.lightTextSecondary, fontSize: 13, fontWeight: FontWeight.w500),
      bodyLarge: GoogleFonts.inter(color: AppColors.lightTextSecondary, fontSize: 15, height: 1.5),
      bodyMedium: GoogleFonts.inter(color: AppColors.lightTextSecondary, fontSize: 14, height: 1.5),
      bodySmall: GoogleFonts.inter(color: AppColors.lightTextMuted, fontSize: 12, height: 1.4),
      labelLarge: GoogleFonts.inter(color: AppColors.lightTextPrimary, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3),
      labelMedium: GoogleFonts.inter(color: AppColors.lightTextSecondary, fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall: GoogleFonts.inter(color: AppColors.lightTextMuted, fontSize: 11, fontWeight: FontWeight.w500),
    );
  }

  static InputDecorationTheme _input() {
    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm), borderSide: const BorderSide(color: AppColors.gold, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm), borderSide: const BorderSide(color: AppColors.error)),
      hintStyle: GoogleFonts.inter(color: AppColors.textDisabled, fontSize: 14),
      labelStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
    );
  }

  static ElevatedButtonThemeData _elevBtn() {
    return ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.gold, foregroundColor: AppColors.bg,
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
      textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2),
      elevation: 0));
  }

  static OutlinedButtonThemeData _outBtn() {
    return OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.gold,
      minimumSize: const Size.fromHeight(52),
      side: BorderSide(color: AppColors.gold.withValues(alpha: 0.5)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
      textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)));
  }

  static TextButtonThemeData _txtBtn() {
    return TextButtonThemeData(style: TextButton.styleFrom(
      foregroundColor: AppColors.gold,
      textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)));
  }

  static const _transitions = PageTransitionsTheme(builders: {
    TargetPlatform.android: CupertinoPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
  });
}

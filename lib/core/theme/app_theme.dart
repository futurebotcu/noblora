import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_spacing.dart';

class AppTheme {
  AppTheme._();

  /// Build dark theme with custom accent color
  static ThemeData darkWithAccent(Color accent) {
    return dark.copyWith(
      colorScheme: dark.colorScheme.copyWith(primary: accent, secondary: accent),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: dark.elevatedButtonTheme.style?.copyWith(
          backgroundColor: WidgetStatePropertyAll(accent),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: dark.outlinedButtonTheme.style?.copyWith(
          foregroundColor: WidgetStatePropertyAll(accent),
          side: WidgetStatePropertyAll(BorderSide(color: accent)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: dark.textButtonTheme.style?.copyWith(
          foregroundColor: WidgetStatePropertyAll(accent),
        ),
      ),
      bottomNavigationBarTheme: dark.bottomNavigationBarTheme.copyWith(
        selectedItemColor: accent,
      ),
    );
  }

  /// Build light theme with custom accent color
  static ThemeData lightWithAccent(Color accent) {
    return light.copyWith(
      colorScheme: light.colorScheme.copyWith(primary: accent, secondary: accent),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: light.elevatedButtonTheme.style?.copyWith(
          backgroundColor: WidgetStatePropertyAll(accent),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: light.outlinedButtonTheme.style?.copyWith(
          foregroundColor: WidgetStatePropertyAll(accent),
          side: WidgetStatePropertyAll(BorderSide(color: accent)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: light.textButtonTheme.style?.copyWith(
          foregroundColor: WidgetStatePropertyAll(accent),
        ),
      ),
      bottomNavigationBarTheme: light.bottomNavigationBarTheme.copyWith(
        selectedItemColor: accent,
      ),
    );
  }

  /// Light theme
  static ThemeData get light {
    return ThemeData.light().copyWith(
      colorScheme: const ColorScheme.light(
        primary: AppColors.gold,
        onPrimary: Colors.white,
        secondary: AppColors.goldLight,
        surface: Color(0xFFF5F5F5),
        onSurface: Color(0xFF1A1A1A),
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: Colors.white,
      cardColor: const Color(0xFFF5F5F5),
      dividerColor: const Color(0xFFE0E0E0),
      textTheme: _buildLightTextTheme(),
      inputDecorationTheme: _buildInputDecorationTheme().copyWith(
        fillColor: const Color(0xFFF5F5F5),
        hintStyle: GoogleFonts.inter(color: const Color(0xFF9E9E9E), fontSize: 14),
      ),
      elevatedButtonTheme: _buildElevatedButtonTheme(),
      outlinedButtonTheme: _buildOutlinedButtonTheme(),
      textButtonTheme: _buildTextButtonTheme(),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.gold,
        unselectedItemColor: Color(0xFF9E9E9E),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.playfairDisplay(
          color: const Color(0xFF1A1A1A),
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData.dark().copyWith(
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold,
        onPrimary: AppColors.bg,
        secondary: AppColors.goldLight,
        onSecondary: AppColors.bg,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
        onError: AppColors.textPrimary,
      ),
      scaffoldBackgroundColor: AppColors.bg,
      cardColor: AppColors.card,
      dividerColor: AppColors.border,
      textTheme: _buildTextTheme(),
      inputDecorationTheme: _buildInputDecorationTheme(),
      elevatedButtonTheme: _buildElevatedButtonTheme(),
      outlinedButtonTheme: _buildOutlinedButtonTheme(),
      textButtonTheme: _buildTextButtonTheme(),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.gold,
        unselectedItemColor: AppColors.textMuted,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.playfairDisplay(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _buildTextTheme() {
    return TextTheme(
      displayLarge: GoogleFonts.playfairDisplay(
        color: AppColors.textPrimary,
        fontSize: 57,
        fontWeight: FontWeight.w400,
      ),
      displayMedium: GoogleFonts.playfairDisplay(
        color: AppColors.textPrimary,
        fontSize: 45,
        fontWeight: FontWeight.w400,
      ),
      displaySmall: GoogleFonts.playfairDisplay(
        color: AppColors.textPrimary,
        fontSize: 36,
        fontWeight: FontWeight.w400,
      ),
      headlineLarge: GoogleFonts.playfairDisplay(
        color: AppColors.textPrimary,
        fontSize: 32,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: GoogleFonts.playfairDisplay(
        color: AppColors.textPrimary,
        fontSize: 28,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: GoogleFonts.playfairDisplay(
        color: AppColors.textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: GoogleFonts.inter(
        color: AppColors.textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: GoogleFonts.inter(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      titleSmall: GoogleFonts.inter(
        color: AppColors.textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: GoogleFonts.inter(
        color: AppColors.textSecondary,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: GoogleFonts.inter(
        color: AppColors.textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: GoogleFonts.inter(
        color: AppColors.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: GoogleFonts.inter(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
      labelMedium: GoogleFonts.inter(
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: GoogleFonts.inter(
        color: AppColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    );
  }

  static InputDecorationTheme _buildInputDecorationTheme() {
    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      hintStyle: GoogleFonts.inter(color: AppColors.textDisabled, fontSize: 14),
      labelStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
      errorStyle: GoogleFonts.inter(color: AppColors.error, fontSize: 12),
    );
  }

  static ElevatedButtonThemeData _buildElevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.bg,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        elevation: 0,
      ),
    );
  }

  static OutlinedButtonThemeData _buildOutlinedButtonTheme() {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.gold,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: AppColors.gold),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static TextButtonThemeData _buildTextButtonTheme() {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.gold,
        textStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  static TextTheme _buildLightTextTheme() {
    const dark = Color(0xFF1A1A1A);
    const muted = Color(0xFF757575);
    return TextTheme(
      displayLarge: GoogleFonts.playfairDisplay(color: dark, fontSize: 57),
      displayMedium: GoogleFonts.playfairDisplay(color: dark, fontSize: 45),
      displaySmall: GoogleFonts.playfairDisplay(color: dark, fontSize: 36),
      headlineLarge: GoogleFonts.playfairDisplay(color: dark, fontSize: 32, fontWeight: FontWeight.w600),
      headlineMedium: GoogleFonts.playfairDisplay(color: dark, fontSize: 28, fontWeight: FontWeight.w600),
      headlineSmall: GoogleFonts.playfairDisplay(color: dark, fontSize: 24, fontWeight: FontWeight.w600),
      titleLarge: GoogleFonts.inter(color: dark, fontSize: 22, fontWeight: FontWeight.w600),
      titleMedium: GoogleFonts.inter(color: dark, fontSize: 16, fontWeight: FontWeight.w500),
      titleSmall: GoogleFonts.inter(color: muted, fontSize: 14, fontWeight: FontWeight.w500),
      bodyLarge: GoogleFonts.inter(color: muted, fontSize: 16),
      bodyMedium: GoogleFonts.inter(color: muted, fontSize: 14),
      bodySmall: GoogleFonts.inter(color: muted, fontSize: 12),
      labelLarge: GoogleFonts.inter(color: dark, fontSize: 14, fontWeight: FontWeight.w600),
      labelMedium: GoogleFonts.inter(color: muted, fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall: GoogleFonts.inter(color: muted, fontSize: 11, fontWeight: FontWeight.w500),
    );
  }
}

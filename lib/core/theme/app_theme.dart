import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  // ── Accent-aware theme builders ──

  static ThemeData darkWithAccent(AccentColor a) {
    return dark.copyWith(
      colorScheme: dark.colorScheme.copyWith(
        primary: a.primary,
        onPrimary: a.onAccent,
        secondary: a.dim,
        onSecondary: a.onAccent,
        surfaceTint: a.primary.withValues(alpha: 0.04),
        outline: a.primary.withValues(alpha: 0.2),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: a.primary,
          foregroundColor: a.onAccent,
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: a.primary,
          side: BorderSide(color: a.border, width: 1),
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: a.primary,
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF111113),
        selectedItemColor: a.primary,
        unselectedItemColor: const Color(0xFF808080),
        showSelectedLabels: true,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? a.onAccent : const Color(0xFF808080)),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? a.primary : const Color(0xFF2A2A2A)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: a.primary,
        thumbColor: a.primary,
        inactiveTrackColor: const Color(0xFF2A2A2A),
        overlayColor: a.glow,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? a.primary : Colors.transparent),
        checkColor: WidgetStatePropertyAll(a.onAccent),
        side: const BorderSide(color: Color(0xFF4A4A4A), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? a.primary : const Color(0xFF4A4A4A)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: a.primary,
        linearTrackColor: const Color(0xFF2A2A2A),
        circularTrackColor: const Color(0xFF2A2A2A),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: a.primary,
        unselectedLabelColor: const Color(0xFF808080),
        indicatorColor: a.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF18181B),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: a.primary, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF222225), width: 0.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD64545)),
        ),
        hintStyle: GoogleFonts.inter(color: const Color(0xFF808080), fontSize: 14),
        labelStyle: GoogleFonts.inter(color: const Color(0xFF808080), fontSize: 14),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF080808),
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Color(0xFFF2F2F2)),
        titleTextStyle: GoogleFonts.inter(
          color: const Color(0xFFF2F2F2),
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      pageTransitionsTheme: _transitions,
    );
  }

  static ThemeData lightWithAccent(AccentColor a) {
    return light.copyWith(
      colorScheme: light.colorScheme.copyWith(
        primary: a.primary,
        onPrimary: a.onAccent,
        secondary: a.dim,
        surfaceTint: a.primary.withValues(alpha: 0.03),
        outline: a.primary.withValues(alpha: 0.2),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: a.primary,
          foregroundColor: a.onAccent,
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: a.primary,
          side: BorderSide(color: a.primary.withValues(alpha: 0.4)),
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: a.primary,
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFFFFFFFF),
        selectedItemColor: a.primary,
        unselectedItemColor: const Color(0xFF8C8680),
        showSelectedLabels: true,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? a.onAccent : Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? a.primary : const Color(0xFFE0DDD8)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: a.primary,
        thumbColor: a.primary,
        inactiveTrackColor: const Color(0xFFE0DDD8),
        overlayColor: a.glow,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: a.primary,
        linearTrackColor: const Color(0xFFE0DDD8),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: a.primary,
        unselectedLabelColor: const Color(0xFF8C8680),
        indicatorColor: a.primary,
        dividerColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F3EE),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: a.primary, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE8E4DC), width: 0.5),
        ),
        hintStyle: GoogleFonts.inter(color: const Color(0xFF8C8680), fontSize: 14),
        labelStyle: GoogleFonts.inter(color: const Color(0xFF8C8680), fontSize: 14),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFFAF9F6),
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Color(0xFF1A1814)),
        titleTextStyle: GoogleFonts.inter(
          color: const Color(0xFF1A1814),
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      pageTransitionsTheme: _transitions,
    );
  }

  // ── Light theme (base) ──

  static ThemeData get light {
    return ThemeData.light().copyWith(
      colorScheme: const ColorScheme.light(
        primary: AppColors.gold, onPrimary: Color(0xFF2D1F00),
        secondary: AppColors.goldDark,
        surface: AppColors.lightSurface, onSurface: AppColors.lightTextPrimary,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.lightBg,
      cardColor: AppColors.lightCard,
      dividerColor: AppColors.lightBorder,
      textTheme: _lightText(),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.lightBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.lightBorder, width: 0.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.gold, width: 1.5)),
        hintStyle: GoogleFonts.inter(color: AppColors.lightTextMuted, fontSize: 14),
        labelStyle: GoogleFonts.inter(color: AppColors.lightTextMuted, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.gold, foregroundColor: const Color(0xFF2D1F00),
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
        elevation: 0)),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.gold,
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.4)),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700))),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(
        foregroundColor: AppColors.gold,
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600))),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        selectedItemColor: AppColors.gold,
        unselectedItemColor: AppColors.lightTextMuted,
        showSelectedLabels: true, showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightBg, elevation: 0, centerTitle: false,
        titleTextStyle: GoogleFonts.inter(color: AppColors.lightTextPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        iconTheme: const IconThemeData(color: AppColors.lightTextPrimary)),
      pageTransitionsTheme: _transitions,
    );
  }

  // ── Dark theme (base) ──

  static ThemeData get dark {
    return ThemeData.dark().copyWith(
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold, onPrimary: Color(0xFF2D1F00),
        secondary: AppColors.goldDark,
        surface: AppColors.surface, onSurface: AppColors.textPrimary,
        error: AppColors.error, onError: AppColors.textPrimary,
      ),
      scaffoldBackgroundColor: AppColors.bg,
      cardColor: AppColors.card,
      dividerColor: AppColors.border,
      textTheme: _darkText(),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border, width: 0.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.gold, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.error)),
        hintStyle: GoogleFonts.inter(color: AppColors.textDisabled, fontSize: 14),
        labelStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.gold, foregroundColor: const Color(0xFF2D1F00),
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
        elevation: 0)),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.gold,
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.5)),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700))),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(
        foregroundColor: AppColors.gold,
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600))),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.gold,
        unselectedItemColor: AppColors.textMuted,
        showSelectedLabels: true, showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg, elevation: 0, centerTitle: false,
        titleTextStyle: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3),
        iconTheme: const IconThemeData(color: AppColors.textPrimary)),
      pageTransitionsTheme: _transitions,
    );
  }

  // ── Shared ──

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

  static const _transitions = PageTransitionsTheme(builders: {
    TargetPlatform.android: CupertinoPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
  });
}

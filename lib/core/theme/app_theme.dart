import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  // ══════════════════════════════════════════════════════════════
  // ACCENT-AWARE BUILDER
  // ══════════════════════════════════════════════════════════════

  static ThemeData withAccent(AccentColor a) {
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: a.primary,
        onPrimary: a.onAccent,
        secondary: a.dim,
        onSecondary: a.onAccent,
        surfaceTint: a.primary.withValues(alpha: 0.06),
        outline: a.primary.withValues(alpha: 0.25),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: a.primary,
          foregroundColor: a.onAccent,
          disabledBackgroundColor: a.primary.withValues(alpha: 0.25),
          disabledForegroundColor: AppColors.textDisabled,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: a.primary,
          side: BorderSide(color: a.primary.withValues(alpha: 0.4)),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: a.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: a.primary,
        unselectedItemColor: AppColors.textMuted,
        showSelectedLabels: true,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? Colors.white : AppColors.textMuted),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? a.primary : AppColors.borderStrong),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? a.primary : AppColors.border),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: a.primary,
        thumbColor: a.primary,
        inactiveTrackColor: AppColors.borderStrong,
        overlayColor: a.glow,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? a.primary : Colors.transparent),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: AppColors.border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? a.primary : AppColors.textMuted),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: a.primary,
        linearTrackColor: AppColors.borderStrong,
        circularTrackColor: AppColors.borderStrong,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: a.primary,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: a.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: AppColors.borderLight,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: a.primary, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border, width: 0.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        hintStyle: GoogleFonts.inter(color: AppColors.textDisabled, fontSize: 14),
        labelStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.elevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x152C8C68)),
        ),
        elevation: 16,
        shadowColor: const Color(0x52000000),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.elevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        elevation: 16,
        shadowColor: Color(0x52000000),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.elevated,
        contentTextStyle: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 0.5,
        space: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceAlt,
        selectedColor: AppColors.emerald900,
        disabledColor: AppColors.surfaceAlt,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
      ),
      pageTransitionsTheme: _transitions,
    );
  }

  // Legacy aliases
  static ThemeData lightWithAccent(AccentColor a) => withAccent(a);
  static ThemeData darkWithAccent(AccentColor a) => withAccent(a);

  // ══════════════════════════════════════════════════════════════
  // BASE THEME — Dark Premium
  // ══════════════════════════════════════════════════════════════

  static ThemeData get base {
    return ThemeData.dark().copyWith(
      colorScheme: const ColorScheme.dark(
        primary: AppColors.emerald600,
        onPrimary: AppColors.textOnEmerald,
        secondary: AppColors.emerald800,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.bg,
      cardColor: AppColors.card,
      dividerColor: AppColors.border,
      textTheme: _textTheme(),
      pageTransitionsTheme: _transitions,
    );
  }

  static ThemeData get light => base;
  static ThemeData get dark => base;

  // ══════════════════════════════════════════════════════════════
  // TYPOGRAPHY
  // ══════════════════════════════════════════════════════════════

  static TextTheme _textTheme() {
    return TextTheme(
      displayLarge:  GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 48, fontWeight: FontWeight.w300, letterSpacing: -1),
      displayMedium: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 36, fontWeight: FontWeight.w300, letterSpacing: -0.5),
      headlineLarge: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      headlineMedium: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      headlineSmall: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
      titleLarge:  GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2),
      titleMedium: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
      titleSmall:  GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
      bodyLarge:  GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 15, height: 1.5),
      bodyMedium: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
      bodySmall:  GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12, height: 1.4),
      labelLarge:  GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3),
      labelMedium: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall:  GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500),
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

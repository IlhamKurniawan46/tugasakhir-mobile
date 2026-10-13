import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Token warna diambil dari desain Stitch "HoloDex Mobile UI Design"
/// (design/stitch/*.html, blok tailwind.config).
class AppColors {
  static const Color surfaceLowest = Color(0xFF0E0E11); // latar halaman
  static const Color surfaceLow = Color(0xFF1B1B1E); // app bar, nav bar
  static const Color surface = Color(0xFF1F1F22); // kartu, input
  static const Color surfaceHigh = Color(0xFF2A2A2D); // border halus
  static const Color surfaceHighest = Color(0xFF353438);

  static const Color gold = Color(0xFFFFBF00); // primary-container: CTA & brand
  static const Color goldSoft = Color(0xFFFFE2AB); // primary
  static const Color onGold = Color(0xFF261A00);

  static const Color cyan = Color(0xFF00DBE9); // secondary: info/status
  static const Color pink = Color(0xFFFFB1C3); // tertiary: rarity badge

  static const Color onSurface = Color(0xFFE4E1E6);
  static const Color onSurfaceVariant = Color(0xFFD4C5AB);
  static const Color outline = Color(0xFF9C8F78);
  static const Color outlineVariant = Color(0xFF504532);

  static const Color error = Color(0xFFFFB4AB);
  static const Color success = Color(0xFF7DDC9A);
}

class AppTheme {
  static const double radiusSm = 8;
  static const double radiusMd = 12;

  static ThemeData get darkTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: GoogleFonts.inter().fontFamily,
    );
    final textTheme = base.textTheme.apply(
      bodyColor: AppColors.onSurface,
      displayColor: AppColors.onSurface,
    );

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: c, width: w),
        );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.surfaceLowest,
      textTheme: textTheme,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold,
        onPrimary: AppColors.onGold,
        secondary: AppColors.cyan,
        tertiary: AppColors.pink,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
        error: AppColors.error,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceLow,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 20,
          letterSpacing: -0.3,
        ),
        shape: const Border(
          bottom: BorderSide(color: AppColors.surfaceHigh),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: AppColors.surfaceHigh),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.outline, fontSize: 14),
        labelStyle:
            const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14),
        floatingLabelStyle: const TextStyle(color: AppColors.gold),
        prefixIconColor: AppColors.outline,
        suffixIconColor: AppColors.outline,
        errorStyle: const TextStyle(color: AppColors.error, fontSize: 12),
        border: border(AppColors.surfaceHigh),
        enabledBorder: border(AppColors.surfaceHigh),
        focusedBorder: border(AppColors.gold, 1.5),
        errorBorder: border(AppColors.error),
        focusedErrorBorder: border(AppColors.error, 1.5),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.onGold,
          disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.4),
          disabledForegroundColor: AppColors.onGold.withValues(alpha: 0.7),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.goldSoft,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.onSurface,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: AppColors.surfaceHigh),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceHighest,
        contentTextStyle: GoogleFonts.inter(color: AppColors.onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      dividerColor: AppColors.surfaceHigh,
    );
  }
}

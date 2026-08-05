import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const forest = Color(0xFF1A7A4C);
  static const forestDeep = Color(0xFF0F4D32);
  static const lime = Color(0xFFB8E06A);
  static const ink = Color(0xFF121816);
  static const mist = Color(0xFFF3F6F4);
  static const stone = Color(0xFF5C6B63);
  static const cardLight = Color(0xFFFFFFFF);
  static const cardDark = Color(0xFF1A211E);
  static const surfaceDark = Color(0xFF0E1311);
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: AppColors.forest,
        onPrimary: Colors.white,
        secondary: AppColors.lime,
        onSecondary: AppColors.ink,
        surface: AppColors.mist,
        onSurface: AppColors.ink,
        outline: const Color(0xFFD5DED8),
      ),
      scaffoldBackgroundColor: AppColors.mist,
    );
    return _withText(base);
  }

  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: AppColors.lime,
        onPrimary: AppColors.ink,
        secondary: AppColors.forest,
        onSecondary: Colors.white,
        surface: AppColors.surfaceDark,
        onSurface: const Color(0xFFE8F0EC),
        outline: const Color(0xFF2A342F),
      ),
      scaffoldBackgroundColor: AppColors.surfaceDark,
    );
    return _withText(base);
  }

  static ThemeData _withText(ThemeData base) {
    final textTheme = GoogleFonts.dmSansTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.outfit(
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
      ),
      displayMedium: GoogleFonts.outfit(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      headlineLarge: GoogleFonts.outfit(fontWeight: FontWeight.w600),
      headlineMedium: GoogleFonts.outfit(fontWeight: FontWeight.w600),
      headlineSmall: GoogleFonts.outfit(fontWeight: FontWeight.w600),
      titleLarge: GoogleFonts.outfit(fontWeight: FontWeight.w600),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: base.scaffoldBackgroundColor,
        foregroundColor: base.colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: base.colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: base.brightness == Brightness.light
            ? AppColors.cardLight
            : AppColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: base.brightness == Brightness.light
            ? Colors.white
            : AppColors.cardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: base.colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: base.colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: base.colorScheme.primary, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: base.brightness == Brightness.light
            ? Colors.white
            : AppColors.cardDark,
        indicatorColor: base.colorScheme.primary.withValues(alpha: 0.15),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary teal seperti referensi
  static const primary     = Color(0xFF0D9488);
  static const primaryDark = Color(0xFF0F766E);
  static const primaryLight= Color(0xFFCCFBF1);

  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const danger  = Color(0xFFEF4444);
  static const info    = Color(0xFF3B82F6);

  static const bg      = Color(0xFFF0FAFA);
  static const surface = Color(0xFFFFFFFF);
  static const card    = Color(0xFFFFFFFF);
  static const border  = Color(0xFFE5E7EB);

  static const textPrimary   = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textHint      = Color(0xFF9CA3AF);

  // Dark
  static const darkBg      = Color(0xFF0F172A);
  static const darkSurface = Color(0xFF1E293B);
  static const darkCard    = Color(0xFF1E293B);
}

class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      surface: AppColors.surface,
      background: AppColors.bg,
    ),
    scaffoldBackgroundColor: AppColors.bg,
    textTheme: GoogleFonts.nunitoTextTheme().apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    cardTheme: CardTheme(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 0.5),
      ),
      color: AppColors.card,
      margin: EdgeInsets.zero,
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(
        color: AppColors.textHint, fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 14),
        textStyle: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 8,
      shadowColor: Colors.black12,
      indicatorColor: AppColors.primaryLight,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          );
        }
        return const TextStyle(
          fontSize: 11,
          color: AppColors.textSecondary,
        );
      }),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 0.5,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20)),
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: AppColors.darkBg,
    textTheme: GoogleFonts.nunitoTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: Color(0xFF134E4A),
      foregroundColor: Colors.white,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.darkSurface,
    ),
  );
}

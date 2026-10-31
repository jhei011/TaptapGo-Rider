import 'package:flutter/material.dart';
import 'app_tokens.dart';

class AppTheme {
  // ── Light theme ─────────────────────────────────────────────────────────────
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: kSurfaceRaised,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kBrand600,
      primary: kActionPrimary,
      secondary: kBrand400,
      surface: kSurfaceBase,
      error: kActionDestructive,
      brightness: Brightness.light,
    ),
    textTheme: const TextTheme(
      bodyLarge:   TextStyle(color: kTextPrimary),
      bodyMedium:  TextStyle(color: kTextPrimary),
      bodySmall:   TextStyle(color: kTextSecondary),
      labelLarge:  TextStyle(color: kTextPrimary),
      labelMedium: TextStyle(color: kTextSecondary),
      labelSmall:  TextStyle(color: kTextMuted),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kSurfaceBase,
      foregroundColor: kTextPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: kHeadingMd,
      shape: Border(
        bottom: BorderSide(color: kBorderSubtle, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kActionPrimary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadiusLg)),
        elevation: 0,
        textStyle: kLabelLg,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurfaceBase,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: kSpace14, vertical: kSpace12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: kBorderDefault),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: kBorderDefault),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: kBrand500, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: kActionDestructive),
      ),
      hintStyle: kBodySm.copyWith(color: kTextMuted),
      labelStyle: kBodySm.copyWith(color: kTextSecondary),
    ),
    cardTheme: CardThemeData(
      color: kSurfaceBase,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusLg),
        side: const BorderSide(color: kBorderDefault),
      ),
      margin: const EdgeInsets.symmetric(vertical: kSpace4),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: kBrand900,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusMd)),
    ),
    dividerTheme: const DividerThemeData(
        color: kBorderSubtle, thickness: 1, space: 1),
  );

  // ── Dark theme ──────────────────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: kDarkSurfaceRaised,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kBrand600,
      primary: kBrand400,
      secondary: kBrand300,
      surface: kDarkSurfaceBase,
      error: kActionDestructive,
      brightness: Brightness.dark,
    ),
    textTheme: const TextTheme(
      bodyLarge:   TextStyle(color: kDarkTextPrimary),
      bodyMedium:  TextStyle(color: kDarkTextPrimary),
      bodySmall:   TextStyle(color: kDarkTextSecondary),
      labelLarge:  TextStyle(color: kDarkTextPrimary),
      labelMedium: TextStyle(color: kDarkTextSecondary),
      labelSmall:  TextStyle(color: kDarkTextMuted),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: kDarkSurfaceBase,
      foregroundColor: kDarkTextPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: kHeadingMd.copyWith(color: kDarkTextPrimary),
      shape: const Border(
        bottom: BorderSide(color: kDarkBorderDefault, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kBrand500,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadiusLg)),
        elevation: 0,
        textStyle: kLabelLg,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kDarkSurfaceBase,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: kSpace14, vertical: kSpace12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: kDarkBorderDefault),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: kDarkBorderDefault),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: kBrand400, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: kActionDestructive),
      ),
      hintStyle: kBodySm.copyWith(color: kDarkTextMuted),
      labelStyle: kBodySm.copyWith(color: kDarkTextSecondary),
    ),
    cardTheme: CardThemeData(
      color: kDarkSurfaceBase,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusLg),
        side: const BorderSide(color: kDarkBorderDefault),
      ),
      margin: const EdgeInsets.symmetric(vertical: kSpace4),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: kDarkSurfaceBase,
      contentTextStyle: const TextStyle(color: kDarkTextPrimary),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusMd)),
    ),
    dividerTheme: const DividerThemeData(
        color: kDarkBorderSubtle, thickness: 1, space: 1),
  );

  // ── Backward-compat alias ────────────────────────────────────────────────────
  /// Alias for [light]. Kept so existing code referencing `AppTheme.theme` keeps
  /// compiling unchanged.
  static ThemeData get theme => light;
}

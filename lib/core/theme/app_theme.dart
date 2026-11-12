import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'app_tokens.dart';

/// Visual theme for TaptapGo — matches TaptapShop Flutter exactly.
///
/// Colors come from app_tokens.dart (same palette as TaptapShop's app_colors.dart).
/// Both light and dark modes are supported.
class AppTheme {
  // ── Light theme ─────────────────────────────────────────────────────────────
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: kSurfaceRaised,

    // Smooth iOS-style slide for every page (matches TaptapShop)
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: _SmoothTransitions(),
      TargetPlatform.iOS:     _SmoothTransitions(),
      TargetPlatform.windows: _SmoothTransitions(),
      TargetPlatform.macOS:   _SmoothTransitions(),
      TargetPlatform.linux:   _SmoothTransitions(),
      TargetPlatform.fuchsia: _SmoothTransitions(),
    }),

    // Dialogs, sheets and popups use white surface — matches TaptapShop
    dialogTheme: const DialogThemeData(
      backgroundColor: kSurfaceBase,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(kRadiusXl)),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: kSurfaceBase,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusXl)),
      ),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: kSurfaceBase,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(kRadiusMd)),
      ),
    ),

    colorScheme: const ColorScheme(
      brightness:   Brightness.light,
      primary:      kBrand700,
      onPrimary:    Colors.white,
      secondary:    kBrand400,
      onSecondary:  Colors.white,
      surface:      kSurfaceBase,
      onSurface:    kTextPrimary,
      error:        kActionDestructive,
      onError:      Colors.white,
    ),

    textTheme: const TextTheme(
      bodyLarge:   TextStyle(color: kTextPrimary,   fontFamily: 'Inter'),
      bodyMedium:  TextStyle(color: kTextPrimary,   fontFamily: 'Inter'),
      bodySmall:   TextStyle(color: kTextSecondary, fontFamily: 'Inter'),
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
      shape: Border(bottom: BorderSide(color: kBorderSubtle, width: 1)),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kBrand700,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadiusLg)),
        elevation: 0,
        textStyle: kLabelLg,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kBrand700,
        minimumSize: const Size(double.infinity, 48),
        side: const BorderSide(color: kBrand700),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadiusLg)),
        textStyle: kLabelLg,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kBrand700,
        textStyle: kLabelMd,
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurfaceBase,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: kSpace14, vertical: kSpace12),
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
        borderSide: const BorderSide(color: kBrand600, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: kActionDestructive),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: kActionDestructive, width: 1.5),
      ),
      hintStyle: kBodySm.copyWith(color: kTextMuted),
      labelStyle: kBodySm.copyWith(color: kTextSecondary),
    ),

    cardTheme: CardThemeData(
      color: kSurfaceBase,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusLg),
        side: const BorderSide(color: kBrand100),
      ),
      margin: const EdgeInsets.symmetric(vertical: kSpace4),
    ),

    // Floating snackbar — deep navy like TaptapShop
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: kBrand900,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusMd)),
    ),

    dividerTheme: const DividerThemeData(
        color: kBorderSubtle, thickness: 1, space: 1),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? kBrand600 : null),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? kBrand600 : null),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? kBrand200
              : kBorderDefault),
    ),
  );

  // ── Dark theme ──────────────────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: kDarkSurfaceRaised,

    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: _SmoothTransitions(),
      TargetPlatform.iOS:     _SmoothTransitions(),
      TargetPlatform.windows: _SmoothTransitions(),
      TargetPlatform.macOS:   _SmoothTransitions(),
      TargetPlatform.linux:   _SmoothTransitions(),
      TargetPlatform.fuchsia: _SmoothTransitions(),
    }),

    dialogTheme: const DialogThemeData(
      backgroundColor: kDarkSurfaceBase,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(kRadiusXl)),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: kDarkSurfaceBase,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusXl)),
      ),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: kDarkSurfaceBase,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(kRadiusMd)),
      ),
    ),

    colorScheme: const ColorScheme(
      brightness:   Brightness.dark,
      primary:      kBrand400,
      onPrimary:    Colors.white,
      secondary:    kBrand300,
      onSecondary:  Colors.white,
      surface:      kDarkSurfaceBase,
      onSurface:    kDarkTextPrimary,
      error:        kActionDestructive,
      onError:      Colors.white,
    ),

    textTheme: const TextTheme(
      bodyLarge:   TextStyle(color: kDarkTextPrimary,   fontFamily: 'Inter'),
      bodyMedium:  TextStyle(color: kDarkTextPrimary,   fontFamily: 'Inter'),
      bodySmall:   TextStyle(color: kDarkTextSecondary, fontFamily: 'Inter'),
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
          bottom: BorderSide(color: kDarkBorderDefault, width: 1)),
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

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kBrand400,
        minimumSize: const Size(double.infinity, 48),
        side: const BorderSide(color: kBrand400),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadiusLg)),
        textStyle: kLabelLg,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kBrand400,
        textStyle: kLabelMd,
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kDarkSurfaceBase,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: kSpace14, vertical: kSpace12),
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
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide:
            const BorderSide(color: kActionDestructive, width: 1.5),
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
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusMd)),
    ),

    dividerTheme: const DividerThemeData(
        color: kDarkBorderSubtle, thickness: 1, space: 1),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? kBrand400 : null),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? kBrand400 : null),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? kDarkBorderDefault
              : kDarkBorderDefault),
    ),
  );

  /// Alias kept for legacy callers.
  static ThemeData get theme => light;
}

// ── Smooth slide transition (same as TaptapShop) ──────────────────────────────
class _SmoothTransitions extends PageTransitionsBuilder {
  const _SmoothTransitions();
  static const _ios = CupertinoPageTransitionsBuilder();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      _ios.buildTransitions(
          route, context, animation, secondaryAnimation, child);
}

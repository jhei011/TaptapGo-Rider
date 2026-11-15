import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'app_tokens.dart';

/// Visual theme for TaptapGo, built like TaptapShop Flutter's AppTheme
/// (lib/core/theme/app_theme.dart): navy header, teal buttons with 10 px corners,
/// 8 px inputs, 12 px bordered cards and a navy floating snackbar, in light and dark.
///
/// Button sizes stay TaptapGo's (full width, 48 tall) so rider screens keep their layout.
class AppTheme {
  static ThemeData get light => _build(AppPalette.lightValues, Brightness.light);
  static ThemeData get dark => _build(AppPalette.darkValues, Brightness.dark);

  /// Alias kept for legacy callers.
  static ThemeData get theme => light;

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    // Teal that reads on the page: the TaptapShop "b700", lighter in dark mode
    final teal = p.brand700;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: p.surfaceRaised,
      canvasColor: p.surfaceBase,

      // Every page that opens or closes uses the same smooth slide (TaptapShop)
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: _SmoothTransitions(),
        TargetPlatform.iOS:     _SmoothTransitions(),
        TargetPlatform.windows: _SmoothTransitions(),
        TargetPlatform.macOS:   _SmoothTransitions(),
        TargetPlatform.linux:   _SmoothTransitions(),
        TargetPlatform.fuchsia: _SmoothTransitions(),
      }),

      dialogTheme: DialogThemeData(backgroundColor: p.surfaceBase, surfaceTintColor: Colors.transparent),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surfaceBase,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
      ),
      popupMenuTheme: PopupMenuThemeData(color: p.surfaceBase, surfaceTintColor: Colors.transparent),

      colorScheme: ColorScheme.fromSeed(
        seedColor: kBrand600,
        brightness: brightness,
        primary: teal,
        onPrimary: Colors.white,
        secondary: kBrand400,
        surface: p.surfaceBase,
        onSurface: p.textPrimary,
        error: p.danger,
      ),

      textTheme: TextTheme(
        bodyLarge:   TextStyle(fontFamily: 'Inter', color: p.textPrimary),
        bodyMedium:  TextStyle(fontFamily: 'Inter', color: p.textPrimary),
        bodySmall:   TextStyle(fontFamily: 'Inter', color: p.textSecondary),
        labelLarge:  TextStyle(color: p.textPrimary),
        labelMedium: TextStyle(color: p.textSecondary),
        labelSmall:  TextStyle(color: p.textMuted),
      ),

      // Navy header with white title and icons (TaptapShop appBarTheme)
      appBarTheme: const AppBarTheme(
        backgroundColor: kBrand900,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.2),
        shadowColor: Colors.black26,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kBrand700Fill,
          foregroundColor: Colors.white,
          disabledBackgroundColor: isDark ? const Color(0xFF3A3945) : const Color(0xFFD1D5DB),
          disabledForegroundColor: isDark ? const Color(0xFF8A8996) : Colors.white,
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusButton)),
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: teal,
          minimumSize: const Size(double.infinity, 48),
          side: BorderSide(color: isDark ? p.borderStrong : teal),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusButton)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: teal,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceBase,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadiusInput),
          borderSide: BorderSide(color: p.borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadiusInput),
          borderSide: BorderSide(color: p.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadiusInput),
          borderSide: const BorderSide(color: kBrand600, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadiusInput),
          borderSide: BorderSide(color: p.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadiusInput),
          borderSide: BorderSide(color: p.danger, width: 1.5),
        ),
        hintStyle: TextStyle(color: p.textMuted, fontSize: 13),
        labelStyle: TextStyle(color: p.textSecondary, fontSize: 13),
        errorStyle: TextStyle(color: p.danger, fontSize: 12),
      ),

      cardTheme: CardThemeData(
        color: p.surfaceBase,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusLg),
          side: BorderSide(color: p.borderDefault),
        ),
        margin: const EdgeInsets.symmetric(vertical: 5),
      ),

      // Floating navy snackbar in both modes (TaptapShop)
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: kBrand900,
        contentTextStyle: const TextStyle(color: Colors.white),
        actionTextColor: kBrandMint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusMd)),
      ),

      dividerTheme: DividerThemeData(color: p.borderSubtle, thickness: 1, space: 1),

      progressIndicatorTheme: ProgressIndicatorThemeData(color: isDark ? kTealOnDark : kBrand600),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? kBrand600 : null),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // TaptapShop's switch: white thumb on a teal track when on
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? (isDark ? kTealOnDark : kBrand600) : null),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? (isDark ? kTealOnDark : kBrand600) : null),
      ),
    );
  }
}

// ── Smooth slide transition (same as TaptapShop) ──────────────────────────────
/// A full, smooth slide for every page: the new page slides in from the right while the page
/// behind shifts left; a swipe from the left edge goes back, following the finger.
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
      _ios.buildTransitions(route, context, animation, secondaryAnimation, child);
}

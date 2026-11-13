import 'package:flutter/material.dart';

/// TaptapGo design tokens: the TaptapShop palette (TaptapShop Flutter, lib/core/theme/app_colors.dart),
/// in light and dark.
///
/// Brand colours are constants. Backgrounds, cards, borders, text and the light tints switch with
/// [AppPalette.dark], which [PaletteSync] (in main.dart) keeps in step with the app's theme, so a
/// screen that reads `kSurfaceBase` or `kTextPrimary` is right in both modes.
class AppPalette {
  /// True while the app shows its dark theme.
  static bool dark = false;

  final Color surfaceBase, surfaceRaised, surfaceSunken;
  final Color borderDefault, borderSubtle, borderStrong, inputBorder;
  final Color textPrimary, textSecondary, textMuted;
  final Color brand50, brand100, brand200, brand700;
  final Color pendingBg, pendingFg, pickupBg, pickupFg, onWayBg, onWayFg;
  final Color deliveredBg, deliveredFg, failedBg, failedFg, cancelledBg, cancelledFg;
  final Color danger;

  const AppPalette._({
    required this.surfaceBase, required this.surfaceRaised, required this.surfaceSunken,
    required this.borderDefault, required this.borderSubtle, required this.borderStrong, required this.inputBorder,
    required this.textPrimary, required this.textSecondary, required this.textMuted,
    required this.brand50, required this.brand100, required this.brand200, required this.brand700,
    required this.pendingBg, required this.pendingFg, required this.pickupBg, required this.pickupFg,
    required this.onWayBg, required this.onWayFg, required this.deliveredBg, required this.deliveredFg,
    required this.failedBg, required this.failedFg, required this.cancelledBg, required this.cancelledFg,
    required this.danger,
  });

  /// TaptapShop light mode.
  static const lightValues = AppPalette._(
    surfaceBase: Color(0xFFFFFFFF), surfaceRaised: Color(0xFFF5F6F4), surfaceSunken: Color(0xFFF3F4F6),
    borderDefault: Color(0xFFE5E7EB), borderSubtle: Color(0xFFF1F3F2), borderStrong: Color(0xFFD1D5DB),
    inputBorder: Color(0xFFE2E5E4),
    textPrimary: Color(0xFF1F2937), textSecondary: Color(0xFF6B7280), textMuted: Color(0xFF9CA3AF),
    brand50: Color(0xFFEEF8F7), brand100: Color(0xFFD8EFEC), brand200: Color(0xFFB4DEDB), brand700: Color(0xFF1F5F66),
    pendingBg: Color(0xFFFBF1E0), pendingFg: Color(0xFFB8802C),
    pickupBg: Color(0xFFF1EEF8), pickupFg: Color(0xFF6D5A9C),
    onWayBg: Color(0xFFEEF3FB), onWayFg: Color(0xFF3457A6),
    deliveredBg: Color(0xFFEAF7EF), deliveredFg: Color(0xFF2E7D4F),
    failedBg: Color(0xFFFDF0EE), failedFg: Color(0xFFC0392B),
    cancelledBg: Color(0xFFF3F4F6), cancelledFg: Color(0xFF6B7280),
    danger: Color(0xFFC0392B),
  );

  /// TaptapShop dark mode: dark grey cards on a darker page.
  static const darkValues = AppPalette._(
    surfaceBase: Color(0xFF26252F), surfaceRaised: Color(0xFF1C1B22), surfaceSunken: Color(0xFF33323D),
    borderDefault: Color(0xFF3A3945), borderSubtle: Color(0xFF3A3945), borderStrong: Color(0xFF4A4956),
    inputBorder: Color(0xFF3A3945),
    textPrimary: Color(0xFFECECF1), textSecondary: Color(0xFFB3B2BD), textMuted: Color(0xFF8A8996),
    brand50: Color(0xFF1B3A3E), brand100: Color(0xFF214A4F), brand200: Color(0xFF5A8C91), brand700: Color(0xFF4FAAB0),
    pendingBg: Color(0xFF3D3222), pendingFg: Color(0xFFE0A85A),
    pickupBg: Color(0xFF302A40), pickupFg: Color(0xFFA996D8),
    onWayBg: Color(0xFF242E42), onWayFg: Color(0xFF8AA6E8),
    deliveredBg: Color(0xFF1F3628), deliveredFg: Color(0xFF5CC489),
    failedBg: Color(0xFF402624), failedFg: Color(0xFFE5675A),
    cancelledBg: Color(0xFF33323D), cancelledFg: Color(0xFFB3B2BD),
    danger: Color(0xFFE5675A),
  );

  static AppPalette get current => dark ? darkValues : lightValues;
}

AppPalette get _p => AppPalette.current;

// ── Brand color scale ─────────────────────────────────────────────────────────
// The light tints are backgrounds, so they darken in dark mode; kBrand700 is teal
// text and icons, so it lightens to stay readable on dark cards.
Color get kBrand50  => _p.brand50;
Color get kBrand100 => _p.brand100;
Color get kBrand200 => _p.brand200;
const Color kBrand300 = Color(0xFF8FCAC6);
const Color kBrand400 = Color(0xFF4A949C);
const Color kBrand500 = Color(0xFF357F85);
const Color kBrand600 = Color(0xFF2E7C82);
Color get kBrand700 => _p.brand700;
const Color kBrand800 = Color(0xFF173F47);
const Color kBrand900 = Color(0xFF0E2A38);

/// Fills behind white text keep their depth in both modes.
const Color kBrand700Fill = Color(0xFF1F5F66);
/// Teal for text and icons on dark or navy backgrounds.
const Color kTealOnDark = Color(0xFF5DB8BE);
/// The light teal of "Go" / "Shop" in the header logo.
const Color kBrandMint = Color(0xFFCDEAE7);

// ── Header and primary gradients (TaptapShop navbarGrad / primaryGrad) ─────────
const LinearGradient kHeaderGradient = LinearGradient(
  colors: [Color(0xFF0E2A38), Color(0xFF1F4F5C), Color(0xFF1F5F66)],
  stops: [0, 0.65, 1],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);
const LinearGradient kPrimaryGradient = LinearGradient(
  colors: [Color(0xFF0E2A38), Color(0xFF4A949C)],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);
const LinearGradient kHeroGradient = LinearGradient(
  colors: [Color(0xFF0E2A38), Color(0xFF1F4F5C), Color(0xFF1F5F66)],
  stops: [0, 0.6, 1],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ── Surface tokens ────────────────────────────────────────────────────────────
Color get kSurfaceBase   => _p.surfaceBase;
Color get kSurfaceRaised => _p.surfaceRaised;
Color get kSurfaceSunken => _p.surfaceSunken;

// ── Border tokens ─────────────────────────────────────────────────────────────
Color get kBorderDefault => _p.borderDefault;
Color get kBorderSubtle  => _p.borderSubtle;
Color get kBorderStrong  => _p.borderStrong;
Color get kInputBorder   => _p.inputBorder;

// ── Text tokens ───────────────────────────────────────────────────────────────
Color get kTextPrimary   => _p.textPrimary;
Color get kTextSecondary => _p.textSecondary;
Color get kTextMuted     => _p.textMuted;

// ── Fixed dark values (for code that picks a mode itself) ─────────────────────
const Color kDarkSurfaceBase   = Color(0xFF26252F);
const Color kDarkSurfaceRaised = Color(0xFF1C1B22);
const Color kDarkSurfaceSunken = Color(0xFF33323D);
const Color kDarkBorderDefault = Color(0xFF3A3945);
const Color kDarkBorderSubtle  = Color(0xFF3A3945);
const Color kDarkTextPrimary   = Color(0xFFECECF1);
const Color kDarkTextSecondary = Color(0xFFB3B2BD);
const Color kDarkTextMuted     = Color(0xFF8A8996);

// ── Action tokens ─────────────────────────────────────────────────────────────
const Color kActionPrimary     = Color(0xFF2E7C82); // kBrand600
/// Red fill behind white text (buttons, snackbars); the same in both modes.
const Color kActionDestructive = Color(0xFFC0392B);
/// Red for text and icons: lighter in dark mode so it reads on dark cards.
Color get kDanger => _p.danger;

// ── Online / Offline status tokens ───────────────────────────────────────────
Color get kOnlineBg  => _p.deliveredBg;
Color get kOnlineFg  => _p.deliveredFg;
Color get kOfflineBg => _p.cancelledBg;
Color get kOfflineFg => _p.cancelledFg;

// ── Status colors (follow the mode) ───────────────────────────────────────────
Color get kStatusPendingBg   => _p.pendingBg;
Color get kStatusPendingFg   => _p.pendingFg;
Color get kStatusPickupBg    => _p.pickupBg;
Color get kStatusPickupFg    => _p.pickupFg;
Color get kStatusOnWayBg     => _p.onWayBg;
Color get kStatusOnWayFg     => _p.onWayFg;
Color get kStatusDeliveredBg => _p.deliveredBg;
Color get kStatusDeliveredFg => _p.deliveredFg;
Color get kStatusFailedBg    => _p.failedBg;
Color get kStatusFailedFg    => _p.failedFg;
Color get kStatusCancelledBg => _p.cancelledBg;
Color get kStatusCancelledFg => _p.cancelledFg;

// ── Status — fixed dark values ────────────────────────────────────────────────
const Color kDarkStatusPendingBg   = Color(0xFF3D3222);
const Color kDarkStatusPendingFg   = Color(0xFFE0A85A);
const Color kDarkStatusPickupBg    = Color(0xFF302A40);
const Color kDarkStatusPickupFg    = Color(0xFFA996D8);
const Color kDarkStatusOnWayBg     = Color(0xFF242E42);
const Color kDarkStatusOnWayFg     = Color(0xFF8AA6E8);
const Color kDarkStatusDeliveredBg = Color(0xFF1F3628);
const Color kDarkStatusDeliveredFg = Color(0xFF5CC489);
const Color kDarkStatusFailedBg    = Color(0xFF402624);
const Color kDarkStatusFailedFg    = Color(0xFFE5675A);
const Color kDarkStatusCancelledBg = Color(0xFF33323D);
const Color kDarkStatusCancelledFg = Color(0xFFB3B2BD);

// ── Radius tokens (TaptapShop: inputs 8, buttons 10, cards 12, menus 14) ───────
const double kRadiusSm     = 6;
const double kRadiusInput  = 8;
const double kRadiusMd     = 10;
const double kRadiusButton = 10;
const double kRadiusLg     = 12;
const double kRadiusMenu   = 14;
const double kRadiusXl     = 20;
const double kRadiusNavBar = 22;
const double kRadiusFull   = 999;

// ── Elevation (TaptapShop FieldCard and header shadows) ───────────────────────
const List<BoxShadow> kCardShadow = [BoxShadow(color: Color(0x060E2A38), blurRadius: 8, offset: Offset(0, 2))];
const List<BoxShadow> kRaisedShadow = [BoxShadow(color: Color(0x120E2A38), blurRadius: 12, offset: Offset(0, 4))];

// ── Spacing tokens ────────────────────────────────────────────────────────────
const double kSpace2  = 2;
const double kSpace4  = 4;
const double kSpace6  = 6;
const double kSpace8  = 8;
const double kSpace10 = 10;
const double kSpace12 = 12;
const double kSpace14 = 14;
const double kSpace16 = 16;
const double kSpace20 = 20;
const double kSpace24 = 24;
const double kSpace28 = 28;
const double kSpace32 = 32;
const double kSpace40 = 40;
const double kSpace48 = 48;

// ── Typography tokens (colour follows the mode) ───────────────────────────────
TextStyle get kDisplayLg => TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.5, color: kTextPrimary);
TextStyle get kDisplayMd => TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.3, color: kTextPrimary);
TextStyle get kDisplaySm => TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.3, color: kTextPrimary);
/// TaptapShop page title, under the header.
TextStyle get kPageTitle => TextStyle(fontSize: 19, fontWeight: FontWeight.w800, height: 1.2, color: kTextPrimary);
TextStyle get kHeadingLg => TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.4, color: kTextPrimary);
TextStyle get kHeadingMd => TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.4, color: kTextPrimary);
TextStyle get kHeadingSm => TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.4, color: kTextPrimary);
TextStyle get kBodyLg => TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.6, color: kTextPrimary);
TextStyle get kBodyMd => TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.6, color: kTextPrimary);
TextStyle get kBodySm => TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.5, color: kTextPrimary);
TextStyle get kLabelLg => TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.4, letterSpacing: 0.4, color: kTextPrimary);
TextStyle get kLabelMd => TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.4, letterSpacing: 0.2, color: kTextPrimary);
TextStyle get kLabelSm => TextStyle(fontSize: 10, fontWeight: FontWeight.w600, height: 1.4, letterSpacing: 0.2, color: kTextPrimary);
TextStyle get kMonoMd => TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.4, fontFamily: 'monospace', color: kTextPrimary);

import 'package:flutter/material.dart';
import 'app_tokens.dart';

/// Exact match to the Laravel CSS variables used across every Blade view, and to TaptapShop
/// Flutter's `C` (lib/core/theme/app_colors.dart).
///
/// Brand colours stay the same in dark mode. Backgrounds, cards, borders, text and the light
/// tints follow [AppPalette.dark], which PaletteSync keeps in step with the app's theme.
class C {
  /// True while dark mode is on.
  static bool get dark => AppPalette.dark;

  /// For colours written straight into a screen: [light] normally, [darkColor] in dark mode.
  static Color adapt(Color light, Color darkColor) => dark ? darkColor : light;

  // Gradient palette
  static const Color grad1 = Color(0xFF0E2A38); // deep navy
  static const Color grad2 = Color(0xFF1F4F5C);
  static const Color grad3 = Color(0xFF4A949C); // teal
  static const Color grad4 = Color(0xFFCDEAE7);
  static const Color grad5 = Color(0xFFFDF1DE); // cream

  // Brand scale — the light tints are backgrounds, so they darken in dark mode
  static Color get b50  => dark ? const Color(0xFF1B3A3E) : const Color(0xFFEEF8F7);
  static Color get b100 => dark ? const Color(0xFF214A4F) : const Color(0xFFD8EFEC);
  static Color get b200 => dark ? const Color(0xFF5A8C91) : const Color(0xFFB4DEDB);
  static const Color b600 = Color(0xFF2E7C82);
  // Used for teal text and buttons; lighter in dark mode so it reads on dark cards
  static Color get b700 => dark ? const Color(0xFF4FAAB0) : _b700;
  static const Color _b700 = Color(0xFF1F5F66);
  // Fills behind white text keep their depth in both modes, so the text stays readable
  static const Color b700Fill   = _b700;
  static const Color dangerFill = Color(0xFFC0392B);
  // Teal for text and icons on dark backgrounds (dark teals and navies are unreadable there)
  static const Color tealOnDark = Color(0xFF5DB8BE);
  static const Color b800 = Color(0xFF173F47);
  static const Color b900 = Color(0xFF0E2A38);

  // Cream
  static Color get cream     => dark ? const Color(0xFF3A3226) : const Color(0xFFFDF1DE);
  static Color get creamDark => dark ? const Color(0xFF8C7650) : const Color(0xFFF2DCB8);

  // Semantic — text colours lighten and their tinted backgrounds darken in dark mode
  static Color get danger    => dark ? const Color(0xFFE5675A) : const Color(0xFFC0392B);
  static Color get dangerBg  => dark ? const Color(0xFF402624) : const Color(0xFFFDF0EE);
  static Color get warn      => dark ? const Color(0xFFE0A85A) : const Color(0xFFB8802C);
  static Color get warnBg    => dark ? const Color(0xFF3D3222) : const Color(0xFFFBF1E0);
  static Color get plum      => dark ? const Color(0xFFA996D8) : const Color(0xFF6D5A9C);
  static Color get plumBg    => dark ? const Color(0xFF302A40) : const Color(0xFFF1EEF8);
  static Color get amber2    => dark ? const Color(0xFFD98A62) : const Color(0xFFA1552F);
  static Color get amber2Bg  => dark ? const Color(0xFF3D2C24) : const Color(0xFFFAEEE6);
  static Color get delivered => dark ? const Color(0xFF5CC489) : const Color(0xFF2E7D4F);
  static Color get deliveredBg => dark ? const Color(0xFF1F3628) : const Color(0xFFEAF7EF);
  static Color get outBg     => dark ? const Color(0xFF242E42) : const Color(0xFFEEF3FB);
  static Color get outFg     => dark ? const Color(0xFF8AA6E8) : const Color(0xFF3457A6);

  // UI — dark grey cards on a darker page
  static Color get bg      => dark ? const Color(0xFF1C1B22) : const Color(0xFFF5F6F4);
  static Color get surface => dark ? const Color(0xFF26252F) : const Color(0xFFFFFFFF);
  static Color get border  => dark ? const Color(0xFF3A3945) : const Color(0xFFE5E7EB);
  static Color get textPrimary   => dark ? const Color(0xFFECECF1) : const Color(0xFF1F2937);
  static Color get textSecondary => dark ? const Color(0xFFB3B2BD) : const Color(0xFF6B7280);
  static Color get textMuted     => dark ? const Color(0xFF8A8996) : const Color(0xFF9CA3AF);
  static Color get gray50        => dark ? const Color(0xFF2C2B36) : const Color(0xFFF9FAFB);
  static Color get gray100       => dark ? const Color(0xFF33323D) : const Color(0xFFF3F4F6);

  // Gradients (the same in both modes)
  static const LinearGradient navbarGrad = kHeaderGradient;
  static const LinearGradient sidebarGrad = LinearGradient(
    colors: [grad1, grad2, _b700],
    stops: [0, 0.65, 1],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static const LinearGradient primaryGrad = kPrimaryGradient;
  static const LinearGradient heroGrad = kHeroGradient;

  // Status pill helper
  static ({Color bg, Color fg}) statusColors(String status) => switch (status) {
    'pending'          => (bg: warnBg,      fg: warn),
    'confirmed'        => (bg: b50,         fg: b700),
    'ready_for_pickup' => (bg: plumBg,      fg: plum),
    'assigned'         => (bg: plumBg,      fg: plum),
    'in_transit'       => (bg: outBg,       fg: outFg),
    'out_for_delivery' => (bg: outBg,       fg: outFg),
    'delivered'        => (bg: deliveredBg, fg: delivered),
    'cancelled'        => (bg: dangerBg,    fg: danger),
    'failed_delivery'  => (bg: dangerBg,    fg: danger),
    'return_to_sender' => (bg: dangerBg,    fg: danger),
    'active'           => (bg: b50,         fg: b700),
    'inactive'         => (bg: gray100,     fg: textSecondary),
    'approved'         => (bg: deliveredBg, fg: delivered),
    'suspended'        => (bg: dangerBg,    fg: danger),
    _ => (bg: gray100, fg: textSecondary),
  };
}

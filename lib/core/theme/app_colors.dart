import 'package:flutter/material.dart';
import 'app_tokens.dart'; // ignore: unused_import — re-exported for convenience

/// Exact match to the Laravel CSS variables used across every Blade view
class C {
  // Gradient palette
  static const Color grad1 = Color(0xFF0E2A38); // deep navy
  static const Color grad2 = Color(0xFF1F4F5C);
  static const Color grad3 = Color(0xFF4A949C); // teal
  static const Color grad4 = Color(0xFFCDEAE7);
  static const Color grad5 = Color(0xFFFDF1DE); // cream

  // Brand scale
  static const Color b50  = Color(0xFFEEF8F7);
  static const Color b100 = Color(0xFFD8EFEC);
  static const Color b200 = Color(0xFFB4DEDB);
  static const Color b600 = Color(0xFF2E7C82);
  static const Color b700 = Color(0xFF1F5F66);
  static const Color b800 = Color(0xFF173F47);
  static const Color b900 = Color(0xFF0E2A38);

  // Cream
  static const Color cream     = Color(0xFFFDF1DE);
  static const Color creamDark = Color(0xFFF2DCB8);

  // Semantic
  static const Color danger    = Color(0xFFC0392B);
  static const Color dangerBg  = Color(0xFFFDF0EE);
  static const Color warn      = Color(0xFFB8802C);
  static const Color warnBg    = Color(0xFFFBF1E0);
  static const Color plum      = Color(0xFF6D5A9C);
  static const Color plumBg    = Color(0xFFF1EEF8);
  static const Color amber2    = Color(0xFFA1552F);
  static const Color amber2Bg  = Color(0xFFFAEEE6);
  static const Color delivered = Color(0xFF2E7D4F);
  static const Color deliveredBg = Color(0xFFEAF7EF);
  static const Color outBg     = Color(0xFFEEF3FB);
  static const Color outFg     = Color(0xFF3457A6);

  // UI
  static const Color bg      = Color(0xFFF5F6F4);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border  = Color(0xFFE5E7EB);
  static const Color textPrimary   = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted     = Color(0xFF9CA3AF);
  static const Color gray50        = Color(0xFFF9FAFB);
  static const Color gray100       = Color(0xFFF3F4F6);

  // Gradients
  static const LinearGradient navbarGrad = LinearGradient(
    colors: [grad1, grad2, b700],
    stops: [0, 0.65, 1],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  static const LinearGradient sidebarGrad = LinearGradient(
    colors: [grad1, grad2, b700],
    stops: [0, 0.65, 1],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static const LinearGradient primaryGrad = LinearGradient(
    colors: [grad1, grad3],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  static const LinearGradient heroGrad = LinearGradient(
    colors: [grad1, grad2, b700],
    stops: [0, 0.6, 1],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Status pill helper
  static ({Color bg, Color fg}) statusColors(String status) => switch (status) {
    'pending'          => (bg: warnBg,      fg: warn),
    'confirmed'        => (bg: b50,         fg: b700),
    'ready_for_pickup' => (bg: plumBg,      fg: plum),
    'out_for_delivery' => (bg: outBg,       fg: outFg),
    'delivered'        => (bg: deliveredBg, fg: delivered),
    'cancelled'        => (bg: dangerBg,    fg: danger),
    'active'           => (bg: b50,         fg: b700),
    'inactive'         => (bg: gray100,     fg: textSecondary),
    'approved'         => (bg: deliveredBg, fg: delivered),
    'suspended'        => (bg: dangerBg,    fg: danger),
    _ => (bg: gray100, fg: textSecondary),
  };
}

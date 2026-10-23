import 'package:flutter/material.dart';

// ── Brand color scale ─────────────────────────────────────────────────────────
const Color kBrand50  = Color(0xFFEEF8F7);
const Color kBrand100 = Color(0xFFD8EFEC);
const Color kBrand200 = Color(0xFFB4DEDB);
const Color kBrand300 = Color(0xFF8FCAC6);
const Color kBrand400 = Color(0xFF4A949C);
const Color kBrand500 = Color(0xFF357F85);
const Color kBrand600 = Color(0xFF2E7C82);
const Color kBrand700 = Color(0xFF1F5F66);
const Color kBrand800 = Color(0xFF173F47);
const Color kBrand900 = Color(0xFF0E2A38);

// ── Surface tokens ────────────────────────────────────────────────────────────
const Color kSurfaceBase   = Color(0xFFFFFFFF);
const Color kSurfaceRaised = Color(0xFFF5F6F4);
const Color kSurfaceSunken = Color(0xFFEEF0EE);

// ── Border tokens ─────────────────────────────────────────────────────────────
const Color kBorderDefault = Color(0xFFE5E7EB);
const Color kBorderSubtle  = Color(0xFFF1F3F2);
const Color kBorderStrong  = Color(0xFFD1D5DB);

// ── Text tokens ───────────────────────────────────────────────────────────────
const Color kTextPrimary   = Color(0xFF1F2937);
const Color kTextSecondary = Color(0xFF6B7280);
const Color kTextMuted     = Color(0xFF9CA3AF);

// ── Dark surface tokens ───────────────────────────────────────────────────────
const Color kDarkSurfaceBase   = Color(0xFF0F1923);
const Color kDarkSurfaceRaised = Color(0xFF1A2530);
const Color kDarkSurfaceSunken = Color(0xFF0A1118);

// ── Dark border tokens ────────────────────────────────────────────────────────
const Color kDarkBorderDefault = Color(0xFF2A3A44);
const Color kDarkBorderSubtle  = Color(0xFF1F2E38);

// ── Dark text tokens ──────────────────────────────────────────────────────────
const Color kDarkTextPrimary   = Color(0xFFF3F4F6);
const Color kDarkTextSecondary = Color(0xFF9CA3AF);
const Color kDarkTextMuted     = Color(0xFF6B7280);

// ── Action tokens ─────────────────────────────────────────────────────────────
const Color kActionPrimary     = Color(0xFF2E7C82); // kBrand600
const Color kActionDestructive = Color(0xFFC0392B);

// ── Online / Offline status tokens ───────────────────────────────────────────
const Color kOnlineBg  = Color(0xFFEAF7EF);
const Color kOnlineFg  = Color(0xFF2E7D4F);
const Color kOfflineBg = Color(0xFFF3F4F6);
const Color kOfflineFg = Color(0xFF6B7280);

// ── Status — light mode ───────────────────────────────────────────────────────
const Color kStatusPendingBg   = Color(0xFFFBF1E0);
const Color kStatusPendingFg   = Color(0xFFB8802C);
const Color kStatusPickupBg    = Color(0xFFF1EEF8);
const Color kStatusPickupFg    = Color(0xFF6D5A9C);
const Color kStatusOnWayBg     = Color(0xFFEEF3FB);
const Color kStatusOnWayFg     = Color(0xFF3457A6);
const Color kStatusDeliveredBg = Color(0xFFEAF7EF);
const Color kStatusDeliveredFg = Color(0xFF2E7D4F);
const Color kStatusFailedBg    = Color(0xFFFDF0EE);
const Color kStatusFailedFg    = Color(0xFFC0392B);
const Color kStatusCancelledBg = Color(0xFFF3F4F6);
const Color kStatusCancelledFg = Color(0xFF6B7280);

// ── Status — dark mode ────────────────────────────────────────────────────────
const Color kDarkStatusPendingBg   = Color(0xFF2C2010);
const Color kDarkStatusPendingFg   = Color(0xFFE8B86D);
const Color kDarkStatusPickupBg    = Color(0xFF1E1A2C);
const Color kDarkStatusPickupFg    = Color(0xFFA89BD0);
const Color kDarkStatusOnWayBg     = Color(0xFF1A1F2E);
const Color kDarkStatusOnWayFg     = Color(0xFF7A9CD4);
const Color kDarkStatusDeliveredBg = Color(0xFF102018);
const Color kDarkStatusDeliveredFg = Color(0xFF5DBB86);
const Color kDarkStatusFailedBg    = Color(0xFF2C1010);
const Color kDarkStatusFailedFg    = Color(0xFFE07070);
const Color kDarkStatusCancelledBg = Color(0xFF1A1F24);
const Color kDarkStatusCancelledFg = Color(0xFF9CA3AF);

// ── Radius tokens ─────────────────────────────────────────────────────────────
const double kRadiusSm   = 6;
const double kRadiusMd   = 10;
const double kRadiusLg   = 14;
const double kRadiusXl   = 20;
const double kRadiusFull = 999;

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

// ── Typography tokens ─────────────────────────────────────────────────────────
const TextStyle kDisplayLg = TextStyle(
  fontSize: 30,
  fontWeight: FontWeight.w800,
  height: 1.2,
  letterSpacing: -0.5,
  color: kTextPrimary,
);

const TextStyle kDisplayMd = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.w800,
  height: 1.2,
  letterSpacing: -0.3,
  color: kTextPrimary,
);

const TextStyle kDisplaySm = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.w700,
  height: 1.3,
  color: kTextPrimary,
);

const TextStyle kHeadingLg = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w700,
  height: 1.4,
  color: kTextPrimary,
);

const TextStyle kHeadingMd = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w700,
  height: 1.4,
  color: kTextPrimary,
);

const TextStyle kHeadingSm = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w700,
  height: 1.4,
  color: kTextPrimary,
);

const TextStyle kBodyLg = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w400,
  height: 1.6,
  color: kTextPrimary,
);

const TextStyle kBodyMd = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w400,
  height: 1.6,
  color: kTextPrimary,
);

const TextStyle kBodySm = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w400,
  height: 1.5,
  color: kTextPrimary,
);

const TextStyle kLabelLg = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w600,
  height: 1.4,
  letterSpacing: 0.4,
  color: kTextPrimary,
);

const TextStyle kLabelMd = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  height: 1.4,
  letterSpacing: 0.2,
  color: kTextPrimary,
);

const TextStyle kLabelSm = TextStyle(
  fontSize: 10,
  fontWeight: FontWeight.w600,
  height: 1.4,
  letterSpacing: 0.2,
  color: kTextPrimary,
);

const TextStyle kMonoMd = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w500,
  height: 1.4,
  fontFamily: 'monospace',
  color: kTextPrimary,
);

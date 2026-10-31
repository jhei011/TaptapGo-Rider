# Phase A — Theme Tokens, Navigation Shell, and Screen Restyle

Phase A lays the design-system foundation (token layer, dark-mode theming, connectivity widget, shared UI components) and restyles all six courier-facing screens and the login screen. The navigation shell replaces the stock `NavigationBar` with a custom 5-slot bottom bar that elevates the Scan FAB above the bar surface. The must-not-break list — `TaptapNavBar`, `StatusPill`, `EmptyState`, `LoadingCenter`, all provider signatures, all named routes — is intact. `AppTheme.theme` alias compiles. ThemeService is wired with `ChangeNotifierProvider` and `load()` is called at boot via `postFrameCallback`. `/courier/scan` is registered.

Watch for: **(HIGH)** `BhStatusChip` uses only light-mode status tokens — status chips will have low-contrast light-colored backgrounds in dark mode. **(MEDIUM)** `Inter` font is referenced in `AppTheme` TextTheme but is not declared in `pubspec.yaml` — all courier and auth screens will silently fall back to the system font. **(MEDIUM)** `BhAppBar` bottom border hardcodes `kBorderSubtle` (a light-mode token) in both themes — in dark mode the separator is invisible. **(LOW)** `_ScanPlaceholder` uses a raw `AppBar` rather than `BhAppBar` — it will render with the Material default AppBar style in dark mode, not the custom surface.

**Verdict**: NEEDS_CHANGES

---

## High-level view

The token system is complete and well-structured: brand scale, surface, border, text, spacing, radius, and typography tokens are all present. Dark-mode surface and text variants exist. The gap is that the widgets consuming these tokens do so correctly in light mode but skip the dark-mode switching for semantic status colors.

`BhStatusChip._resolve()` returns fixed light-mode colors regardless of brightness. All six dark-mode status token constants exist in `app_tokens.dart` and go unused. In dark mode every status chip renders a light pastel background against a dark scaffold — legible colors will not be guaranteed.

`AppTheme.dark` defines a full `TextTheme` with `fontFamily: 'Inter'`, but `pubspec.yaml` declares no `fonts:` section and no asset bundle entry for Inter. Flutter's font loader will print a warning and substitute the system default on every text widget that inherits the theme.

`BhAppBar.build()` correctly selects `bgColor` from the dark token but writes the bottom border with the constant `kBorderSubtle` (`Color(0xFFF1F3F2)` — a near-white value). On a dark background this 1px line is invisible, losing the visual separator between the AppBar and the content area. `kDarkBorderSubtle` (`Color(0xFF1F2E38)`) exists in the token set and is the correct substitution.

The navigation shell (`CourierShell` / `_BhBottomBar`) delivers the `IndexedStack` with 4 screens, Scan FAB lifted 10 dp above the bar via `Positioned(top: -10)`, online badge on slot 0 only, and `Navigator.pushNamed('/courier/scan')` that does not mutate `_idx`.

`ScanCodeParser` is intentionally strict — all-digit only, BH- prefix rejected until OD-01 resolves. All 8 specified test cases pass.

`_ScanPlaceholder` uses a raw Material `AppBar` rather than `BhAppBar`. The background color follows the theme, but the 1px bottom border (set by `BhAppBar` via its own `shape`) is absent, so the Scan route looks inconsistent during dark-mode testing.

---

<details>
<summary>Issues (4)</summary>

1. **Status chips unreadable in dark mode** — `BhStatusChip._resolve()` always returns light-mode token pairs (`kStatusPendingBg` / `kStatusPendingFg`, etc.). Six dark-mode variants (`kDarkStatus*Bg/Fg`) are defined in `app_tokens.dart` but unused. Fix: accept a `BuildContext` or `Brightness` and switch token sets based on `Theme.of(context).brightness`.

2. **Inter font not bundled** — `AppTheme.light` and `AppTheme.dark` both declare `fontFamily: 'Inter'` in their `TextTheme`, but `pubspec.yaml` has no `fonts:` section. Flutter silently falls back to the system font on every screen using the theme. Either add the font asset and declare it in pubspec, or remove the `fontFamily` references until the font is confirmed available.

3. **BhAppBar dark-mode border invisible** — The bottom `BorderSide` in `BhAppBar.build()` uses the hardcoded constant `kBorderSubtle` (`Color(0xFFF1F3F2)`) in both themes. On a dark surface this is effectively invisible. Should switch to `isDark ? kDarkBorderSubtle : kBorderSubtle`.

4. **_ScanPlaceholder uses raw AppBar** — The placeholder pushed by `/courier/scan` builds with a plain `AppBar`, not `BhAppBar`. In dark mode it renders with Material defaults (gray surface) instead of the custom dark surface. Low-risk since this is a Phase C placeholder, but worth fixing to keep the test path consistent.

</details>

---

<details>
<summary>Details</summary>

### Status chip dark-mode gap

`BhStatusChip._resolve()` is a `static` function that receives only a `String` and returns a fixed triple of `(bg, fg, label)`. Every color it returns is a light-mode token: `kStatusPendingBg` is `Color(0xFFFBF1E0)` — a warm amber tint that works against a white card but inverts to poor contrast against `kDarkSurfaceBase` (`Color(0xFF0F1923)`). The six dark-mode status token sets (`kDarkStatus*Bg/Fg`) are confirmed present in `app_tokens.dart` lines 69–80 and are referenced by no production code.

The fix requires `BhStatusChip` to read brightness from `context` and select the appropriate token pair:

```dart
static (Color bg, Color fg, String label) _resolve(String status, bool isDark) =>
    switch (status) {
      'pending' => isDark
          ? (kDarkStatusPendingBg, kDarkStatusPendingFg, 'Pending')
          : (kStatusPendingBg,     kStatusPendingFg,     'Pending'),
      // ... etc.
    };
```

`build()` already has `BuildContext context`, so `Theme.of(context).brightness` is available without API changes. `_resolve` becomes an instance call rather than a static call. Confirmed: no callers pass brightness today.

### Inter font fallback

`AppTheme.light` TextTheme (line ~17) and `AppTheme.dark` TextTheme both set `fontFamily: 'Inter'` on every text role. `pubspec.yaml` has a `fonts:` section that is absent — the key does not appear in the file. Flutter's font loader resolves missing families to Roboto (Android) or SF Pro (iOS) at runtime without a compile error, so `flutter analyze` and `flutter build apk` both pass. The behavior is a silent visual discrepancy: the design intent calls for Inter, but the shipped binary uses the OS default.

### BhAppBar bottom border in dark mode

In `bh_app_bar.dart`, `bgColor` is correctly conditioned on `isDark`, but the `shape` parameter:

```dart
shape: const Border(
  bottom: BorderSide(color: kBorderSubtle, width: 1),
),
```

uses a `const` constructor with `kBorderSubtle` hardcoded. `kBorderSubtle` is `Color(0xFFF1F3F2)` — almost white. Against `kDarkSurfaceBase` (`Color(0xFF0F1923)`) it blends into the background and disappears. `kDarkBorderSubtle` (`Color(0xFF1F2E38)`) is available and appropriate. Because `shape` accepts a non-const value when constructed inline, the fix is:

```dart
shape: Border(
  bottom: BorderSide(
    color: isDark ? kDarkBorderSubtle : kBorderSubtle,
    width: 1,
  ),
),
```

### Scan placeholder inconsistency

`_ScanPlaceholder` builds with a plain `AppBar`. The background picks up `kDarkSurfaceBase` from `AppTheme.appBarTheme` correctly, but the 1px bottom border is missing — `BhAppBar` sets that via its own `shape` parameter rather than relying on the theme. Replacing `AppBar` with `BhAppBar(title: 'Scan Parcel')` aligns the placeholder with the rest of the courier flow at negligible cost.

### Test coverage

The 8 `scan_code_parser_test.dart` cases match the amended spec. No widget tests cover `BhStatusChip`, `BhOfflineBanner`, `BhAppBar`, or any courier screen state transition — expected scope for Phase A, flagged as open items for Phase B.

</details>

---

<details>
<summary>File map</summary>

| File | Change |
|---|---|
| `pubspec.yaml` | Added `connectivity_plus: ^6.0.3` |
| `lib/core/theme/app_tokens.dart` | New — full token set (brand, surface, border, text, dark variants, status colors, radius, spacing, typography) |
| `lib/core/theme/app_colors.dart` | Added `import 'app_tokens.dart'`; added `C.b900` |
| `lib/core/theme/app_theme.dart` | Rewrote — `AppTheme.light`, `AppTheme.dark`, `AppTheme.theme` alias |
| `lib/core/services/theme_service.dart` | New — `AppThemeMode` enum + SharedPreferences persistence |
| `lib/core/utils/scan_code_parser.dart` | New — strict all-digit parser |
| `lib/widgets/bh_app_bar.dart` | New — `BhAppBar implements PreferredSizeWidget`, brightness-adaptive |
| `lib/widgets/bh_offline_banner.dart` | New — connectivity-plus v6 stream-based offline banner |
| `lib/widgets/bh_skeleton.dart` | New — `SkeletonBox`, `SkeletonCard`, `SkeletonList` with shimmer |
| `lib/widgets/bh_status_chip.dart` | New — token-based status chip replacing `StatusPill` for courier screens |
| `lib/widgets/bh_primary_button.dart` | New — full-width branded button |
| `lib/widgets/bh_stat_tile.dart` | New — stat tile with icon, value, label |
| `lib/widgets/bh_empty_state.dart` | New — centered empty state with icon, title, subtitle, optional action |
| `lib/widgets/bh_section_header.dart` | New — label + optional text action row |
| `lib/widgets/bh_parcel_card.dart` | New — shared parcel card widget extracted from orders screen |
| `lib/screens/courier/courier_shell.dart` | Rewritten — `_BhBottomBar` with `IndexedStack`, Scan FAB, online badge |
| `lib/screens/courier/courier_dashboard_screen.dart` | Restyled — `BhAppBar`, `SkeletonList`, flat `kBrand800` banner, `BhStatTile`, `BhStatusChip`, `BhOfflineBanner`, `BhEmptyState` |
| `lib/screens/courier/courier_orders_screen.dart` | Restyled — `BhAppBar`, filter chips replacing `TabBar`, `BhParcelCard`, `BhOfflineBanner`, `SkeletonList` |
| `lib/screens/courier/courier_earnings_screen.dart` | Restyled — `BhAppBar`, `SkeletonList`, flat `kBrand800` hero card, `BhOfflineBanner`, `BhEmptyState` |
| `lib/screens/courier/courier_profile_screen.dart` | Restyled — `BhAppBar`, `BhOfflineBanner`, `_ThemeSelector` (System/Light/Dark chips), flat `kBrand800` avatar header |
| `lib/screens/courier/parcel_detail_screen.dart` | Restyled — `BhAppBar`, `SkeletonList`, `BhStatusChip` in `_StatusBanner`, `BhOfflineBanner`, `_ActionButton` |
| `lib/screens/auth/login_screen.dart` | Modified — `AnimatedContainer` header collapses on keyboard open, `resizeToAvoidBottomInset: true` |
| `lib/main.dart` | Rewritten — `BilisHatidApp` → StatefulWidget, `MultiProvider` inside state, `Consumer<ThemeService>`, `AppTheme.light/dark/themeMode`, `/courier/scan` route |
| `test/scan_code_parser_test.dart` | New — 8 test cases for `ScanCodeParser.parse()` |

Full diff: `git diff HEAD~3 HEAD`

</details>

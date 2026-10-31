# Phase A Implementation Plan — Bilis Hatid Rider App

## Investigation Summary

### Codebase findings
- **Workspace root**: `c:\Users\emjhe\Flutter Projects\Bilis Hatid Express Inc`
- **Package name**: `bilis_hatid_rider`
- **Dart SDK**: `>=3.0.0 <4.0.0` (supports exhaustive switches, records, patterns)
- **Flutter**: uses Material 3 flag not yet set globally — `app_theme.dart` sets `useMaterial3: true`
- **AppTheme.theme** is the sole getter; becomes an alias for `AppTheme.light` after Task 3
- **shared_preferences** `^2.2.3` already in pubspec — confirmed ✅
- **connectivity_plus** NOT in pubspec — must be added (Task 1)
- **`C` class in app_colors.dart** — 27 constants used across buyer, seller, auth, courier screens — MUST remain; will add token delegate imports
- **LoadingCenter** lives in `lib/widgets/empty_state.dart` (same file as EmptyState) — must be preserved
- **TaptapNavBar** lives in `lib/widgets/taptap_navbar.dart`; also contains `BuyerNavBar` — both must be kept
- **StatusPill** in `lib/widgets/status_pill.dart` — used in courier screens; must be kept, BhStatusChip is additive
- **EmptyState** in `lib/widgets/empty_state.dart` — must be kept; `BhEmptyState` is additive
- **courier_shell.dart** uses `NavigationBar` (Material 3) — will be replaced with custom `_BhBottomBar` inside `BhNavShell`
- **No existing test infrastructure** beyond `flutter_test`; scan_code_parser tests use `flutter_test` (group/test/expect)
- **No existing `lib/core/services/theme_service.dart`** — new file
- **No existing `lib/core/theme/app_tokens.dart`** — new file
- **`BilisHatidApp` is StatelessWidget** — must become StatefulWidget or use Consumer for ThemeService watch
- **build.gradle.kts**: `compileSdk = 36`, `applicationId = "com.bilishatid.rider"` — locked, not touched

### Backward-compat hazards
1. **`C.b900`** is referenced in `field_card.dart` (`InfoRow`) but NOT defined in `app_colors.dart`. This is a pre-existing bug — add `b900` to C class during Task 3 (it already appears in app_theme.dart's ColorScheme as `C.b600` etc.). The token value for `kBrand900 = Color(0xFF071920)` — use that.
2. **`C.grad4`** is used in `courier_orders_screen.dart` (`_PaymentBadge`) — already in C class ✅
3. **`C.deliveredBg`** and `C.delivered` used in multiple courier screens — already in C class ✅
4. **LoginScreen** uses `C.heroGrad` — in C class ✅
5. **courier_orders_screen** uses `SingleTickerProviderStateMixin` + `TabController` — Task 9 replaces TabBar with filter chips, disposing `_tabs` properly
6. **`_ParcelCard` in courier_dashboard_screen** is a private class that works on `Map<String, dynamic>`; `_ParcelCard` in courier_orders_screen works on `Order` model — these are different widgets; the new `BhParcelCard` in Task 9 extracts the orders-screen variant. Dashboard variant stays private.
7. **`widget_test.dart`** pumps `BilisHatidApp()` — after Task 10, `BilisHatidApp` is a `StatefulWidget`; its constructor signature is unchanged, so `const BilisHatidApp()` must still work. Mark constructor `const` on the new StatefulWidget.

### Confirmed preserved widgets
- `TaptapNavBar` (and `BuyerNavBar`) in `taptap_navbar.dart` — untouched
- `StatusPill` in `status_pill.dart` — untouched
- `EmptyState`, `LoadingCenter`, `ErrorRetry` in `empty_state.dart` — untouched
- `FieldCard`, `InfoRow` in `field_card.dart` — untouched

---

## Implementation Order

> Dependencies flow: tokens → theme/colors → services → widgets → screens → main

---

- [ ] 1. **Add connectivity_plus to pubspec.yaml and run pub get**
      Add `connectivity_plus: ^6.0.3` under dependencies. Run `flutter pub get`.
      Files: `pubspec.yaml`
      Verify: `flutter pub get` exits 0 with no dependency conflicts.

- [ ] 2. **Create design token file**
      Create `lib/core/theme/app_tokens.dart` with all const color, radius, spacing, and TextStyle tokens exactly as specified in Task 2. Every TextStyle uses `color: kTextPrimary`. MonoMd uses `fontFamily: 'monospace'`.
      Files: `lib/core/theme/app_tokens.dart` (NEW)
      Verify: `flutter analyze lib/core/theme/app_tokens.dart` — no issues.

- [ ] 3. **Update app_colors.dart to import tokens and add C.b900**
      Add `import 'app_tokens.dart';` at top of `app_colors.dart`. Add the missing `static const Color b900 = Color(0xFF071920);` to class C (fixing the pre-existing InfoRow compile error). All existing C.* constants remain with their original literal values — do NOT replace with token references yet (that would risk breaking const contexts). The token file already has the same values; the C class stays as a standalone shim.
      Files: `lib/core/theme/app_colors.dart` (MODIFY)
      Verify: `flutter analyze lib` — no issues (b900 missing reference in field_card.dart now resolves).

- [ ] 4. **Create AppTheme.light and AppTheme.dark; keep AppTheme.theme alias**
      Rewrite `lib/core/theme/app_theme.dart` to import `app_tokens.dart` and define:
      - `static ThemeData get light` — full ThemeData using token values per Task 3 spec
      - `static ThemeData get dark`  — full dark ThemeData using dark token values per Task 3 spec
      - `static ThemeData get theme => light;` — backward-compat alias so all existing `AppTheme.theme` references compile
      Both themes set `useMaterial3: true`. Keep snackBarTheme and dividerTheme. Card border uses `kBorderDefault`. App bar has a 1dp bottom border via `shape: Border(bottom: BorderSide(color: kBorderSubtle))` in AppBarTheme.
      Files: `lib/core/theme/app_theme.dart` (MODIFY)
      Verify: `flutter analyze lib/core/theme/` — no issues.

- [ ] 5. **Create ThemeService**
      Create `lib/core/services/theme_service.dart` with `enum AppThemeMode { system, light, dark }` and `ThemeService extends ChangeNotifier` per Task 4 spec. Use `shared_preferences` key `'theme_mode'` storing the enum name string. `load()` reads on startup; `setMode()` persists and calls `notifyListeners()`.
      Files: `lib/core/services/theme_service.dart` (NEW)
      Verify: `flutter analyze lib/core/services/theme_service.dart` — no issues.

- [ ] 6. **Create ScanCodeParser utility + unit tests**
      Create `lib/core/utils/scan_code_parser.dart`:
      - `class ScanCodeParser { static int? parse(String raw) }`
      - Logic: trim whitespace; if trimmed is empty → null; if trimmed matches `RegExp(r'^\d+$')` → `int.tryParse(trimmed)`; else → null
      - Doc comment: "BH- prefix reserved for future use (OD-01). Example: 'BH-1042' → null until prefix format confirmed."
      Create `test/scan_code_parser_test.dart` with all 8 test cases from Task 6.
      Files: `lib/core/utils/scan_code_parser.dart` (NEW), `test/scan_code_parser_test.dart` (NEW)
      Verify: `flutter test test/scan_code_parser_test.dart` — all 8 tests pass.

- [ ] 7. **Create BhOfflineBanner widget**
      Create `lib/widgets/bh_offline_banner.dart` per Task 5 spec:
      - `BhOfflineBanner({required Widget child})`
      - Uses `connectivity_plus` `Connectivity().onConnectivityChanged` stream
      - Initial check via `Connectivity().checkConnectivity()` in `initState`
      - Amber banner 36dp (Colors.amber.shade700 bg, white text), `"⚡ You're offline — data may be outdated"`
      - `AnimatedSlide` (offset 0→-1 vertically) wrapping the banner, duration 300ms
      - Wraps child in a `Column` with the banner on top (hidden via AnimatedSlide when online)
      - `Semantics(label: 'Offline warning banner', child: ...)` wrapping the banner
      Files: `lib/widgets/bh_offline_banner.dart` (NEW)
      Verify: `flutter analyze lib/widgets/bh_offline_banner.dart` — no issues.

- [ ] 8. **Create BhSkeleton widgets**
      Create `lib/widgets/bh_skeleton.dart` per Task 5 spec:
      - `SkeletonBox({double? width, double height = 16, double radius = kRadiusMd})` — TweenAnimationBuilder animates a shimmer LinearGradient from `kBrand50` to `kBrand100` and back (colors list tween via ColorTween or manual list lerp), duration 1200ms, repeat=true
      - `SkeletonCard({double height = 80})` — full-width SkeletonBox with `kRadiusLg` radius
      - `SkeletonList({int count = 3, double itemHeight = 80})` — Column of SkeletonCards with `kSpace8` spacing between items
      Files: `lib/widgets/bh_skeleton.dart` (NEW)
      Verify: `flutter analyze lib/widgets/bh_skeleton.dart` — no issues.

- [ ] 9. **Create component library: BhStatusChip**
      Create `lib/widgets/bh_status_chip.dart` per Task 6 spec. Map all status strings to token pairs. Keep `StatusPill` untouched. Label map: `ready_for_pickup`→"Ready for Pickup", `out_for_delivery`→"Out for Delivery", `active`→"Active", `inactive`→"Inactive", `approved`→"Approved", `suspended`→"Suspended", `pending`→"Pending", `delivered`→"Delivered", `failed`→"Failed", `cancelled`→"Cancelled". Unknown → ("Status", kStatusCancelledBg/Fg).
      Files: `lib/widgets/bh_status_chip.dart` (NEW)
      Verify: `flutter analyze lib/widgets/bh_status_chip.dart` — no issues.

- [ ] 10. **Create component library: BhPrimaryButton, BhStatTile, BhEmptyState, BhSectionHeader**
       Create four files, each per Task 6 spec:
       - `lib/widgets/bh_primary_button.dart` — full-width, 48dp min, destructive variant, loading state
       - `lib/widgets/bh_stat_tile.dart` — tappable stat card with icon
       - `lib/widgets/bh_empty_state.dart` — centered icon/title/subtitle + optional action; does NOT modify existing `EmptyState`
       - `lib/widgets/bh_section_header.dart` — uppercase label + optional trailing action link
       Files: `lib/widgets/bh_primary_button.dart` (NEW), `lib/widgets/bh_stat_tile.dart` (NEW), `lib/widgets/bh_empty_state.dart` (NEW), `lib/widgets/bh_section_header.dart` (NEW)
       Verify: `flutter analyze lib/widgets/` — no issues.

- [ ] 11. **Create BhAppBar widget**
       Create `lib/widgets/bh_app_bar.dart` per Task 7 spec.
       - Implements `PreferredSizeWidget`; preferred height = `kToolbarHeight + (bottom?.preferredSize.height ?? 0)`
       - Uses `Theme.of(context).brightness` to choose white vs `kDarkSurfaceBase` background
       - Back button rendered when `showBack && Navigator.of(context).canPop()`
       - 1dp bottom border `kBorderSubtle`
       Files: `lib/widgets/bh_app_bar.dart` (NEW)
       Verify: `flutter analyze lib/widgets/bh_app_bar.dart` — no issues.

- [ ] 12. **Create BhParcelCard**
       Create `lib/widgets/bh_parcel_card.dart` per Task 9 spec — extracts the `_ParcelCard` pattern from courier_orders_screen as a public `BhParcelCard({required Order order, required CourierProvider cp})`. Identical logic to the existing `_ParcelCard` in orders screen but uses token values (kBrand50, kBrand700, kBorderDefault etc.) instead of `C.*`. Imports `Order`, `CourierProvider`, `AppConstants`, token refs.
       Files: `lib/widgets/bh_parcel_card.dart` (NEW)
       Verify: `flutter analyze lib/widgets/bh_parcel_card.dart` — no issues.

- [ ] 13. **Replace CourierShell with BhNavShell**
       Rewrite `lib/screens/courier/courier_shell.dart` to export `CourierShell` (same class name — no route change needed):
       - `BhNavShell` is the new internal implementation; `CourierShell = BhNavShell` (or just rename the StatefulWidget class to `CourierShell` directly)
       - `IndexedStack` with 4 screens; Scan slot in bottom bar does NOT add an item to the stack
       - Custom `_BhBottomBar` StatelessWidget (NOT NavigationBar / BottomNavigationBar) per Task 8 spec
       - FAB scan slot: `GestureDetector` → `Stack` → 56×56 circular container 10dp above bar baseline; navigates to `/courier/scan` via `Navigator.pushNamed`
       - Online badge on Home tab icon
       - `initState` logic: role guard + `cp.loadDashboard()` — byte-for-byte match to original
       - `_onTabTap(i)`: cases 0–3 mapping identical to original
       Files: `lib/screens/courier/courier_shell.dart` (REWRITE)
       Verify: `flutter analyze lib/screens/courier/courier_shell.dart` — no issues; app navigates to /courier without crash.

- [ ] 14. **Restyle CourierDashboardScreen**
       Modify `lib/screens/courier/courier_dashboard_screen.dart`:
       - Replace `TaptapNavBar` import/usage with `BhAppBar` (add import)
       - Replace `const LoadingCenter()` with `SkeletonList(count: 3)` in loading branch
       - Replace `_WelcomeBanner` gradient `BoxDecoration(gradient: C.heroGrad)` with `color: kBrand800` (flat solid)
       - Replace `_stat()` helper / `_StatsRow` private widgets with `BhStatTile` (add import)
       - Replace `StatusPill` in `_ParcelCard` with `BhStatusChip` (keep `StatusPill` import removed only if no longer used; otherwise keep both)
       - Wrap `Scaffold.body` in `BhOfflineBanner(child: ...)`
       - Replace hardcoded `Color(0xFF...)` literals with token consts throughout
       - `_emptyParcels()` → replaced with `BhEmptyState(...)`
       - All logic (loadDashboard, markPickedUp, markDelivered, toggleOnlineStatus, confirmAction dialogs) unchanged
       Files: `lib/screens/courier/courier_dashboard_screen.dart` (MODIFY)
       Verify: `flutter analyze lib/screens/courier/courier_dashboard_screen.dart` — no issues.

- [ ] 15. **Restyle CourierOrdersScreen**
       Modify `lib/screens/courier/courier_orders_screen.dart`:
       - Remove `TabController` + `SingleTickerProviderStateMixin`; replace with `String? _filterStatus` state
       - Replace `TaptapNavBar` with `BhAppBar`; remove `bottom:` TabBar
       - Add horizontally scrollable filter chip row below BhAppBar inside body (not in AppBar bottom). Use `_BhFilterChip` private widget: kBrand500 selected, kBorderDefault unselected, labels: All / Pickup / On the Way / Delivered
       - Replace `_ParcelCard` private class with `BhParcelCard` widget (add import)
       - Replace `const LoadingCenter()` with `SkeletonList(count: 5)`
       - Replace `EmptyState` with `BhEmptyState`
       - Replace `StatusPill` with `BhStatusChip` if directly used (check — it's inside `_ParcelCard` which is replaced by `BhParcelCard`)
       - Wrap body in `BhOfflineBanner`
       - `loadOrders()` call in initState unchanged; filter logic stays in-widget using `_filterStatus`
       - Keep `_PaymentBadge` private widget (used in BhParcelCard indirectly via existing logic)
       Files: `lib/screens/courier/courier_orders_screen.dart` (MODIFY)
       Verify: `flutter analyze lib/screens/courier/courier_orders_screen.dart` — no issues.

- [ ] 16. **Restyle CourierEarningsScreen**
       Modify `lib/screens/courier/courier_earnings_screen.dart`:
       - Replace `TaptapNavBar` with `BhAppBar`
       - Replace hero card `BoxDecoration(gradient: C.heroGrad)` with `color: kBrand800` flat header
       - Replace `const LoadingCenter()` with `SkeletonList(count: 4)`
       - Replace `EmptyState` with `BhEmptyState`
       - Wrap body in `BhOfflineBanner`
       - Replace hardcoded Color literals with token consts
       - All logic (loadEarnings, _HistoryItem) unchanged
       Files: `lib/screens/courier/courier_earnings_screen.dart` (MODIFY)
       Verify: `flutter analyze lib/screens/courier/courier_earnings_screen.dart` — no issues.

- [ ] 17. **Restyle CourierProfileScreen**
       Modify `lib/screens/courier/courier_profile_screen.dart`:
       - Replace `TaptapNavBar` with `BhAppBar`
       - Replace gradient header `BoxDecoration(gradient: C.heroGrad)` with `color: kBrand800`
       - Wrap body in `BhOfflineBanner`
       - Add theme selector section to profile body: Row of 3 chips (System / Light / Dark) reading `context.watch<ThemeService>().mode` and calling `context.read<ThemeService>().setMode(...)` — add ThemeService import
       - Replace hardcoded Color literals with token consts
       - Restructure menu into Account / Support sections per Task 9 spec
       - All auth/logout/profile logic unchanged
       Files: `lib/screens/courier/courier_profile_screen.dart` (MODIFY)
       Verify: `flutter analyze lib/screens/courier/courier_profile_screen.dart` — no issues.

- [ ] 18. **Restyle ParcelDetailScreen**
       Modify `lib/screens/courier/parcel_detail_screen.dart`:
       - Replace `TaptapNavBar` with `BhAppBar`
       - Replace `StatusPill` with `BhStatusChip` in `_StatusBanner`
       - Replace `const LoadingCenter()` with `SkeletonList(count: 6)`
       - Wrap body in `BhOfflineBanner`
       - Replace hardcoded Color literals with token consts
       - All logic (loadOrderDetail, markPickedUp, markDelivered, confirmAction) unchanged
       Files: `lib/screens/courier/parcel_detail_screen.dart` (MODIFY)
       Verify: `flutter analyze lib/screens/courier/parcel_detail_screen.dart` — no issues.

- [ ] 19. **Restyle LoginScreen**
       Modify `lib/screens/auth/login_screen.dart`:
       - Wrap the icon+title header section (the Container with gradient box + two_wheeler icon + "Rider Login" text + subtitle) in an `AnimatedContainer` with height `180` when keyboard hidden, `80` when `MediaQuery.of(context).viewInsets.bottom > 0`
       - Detect keyboard: add `bool get _keyboardOpen => MediaQuery.of(context).viewInsets.bottom > 0;` — use in `build()`
       - The AnimatedContainer wraps ONLY the header (icon + title + subtitle), not the full card. The card itself stays in a SingleChildScrollView. Set `clipBehavior: Clip.hardEdge` on the AnimatedContainer so content is clipped at 80dp
       - Keep ALL existing login logic (remember-me, validation, auth call, role dispatch) byte-for-byte identical
       - Replace hardcoded Color literals with token consts where possible (keep `C.heroGrad` reference as-is since that's the existing brand logo treatment)
       Files: `lib/screens/auth/login_screen.dart` (MODIFY)
       Verify: `flutter analyze lib/screens/auth/login_screen.dart` — no issues.

- [ ] 20. **Update main.dart**
       Modify `lib/main.dart`:
       - Add import `'core/services/theme_service.dart'`
       - Add `ChangeNotifierProvider(create: (_) => ThemeService())` to the MultiProvider list
       - Convert `BilisHatidApp` from `StatelessWidget` to `StatefulWidget` (keep `const BilisHatidApp({super.key})` constructor so widget_test.dart still compiles); use `Consumer<ThemeService>` inside build rather than `context.watch` (avoids needing BuildContext above the MaterialApp)
       - In `_AppRootState.initState`, after `super.initState()`, add `WidgetsBinding.instance.addPostFrameCallback((_) => context.read<ThemeService>().load())`
       - Update MaterialApp: `theme: AppTheme.light`, `darkTheme: AppTheme.dark`, `themeMode: themeService.flutterMode` (from Consumer)
       - Add route `'/courier/scan': (_) => const _ScanPlaceholder()` to routes map
       - Add `_ScanPlaceholder` private widget at bottom of file (simple Scaffold with AppBar title "Scan Parcel" and centered Text "Scan — coming in Phase C")
       - Keep `/courier/parcel` route and ALL other routes unchanged
       Files: `lib/main.dart` (MODIFY)
       Verify: `flutter analyze lib/main.dart` — no issues.

- [ ] 21. **Full analyze + test + build**
       Run in order:
       1. `flutter analyze lib` — must return "No issues found!"
       2. `flutter test` — all tests pass (widget_test.dart + scan_code_parser_test.dart)
       3. `flutter build apk --debug` — must succeed
       Report every file created/modified with a one-line description.
       Files: none (verification only)
       Verify: All three commands exit 0. If analyze reports issues, fix them before proceeding to test/build.

---

## Files to Create (12 new files)

| File | Description |
|------|-------------|
| `lib/core/theme/app_tokens.dart` | All design token consts (colors, radii, spacing, typography) |
| `lib/core/services/theme_service.dart` | ThemeMode persistence via shared_preferences |
| `lib/core/utils/scan_code_parser.dart` | Strict digits-only QR code parser |
| `lib/widgets/bh_offline_banner.dart` | Connectivity-aware offline amber banner wrapper |
| `lib/widgets/bh_skeleton.dart` | SkeletonBox, SkeletonCard, SkeletonList shimmer widgets |
| `lib/widgets/bh_status_chip.dart` | Token-mapped status chip (additive, StatusPill preserved) |
| `lib/widgets/bh_primary_button.dart` | Full-width primary button with loading + destructive states |
| `lib/widgets/bh_stat_tile.dart` | Stat tile card with icon, value, label |
| `lib/widgets/bh_empty_state.dart` | Empty state widget (additive, EmptyState preserved) |
| `lib/widgets/bh_section_header.dart` | Section header with optional action link |
| `lib/widgets/bh_app_bar.dart` | Token-styled AppBar implementing PreferredSizeWidget |
| `lib/widgets/bh_parcel_card.dart` | Reusable parcel card extracted from courier_orders_screen |
| `test/scan_code_parser_test.dart` | 8 unit tests for ScanCodeParser |

## Files to Modify (9 existing files)

| File | Change summary |
|------|----------------|
| `pubspec.yaml` | Add connectivity_plus ^6.0.3 |
| `lib/core/theme/app_colors.dart` | Add `import 'app_tokens.dart'`; add missing `C.b900` const |
| `lib/core/theme/app_theme.dart` | Add light/dark getters; keep `theme` as alias for `light` |
| `lib/screens/courier/courier_shell.dart` | Replace NavigationBar with custom BhNavShell + _BhBottomBar |
| `lib/screens/courier/courier_dashboard_screen.dart` | Apply tokens, BhAppBar, SkeletonList, BhStatTile, BhOfflineBanner |
| `lib/screens/courier/courier_orders_screen.dart` | Apply tokens, BhAppBar, BhParcelCard, filter chips, BhOfflineBanner |
| `lib/screens/courier/courier_earnings_screen.dart` | Apply tokens, BhAppBar, SkeletonList, flat header, BhOfflineBanner |
| `lib/screens/courier/courier_profile_screen.dart` | Apply tokens, BhAppBar, flat header, theme selector, BhOfflineBanner |
| `lib/screens/courier/parcel_detail_screen.dart` | Apply tokens, BhAppBar, BhStatusChip, SkeletonList, BhOfflineBanner |
| `lib/screens/auth/login_screen.dart` | AnimatedContainer keyboard-aware header only; all logic unchanged |
| `lib/main.dart` | Add ThemeService provider, Consumer, dark theme, /courier/scan route |

## Must-Not-Break Confirmation

- ✅ `lib/core/services/api.dart` — not touched
- ✅ `lib/core/services/auth_service.dart` — not touched
- ✅ `lib/core/services/courier_service.dart` — not touched
- ✅ `lib/providers/auth_provider.dart` — not touched
- ✅ `lib/providers/courier_provider.dart` — not touched (all 6 required methods preserved)
- ✅ `lib/models/order.dart`, `user.dart`, `user_profile.dart`, `order_item.dart` — not touched
- ✅ Named routes `/courier`, `/courier/parcel`, `/login`, `/register/courier`, `/buyer`, `/seller`, `/rider/activate` — all preserved in main.dart
- ✅ Multi-role login dispatch — unchanged in `_boot()` and `_login()`
- ✅ `build.gradle.kts` — not touched
- ✅ `CourierProvider` method calls in screens — all call sites preserved (loadDashboard, loadOrders, loadEarnings, markPickedUp, markDelivered, toggleOnlineStatus)
- ✅ `TaptapNavBar`, `EmptyState`, `StatusPill` — kept in original files, not modified
- ✅ `C` class — stays in app_colors.dart with all existing constants; `b900` added (was missing, causes compile error without it)
- ✅ `AppTheme.theme` — kept as alias for `AppTheme.light`

## Dependency Order (critical path)

```
pubspec.yaml (1)
  └── app_tokens.dart (2)
        ├── app_colors.dart (3) [imports tokens, adds b900]
        ├── app_theme.dart (4) [imports tokens]
        ├── theme_service.dart (5) [uses shared_prefs]
        ├── scan_code_parser.dart (6)
        ├── bh_offline_banner.dart (7) [uses connectivity_plus from step 1]
        ├── bh_skeleton.dart (8) [uses tokens]
        ├── bh_status_chip.dart (9) [uses tokens]
        ├── bh_primary_button.dart (10) [uses tokens]
        ├── bh_stat_tile.dart (10) [uses tokens]
        ├── bh_empty_state.dart (10) [uses tokens]
        ├── bh_section_header.dart (10) [uses tokens]
        ├── bh_app_bar.dart (11) [uses tokens]
        ├── bh_parcel_card.dart (12) [uses Order, CourierProvider, bh_status_chip, tokens]
        ├── courier_shell.dart (13) [uses bh_app_bar, bh_offline_banner, tokens]
        ├── courier_dashboard_screen.dart (14) [uses bh_app_bar, bh_skeleton, bh_stat_tile, bh_status_chip, bh_offline_banner]
        ├── courier_orders_screen.dart (15) [uses bh_app_bar, bh_skeleton, bh_parcel_card, bh_offline_banner]
        ├── courier_earnings_screen.dart (16) [uses bh_app_bar, bh_skeleton, bh_empty_state, bh_offline_banner]
        ├── courier_profile_screen.dart (17) [uses bh_app_bar, theme_service, bh_offline_banner]
        ├── parcel_detail_screen.dart (18) [uses bh_app_bar, bh_skeleton, bh_status_chip, bh_offline_banner]
        ├── login_screen.dart (19) [minimal change: AnimatedContainer only]
        └── main.dart (20) [uses app_theme light/dark, theme_service, new route]
```

## wf-coder Readiness

All information needed to implement is present:
- All source files have been read; exact class names, method signatures, import paths are known
- Token values are specified verbatim in the task brief
- Backward-compat hazards (C.b900, widget_test.dart constructor, TabController removal) are identified and resolved in plan
- `connectivity_plus: ^6.0.3` and `shared_preferences: ^2.2.3` (already present) are the only new/confirmed dependencies
- No environment setup required — local dev build
- Build command: `flutter build apk --debug`
- Test command: `flutter test`
- Analyze command: `flutter analyze lib`

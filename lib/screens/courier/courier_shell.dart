import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../providers/courier_provider.dart';
import 'courier_dashboard_screen.dart';
import 'courier_orders_screen.dart';
import 'courier_earnings_screen.dart';
import 'courier_profile_screen.dart';

class CourierShell extends StatefulWidget {
  const CourierShell({super.key});
  @override
  State<CourierShell> createState() => _CourierShellState();
}

class _CourierShellState extends State<CourierShell> {
  int _idx = 0;

  static const _screens = [
    CourierDashboardScreen(),
    CourierOrdersScreen(),
    CourierEarningsScreen(),
    CourierProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null && user.role != 'courier') {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        return;
      }
      context.read<CourierProvider>().loadDashboard();
    });
  }

  void _onTabTap(int i) {
    setState(() => _idx = i);
    final cp = context.read<CourierProvider>();
    switch (i) {
      case 0:
        cp.loadDashboard();
        break;
      case 1:
        cp.loadOrders();
        break;
      case 2:
        cp.loadEarnings();
        break;
      case 3:
        cp.loadProfile();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<CourierProvider>();
    final isOnline = cp.isOnline ?? false;

    return Scaffold(
      body: IndexedStack(index: _idx, children: _screens),
      bottomNavigationBar: _BhBottomBar(
        selectedIndex: _idx,
        onTap: _onTabTap,
        isOnline: isOnline,
      ),
    );
  }
}

// ── Custom bottom bar ─────────────────────────────────────────────────────────

class _BhBottomBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final bool isOnline;

  const _BhBottomBar({
    required this.selectedIndex,
    required this.onTap,
    required this.isOnline,
  });

  // Maps visual slot index → tab index in IndexedStack.
  // Slots: 0=Home, 1=Parcels, 2=Scan(center/no tab), 3=Earnings, 4=Profile
  static const _slotToTab = <int>[0, 1, -1, 2, 3];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? kDarkSurfaceBase : kSurfaceBase;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final barHeight = 64.0 + bottomPadding;

    return Container(
      height: barHeight,
      decoration: BoxDecoration(
        color: bgColor,
        border: const Border(top: BorderSide(color: kBorderSubtle, width: 1)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Tab row (5 slots)
          Positioned.fill(
            child: Row(
              children: List.generate(5, (slot) {
                if (slot == 2) {
                  // Scan slot — spacer so scan FAB occupies its space
                  return const Expanded(child: SizedBox.shrink());
                }
                final tabIdx = _slotToTab[slot];
                final isSelected = tabIdx == selectedIndex;
                return Expanded(
                  child: _TabSlot(
                    slot: slot,
                    tabIdx: tabIdx,
                    isSelected: isSelected,
                    isOnline: isOnline,
                    onTap: () => onTap(tabIdx),
                  ),
                );
              }),
            ),
          ),

          // Scan FAB — centered, lifted above bar top
          Positioned(
            top: -10,
            left: 0,
            right: 0,
            child: Center(
              child: Semantics(
                label: 'Scan parcel',
                button: true,
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(
                      context, '/courier/scan'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: kBrand800,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: kBrand900.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.qr_code_scanner,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Scan',
                        style: kLabelSm.copyWith(color: kTextMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Individual tab slot (non-scan) ────────────────────────────────────────────

class _TabSlot extends StatelessWidget {
  final int slot;
  final int tabIdx;
  final bool isSelected;
  final bool isOnline;
  final VoidCallback onTap;

  const _TabSlot({
    required this.slot,
    required this.tabIdx,
    required this.isSelected,
    required this.isOnline,
    required this.onTap,
  });

  static const _icons = <int, (IconData, IconData, String)>{
    0: (Icons.dashboard_outlined, Icons.dashboard, 'Home'),
    1: (Icons.inventory_2_outlined, Icons.inventory_2, 'Parcels'),
    3: (Icons.account_balance_wallet_outlined,
        Icons.account_balance_wallet, 'Earnings'),
    4: (Icons.person_outline, Icons.person, 'Profile'),
  };

  @override
  Widget build(BuildContext context) {
    final (outlinedIcon, filledIcon, label) = _icons[slot]!;
    final icon = isSelected ? filledIcon : outlinedIcon;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Top indicator line
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2,
              width: isSelected ? 24.0 : 0.0,
              decoration: BoxDecoration(
                color: kBrand400,
                borderRadius: BorderRadius.circular(kRadiusFull),
              ),
            ),
            const SizedBox(height: 10),
            // Icon with optional online badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected ? kBrand800 : kTextMuted,
                ),
                // Online badge for Home slot
                if (isOnline && slot == 0)
                  Positioned(
                    top: 0,
                    right: -1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            // Label — only show when selected
            if (isSelected)
              Text(
                label,
                style: kLabelSm.copyWith(color: kBrand800),
              ),
          ],
        ),
      ),
    );
  }
}

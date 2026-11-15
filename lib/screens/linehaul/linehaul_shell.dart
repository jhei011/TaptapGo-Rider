import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/tap.dart';
import 'linehaul_home_screen.dart';
import 'linehaul_trips_screen.dart';

/// The Linehaul Courier panel: separate from the Rider panel (CourierShell).
///
/// Riders (role `courier`) pick up from sellers and deliver to buyers within one hub's area.
/// Linehaul couriers (role `linehaul`) drive sorted parcels between hubs, so their panel has
/// trips instead of parcels, earnings, COD and the online switch.
class LinehaulShell extends StatefulWidget {
  const LinehaulShell({super.key});
  @override
  State<LinehaulShell> createState() => _LinehaulShellState();
}

class _LinehaulShellState extends State<LinehaulShell> {
  int _idx = 0;
  final _homeKey = GlobalKey<LinehaulHomeScreenState>();
  final _tripsKey = GlobalKey<LinehaulTripsScreenState>();
  final _historyKey = GlobalKey<LinehaulTripsScreenState>();

  late final List<Widget> _screens = [
    LinehaulHomeScreen(key: _homeKey, onOpenTrips: () => _onTabTap(1)),
    LinehaulTripsScreen(key: _tripsKey),
    LinehaulTripsScreen(key: _historyKey, scope: 'history'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      // Only linehaul couriers use this panel; riders have their own
      if (user != null && user.role != 'linehaul') {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      }
    });
  }

  void _onTabTap(int i) {
    setState(() => _idx = i);
    switch (i) {
      case 0:
        _homeKey.currentState?.reload();
      case 1:
        _tripsKey.currentState?.reload();
      case 2:
        _historyKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _idx, children: _screens),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: kSurfaceBase,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(kRadiusNavBar)),
            border: Border.all(color: AppPalette.dark ? kBorderDefault : const Color(0x14000000), width: 0.8),
            boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, -4))],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 60,
              child: Row(children: [
                _item(Icons.home_outlined, Icons.home_rounded, 'Home', 0),
                _item(Icons.local_shipping_outlined, Icons.local_shipping, 'Trips', 1),
                _item(Icons.history_outlined, Icons.history, 'History', 2),
              ]),
            ),
          ),
        ),
      );

  Widget _item(IconData icon, IconData activeIcon, String label, int index) {
    final active = index == _idx;
    final color = active ? (AppPalette.dark ? kTealOnDark : kBrand700) : kTextSecondary;
    return Expanded(
      child: Semantics(
        selected: active,
        button: true,
        label: label,
        excludeSemantics: true,
        child: Tap(
          onTap: () => _onTabTap(index),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            // A soft pill grows behind the active tab's icon (as in the Rider panel)
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: active ? 56 : 32,
              height: 30,
              decoration: BoxDecoration(
                color: active ? color.withValues(alpha: AppPalette.dark ? 0.18 : 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
              alignment: Alignment.center,
              child: Icon(active ? activeIcon : icon, size: 23, color: color),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, maxLines: 1,
                  style: TextStyle(fontSize: 10, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: color)),
            ),
          ]),
        ),
      ),
    );
  }
}

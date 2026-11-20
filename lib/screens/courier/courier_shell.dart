import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/push_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../providers/courier_provider.dart';
import '../../widgets/tap.dart';
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

  StreamSubscription<PushMessage>? _pushes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null && user.role != 'courier') {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        return;
      }
      // A tapped push notification opens its job (also the one that started the app). The tap
      // can arrive after this screen is built (Firebase starts after the login check), so it
      // is checked again once Home has loaded.
      context.read<CourierProvider>().loadDashboard().whenComplete(_openTappedPush);
      PushService.pendingTap.addListener(_openTappedPush);
      _openTappedPush();
      // A push while the app is open: the new job or offer shows without pulling to refresh
      _pushes = PushService.received.listen((m) {
        // A job push, or one about the rider (e.g. "NBI clearance verified", no job): refresh
        if ((m.tap != null && m.tap!.type != 'job') || !mounted) return;
        final cp = context.read<CourierProvider>();
        cp.loadDashboard();
        cp.loadNotifications();
        if (_idx == 1) cp.loadJobs();
      });
    });
  }

  void _openTappedPush() {
    if (!mounted) return;
    final tap = PushService.takeTap('job');
    if (tap == null) return;
    context.read<CourierProvider>().loadNotifications();
    if (tap.opensDetail) {
      Navigator.pushNamed(context, '/courier/job', arguments: tap.id);
    } else {
      Navigator.pushNamed(context, '/courier/notifications');
    }
  }

  @override
  void dispose() {
    PushService.pendingTap.removeListener(_openTappedPush);
    _pushes?.cancel();
    super.dispose();
  }

  void _onTabTap(int i) {
    setState(() => _idx = i);
    final cp = context.read<CourierProvider>();
    switch (i) {
      case 0:
        cp.loadDashboard();
        break;
      case 1:
        cp.loadJobs();
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
    // Another screen asked to open a tab (Home's "Upload NBI clearance" → Profile)
    final requested = cp.takeRequestedTab();
    if (requested != null && requested != _idx) {
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _onTabTap(requested); });
    }

    return Scaffold(
      // Every tab stays alive; switching fades the new one in (TaptapShop)
      body: _FadeTabs(index: _idx, children: _screens),
      bottomNavigationBar: _BhBottomBar(
        selectedIndex: _idx,
        onTap: _onTabTap,
        isOnline: isOnline,
      ),
    );
  }
}

/// Like an IndexedStack (each tab keeps its state), but the newly picked tab fades in with a
/// slight upward glide instead of appearing at once — TaptapShop's _FadeTabs.
class _FadeTabs extends StatefulWidget {
  final int index;
  final List<Widget> children;
  const _FadeTabs({required this.index, required this.children});
  @override
  State<_FadeTabs> createState() => _FadeTabsState();
}

class _FadeTabsState extends State<_FadeTabs> with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 240), value: 1);
  late final _curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);

  @override
  void didUpdateWidget(_FadeTabs old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _curve,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.015), end: Offset.zero).animate(_curve),
          child: IndexedStack(index: widget.index, children: widget.children),
        ),
      );
}

// ── Bottom bar (TaptapShop's _BottomNav, with the rider's Scan button in the middle) ──

class _BhBottomBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final bool isOnline;

  const _BhBottomBar({
    required this.selectedIndex,
    required this.onTap,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    // Rounded top corners with a soft shadow, so the bar floats over the page
    return Container(
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
            _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home',
                index: 0, current: selectedIndex, onTap: onTap, showOnlineDot: isOnline),
            _NavItem(icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2, label: 'Parcels',
                index: 1, current: selectedIndex, onTap: onTap),
            const _ScanButton(),
            _NavItem(icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet,
                label: 'Earnings', index: 2, current: selectedIndex, onTap: onTap),
            _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile',
                index: 3, current: selectedIndex, onTap: onTap),
          ]),
        ),
      ),
    );
  }
}

/// The rider's waybill scanner, raised in the middle of the bar.
class _ScanButton extends StatelessWidget {
  const _ScanButton();

  @override
  Widget build(BuildContext context) => Expanded(
        child: Semantics(
          label: 'Scan parcel',
          button: true,
          child: Tap(
            onTap: () => Navigator.pushNamed(context, '/courier/scan'),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: kPrimaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: kBrand900.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3)),
                  ],
                ),
                child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 2),
              _label('Scan', active: false),
            ]),
          ),
        ),
      );
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int current;
  final ValueChanged<int> onTap;
  final bool showOnlineDot;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
    this.showOnlineDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    final color = isActive ? _activeColor : kTextSecondary;
    return Expanded(
      child: Semantics(
        selected: isActive,
        button: true,
        label: label,
        excludeSemantics: true,
        child: Tap(
          onTap: () => onTap(index),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            // A soft pill grows behind the active tab's icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: isActive ? 56 : 32,
              height: 30,
              decoration: BoxDecoration(
                color: isActive ? _activeColor.withValues(alpha: AppPalette.dark ? 0.18 : 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
              alignment: Alignment.center,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                // Green dot on Home while the rider is Online
                child: Badge(
                  key: ValueKey(isActive),
                  isLabelVisible: showOnlineDot,
                  smallSize: 8,
                  backgroundColor: const Color(0xFF4CAF50),
                  child: AnimatedScale(
                    scale: isActive ? 1.0 : 0.92,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(isActive ? activeIcon : icon, size: 23, color: color),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            _label(label, active: isActive),
          ]),
        ),
      ),
    );
  }
}

Color get _activeColor => AppPalette.dark ? kTealOnDark : kBrand700;

/// One line always: shrinks on narrow phones or with large text (TaptapShop).
Widget _label(String text, {required bool active}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? _activeColor : kTextSecondary,
          ),
        ),
      ),
    );

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/seller_provider.dart';
import 'seller_dashboard_screen.dart';
import 'seller_products_screen.dart';
import 'seller_orders_screen.dart';
import 'seller_profile_screen.dart';
import 'seller_widgets.dart';

/// Index → screen mapping (defined in seller_widgets.dart)

class SellerShell extends StatefulWidget {
  const SellerShell({super.key});
  @override State<SellerShell> createState() => SellerShellState();
}

class SellerShellState extends State<SellerShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  SellerPage _page = SellerPage.dashboard;

  void openDrawer() => _scaffoldKey.currentState?.openDrawer();

  void navigateTo(SellerPage page) {
    setState(() => _page = page);
    _scaffoldKey.currentState?.closeDrawer();
    final sp = context.read<SellerProvider>();
    switch (page) {
      case SellerPage.dashboard: sp.loadDashboard();
      case SellerPage.products:  sp.loadProducts();
      case SellerPage.orders:    sp.loadOrders();
      case SellerPage.profile:   sp.loadProfile();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sp = context.read<SellerProvider>();
      sp.loadDashboard();
      sp.loadCategories();
    });
  }

  Widget _buildBody() {
    switch (_page) {
      case SellerPage.dashboard: return SellerDashboardScreen(shell: this);
      case SellerPage.products:  return SellerProductsScreen(shell: this);
      case SellerPage.orders:    return SellerOrdersScreen(shell: this);
      case SellerPage.profile:   return SellerProfileScreen(shell: this);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sp      = context.watch<SellerProvider>();
    final auth    = context.watch<AuthProvider>();
    final user    = auth.user;
    final pending = sp.orders.where((o) => o.status == 'pending').length;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _SellerDrawer(
        currentPage: _page,
        pendingOrders: pending,
        user: user,
        onNavigate: navigateTo,
        onLogout: () => _logout(context, auth),
      ),
      body: _buildBody(),
    );
  }

  Future<void> _logout(BuildContext ctx, AuthProvider auth) async {
    _scaffoldKey.currentState?.closeDrawer();
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Log Out',
                  style: TextStyle(color: C.danger))),
        ],
      ),
    );
    if (ok == true && ctx.mounted) {
      await auth.logout();
      if (ctx.mounted) {
        Navigator.pushNamedAndRemoveUntil(ctx, '/login', (_) => false);
      }
    }
  }
}

// ── Drawer ─────────────────────────────────────────────────────────────────────
class _SellerDrawer extends StatelessWidget {
  final SellerPage currentPage;
  final int pendingOrders;
  final dynamic user;
  final void Function(SellerPage) onNavigate;
  final VoidCallback onLogout;

  const _SellerDrawer({
    required this.currentPage,
    required this.pendingOrders,
    required this.user,
    required this.onNavigate,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final p = user?.profile;

    return Drawer(
      width: 270,
      child: Container(
        decoration: const BoxDecoration(gradient: C.sidebarGrad),
        child: SafeArea(
          child: Column(children: [
            // ── Header: logo + title ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(children: [
                Image.asset('assets/images/taptapgo-logo.png',
                    width: 42, height: 42),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  RichText(text: const TextSpan(
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    children: [
                      TextSpan(text: 'Taptap', style: TextStyle(color: Colors.white)),
                      TextSpan(text: 'Go', style: TextStyle(color: Color(0xFF8FE0D2), fontStyle: FontStyle.italic)),
                    ],
                  )),
                  Text('Seller Panel',
                      style: TextStyle(
                          color: C.grad4.withValues(alpha: 0.75),
                          fontSize: 11)),
                ]),
              ]),
            ),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 8),

            // ── Main Menu ───────────────────────────────────────────────
            _section('MAIN MENU'),
            _navItem(context, Icons.dashboard_outlined, Icons.dashboard,
                'Dashboard', SellerPage.dashboard),
            _navItem(context, Icons.inventory_2_outlined, Icons.inventory_2,
                'My Products', SellerPage.products),
            _navItemBadge(context, Icons.receipt_long_outlined,
                Icons.receipt_long, 'Orders', SellerPage.orders,
                pendingOrders),
            const SizedBox(height: 12),

            // ── Account ─────────────────────────────────────────────────
            _section('ACCOUNT'),
            _navItem(context, Icons.person_outline, Icons.person,
                'My Profile', SellerPage.profile),
            _logoutItem(context),

            const Spacer(),

            // ── User info footer ─────────────────────────────────────────
            Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  child: Text(
                    user?.initials ?? '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (p?.businessName != null)
                        Text(p!.businessName!,
                            style: TextStyle(
                                color: C.grad4.withValues(alpha: 0.75),
                                fontSize: 10),
                            overflow: TextOverflow.ellipsis),
                      Text(user?.name ?? '',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _section(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
    child: Text(label,
        style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: C.grad4.withValues(alpha: 0.6),
            letterSpacing: 1.2)),
  );

  Widget _navItem(BuildContext ctx, IconData icon, IconData activeIcon,
      String label, SellerPage page) {
    final isActive = currentPage == page;
    return _NavRow(
      icon: isActive ? activeIcon : icon,
      label: label,
      isActive: isActive,
      onTap: () => onNavigate(page),
    );
  }

  Widget _navItemBadge(BuildContext ctx, IconData icon, IconData activeIcon,
      String label, SellerPage page, int badge) {
    final isActive = currentPage == page;
    return _NavRow(
      icon: isActive ? activeIcon : icon,
      label: label,
      isActive: isActive,
      badge: badge,
      onTap: () => onNavigate(page),
    );
  }

  Widget _logoutItem(BuildContext ctx) => _NavRow(
    icon: Icons.logout,
    label: 'Logout',
    isActive: false,
    isDanger: true,
    onTap: onLogout,
  );
}

// ── Single nav row ─────────────────────────────────────────────────────────────
class _NavRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isDanger;
  final int badge;
  final VoidCallback onTap;

  const _NavRow({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.isDanger = false,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDanger
        ? C.danger
        : isActive
            ? Colors.white
            : C.grad4.withValues(alpha: 0.82);

    return Stack(
      children: [
        // Active left accent bar
        if (isActive)
          Positioned(
            left: 0, top: 6, bottom: 6,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w500)),
              ),
              if (badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: C.danger,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$badge',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
            ]),
          ),
        ),
      ],
    );
  }
}

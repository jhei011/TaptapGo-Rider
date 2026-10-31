import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/seller_provider.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/empty_state.dart';
import 'seller_shell.dart';
import 'seller_widgets.dart';

class SellerDashboardScreen extends StatefulWidget {
  final SellerShellState? shell;
  const SellerDashboardScreen({super.key, this.shell});
  @override State<SellerDashboardScreen> createState() => _SellerDashState();
}

class _SellerDashState extends State<SellerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<SellerProvider>().loadDashboard());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final sp   = context.watch<SellerProvider>();
    final user = auth.user;
    final db   = sp.dashboard;
    final p    = user?.profile;

    return Scaffold(
      backgroundColor: C.bg,
      appBar: SellerAppBar(
        title: 'Dashboard',
        onMenuTap: () {
          widget.shell?.openDrawer();
          if (widget.shell == null) Scaffold.of(context).openDrawer();
        },
      ),
      body: sp.loadingDash
          ? const LoadingCenter()
          : RefreshIndicator(
              onRefresh: sp.loadDashboard,
              color: C.b600,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Welcome banner ──────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: C.heroGrad,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_greeting(p?.firstName ?? user?.name.split(' ').first ?? ''),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Text(
                                  "Here's how your store is doing today.",
                                  style: TextStyle(
                                      color: Colors.white
                                          .withValues(alpha: 0.75),
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.white
                                      .withValues(alpha: 0.22)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min,
                                children: [
                              const Icon(Icons.calendar_today_outlined,
                                  size: 12, color: Colors.white),
                              const SizedBox(width: 5),
                              Text(_todayDate(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500)),
                            ]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (db != null) ...[
                      // ── 4 Stat cards (2×2 grid) ─────────────────────
                      Column(children: [
                        Row(children: [
                          Expanded(child: _StatHero(
                            label: 'Total Earnings',
                            value: '₱${(db['total_revenue'] as num? ?? 0).toStringAsFixed(2)}',
                            icon: Icons.currency_exchange,
                          )),
                          const SizedBox(width: 10),
                          Expanded(child: _StatCard(
                            label: 'Total Products',
                            value: '${db['total_products'] ?? 0}',
                            icon: Icons.inventory_2_outlined,
                            bg: C.b50,
                            iconBg: C.b100,
                            iconColor: C.b700,
                            accentColor: C.b600,
                          )),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: _StatCard(
                            label: 'Active Products',
                            value: '${db['active_products'] ?? db['total_products'] ?? 0}',
                            icon: Icons.check_circle_outline,
                            bg: const Color(0xFFF2FBFA),
                            iconBg: C.grad4,
                            iconColor: C.b800,
                            accentColor: C.grad3,
                          )),
                          const SizedBox(width: 10),
                          Expanded(child: _StatCard(
                            label: 'Total Orders',
                            value: '${db['total_orders'] ?? 0}',
                            icon: Icons.receipt_long_outlined,
                            bg: C.cream,
                            iconBg: C.creamDark,
                            iconColor: const Color(0xFFA15C1F),
                            accentColor: const Color(0xFFC99A3D),
                          )),
                        ]),
                      ]),
                      const SizedBox(height: 16),

                      // ── Quick Actions ────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: C.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Quick Actions',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: C.textPrimary)),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(
                                child: _QuickAction(
                                  label: 'Add New Product',
                                  icon: Icons.add_box_outlined,
                                  bg: C.b50,
                                  border: C.b200,
                                  iconColor: C.b700,
                                  onTap: () async {
                                    await Navigator.pushNamed(
                                        context,
                                        '/seller/products/add');
                                    if (context.mounted) {
                                      context.read<SellerProvider>().loadDashboard();
                                      context.read<SellerProvider>().loadProducts();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _QuickAction(
                                  label: 'View Orders',
                                  icon: Icons.receipt_long_outlined,
                                  bg: const Color(0xFFF2FBFA),
                                  border: C.grad4,
                                  iconColor: C.b800,
                                  onTap: () => widget.shell?.navigateTo(
                                          SellerPage.orders),
                                ),
                              ),
                            ]),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Recent Products ──────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Recent Products',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: C.textPrimary)),
                              Text('Your latest listings',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: C.textSecondary)),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => widget.shell
                                ?.navigateTo(SellerPage.products),
                            child: const Text('View all →',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: C.b600,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Product cards — mobile-friendly list
                      if ((db['recent_products'] as List?)?.isNotEmpty == true)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: C.b100),
                          ),
                          child: Column(
                            children: (db['recent_products'] as List)
                                .map<Widget>((item) {
                              final m = item as Map<String, dynamic>;
                              return _ProductRow(product: m);
                            }).toList(),
                          ),
                        )
                      // Fallback: recent_orders if no recent_products
                      else if ((db['recent_orders'] as List?)
                              ?.isNotEmpty ==
                          true) ...[
                        const SizedBox(height: 4),
                        ...((db['recent_orders'] as List).map((o) {
                          final m = o as Map<String, dynamic>;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: C.border),
                            ),
                            child: Row(children: [
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                Text('Order #${m['id']}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13)),
                                Text(m['buyer_name'] ?? '',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: C.textSecondary)),
                              ])),
                              Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                StatusPill(
                                    status: m['status'] ?? '',
                                    small: true),
                                const SizedBox(height: 3),
                                Text(
                                    '₱${(m['total'] as num? ?? 0).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: C.b700)),
                              ]),
                            ]),
                          );
                        })),
                      ] else
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(10)),
                            border: Border.all(color: C.b100),
                          ),
                          child: const Center(
                            child: Text('No products yet',
                                style: TextStyle(
                                    color: C.textMuted, fontSize: 13)),
                          ),
                        ),
                    ] else
                      const Center(
                          child: Text('No data',
                              style: TextStyle(color: C.textMuted))),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  String _greeting(String name) {
    final h = DateTime.now().hour;
    final part = h < 12
        ? 'Good morning'
        : h < 17
            ? 'Good afternoon'
            : 'Good evening';
    return '$part, $name';
  }

  String _todayDate() {
    final now = DateTime.now();
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
  }
}

// ── Total Earnings — dark gradient hero card ───────────────────────────────────
class _StatHero extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _StatHero({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: C.heroGrad,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 15),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.75))),
          ]),
        ),
      ],
    ),
  );
}

// ── Regular stat card ──────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color bg, iconBg, iconColor, accentColor;

  const _StatCard({
    required this.label, required this.value, required this.icon,
    required this.bg, required this.iconBg,
    required this.iconColor, required this.accentColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      border: Border(top: BorderSide(color: accentColor, width: 3)),
      boxShadow: const [
        BoxShadow(
            color: Color(0x060E2A38), blurRadius: 6, offset: Offset(0, 2))
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 15),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: iconColor)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: C.textSecondary)),
          ]),
        ),
      ],
    ),
  );
}

// ── Quick action card ──────────────────────────────────────────────────────────
class _QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bg, border, iconColor;
  final VoidCallback onTap;

  const _QuickAction({
    required this.label, required this.icon,
    required this.bg, required this.border, required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: iconColor)),
        ),
        Icon(Icons.chevron_right, size: 16, color: iconColor),
      ]),
    ),
  );
}

// ── Recent product row ────────────────────────────────────────────────────────
class _ProductRow extends StatelessWidget {
  final Map<String, dynamic> product;
  const _ProductRow({required this.product});

  @override
  Widget build(BuildContext context) {
    final imageUrl = product['image'] as String?;
    final name     = product['name'] ?? '—';
    final category = (product['category'] as Map?)?['name'] ?? '—';
    final price    = (product['price'] as num?)?.toDouble() ?? 0;
    final stock    = product['stock'] ?? 0;
    final status   = product['status'] ?? 'active';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: C.border, width: 0.5)),
      ),
      child: Row(children: [
        // Image
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 48, height: 48,
            child: imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: imageUrl, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                        color: C.b50,
                        child: const Icon(Icons.image_outlined,
                            color: C.b200, size: 20)))
                : Container(color: C.b50,
                    child: const Icon(Icons.image_outlined,
                        color: C.b200, size: 20)),
          ),
        ),
        const SizedBox(width: 10),
        // Name + category + price
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(name,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: C.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: C.b50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(category,
                  style: const TextStyle(
                      fontSize: 10,
                      color: C.b700,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1),
            ),
            const SizedBox(height: 3),
            Text('₱${price.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: C.b700)),
          ]),
        ),
        const SizedBox(width: 8),
        // Stock + status
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$stock in stock',
              style: const TextStyle(
                  fontSize: 10, color: C.textMuted)),
          const SizedBox(height: 4),
          StatusPill(status: status, small: true),
        ]),
      ]),
    );
  }
}



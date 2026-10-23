import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../providers/courier_provider.dart';
import '../../widgets/bh_app_bar.dart';
import '../../widgets/bh_skeleton.dart';
import '../../widgets/bh_stat_tile.dart';
import '../../widgets/bh_status_chip.dart';
import '../../widgets/bh_offline_banner.dart';
import '../../widgets/bh_empty_state.dart';

class CourierDashboardScreen extends StatefulWidget {
  const CourierDashboardScreen({super.key});
  @override
  State<CourierDashboardScreen> createState() => _CourierDashState();
}

class _CourierDashState extends State<CourierDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<CourierProvider>().loadDashboard());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cp = context.watch<CourierProvider>();
    final user = auth.user;
    if (user == null) return const SizedBox.shrink();
    final db = cp.dashboard;

    return Scaffold(
      backgroundColor: kSurfaceRaised,
      appBar: BhAppBar(
        title: 'Dashboard',
        showBack: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: cp.loadDashboard,
          ),
        ],
      ),
      body: BhOfflineBanner(
        child: cp.loadingDash
            ? const Padding(
                padding: EdgeInsets.all(kSpace16),
                child: SkeletonList(count: 3),
              )
            : RefreshIndicator(
                onRefresh: cp.loadDashboard,
                color: kBrand600,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(kSpace16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Welcome + Online/Offline banner ──────────────────
                      _WelcomeBanner(user: user, cp: cp, db: db),
                      const SizedBox(height: kSpace14),

                      // ── Stats row ─────────────────────────────────────────
                      _StatsRow(db: db),
                      const SizedBox(height: kSpace14),

                      // ── Earnings summary ─────────────────────────────────
                      if (db != null) _EarningsCard(db: db),
                      if (db != null) const SizedBox(height: kSpace14),

                      // ── Active parcels ───────────────────────────────────
                      Text('Active Parcels',
                          style: kHeadingSm.copyWith(color: kTextPrimary)),
                      const SizedBox(height: kSpace10),

                      if (db != null &&
                          (db['assigned_orders'] as List?)?.isNotEmpty == true)
                        ...((db['assigned_orders'] as List).map((o) =>
                            _ParcelCard(
                              order: o as Map<String, dynamic>,
                              cp: cp,
                            )))
                      else
                        const BhEmptyState(
                          icon: Icons.inbox_outlined,
                          title: 'No active parcels',
                          subtitle: 'New assignments will appear here',
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

// ── Welcome + Online/Offline Banner ──────────────────────────────────────────
class _WelcomeBanner extends StatelessWidget {
  final dynamic user;
  final CourierProvider cp;
  final Map<String, dynamic>? db;

  const _WelcomeBanner({required this.user, required this.cp, required this.db});

  @override
  Widget build(BuildContext context) {
    final isOnline = cp.isOnline ?? false;
    final isToggling = cp.togglingOnline;
    final company =
        db?['logistics_company'] as String? ?? 'Bilis Hatid Express Inc.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(kSpace20),
      decoration: BoxDecoration(
        color: kBrand800,
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: const [
          BoxShadow(
              color: Color(0x220E2A38), blurRadius: 12, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome back,',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(user.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(company,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: kSpace12),
              // Date pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(kRadiusSm),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Text(_todayDate(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: kSpace16),

          // ── Online / Offline toggle ──────────────────────────────────
          GestureDetector(
            onTap: isToggling ? null : () => cp.toggleOnlineStatus(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isOnline
                    ? const Color(0xFF2E7D4F).withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(kRadiusMd),
                border: Border.all(
                    color: isOnline
                        ? const Color(0xFF4CAF50)
                        : Colors.white.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isToggling)
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                  else
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isOnline
                            ? const Color(0xFF69F0AE)
                            : Colors.white.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                        boxShadow: isOnline
                            ? [
                                BoxShadow(
                                    color: const Color(0xFF69F0AE)
                                        .withValues(alpha: 0.6),
                                    blurRadius: 6)
                              ]
                            : null,
                      ),
                    ),
                  const SizedBox(width: kSpace8),
                  Text(
                    isToggling
                        ? 'Updating...'
                        : isOnline
                            ? 'Online — Ready to Deliver'
                            : 'Offline — Go Online to Accept Parcels',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  _OnlineSwitch(isOnline: isOnline),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _todayDate() {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }
}

class _OnlineSwitch extends StatelessWidget {
  final bool isOnline;
  const _OnlineSwitch({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 40,
      height: 22,
      decoration: BoxDecoration(
        color: isOnline
            ? const Color(0xFF4CAF50)
            : Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          alignment: isOnline ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 16,
            height: 16,
            decoration:
                const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final Map<String, dynamic>? db;
  const _StatsRow({required this.db});

  @override
  Widget build(BuildContext context) {
    final totalDelivered = db?['total_delivered'] ?? 0;
    final activeCount = (db?['assigned_orders'] as List?)?.length ?? 0;
    final todayCount = db?['today_delivered'] ?? 0;

    return Row(children: [
      Expanded(
        child: BhStatTile(
          value: '$totalDelivered',
          label: 'Total Delivered',
          icon: Icons.check_circle_outline,
          iconColor: kBrand600,
        ),
      ),
      const SizedBox(width: kSpace10),
      Expanded(
        child: BhStatTile(
          value: '$activeCount',
          label: 'Active Parcels',
          icon: Icons.inventory_2_outlined,
          iconColor: kBrand400,
        ),
      ),
      const SizedBox(width: kSpace10),
      Expanded(
        child: BhStatTile(
          value: '$todayCount',
          label: 'Today',
          icon: Icons.today_outlined,
          iconColor: const Color(0xFFF0A500),
        ),
      ),
    ]);
  }
}

// ── Earnings Summary Card ─────────────────────────────────────────────────────
class _EarningsCard extends StatelessWidget {
  final Map<String, dynamic> db;
  const _EarningsCard({required this.db});

  @override
  Widget build(BuildContext context) {
    final todayEarnings = (db['today_earnings'] as num?)?.toDouble() ?? 0.0;
    final totalEarnings = (db['total_earnings'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(kSpace16),
      decoration: BoxDecoration(
        color: kSurfaceBase,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kBorderDefault),
        boxShadow: const [
          BoxShadow(
              color: Color(0x060E2A38), blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: kBrand50,
            borderRadius: BorderRadius.circular(kRadiusMd),
          ),
          child: const Icon(Icons.account_balance_wallet_outlined,
              size: 22, color: kBrand700),
        ),
        const SizedBox(width: kSpace14),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Earnings',
                style: kBodySm.copyWith(color: kTextSecondary)),
            const SizedBox(height: 2),
            Text('₱${totalEarnings.toStringAsFixed(2)}',
                style: kDisplaySm.copyWith(color: kBrand700)),
          ],
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: kStatusDeliveredBg,
            borderRadius: BorderRadius.circular(kRadiusSm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Today',
                  style: kLabelSm.copyWith(color: kStatusDeliveredFg)),
              Text('₱${todayEarnings.toStringAsFixed(2)}',
                  style: kHeadingSm.copyWith(color: kStatusDeliveredFg)),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Active Parcel Card ────────────────────────────────────────────────────────
class _ParcelCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final CourierProvider cp;

  const _ParcelCard({required this.order, required this.cp});

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String? ?? '';
    final address = [
      order['delivery_barangay'],
      order['delivery_municipality'],
      order['delivery_province'],
    ].where((s) => s != null && (s as String).isNotEmpty).join(', ');

    final canPickUp = status == 'ready_for_pickup';
    final canDeliver = status == 'out_for_delivery';

    return Container(
      margin: const EdgeInsets.only(bottom: kSpace10),
      padding: const EdgeInsets.all(kSpace16),
      decoration: BoxDecoration(
        color: kSurfaceBase,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kBorderDefault),
        boxShadow: const [
          BoxShadow(
              color: Color(0x060E2A38), blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      color: kBrand50,
                      borderRadius: BorderRadius.circular(kSpace10)),
                  child: const Icon(Icons.inventory_2_outlined,
                      size: 18, color: kBrand700),
                ),
                const SizedBox(width: kSpace10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Parcel #${order['id']}',
                      style: kHeadingSm.copyWith(color: kTextPrimary)),
                  if (order['buyer_name'] != null)
                    Text(order['buyer_name'],
                        style: kBodySm.copyWith(color: kTextSecondary)),
                ]),
              ]),
              BhStatusChip(status: status, size: BhChipSize.small),
            ],
          ),
          const SizedBox(height: kSpace10),

          // Address
          Row(children: [
            const Icon(Icons.location_on_outlined, size: 13, color: kBrand600),
            const SizedBox(width: kSpace4),
            Expanded(
              child: Text(address,
                  style: kBodySm.copyWith(color: kTextSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: kSpace8),
            Text('₱${(order['total'] as num? ?? 0).toStringAsFixed(2)}',
                style: kHeadingSm.copyWith(color: kBrand700)),
          ]),

          const SizedBox(height: kSpace12),

          // Action buttons
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.info_outline, size: 15),
                label: const Text('Details'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kBrand700,
                  side: const BorderSide(color: kBorderDefault),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kRadiusSm + 3)),
                  textStyle: kLabelMd,
                ),
                onPressed: () => Navigator.pushNamed(
                    context, '/courier/parcel',
                    arguments: order['id'] as int),
              ),
            ),
            if (canPickUp || canDeliver) ...[
              const SizedBox(width: kSpace10),
              Expanded(
                child: ElevatedButton.icon(
                  icon: Icon(
                      canPickUp
                          ? Icons.local_shipping_outlined
                          : Icons.check_circle_outline,
                      size: 15),
                  label: Text(canPickUp ? 'Picked Up' : 'Delivered'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        canPickUp ? kBrand600 : kStatusDeliveredFg,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(kRadiusSm + 3)),
                    elevation: 0,
                    textStyle: kLabelMd,
                  ),
                  onPressed: () => _confirmAction(context, order['id'] as int,
                      canPickUp ? 'pickup' : 'deliver'),
                ),
              ),
            ],
          ]),
        ],
      ),
    );
  }

  Future<void> _confirmAction(
      BuildContext ctx, int orderId, String action) async {
    final isPickup = action == 'pickup';
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusLg)),
        title: Text(isPickup ? 'Confirm Pickup' : 'Confirm Delivery'),
        content: Text(isPickup
            ? 'Mark Parcel #$orderId as picked up (out for delivery)?'
            : 'Mark Parcel #$orderId as delivered?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isPickup ? 'Picked Up' : 'Delivered',
                  style: const TextStyle(color: kBrand700))),
        ],
      ),
    );
    if (ok == true && ctx.mounted) {
      final success = isPickup
          ? await cp.markPickedUp(orderId)
          : await cp.markDelivered(orderId);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text(success
              ? 'Parcel #$orderId updated successfully'
              : cp.error ?? 'Update failed'),
          backgroundColor: success ? kBrand700 : kActionDestructive,
        ));
        if (success) cp.loadDashboard();
      }
    }
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/seller_provider.dart';
import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/empty_state.dart';
import '../courier/rider_job_widgets.dart' show formatTime;
import 'seller_shell.dart';
import 'seller_widgets.dart';
class SellerOrdersScreen extends StatefulWidget {
  final SellerShellState? shell;
  const SellerOrdersScreen({super.key, this.shell});
  @override State<SellerOrdersScreen> createState() => _SellerOrdersState();
}

class _SellerOrdersState extends State<SellerOrdersScreen> {
  String _searchQuery = '';
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<SellerProvider>().loadOrders());
  }

  List<Order> _filtered(List<Order> orders) {
    return orders.where((o) {
      final matchSearch = _searchQuery.isEmpty ||
          '#${o.id}'.contains(_searchQuery) ||
          (o.buyerName?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
              false);
      final matchStatus =
          _filterStatus == 'all' || o.status == _filterStatus;
      return matchSearch && matchStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final sp     = context.watch<SellerProvider>();
    final orders = _filtered(sp.orders);

    return Scaffold(
      backgroundColor: C.bg,
      appBar: SellerAppBar(
        title: 'Orders',
        onMenuTap: () {
          widget.shell?.openDrawer();
          if (widget.shell == null) Scaffold.of(context).openDrawer();
        },
      ),
      body: sp.loadingOrders
          ? const LoadingCenter()
          : Column(children: [
              // ── Search + Filter bar ───────────────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(children: [
                  // Search
                  Expanded(
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: C.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: C.border),
                      ),
                      child: Row(children: [
                        const SizedBox(width: 10),
                        const Icon(Icons.search,
                            size: 16, color: C.textMuted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            onChanged: (v) =>
                                setState(() => _searchQuery = v),
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: 'Search order # or buyer...',
                              hintStyle: TextStyle(
                                  color: C.textMuted, fontSize: 12),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status filter
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: C.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: C.border),
                    ),
                    child: DropdownButton<String>(
                      value: _filterStatus,
                      underline: const SizedBox(),
                      isDense: true,
                      style: const TextStyle(
                          fontSize: 12, color: C.textPrimary),
                      items: const [
                        DropdownMenuItem(
                            value: 'all', child: Text('All Status')),
                        DropdownMenuItem(
                            value: 'pending', child: Text('Pending')),
                        DropdownMenuItem(
                            value: 'confirmed',
                            child: Text('Confirmed')),
                        DropdownMenuItem(
                            value: 'ready_for_pickup',
                            child: Text('Ready for Pickup')),
                        DropdownMenuItem(
                            value: 'out_for_delivery',
                            child: Text('Out for Delivery')),
                        DropdownMenuItem(
                            value: 'delivered',
                            child: Text('Delivered')),
                        DropdownMenuItem(
                            value: 'cancelled',
                            child: Text('Cancelled')),
                      ],
                      onChanged: (v) =>
                          setState(() => _filterStatus = v ?? 'all'),
                    ),
                  ),
                ]),
              ),

              // ── Order list ────────────────────────────────────────
              Expanded(
                child: orders.isEmpty
                    ? EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: sp.orders.isEmpty
                            ? 'No orders yet'
                            : 'No orders match filter',
                        subtitle: sp.orders.isEmpty
                            ? 'Orders from buyers will appear here'
                            : 'Try adjusting your search or filter',
                      )
                    : RefreshIndicator(
                        onRefresh: sp.loadOrders,
                        color: C.b600,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(14),
                          itemCount: orders.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) =>
                              _OrderCard(order: orders[i], sp: sp),
                        ),
                      ),
              ),
            ]),
    );
  }
}

// ── Order card ─────────────────────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final Order order;
  final SellerProvider sp;
  const _OrderCard({required this.order, required this.sp});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x060E2A38), blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Order header ──────────────────────────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Icon box
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: C.b50, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.receipt_outlined,
                size: 18, color: C.b700),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order #${order.id}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: C.textPrimary)),
                if (order.createdAt != null)
                  Text(_fmt(order.createdAt!),
                      style: const TextStyle(
                          fontSize: 11, color: C.textMuted)),
                if (order.buyerName != null)
                  Text(order.buyerName!,
                      style: const TextStyle(
                          fontSize: 12, color: C.textSecondary)),
              ],
            ),
          ),
          // Payment + status side by side
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: C.grad4,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(order.paymentMethod.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: C.b800)),
            ),
            const SizedBox(width: 6),
            StatusPill(status: order.status, small: true),
          ]),
        ]),

        const SizedBox(height: 12),

        // ── Order items ───────────────────────────────────────────────
        ...order.items.isNotEmpty
            ? order.items.map((item) => _ItemRow(item: item))
            : [
                Text('${order.itemsCount ?? 0} item(s)',
                    style: const TextStyle(
                        fontSize: 13, color: C.textSecondary))
              ],

        const Divider(height: 18, color: C.border),

        // ── Order notes ───────────────────────────────────────────────
        if (order.notes?.isNotEmpty == true) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: C.cream,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: C.creamDark),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Icon(Icons.sticky_note_2_outlined,
                  size: 14, color: Color(0xFFA15C1F)),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Order Notes',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFA15C1F))),
                  const SizedBox(height: 2),
                  Text(order.notes!,
                      style: const TextStyle(
                          fontSize: 12, color: C.textPrimary)),
                ]),
              ),
            ]),
          ),
        ],

        // ── Footer: address + financial breakdown + status ────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        size: 13, color: C.b600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(order.shortAddress,
                          style: const TextStyle(
                              fontSize: 11, color: C.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                  // Shipment progress with the time of the latest step
                  if (order.shipment != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${AppConstants.orderStatusLabel(order.status)} · '
                      '${formatTime(order.shipment!.latestTime)} · ${order.shipment!.trackingNumber}',
                      style: const TextStyle(fontSize: 11, color: C.textSecondary),
                    ),
                  ],
                  if (!order.isCancelled) ...[
                    const SizedBox(height: 8),
                    // Financial breakdown matching website
                    _finRow('Subtotal',
                        '₱${order.subtotal.toStringAsFixed(2)}'),
                    _finRow('Commission (10%)',
                        '− ₱${order.commission.toStringAsFixed(2)}',
                        color: C.danger),
                    const Divider(height: 10, color: C.border),
                    Row(children: [
                      const Text('Net Earnings  ',
                          style: TextStyle(
                              fontSize: 11, color: C.textMuted)),
                      Text(
                        '₱${(order.subtotal - order.commission).toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: C.b700),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Status update dropdown — only before the order goes to the logistics company
            if (order.sellerCanUpdate)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: C.gray50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: C.border),
                ),
                child: DropdownButton<String>(
                  value: order.status,
                  underline: const SizedBox(),
                  isDense: true,
                  style: const TextStyle(
                      fontSize: 12,
                      color: C.textPrimary,
                      fontWeight: FontWeight.w500),
                  items: const [
                    DropdownMenuItem(
                        value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(
                        value: 'confirmed', child: Text('Confirmed')),
                    DropdownMenuItem(
                        value: 'ready_for_pickup',
                        child: Text('Ready for Pickup')),
                    DropdownMenuItem(
                        value: 'cancelled', child: Text('Cancelled')),
                  ],
                  onChanged: (s) async {
                    if (s != null && s != order.status) {
                      final ok =
                          await sp.updateOrderStatus(order.id, s);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'Status updated to ${AppConstants.orderStatusLabel(s)}'
                                : sp.error ?? 'Failed'),
                            backgroundColor: ok ? C.b700 : C.danger,
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
          ],
        ),
      ]),
    );
  }

  Widget _finRow(String label, String value, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
      Text(label, style: const TextStyle(fontSize: 11, color: C.textMuted)),
      Text(value, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: color ?? C.textPrimary)),
    ]),
  );

  String _fmt(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      const m = ['Jan','Feb','Mar','Apr','May','Jun',
                  'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${m[d.month - 1]} ${d.day}, ${d.year}  '
          '${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';
    } catch (_) { return iso; }
  }
}

// ── Order item row ─────────────────────────────────────────────────────────────
class _ItemRow extends StatelessWidget {
  final OrderItem item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: C.b50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: C.b100),
        ),
        child: const Icon(Icons.image_outlined, color: C.b200, size: 22),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(item.productName,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text('x${item.quantity} @ ₱${item.productPrice.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 11, color: C.textMuted)),
        ]),
      ),
      Text('₱${item.subtotal.toStringAsFixed(2)}',
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 13)),
    ]),
  );
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/buyer_provider.dart';
import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../widgets/taptap_navbar.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/empty_state.dart';
import '../courier/rider_job_widgets.dart' show formatTime;

class BuyerOrdersScreen extends StatefulWidget {
  const BuyerOrdersScreen({super.key});
  @override State<BuyerOrdersScreen> createState() => _BuyerOrdersState();
}

class _BuyerOrdersState extends State<BuyerOrdersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<BuyerProvider>().loadOrders());
  }

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BuyerProvider>();

    return Scaffold(
      backgroundColor: C.bg,
      appBar: const TaptapNavBar(title: 'My Orders', showBack: false),
      body: bp.loadingOrders
          ? const LoadingCenter()
          : bp.orders.isEmpty
              ? EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No orders yet',
                  subtitle: 'Start shopping and place your first order',
                  buttonLabel: 'Start Shopping',
                  onButton: () => Navigator.pop(context),
                )
              : RefreshIndicator(
                  onRefresh: bp.loadOrders,
                  color: C.b600,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: bp.orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) =>
                        _OrderCard(order: bp.orders[i], bp: bp),
                  ),
                ),
    );
  }
}

// ── Shipment progress on an order card ────────────────────────────────────────
class _ShipmentInfo extends StatelessWidget {
  final Order order;
  const _ShipmentInfo({required this.order});

  @override
  Widget build(BuildContext context) {
    final s = order.shipment!;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Tracking ${s.trackingNumber} · ${AppConstants.orderStatusLabel(order.status)} ${formatTime(s.latestTime)}',
            style: const TextStyle(fontSize: 11, color: C.textSecondary)),
        // A32: the rider asks for this code to complete the delivery
        if (s.deliveryOtp != null)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: C.b50, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.b200)),
            child: Row(children: [
              const Expanded(
                child: Text('Delivery code — give it to the rider when your parcel arrives',
                    style: TextStyle(fontSize: 12, color: C.b700)),
              ),
              Text(s.deliveryOtp!,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 4, color: C.b700)),
            ]),
          ),
        if (s.failedReason != null && order.status != 'delivered')
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              order.status == 'return_to_sender'
                  ? 'Could not be delivered (${s.failedReason}). It is being returned to the seller.'
                  : 'Delivery attempt ${s.attempt} of 3 failed: ${s.failedReason}. The courier will try again.',
              style: const TextStyle(fontSize: 12, color: C.danger),
            ),
          ),
        if (s.podPhotoUrl != null) ...[
          const SizedBox(height: 8),
          Text('Proof of delivery · ${formatTime(s.times['delivered'])}',
              style: const TextStyle(fontSize: 11, color: C.textSecondary)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(s.podPhotoUrl!, height: 140, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ),
        ],
      ]),
    );
  }
}

// ── Order card — matches website .order-card layout exactly ───────────────────
class _OrderCard extends StatelessWidget {
  final Order order;
  final BuyerProvider bp;

  const _OrderCard({required this.order, required this.bp});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x060E2A38), blurRadius: 10, offset: Offset(0, 3))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showDetail(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header: Order# + date | payment pill + status pill ────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Order #${order.id}',
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: C.textPrimary)),
                          const SizedBox(height: 2),
                          Text(_formatDate(order.createdAt),
                              style: const TextStyle(
                                  fontSize: 11, color: C.textMuted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Payment pill + Status pill side by side
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Payment pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: C.b50,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                                width: 6, height: 6,
                                decoration: const BoxDecoration(
                                    color: C.b600, shape: BoxShape.circle)),
                            const SizedBox(width: 5),
                            Text(
                              order.paymentMethod.toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: C.b700),
                            ),
                          ]),
                        ),
                        const SizedBox(width: 6),
                        // Status pill
                        StatusPill(status: order.status),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ── Order items ───────────────────────────────────────────
                ...order.items.map((item) => _ItemRow(item: item)),

                const Divider(height: 20, color: C.border),

                // ── Footer: address + total ────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 14, color: C.b600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              order.shortAddress,
                              style: const TextStyle(
                                  fontSize: 12, color: C.textSecondary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      const Text('Total',
                          style: TextStyle(
                              fontSize: 11, color: C.textMuted)),
                      Text(
                        '₱${order.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: C.b700),
                      ),
                    ]),
                  ],
                ),

                // ── Shipment: delivery code, proof of delivery, failed attempts
                if (order.shipment != null) _ShipmentInfo(order: order),

                // ── Cancel button (pending only) ───────────────────────────
                if (order.isCancellable) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _cancelOrder(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: C.danger,
                        side: BorderSide(
                            color: C.danger.withValues(alpha: 0.5)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9)),
                      ),
                      child: const Text('Cancel Order',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Order detail bottom sheet ────────────────────────────────────────────
  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: C.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            // Title row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Order #${order.id}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 18)),
                    StatusPill(status: order.status),
                  ]),
            ),
            const Divider(height: 18),
            // Scrollable content
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                children: [
                  if (order.seller != null)
                    _dRow('Seller', order.seller!.name),
                  _dRow('Payment',
                      AppConstants.paymentLabel(order.paymentMethod)),
                  _dRow('Payment Status',
                      order.paymentStatus.toUpperCase()),
                  _dRow('Delivery', order.fullAddress),
                  if (order.notes?.isNotEmpty == true)
                    _dRow('Notes', order.notes!),
                  const Divider(height: 20),
                  const Text('Items',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 10),
                  ...order.items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(children: [
                      // Image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 56, height: 56,
                          child: item.image != null
                              ? CachedNetworkImage(
                                  imageUrl: item.image!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      Container(color: C.b50,
                                          child: const Icon(
                                              Icons.image_outlined,
                                              color: C.b200)),
                                )
                              : Container(
                                  color: C.b50,
                                  child: const Icon(
                                      Icons.image_outlined,
                                      color: C.b200)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(item.productName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                          Text(
                            '₱${item.productPrice.toStringAsFixed(2)} × ${item.quantity}',
                            style: const TextStyle(
                                fontSize: 12, color: C.textMuted),
                          ),
                        ]),
                      ),
                      Text('₱${item.subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ]),
                  )),
                  const Divider(height: 20),
                  _summRow('Subtotal',
                      '₱${order.subtotal.toStringAsFixed(2)}'),
                  _summRow('Service fee',
                      '₱${order.commission.toStringAsFixed(2)}'),
                  const SizedBox(height: 4),
                  _summRow('Total',
                      '₱${order.total.toStringAsFixed(2)}',
                      bold: true, color: C.b700),
                  const SizedBox(height: 20),
                  if (order.isCancellable)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _cancelOrder(context);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: C.danger,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      child: const Text('Cancel Order'),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _cancelOrder(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Order'),
        content:
            const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes, Cancel',
                  style: TextStyle(color: C.danger))),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final success = await context.read<BuyerProvider>().cancelOrder(order.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'Order cancelled' : 'Failed to cancel'),
          backgroundColor: success ? C.b700 : C.danger,
        ));
      }
    }
  }

  Widget _dRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
          width: 110,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13, color: C.textSecondary))),
      Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600))),
    ]),
  );

  Widget _summRow(String label, String value,
          {bool bold = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
          Text(label,
              style: TextStyle(
                  fontSize: bold ? 15 : 13, color: C.textSecondary)),
          Text(value,
              style: TextStyle(
                  fontSize: bold ? 17 : 13,
                  fontWeight:
                      bold ? FontWeight.w800 : FontWeight.w600,
                  color: color ?? C.textPrimary)),
        ]),
      );

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      const m = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      return '${m[d.month - 1]} ${d.day}, ${d.year}  '
          '${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

// ── Single item row inside the card ───────────────────────────────────────────
class _ItemRow extends StatelessWidget {
  final OrderItem item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        // Product image — 64×64 matching website
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 64, height: 64,
            child: item.image != null
                ? CachedNetworkImage(
                    imageUrl: item.image!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                        color: C.b50,
                        child: const Icon(Icons.image_outlined,
                            color: C.b200, size: 24)),
                  )
                : Container(
                    color: C.b50,
                    child: const Icon(Icons.image_outlined,
                        color: C.b200, size: 24)),
          ),
        ),
        const SizedBox(width: 12),
        // Name + qty × price
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(item.productName,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: C.textPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(
              'x${item.quantity}  @  ₱${item.productPrice.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 11, color: C.textMuted),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        // Subtotal
        Text(
          '₱${item.subtotal.toStringAsFixed(2)}',
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: C.textPrimary),
        ),
      ]),
    );
  }
}

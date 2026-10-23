import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/constants/app_constants.dart';
import '../../models/order.dart';
import '../../providers/courier_provider.dart';
import '../../widgets/bh_app_bar.dart';
import '../../widgets/bh_skeleton.dart';
import '../../widgets/bh_status_chip.dart';
import '../../widgets/bh_offline_banner.dart';
import '../../widgets/field_card.dart';

class ParcelDetailScreen extends StatefulWidget {
  final int parcelId;
  const ParcelDetailScreen({super.key, required this.parcelId});

  @override
  State<ParcelDetailScreen> createState() => _ParcelDetailScreenState();
}

class _ParcelDetailScreenState extends State<ParcelDetailScreen> {
  Order? _order;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final cp = context.read<CourierProvider>();
    final order = await cp.loadOrderDetail(widget.parcelId);
    if (!mounted) return;
    if (order != null) {
      setState(() {
        _order = order;
        _loading = false;
      });
    } else {
      setState(() {
        _error = cp.error ?? 'Failed to load parcel details.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurfaceRaised,
      appBar: BhAppBar(
        title: _order != null ? 'Parcel #${_order!.id}' : 'Parcel Details',
        showBack: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: BhOfflineBanner(
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(kSpace16),
                child: SkeletonList(count: 6),
              )
            : _error != null
                ? _buildError()
                : _buildBody(),
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────
  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(kSpace24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 48, color: kActionDestructive),
            const SizedBox(height: kSpace12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: kBodyMd.copyWith(color: kTextSecondary)),
            const SizedBox(height: kSpace20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: kBrand700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(kRadiusSm + 3)),
              ),
            ),
          ]),
        ),
      );

  // ── Main body ─────────────────────────────────────────────────────────────
  Widget _buildBody() {
    final o = _order!;
    final cp = context.read<CourierProvider>();

    final canPickUp = o.status == 'ready_for_pickup';
    final canDeliver = o.status == 'out_for_delivery';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(kSpace16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Status banner ────────────────────────────────────────────
          _StatusBanner(order: o),
          const SizedBox(height: kSpace14),

          // ── Delivery address ─────────────────────────────────────────
          FieldCard(
            title: 'Delivery Address',
            titleIcon: Icons.location_on_outlined,
            children: [
              _row('Province', o.deliveryProvince),
              _row('Municipality', o.deliveryMunicipality),
              _row('Barangay', o.deliveryBarangay),
              if (o.deliveryStreet != null && o.deliveryStreet!.isNotEmpty)
                _row('Street', o.deliveryStreet!),
              if (o.deliveryHouseNo != null && o.deliveryHouseNo!.isNotEmpty)
                _row('House / Unit', o.deliveryHouseNo!),
            ],
          ),
          const SizedBox(height: kSpace12),

          // ── Recipient info ────────────────────────────────────────────
          FieldCard(
            title: 'Recipient',
            titleIcon: Icons.person_outline,
            children: [
              _row('Name', o.buyerName ?? '—'),
              _row('Payment', AppConstants.paymentLabel(o.paymentMethod)),
              _row('Payment Status', _payStatusLabel(o.paymentStatus)),
            ],
          ),
          const SizedBox(height: kSpace12),

          // ── Order items ───────────────────────────────────────────────
          if (o.items.isNotEmpty) ...[
            FieldCard(
              title: 'Items',
              titleIcon: Icons.inventory_2_outlined,
              children: [
                ...o.items.map((item) => _ItemRow(item: item)),
              ],
            ),
            const SizedBox(height: kSpace12),
          ],

          // ── Financial summary ─────────────────────────────────────────
          FieldCard(
            title: 'Summary',
            titleIcon: Icons.receipt_long_outlined,
            children: [
              _row('Subtotal', '₱${o.subtotal.toStringAsFixed(2)}'),
              _row('Total', '₱${o.total.toStringAsFixed(2)}',
                  valueStyle: kHeadingMd.copyWith(color: kBrand700)),
            ],
          ),
          const SizedBox(height: kSpace12),

          // ── Notes ─────────────────────────────────────────────────────
          if (o.notes != null && o.notes!.isNotEmpty) ...[
            FieldCard(
              title: 'Notes from Buyer',
              titleIcon: Icons.notes_outlined,
              children: [
                Text(o.notes!,
                    style: kBodyMd.copyWith(color: kTextSecondary, height: 1.5)),
              ],
            ),
            const SizedBox(height: kSpace12),
          ],

          // ── Action buttons ────────────────────────────────────────────
          if (canPickUp)
            _ActionButton(
              label: 'Mark as Picked Up',
              sublabel: 'Confirm you have collected this parcel',
              icon: Icons.local_shipping_outlined,
              color: kBrand600,
              onPressed: () => _confirmAction(context, cp, 'pickup'),
            ),
          if (canDeliver)
            _ActionButton(
              label: 'Mark as Delivered',
              sublabel: 'Confirm successful delivery to recipient',
              icon: Icons.check_circle_outline,
              color: kStatusDeliveredFg,
              onPressed: () => _confirmAction(context, cp, 'deliver'),
            ),
          if (!canPickUp && !canDeliver) _StatusFinalBadge(status: o.status),

          const SizedBox(height: kSpace24),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _row(String label, String value, {TextStyle? valueStyle}) => Padding(
        padding: const EdgeInsets.only(bottom: kSpace10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: kBodySm.copyWith(color: kTextSecondary)),
            const SizedBox(width: kSpace12),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: valueStyle ?? kLabelMd.copyWith(color: kTextPrimary)),
            ),
          ],
        ),
      );

  String _payStatusLabel(String s) => switch (s) {
        'paid' => 'Paid',
        'unpaid' => 'Unpaid (COD)',
        _ => s,
      };

  Future<void> _confirmAction(
      BuildContext ctx, CourierProvider cp, String action) async {
    final isPickup = action == 'pickup';
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadiusLg)),
        title: Text(isPickup ? 'Confirm Pickup' : 'Confirm Delivery'),
        content: Text(isPickup
            ? 'Mark this parcel as picked up and out for delivery?'
            : 'Mark this parcel as successfully delivered?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isPickup ? 'Picked Up' : 'Delivered',
                  style: TextStyle(
                      color: isPickup ? kBrand700 : kStatusDeliveredFg,
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );

    if (ok == true && ctx.mounted) {
      final success = isPickup
          ? await cp.markPickedUp(_order!.id)
          : await cp.markDelivered(_order!.id);

      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text(success
              ? 'Parcel #${_order!.id} updated successfully'
              : cp.error ?? 'Update failed'),
          backgroundColor: success ? kBrand700 : kActionDestructive,
        ));
        if (success) await _load(); // refresh detail
      }
    }
  }
}

// ── Status Banner ─────────────────────────────────────────────────────────────
class _StatusBanner extends StatelessWidget {
  final Order order;
  const _StatusBanner({required this.order});

  @override
  Widget build(BuildContext context) {
    // Determine banner bg/fg via status chip colors (same logic)
    final (bg, fg, _) = _resolveStatus(order.status);

    return Container(
      padding: const EdgeInsets.all(kSpace16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: fg.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(kRadiusMd),
          ),
          child: Icon(_statusIcon(order.status), color: fg, size: 22),
        ),
        const SizedBox(width: kSpace14),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Parcel #${order.id}',
                style: kHeadingMd.copyWith(color: fg)),
            const SizedBox(height: 3),
            BhStatusChip(status: order.status),
            if (order.createdAt != null) ...[
              const SizedBox(height: 4),
              Text(_fmt(order.createdAt!),
                  style: kLabelSm.copyWith(color: kTextMuted)),
            ],
          ],
        )),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('Total', style: kLabelSm.copyWith(color: kTextMuted)),
          Text('₱${order.total.toStringAsFixed(2)}',
              style: kDisplaySm.copyWith(color: kBrand700)),
        ]),
      ]),
    );
  }

  static (Color bg, Color fg, String label) _resolveStatus(String s) =>
      switch (s) {
        'pending' => (kStatusPendingBg, kStatusPendingFg, 'Pending'),
        'ready_for_pickup' => (
            kStatusPickupBg,
            kStatusPickupFg,
            'Ready for Pickup'
          ),
        'out_for_delivery' => (
            kStatusOnWayBg,
            kStatusOnWayFg,
            'Out for Delivery'
          ),
        'delivered' => (kStatusDeliveredBg, kStatusDeliveredFg, 'Delivered'),
        'failed' => (kStatusFailedBg, kStatusFailedFg, 'Failed'),
        'cancelled' => (kStatusCancelledBg, kStatusCancelledFg, 'Cancelled'),
        _ => (kStatusCancelledBg, kStatusCancelledFg, s),
      };

  IconData _statusIcon(String s) => switch (s) {
        'pending' => Icons.hourglass_empty_outlined,
        'confirmed' => Icons.thumb_up_outlined,
        'ready_for_pickup' => Icons.store_outlined,
        'out_for_delivery' => Icons.local_shipping_outlined,
        'delivered' => Icons.check_circle_outline,
        'cancelled' => Icons.cancel_outlined,
        _ => Icons.inventory_2_outlined,
      };

  String _fmt(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      const m = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${m[d.month - 1]} ${d.day}, ${d.year} — '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

// ── Item Row ──────────────────────────────────────────────────────────────────
class _ItemRow extends StatelessWidget {
  final dynamic item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = item.productName as String? ?? '—';
    final qty = item.quantity as int? ?? 0;
    final price = item.productPrice as double? ?? 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace10),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: kBrand50,
              borderRadius: BorderRadius.circular(kRadiusSm)),
          child: const Icon(Icons.inventory_outlined, size: 16, color: kBrand600),
        ),
        const SizedBox(width: kSpace10),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: kLabelMd.copyWith(color: kTextPrimary)),
            Text('Qty: $qty',
                style: kBodySm.copyWith(color: kTextSecondary)),
          ],
        )),
        Text('₱${(price * qty).toStringAsFixed(2)}',
            style: kLabelMd.copyWith(color: kBrand700)),
      ]),
    );
  }
}

// ── Action Button ─────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: kSpace10),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kRadiusLg)),
          elevation: 0,
        ),
        child: Row(children: [
          Icon(icon, size: 22),
          const SizedBox(width: kSpace12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  Text(sublabel,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.8))),
                ]),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14),
        ]),
      ),
    );
  }
}

// ── Final status badge (delivered / cancelled) ────────────────────────────────
class _StatusFinalBadge extends StatelessWidget {
  final String status;
  const _StatusFinalBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isDelivered = status == 'delivered';
    final bg = isDelivered ? kStatusDeliveredBg : kStatusFailedBg;
    final fg = isDelivered ? kStatusDeliveredFg : kActionDestructive;
    final icon = isDelivered ? Icons.check_circle : Icons.cancel;
    final label = isDelivered
        ? 'Parcel Delivered Successfully'
        : 'Parcel Cancelled';
    final sub = isDelivered
        ? 'This delivery has been completed.'
        : 'This parcel has been cancelled.';

    return Container(
      padding: const EdgeInsets.all(kSpace16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(icon, color: fg, size: 28),
        const SizedBox(width: kSpace12),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: kHeadingSm.copyWith(color: fg)),
            Text(sub,
                style: kBodySm.copyWith(color: fg.withValues(alpha: 0.75))),
          ],
        )),
      ]),
    );
  }
}

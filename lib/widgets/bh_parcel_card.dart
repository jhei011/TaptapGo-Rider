import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_tokens.dart';
import '../core/constants/app_constants.dart';
import '../models/order.dart';
import '../providers/courier_provider.dart';
import 'bh_status_chip.dart';

/// Token-styled parcel card.
///
/// Mirrors the logic of the private [_ParcelCard] in courier_orders_screen.dart
/// but uses design-token values instead of raw colours.  Both widgets can
/// co-exist during the migration; the legacy screen is left untouched.
class BhParcelCard extends StatelessWidget {
  const BhParcelCard({
    super.key,
    required this.order,
    required this.cp,
  });

  final Order order;
  final CourierProvider cp;

  @override
  Widget build(BuildContext context) {
    final canPickUp  = order.status == 'ready_for_pickup';
    final canDeliver = order.status == 'out_for_delivery';

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
          context, '/courier/parcel',
          arguments: order.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: kSpace10),
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
            // ── Card header ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  kSpace14, kSpace14, kSpace14, 0),
              child: Row(
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Parcel #${order.id}',
                          style: kHeadingSm.copyWith(color: kTextPrimary),
                        ),
                        if (order.createdAt != null)
                          Text(_fmt(order.createdAt!),
                              style: kBodySm.copyWith(color: kTextMuted)),
                      ],
                    ),
                  ]),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _PaymentBadge(method: order.paymentMethod),
                      const SizedBox(height: kSpace4),
                      BhStatusChip(status: order.status, size: BhChipSize.small),
                    ],
                  ),
                ],
              ),
            ),

            // ── Recipient + address ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  kSpace14, kSpace10, kSpace14, 0),
              child: Container(
                padding: const EdgeInsets.all(kSpace10),
                decoration: BoxDecoration(
                  color: kBrand50,
                  borderRadius: BorderRadius.circular(kRadiusSm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (order.buyerName != null) ...[
                      Row(children: [
                        const Icon(Icons.person_outline,
                            size: 13, color: kBrand600),
                        const SizedBox(width: kSpace4),
                        Text(
                          order.buyerName!,
                          style: kBodySm.copyWith(
                              fontWeight: FontWeight.w600,
                              color: kTextPrimary),
                        ),
                      ]),
                      const SizedBox(height: kSpace4),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 13, color: kBrand600),
                        const SizedBox(width: kSpace4),
                        Expanded(
                          child: Text(
                            order.fullAddress.isNotEmpty
                                ? order.fullAddress
                                : order.shortAddress,
                            style: kBodySm.copyWith(color: kTextSecondary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Total + action buttons ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(kSpace14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total',
                          style: kLabelSm.copyWith(color: kTextMuted)),
                      Text(
                        '₱${order.total.toStringAsFixed(2)}',
                        style: kHeadingMd.copyWith(color: kBrand700),
                      ),
                    ],
                  ),
                  Row(children: [
                    // Always show Details button
                    OutlinedButton.icon(
                      icon: const Icon(Icons.info_outline, size: 14),
                      label: const Text('Details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kBrand700,
                        side: const BorderSide(color: kBorderDefault),
                        padding: const EdgeInsets.symmetric(
                            horizontal: kSpace12, vertical: kSpace8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(kRadiusSm + 3)),
                        textStyle: kLabelMd,
                      ),
                      onPressed: () => Navigator.pushNamed(
                          context, '/courier/parcel',
                          arguments: order.id),
                    ),
                    if (canPickUp || canDeliver) ...[
                      const SizedBox(width: kSpace8),
                      ElevatedButton.icon(
                        icon: Icon(
                          canPickUp
                              ? Icons.local_shipping_outlined
                              : Icons.check_circle_outline,
                          size: 14,
                        ),
                        label: Text(canPickUp ? 'Picked Up' : 'Delivered'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              canPickUp ? kBrand600 : kStatusDeliveredFg,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: kSpace12, vertical: kSpace8),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(kRadiusSm + 3)),
                          elevation: 0,
                          minimumSize: Size.zero,
                          textStyle: kLabelMd,
                        ),
                        onPressed: () => _confirmAction(
                            context, order.id, canPickUp ? 'pickup' : 'deliver'),
                      ),
                    ] else if (order.status == 'delivered')
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: kSpace12, vertical: 7),
                        decoration: BoxDecoration(
                          color: kStatusDeliveredBg,
                          borderRadius: BorderRadius.circular(kRadiusSm + 3),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle,
                                size: 13, color: kStatusDeliveredFg),
                            const SizedBox(width: kSpace4),
                            Text('Delivered',
                                style:
                                    kLabelMd.copyWith(color: kStatusDeliveredFg)),
                          ],
                        ),
                      ),
                  ]),
                ],
              ),
            ),
          ],
        ),
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
              child: Text(
                isPickup ? 'Picked Up' : 'Delivered',
                style: TextStyle(
                  color: isPickup ? kBrand700 : kStatusDeliveredFg,
                  fontWeight: FontWeight.w700,
                ),
              )),
        ],
      ),
    );

    if (ok == true && ctx.mounted) {
      final courierProvider = ctx.read<CourierProvider>();
      final success = isPickup
          ? await courierProvider.markPickedUp(orderId)
          : await courierProvider.markDelivered(orderId);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text(success
              ? 'Parcel #$orderId updated successfully'
              : courierProvider.error ?? 'Update failed'),
          backgroundColor: success ? kBrand700 : kActionDestructive,
        ));
      }
    }
  }

  String _fmt(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      const m = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${m[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) {
      return iso;
    }
  }
}

// ── Payment method badge ───────────────────────────────────────────────────────
class _PaymentBadge extends StatelessWidget {
  const _PaymentBadge({required this.method});

  final String method;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: kBrand100,
          borderRadius: BorderRadius.circular(kRadiusFull)),
      child: Text(
        AppConstants.paymentLabel(method).toUpperCase(),
        style: kLabelSm.copyWith(color: kBrand800),
      ),
    );
  }
}

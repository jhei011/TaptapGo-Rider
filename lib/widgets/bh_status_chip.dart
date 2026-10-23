import 'package:flutter/material.dart';
import '../core/theme/app_tokens.dart';

/// Size variant for [BhStatusChip].
enum BhChipSize { small, normal }

/// Token-based status chip that replaces the legacy [StatusPill].
///
/// Renders a coloured pill with a 8dp dot and a translated status label.
class BhStatusChip extends StatelessWidget {
  const BhStatusChip({
    super.key,
    required this.status,
    this.size = BhChipSize.normal,
  });

  final String status;
  final BhChipSize size;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = _resolve(status);

    final textStyle = size == BhChipSize.small ? kLabelSm : kLabelMd;
    final padding = size == BhChipSize.small
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 6);

    return Semantics(
      label: 'Status: $label',
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(kRadiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(label, style: textStyle.copyWith(color: fg)),
          ],
        ),
      ),
    );
  }

  static (Color bg, Color fg, String label) _resolve(String status) =>
      switch (status) {
        'pending'           => (kStatusPendingBg,   kStatusPendingFg,   'Pending'),
        'ready_for_pickup'  => (kStatusPickupBg,    kStatusPickupFg,    'Ready for Pickup'),
        'out_for_delivery'  => (kStatusOnWayBg,     kStatusOnWayFg,     'Out for Delivery'),
        'delivered'         => (kStatusDeliveredBg, kStatusDeliveredFg, 'Delivered'),
        'failed'            => (kStatusFailedBg,    kStatusFailedFg,    'Failed'),
        'cancelled'         => (kStatusCancelledBg, kStatusCancelledFg, 'Cancelled'),
        'active'            => (kStatusDeliveredBg, kStatusDeliveredFg, 'Active'),
        'inactive'          => (kStatusCancelledBg, kStatusCancelledFg, 'Inactive'),
        'approved'          => (kStatusDeliveredBg, kStatusDeliveredFg, 'Approved'),
        'suspended'         => (kStatusFailedBg,    kStatusFailedFg,    'Suspended'),
        final s             => (kStatusCancelledBg, kStatusCancelledFg, s),
      };
}

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (bg, fg, label) = _resolve(status, isDark: isDark);

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

  static (Color bg, Color fg, String label) _resolve(
    String status, {
    required bool isDark,
  }) =>
      switch (status) {
        'pending'           => (
            isDark ? kDarkStatusPendingBg   : kStatusPendingBg,
            isDark ? kDarkStatusPendingFg   : kStatusPendingFg,
            'Pending'),
        'ready_for_pickup'  => (
            isDark ? kDarkStatusPickupBg    : kStatusPickupBg,
            isDark ? kDarkStatusPickupFg    : kStatusPickupFg,
            'Ready for Pickup'),
        'awaiting_pickup'   => (
            isDark ? kDarkStatusPickupBg    : kStatusPickupBg,
            isDark ? kDarkStatusPickupFg    : kStatusPickupFg,
            'Ready for Pickup'),
        'assigned'          => (
            isDark ? kDarkStatusPickupBg    : kStatusPickupBg,
            isDark ? kDarkStatusPickupFg    : kStatusPickupFg,
            'Assigned'),
        'picked_up' || 'in_transit' => (
            isDark ? kDarkStatusOnWayBg     : kStatusOnWayBg,
            isDark ? kDarkStatusOnWayFg     : kStatusOnWayFg,
            'Picked Up'),
        'at_hub'            => (
            isDark ? kDarkStatusPendingBg   : kStatusPendingBg,
            isDark ? kDarkStatusPendingFg   : kStatusPendingFg,
            'At Hub'),
        'out_for_delivery'  => (
            isDark ? kDarkStatusOnWayBg     : kStatusOnWayBg,
            isDark ? kDarkStatusOnWayFg     : kStatusOnWayFg,
            'Out for Delivery'),
        'failed_delivery'   => (
            isDark ? kDarkStatusFailedBg    : kStatusFailedBg,
            isDark ? kDarkStatusFailedFg    : kStatusFailedFg,
            'Failed Delivery'),
        'return_to_sender'  => (
            isDark ? kDarkStatusFailedBg    : kStatusFailedBg,
            isDark ? kDarkStatusFailedFg    : kStatusFailedFg,
            'Return to Sender'),
        'delivered'         => (
            isDark ? kDarkStatusDeliveredBg : kStatusDeliveredBg,
            isDark ? kDarkStatusDeliveredFg : kStatusDeliveredFg,
            'Delivered'),
        'failed'            => (
            isDark ? kDarkStatusFailedBg    : kStatusFailedBg,
            isDark ? kDarkStatusFailedFg    : kStatusFailedFg,
            'Failed'),
        'cancelled'         => (
            isDark ? kDarkStatusCancelledBg : kStatusCancelledBg,
            isDark ? kDarkStatusCancelledFg : kStatusCancelledFg,
            'Cancelled'),
        'active'            => (
            isDark ? kDarkStatusDeliveredBg : kStatusDeliveredBg,
            isDark ? kDarkStatusDeliveredFg : kStatusDeliveredFg,
            'Active'),
        'inactive'          => (
            isDark ? kDarkStatusCancelledBg : kStatusCancelledBg,
            isDark ? kDarkStatusCancelledFg : kStatusCancelledFg,
            'Inactive'),
        'approved'          => (
            isDark ? kDarkStatusDeliveredBg : kStatusDeliveredBg,
            isDark ? kDarkStatusDeliveredFg : kStatusDeliveredFg,
            'Approved'),
        'suspended'         => (
            isDark ? kDarkStatusFailedBg    : kStatusFailedBg,
            isDark ? kDarkStatusFailedFg    : kStatusFailedFg,
            'Suspended'),
        final s             => (
            isDark ? kDarkStatusCancelledBg : kStatusCancelledBg,
            isDark ? kDarkStatusCancelledFg : kStatusCancelledFg,
            s),
      };
}

import 'package:flutter/material.dart';
import '../core/theme/app_tokens.dart';
import 'tap.dart';

/// A metric tile used on dashboard screens, on TaptapShop's card (12 px corners, thin border,
/// soft shadow).
///
/// Shows an optional icon, a large [value], and a descriptive [label]. When [onTap] is provided
/// the tile gets button semantics, a 48 dp minimum touch target and the TaptapShop ripple.
class BhStatTile extends StatelessWidget {
  const BhStatTile({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.iconColor,
    this.onTap,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(kSpace14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: iconColor ?? kBrand600),
            const SizedBox(height: kSpace8),
          ],
          Text(value, style: kDisplayMd),
          Text(label, style: kBodySm.copyWith(color: kTextSecondary), maxLines: 2),
        ],
      ),
    );

    Widget tile = Container(
      decoration: BoxDecoration(
        color: kSurfaceBase,
        border: Border.all(color: kBorderDefault),
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: kCardShadow,
      ),
      child: onTap == null ? content : Tap(onTap: onTap, borderRadius: BorderRadius.circular(kRadiusLg), child: content),
    );

    if (onTap != null) {
      tile = Semantics(
        button: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: tile,
        ),
      );
    }

    return tile;
  }
}

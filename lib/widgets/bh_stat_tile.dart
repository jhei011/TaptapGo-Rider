import 'package:flutter/material.dart';
import '../core/theme/app_tokens.dart';

/// A metric tile used on dashboard screens.
///
/// Shows an optional icon, a large [value], and a descriptive [label].
/// Tap support is optional; when [onTap] is provided the tile gains
/// button semantics and a minimum 48 dp touch target.
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
    Widget tile = Container(
      decoration: BoxDecoration(
        color: kSurfaceBase,
        border: Border.all(color: kBrand100),
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E0E2A38),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(kSpace16),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: iconColor ?? kBrand400),
              const SizedBox(height: kSpace8),
            ],
            Text(value, style: kDisplayMd),
            Text(label, style: kBodySm.copyWith(color: kTextSecondary)),
          ],
        ),
      ),
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

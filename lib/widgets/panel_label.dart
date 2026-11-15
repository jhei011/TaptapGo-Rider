import 'package:flutter/material.dart';

/// "Rider Panel" / "Linehaul Courier Panel" under the name on the teal welcome card:
/// a small icon and the panel's name in TaptapGo's mint.
class PanelLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  const PanelLabel({super.key, required this.icon, required this.text});

  static const _mint = Color(0xFF8FE0D2);

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: _mint),
        const SizedBox(width: 5),
        // Shrinks with "…" on small phones or large text instead of overflowing
        Flexible(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _mint, letterSpacing: 0.2)),
        ),
      ]);
}

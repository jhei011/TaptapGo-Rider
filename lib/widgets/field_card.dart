import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// White card section — matches Laravel .field-card / form card
class FieldCard extends StatelessWidget {
  final String? title;
  final IconData? titleIcon;
  final String? subtitle;
  final List<Widget> children;
  final EdgeInsets padding;

  const FieldCard({
    super.key,
    this.title,
    this.titleIcon,
    this.subtitle,
    required this.children,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.border),
        boxShadow: const [BoxShadow(color: Color(0x060E2A38), blurRadius: 8, offset: Offset(0, 2))],
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(children: [
              if (titleIcon != null) ...[
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: C.b50, borderRadius: BorderRadius.circular(10)),
                  child: Icon(titleIcon, size: 18, color: C.b700),
                ),
                const SizedBox(width: 10),
              ],
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title!,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: C.textPrimary)),
                if (subtitle != null)
                  Text(subtitle!, style: const TextStyle(fontSize: 11, color: C.textMuted)),
              ]),
            ]),
            const SizedBox(height: 14),
          ],
          ...children,
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const InfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F3F2))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF8A9491))),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.b900)),
          ),
        ],
      ),
    );
  }
}

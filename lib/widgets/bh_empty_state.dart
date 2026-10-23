import 'package:flutter/material.dart';
import '../core/theme/app_tokens.dart';

/// A centred empty-state placeholder.
///
/// This is a NEW widget and does NOT modify or replace the existing
/// [EmptyState] widget in empty_state.dart, which buyer/seller screens
/// continue to use.
class BhEmptyState extends StatelessWidget {
  const BhEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(kSpace32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: kTextMuted),
            const SizedBox(height: kSpace16),
            Text(title, style: kHeadingSm, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: kSpace8),
              Text(
                subtitle!,
                style: kBodyMd.copyWith(color: kTextSecondary),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: kSpace16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

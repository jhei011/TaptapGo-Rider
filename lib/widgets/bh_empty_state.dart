import 'package:flutter/material.dart';
import '../core/theme/app_tokens.dart';

/// A centred empty-state placeholder, styled like TaptapShop's EmptyState: the icon in a soft
/// teal circle, a bold title and a muted line under it.
///
/// This does NOT modify or replace the [EmptyState] widget in empty_state.dart, which
/// buyer/seller screens continue to use.
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
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [kBrand50, kBrand100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Icon(icon, size: 30, color: kBrand700),
            ),
            const SizedBox(height: kSpace14),
            Text(title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary),
                textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: kSpace6),
              Text(
                subtitle!,
                style: TextStyle(fontSize: 13, color: kTextMuted),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 18),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

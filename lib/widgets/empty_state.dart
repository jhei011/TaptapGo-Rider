import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? buttonLabel;
  final VoidCallback? onButton;

  const EmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.subtitle,
    this.buttonLabel,
    this.onButton,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [C.b50, C.b100],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Icon(icon, size: 30, color: C.b700),
          ),
          const SizedBox(height: 14),
          Text(title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.textPrimary),
              textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!,
                style: const TextStyle(fontSize: 13, color: C.textMuted),
                textAlign: TextAlign.center),
          ],
          if (buttonLabel != null && onButton != null) ...[
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onButton,
              style: ElevatedButton.styleFrom(backgroundColor: C.b700),
              child: Text(buttonLabel!),
            ),
          ],
        ]),
      ),
    );
  }
}

class LoadingCenter extends StatelessWidget {
  const LoadingCenter({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: C.b600));
}

class ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorRetry({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 40, color: C.danger),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: C.textSecondary, fontSize: 13)),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: C.b700),
            ),
          ],
        ]),
      ),
    );
  }
}

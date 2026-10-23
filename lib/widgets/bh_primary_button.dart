import 'package:flutter/material.dart';
import '../core/theme/app_tokens.dart';

/// Full-width primary action button with loading and destructive variants.
class BhPrimaryButton extends StatelessWidget {
  const BhPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.destructive = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool destructive;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bg = destructive ? kActionDestructive : kActionPrimary;

    return Semantics(
      label: label,
      button: true,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: Colors.white,
            disabledBackgroundColor: bg.withValues(alpha: 0.6),
            disabledForegroundColor: Colors.white70,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kRadiusLg),
            ),
            elevation: 0,
            textStyle: kLabelLg,
          ),
          child: loading ? _loadingChild() : _labelChild(),
        ),
      ),
    );
  }

  Widget _loadingChild() {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        SizedBox(width: kSpace8),
        Text('Please wait'),
      ],
    );
  }

  Widget _labelChild() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18),
          const SizedBox(width: kSpace8),
        ],
        Text(label),
      ],
    );
  }
}

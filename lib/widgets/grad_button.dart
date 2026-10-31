import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Primary gradient button — matches Laravel .btn-primary
class GradButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final double height;
  final double? width;

  const GradButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.height = 48,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width ?? double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed == null && !loading
              ? const LinearGradient(colors: [Color(0xFF9CA3AF), Color(0xFF6B7280)])
              : C.primaryGrad,
          borderRadius: BorderRadius.circular(10),
        ),
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: EdgeInsets.zero,
          ),
          child: loading
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[Icon(icon, size: 17), const SizedBox(width: 7)],
                    Text(label,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  ],
                ),
        ),
      ),
    );
  }
}

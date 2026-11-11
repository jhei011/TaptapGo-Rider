import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';

/// Full-width primary action button.
///
/// [gradient] (default true) uses the TaptapShop C.primaryGrad (#0E2A38→#4A949C).
/// Set [gradient] = false for a flat teal button (e.g. inside cards).
/// Set [destructive] = true for a red danger action.
class BhPrimaryButton extends StatelessWidget {
  const BhPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.destructive = false,
    this.gradient = true,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool destructive;
  final bool gradient;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    // Destructive always uses flat red; gradient only applies to primary action
    final useGradient = gradient && !destructive;
    final flatColor = destructive ? kActionDestructive : kBrand700;

    return Semantics(
      label: label,
      button: true,
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: useGradient
            ? _gradientButton()
            : ElevatedButton(
                onPressed: loading ? null : onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: flatColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: flatColor.withValues(alpha: 0.6),
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

  Widget _gradientButton() {
    final disabled = onPressed == null && !loading;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: disabled
            ? const LinearGradient(
                colors: [Color(0xFF9CA3AF), Color(0xFF6B7280)])
            : C.primaryGrad,
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: disabled
            ? null
            : const [
                BoxShadow(
                  color: Color(0x300E2A38),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadiusLg),
          ),
          elevation: 0,
          padding: EdgeInsets.zero,
          textStyle: kLabelLg,
        ),
        child: loading ? _loadingChild() : _labelChild(),
      ),
    );
  }

  Widget _loadingChild() => const Row(
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

  Widget _labelChild() => Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: kSpace8),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
}

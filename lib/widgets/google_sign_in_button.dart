import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// "Sign in with Google" in Google's own button style (Sign in with Google branding
/// guidelines): the official four-colour "G" (assets/images/google_g.svg) at 20 px,
/// 12 px gap, 14 px medium label. Light: white with a #747775 outline; dark: #131314
/// with a #8E918F outline. Same look as the TaptapShop app's button.
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;
  final bool dark;
  final String label;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.loading = false,
    this.dark = false,
    this.label = 'Sign in with Google',
  });

  @override
  Widget build(BuildContext context) {
    final fg = dark ? const Color(0xFFE3E3E3) : const Color(0xFF1F1F1F);
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        key: const Key('googleSignIn'),
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: dark ? const Color(0xFF131314) : Colors.white,
          foregroundColor: fg,
          disabledBackgroundColor: dark ? const Color(0xFF131314) : Colors.white,
          side: BorderSide(color: dark ? const Color(0xFF8E918F) : const Color(0xFF747775)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          elevation: 0,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (loading)
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
          else
            SvgPicture.asset('assets/images/google_g.svg', width: 20, height: 20,
                semanticsLabel: 'Google logo'),
          const SizedBox(width: 12),
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.25,
                    color: loading ? fg.withValues(alpha: 0.38) : fg)),
          ),
        ]),
      ),
    );
  }
}

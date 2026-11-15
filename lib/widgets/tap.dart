// Copied from TaptapShop Flutter (lib/widgets/tap.dart) so both apps share the same touch feedback.
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Makes [child] tappable with the same touch ripple as the TaptapShop logo:
/// a soft circle spreads from the finger and fades when it lifts.
///
/// The ripple is painted on top of [child] (so it shows over images and coloured
/// backgrounds) but never takes taps, so buttons inside [child], like a card's
/// heart, keep working.
///
/// Cheap when idle: nothing extra is built, painted or animated until a finger
/// touches it, so long lists of cards scroll as smoothly as without it.
class Tap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  /// For round buttons.
  final bool circle;
  /// Ripple colour; white suits teal or dark backgrounds.
  final Color? splashColor;

  const Tap({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius,
    this.circle = false,
    this.splashColor,
  });

  @override
  State<Tap> createState() => _TapState();
}

class _TapState extends State<Tap> with TickerProviderStateMixin {
  // Made on the first touch only
  AnimationController? _spread, _fade;
  Offset _origin = Offset.zero;
  bool _held = false;
  bool _showing = false;

  @override
  void dispose() {
    _spread?.dispose();
    _fade?.dispose();
    super.dispose();
  }

  void _ensureControllers() {
    if (_spread != null) return;
    _spread = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 220))
      ..addStatusListener((s) {
        // Faded out: drop the ripple layer until the next touch
        if (s == AnimationStatus.completed && !_held && mounted) setState(() => _showing = false);
      });
  }

  void _down(TapDownDetails d) {
    _ensureControllers();
    _origin = d.localPosition;
    _held = true;
    _fade!.value = 0;
    _spread!.forward(from: 0);
    if (!_showing) setState(() => _showing = true);
  }

  Future<void> _release() async {
    if (!_held) return;
    _held = false;
    // Let the circle finish spreading before it fades, like a Material ripple
    if (_spread!.isAnimating) await _spread!.forward();
    if (mounted && !_held) _fade!.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // the whole button, not just its text or icon
      onTapDown: enabled ? _down : null,
      onTapUp: enabled ? (_) => _release() : null,
      onTapCancel: enabled ? _release : null,
      onTap: widget.onTap,
      // The Stack is always here so [child] is never rebuilt from scratch;
      // only the ripple layer comes and goes. Passthrough keeps the button's size.
      child: Stack(fit: StackFit.passthrough, children: [
        widget.child,
        if (_showing) Positioned.fill(child: _ripple()),
      ]),
    );
  }

  Widget _ripple() {
    final color = widget.splashColor ?? (C.dark ? Colors.white : Colors.black);
    final paint = AnimatedBuilder(
      animation: Listenable.merge([_spread, _fade]),
      builder: (_, __) => CustomPaint(
        painter: _RipplePainter(
          origin: _origin,
          spread: Curves.easeOut.transform(_spread!.value),
          opacity: 1 - _fade!.value,
          color: color,
        ),
      ),
    );
    // Its own layer, so the ripple's frames never repaint the card under it
    return IgnorePointer(
      child: RepaintBoundary(
        child: widget.circle
            ? ClipOval(child: paint)
            : ClipRRect(borderRadius: widget.borderRadius ?? BorderRadius.circular(10), child: paint),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  final Offset origin;
  final double spread, opacity;
  final Color color;
  const _RipplePainter({required this.origin, required this.spread, required this.opacity, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    // A light wash over the whole button, and the spreading circle
    canvas.drawRect(Offset.zero & size, Paint()..color = color.withValues(alpha: 0.05 * opacity));
    final far = [
      Offset.zero, Offset(size.width, 0), Offset(0, size.height), Offset(size.width, size.height),
    ].map((c) => (c - origin).distance).reduce((a, b) => a > b ? a : b);
    canvas.drawCircle(origin, far * spread, Paint()..color = color.withValues(alpha: 0.12 * opacity));
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.spread != spread || old.opacity != opacity || old.origin != origin || old.color != color;
}

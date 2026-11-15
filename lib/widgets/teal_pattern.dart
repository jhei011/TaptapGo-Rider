import 'dart:math' as math;
import 'package:flutter/material.dart';

/// The soft background design on TaptapGo's teal surfaces: large faint white circles and thin
/// rings over the teal gradient, after the circles on TaptapShop's login background.
///
/// Use it in place of the teal box's BoxDecoration; layout does not change:
///
///   Container(decoration: TealDecoration(BoxDecoration(gradient: kHeroGradient, borderRadius: ...)))
///
/// The design is painted under the box's content and clipped to its (rounded) corners.
class TealDecoration extends Decoration {
  /// The teal box itself: gradient or color, corners, shadow.
  final BoxDecoration base;

  /// Whole-screen backgrounds (login, sign-up) use TaptapShop's fixed circle sizes;
  /// headers and cards scale the circles to their height.
  final bool screen;

  const TealDecoration(this.base, {this.screen = false});

  @override
  EdgeInsetsGeometry get padding => base.padding;

  @override
  bool hitTest(Size size, Offset position, {TextDirection? textDirection}) =>
      base.hitTest(size, position, textDirection: textDirection);

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _TealPainter(this, base.createBoxPainter(onChanged));
}

class _TealPainter extends BoxPainter {
  final TealDecoration decoration;
  final BoxPainter inner;
  _TealPainter(this.decoration, this.inner);

  static final _fill = Paint()..color = Colors.white.withAlpha(13);
  static final _fillSoft = Paint()..color = Colors.white.withAlpha(9);
  static final _ring = Paint()
    ..color = Colors.white.withAlpha(24)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    inner.paint(canvas, offset, configuration); // the teal gradient, corners and shadow
    final size = configuration.size;
    if (size == null || size.isEmpty) return;
    final w = size.width, h = size.height;
    final corners = decoration.base.borderRadius?.resolve(configuration.textDirection) ?? BorderRadius.zero;

    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.clipRRect(corners.toRRect(Offset.zero & size));
    if (decoration.screen) {
      // TaptapShop login: a 320 circle off the top-right corner, a 200 circle off the left edge near the bottom
      canvas.drawCircle(Offset(w - 80, 80), 160, _fill);
      canvas.drawCircle(Offset(40, h - 180), 100, _fillSoft);
      canvas.drawCircle(Offset(w * 0.18, h * 0.16), 46, _ring);
      canvas.drawCircle(Offset(w * 0.86, h * 0.62), 70, _ring);
    } else {
      // Headers and hero cards: the same idea scaled to the box
      final r = math.min(math.max(h * 0.85, 56.0), 170.0);
      canvas.drawCircle(Offset(w - r * 0.30, -r * 0.30), r, _fill);
      canvas.drawCircle(Offset(w * 0.08, h + r * 0.30), r * 0.62, _fillSoft);
      canvas.drawCircle(Offset(w - r * 1.05, h * 0.92), r * 0.34, _ring);
    }
    canvas.restore();
  }

  @override
  void dispose() {
    inner.dispose();
    super.dispose();
  }
}

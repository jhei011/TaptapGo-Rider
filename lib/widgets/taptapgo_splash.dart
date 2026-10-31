// TaptapGo animated splash screen (Flutter port of TaptapGo_Splash_Preview.html)
//
// Drop this file into lib/, add assets/images/taptapgo_logo.png to your
// project, register it in pubspec.yaml, then show <TaptapGoSplash/> as your
// first screen. No third-party packages required.
//
// The logo is auto-cropped to its visible pixels at load time, so a PNG with
// transparent margins (any size / aspect ratio) still lines up correctly.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TaptapGoSplash extends StatefulWidget {
  const TaptapGoSplash({
    super.key,
    required this.onFinished,
    this.assetPath = 'assets/images/taptapgo_logo.png',
    this.badge = 'RIDER',
    this.subtitle = 'Getting things ready',
  });

  /// Called once, when the 4.5 s animation completes.
  final VoidCallback onFinished;

  /// Path of the scooter logo (the trimmed 780x431 PNG).
  final String assetPath;

  /// Text inside the outlined pill under the wordmark.
  final String badge;

  /// Small caption at the bottom.
  final String subtitle;

  @override
  State<TaptapGoSplash> createState() => _TaptapGoSplashState();
}

class _TaptapGoSplashState extends State<TaptapGoSplash>
    with SingleTickerProviderStateMixin {
  static const double _durSeconds = 4.5;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (_durSeconds * 1000).round()),
  );

  ui.Image? _logo;
  Rect? _logoSrc; // visible (non-transparent) area of the logo

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onFinished();
    });
    _loadLogo();
  }

  Future<void> _loadLogo() async {
    final data = await rootBundle.load(widget.assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    if (!mounted) {
      frame.image.dispose();
      return;
    }
    final src = await _opaqueBounds(frame.image);
    if (!mounted) {
      frame.image.dispose();
      return;
    }
    setState(() {
      _logo = frame.image;
      _logoSrc = src;
    });
    _c.forward(); // start only after the logo is decoded, so nothing pops in
  }

  /// Bounding box of the pixels that are not (nearly) transparent.
  static Future<Rect> _opaqueBounds(ui.Image img) async {
    final full = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytes == null) return full;
    final w = img.width, h = img.height;
    var minX = w, minY = h, maxX = -1, maxY = -1;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (bytes.getUint8((y * w + x) * 4 + 3) > 8) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX < 0) return full;
    return Rect.fromLTRB(
        minX.toDouble(), minY.toDouble(), (maxX + 1).toDouble(), (maxY + 1).toDouble());
  }

  @override
  void dispose() {
    _c.dispose();
    _logo?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF06141D),
        body: (_logo == null || _logoSrc == null)
            ? const SizedBox.expand()
            : RepaintBoundary(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _SplashPainter(
                    controller: _c,
                    totalSeconds: _durSeconds,
                    logo: _logo!,
                    logoSrc: _logoSrc!,
                    badge: widget.badge,
                    subtitle: widget.subtitle,
                  ),
                ),
              ),
      ),
    );
  }
}

// ───────────────────────────── painter ─────────────────────────────

const _mintRGB = [143, 224, 210];
const _iceRGB = [244, 251, 250];

Color _rgba(List<int> rgb, double a) =>
    Color.fromRGBO(rgb[0], rgb[1], rgb[2], a.clamp(0.0, 1.0).toDouble());

double _clamp01(double v) => v.clamp(0.0, 1.0).toDouble();
double _easeOut(double x) => 1 - math.pow(1 - x, 3).toDouble();

class _Star {
  const _Star(this.fx, this.fy);
  final double fx; // 0..1 of width
  final double fy; // 0..1 of the upper sky band
}

class _SplashPainter extends CustomPainter {
  _SplashPainter({
    required this.controller,
    required this.totalSeconds,
    required this.logo,
    required this.logoSrc,
    required this.badge,
    required this.subtitle,
  }) : super(repaint: controller);

  final AnimationController controller;
  final double totalSeconds;
  final ui.Image logo;
  final Rect logoSrc;
  final String badge;
  final String subtitle;

  static const double arrive = 1.35; // seconds until the rider has stopped
  static const double bikeW = 260;
  // Height follows the logo's real aspect ratio; bottom stays on the 157 baseline.
  double get bikeH => bikeW * logoSrc.height / logoSrc.width;
  double get bikeY => 157 - bikeH;

  static final List<_Star> _stars = () {
    final r = math.Random(3);
    return List.generate(46, (_) => _Star(r.nextDouble(), r.nextDouble() * .35));
  }();

  @override
  void paint(Canvas canvas, Size size) {
    // Design space is 390 x 780 logical px, scaled to fit any screen.
    final k = math.min(size.width / 390, size.height / 780);
    final w = size.width / k;
    final h = size.height / k;

    final t = controller.value * totalSeconds;
    final s = math.min(t, totalSeconds);
    final p = s / totalSeconds;
    final u = _easeOut(_clamp01(s / arrive));
    final roadTop = h * .5;

    canvas.save();
    canvas.scale(k);

    _scene(canvas, w, h, t, s, u, roadTop);

    // Bike slides in from the left, then settles.
    final ox = -(1 - u) * (w / 2 + 260);
    _bike(canvas, t, s, u, (w - bikeW) / 2 + ox, roadTop + 34 - 152);

    _words(canvas, w, p, t, roadTop + 96);

    canvas.restore();
  }

  // ── background ──
  void _scene(Canvas c, double w, double h, double t, double s, double u,
      double roadTop) {
    final bg = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, h),
        const [Color(0xFF06141D), Color(0xFF0E2A38), Color(0xFF1B5260)],
        const [0, .5, 1],
      );
    c.drawRect(Rect.fromLTWH(0, 0, w, h), bg);

    // twinkling stars
    final starPaint = Paint();
    for (var i = 0; i < _stars.length; i++) {
      final st = _stars[i];
      final a = .75 * (.35 + .65 * (.5 + .5 * math.sin(t * 2 + i)));
      starPaint.color = Color.fromRGBO(255, 255, 255, a);
      c.drawCircle(Offset(st.fx * w, st.fy * h), 1.1, starPaint);
    }

    // moon + glow
    final moon = Offset(w * .78, h * .13);
    c.drawCircle(
      moon,
      22,
      Paint()
        ..color = _rgba(_mintRGB, .5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );
    c.drawCircle(moon, 22, Paint()..color = const Color(0xFFF3F1D6));

    // horizon glow
    final glowRect = Rect.fromLTWH(0, roadTop - 120, w, 120);
    c.drawRect(
      glowRect,
      Paint()
        ..shader = ui.Gradient.linear(
          glowRect.topCenter,
          glowRect.bottomCenter,
          const [Color.fromRGBO(46, 124, 130, 0), Color.fromRGBO(46, 160, 150, .38)],
        ),
    );

    // speed lines while the bike is arriving
    if (s < arrive + .2) {
      final f = _clamp01(1 - u);
      final line = Paint()
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..color = _rgba(_iceRGB, .35 * f);
      for (var i = 0; i < 14; i++) {
        final y = roadTop * .28 + i * (roadTop * .8 / 14);
        final x = w - ((t * 1100 + i * 131) % (w + 240));
        c.drawLine(Offset(x, y), Offset(x + 70 + (i % 3) * 50, y), line);
      }
    }
  }

  // ── bike + effects ──
  void _bike(Canvas c, double t, double s, double u, double left, double top) {
    final bob = math.sin(t * 9) * 1.2;
    final pitch = s < arrive
        ? -.04 * (1 - u)
        : .06 * math.sin((s - arrive) * 13) * math.exp(-(s - arrive) * 4.5);

    c.save();
    c.translate(left, top + bob);
    c.translate(97, 152);
    c.rotate(pitch);
    c.translate(-97, -152);

    _fx(c, t, s);

    c.drawImageRect(
      logo,
      logoSrc,
      Rect.fromLTWH(0, bikeY, bikeW, bikeH),
      Paint()..filterQuality = FilterQuality.high,
    );

    _rings(c, s);
    c.restore();
  }

  void _fx(Canvas c, double t, double s) {
    final hl = _clamp01((s - 1.2) * 2.5);

    // headlight beam
    final beam = Path()
      ..moveTo(241, 86)
      ..lineTo(430, 134)
      ..lineTo(430, 40)
      ..close();
    c.drawPath(
      beam,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(240, 0),
          const Offset(430, 0),
          [
            Color.fromRGBO(255, 243, 196, .45 * hl),
            const Color.fromRGBO(255, 243, 196, 0),
          ],
        ),
    );

    // tail light
    c.drawCircle(
      const Offset(71, 62),
      4.5,
      Paint()
        ..color = const Color.fromRGBO(255, 90, 90, .9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    c.drawCircle(
      const Offset(71, 62),
      4.5,
      Paint()..color = const Color.fromRGBO(255, 90, 90, .6),
    );

    // exhaust puffs
    final puff = Paint();
    for (var i = 0; i < 8; i++) {
      final a = ((t / .9) + i / 8) % 1;
      puff.color = Color.fromRGBO(220, 238, 236, .32 * (1 - a));
      c.drawCircle(Offset(82 - a * 62, 127 - a * 12), 3 + a * 9, puff);
    }

    // headlight dot
    c.drawCircle(
      const Offset(241, 86),
      4,
      Paint()..color = Color.fromRGBO(255, 243, 196, _clamp01(.35 + .65 * hl)),
    );
  }

  // pulse rings around the tap icon on the delivery box
  void _rings(Canvas c, double s) {
    if (s <= arrive) return;
    final k = s - arrive;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    for (var j = 0; j < 2; j++) {
      final a = ((k / 1.6) - j * .16 + 10) % 1;
      ring.color = _rgba(_mintRGB, .7 * (1 - a));
      c.drawCircle(const Offset(102, 62), 16 + a * 44, ring);
    }
  }

  // ── wordmark, badge, loader ──
  void _words(Canvas c, double w, double p, double t, double top) {
    double seg(double a, double b) => _easeOut(_clamp01((p - a) / (b - a)));
    final n = seg(.30, .52);
    final ch = seg(.42, .66);

    // "Taptap" + italic "Go"
    final tapStyle = TextStyle(
      fontSize: 40,
      fontWeight: FontWeight.w800,
      color: _rgba(_iceRGB, n),
    );
    final goStyle = TextStyle(
      fontSize: 40,
      fontWeight: FontWeight.w800,
      fontStyle: FontStyle.italic,
      color: _rgba(_mintRGB, n),
    );
    final tap = _tp('Taptap', tapStyle);
    final go = _tp('Go', goStyle);
    final x0 = (w - tap.width - go.width) / 2;
    final y = top + 36 + 14 * (1 - n);
    _paintAtBaseline(c, tap, Offset(x0, y));
    _paintAtBaseline(c, go, Offset(x0 + tap.width, y));

    // outlined badge
    final badgeStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 4,
      color: _rgba(_mintRGB, ch),
    );
    final badgeTp = _tp(badge, badgeStyle);
    final bw = badgeTp.width + 32;
    final cy = top + 62 + 14 * (1 - ch);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH((w - bw) / 2, cy, bw, 24),
        const Radius.circular(6),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _rgba(_mintRGB, ch),
    );
    _paintAtBaseline(c, badgeTp, Offset((w - bw) / 2 + 18, cy + 16));

    // 3 pulsing dots
    final dot = Paint()..color = _rgba(_mintRGB, ch);
    for (var i = 0; i < 3; i++) {
      final sc = 1 + .55 * math.max(0.0, math.sin(t * 6 - i * .9));
      c.drawCircle(Offset(w / 2 + (i - 1) * 18, top + 116), 4 * sc, dot);
    }

    // caption
    final cap = _tp(
      subtitle,
      TextStyle(fontSize: 12, color: _rgba(_iceRGB, .5 * ch)),
    );
    _paintAtBaseline(c, cap, Offset((w - cap.width) / 2, top + 148));
  }

  TextPainter _tp(String text, TextStyle style) => TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();

  void _paintAtBaseline(Canvas c, TextPainter tp, Offset baselineLeft) {
    final base = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    tp.paint(c, Offset(baselineLeft.dx, baselineLeft.dy - base));
  }

  @override
  bool shouldRepaint(covariant _SplashPainter old) =>
      old.logo != logo || old.logoSrc != logoSrc || old.badge != badge || old.subtitle != subtitle;
}

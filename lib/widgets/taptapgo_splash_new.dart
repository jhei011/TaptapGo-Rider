// TapTapGo Rider — animated splash / loading screen.
// Asset required: assets/images/taptapgo_scooter.png
// Already covered by the `- assets/images/` wildcard in pubspec.yaml.

import 'package:flutter/material.dart';

class TapTapGoSplashScreen extends StatefulWidget {
  const TapTapGoSplashScreen({
    super.key,
    this.duration = const Duration(milliseconds: 2800),
    this.onFinished,
  });

  /// How long the loading bar takes to fill.
  final Duration duration;

  /// Called once when loading finishes.
  final VoidCallback? onFinished;

  @override
  State<TapTapGoSplashScreen> createState() => _TapTapGoSplashScreenState();
}

class _TapTapGoSplashScreenState extends State<TapTapGoSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _load;
  late final AnimationController _road;
  late final AnimationController _bob;

  @override
  void initState() {
    super.initState();
    _load = AnimationController(vsync: this, duration: widget.duration);
    _road = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _load.forward().whenComplete(() {
      if (mounted) widget.onFinished?.call();
    });
  }

  @override
  void dispose() {
    _load.dispose();
    _road.dispose();
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media  = MediaQuery.of(context);
    final w      = media.size.width;
    final h      = media.size.height;
    final scooterW = (w * 0.82).clamp(200.0, 360.0);
    final scooterH = scooterW * 571 / 800;
    final roadTop  = h * 0.65;

    return Scaffold(
      backgroundColor: const Color(0xFF032E37),
      body: Stack(
        children: [
          // ── Background gradient ──────────────────────────────────────────
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF27E8C0),
                    Color(0xFF0E9C92),
                    Color(0xFF06545C),
                    Color(0xFF032E37),
                  ],
                  stops: [0.0, 0.4, 0.75, 1.0],
                ),
              ),
            ),
          ),

          // ── Soft glow + rings ────────────────────────────────────────────
          Positioned.fill(child: CustomPaint(painter: _GlowPainter())),

          // ── Wordmark ─────────────────────────────────────────────────────
          Positioned(
            top: media.padding.top + h * 0.09,
            left: 0,
            right: 0,
            child: const Column(
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: 'Tap'),
                      TextSpan(
                        text: 'Tap',
                        style: TextStyle(color: Color(0xFF9DFBE3)),
                      ),
                      TextSpan(text: 'Go'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 54,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    letterSpacing: -1.5,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Color(0x4D021A20),
                        offset: Offset(0, 3),
                        blurRadius: 0,
                      ),
                      Shadow(
                        color: Color(0x59021A20),
                        offset: Offset(0, 10),
                        blurRadius: 22,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  'RIDER',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 11,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // ── Road (dashes scroll left) ────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            top: roadTop,
            bottom: 0,
            child: CustomPaint(painter: _RoadPainter(_road)),
          ),

          // ── Ground shadow under scooter ──────────────────────────────────
          Positioned(
            top: roadTop - 8,
            left: (w - scooterW * 0.8) / 2,
            width: scooterW * 0.8,
            height: 14,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(50)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x8C021A20),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),

          // ── Scooter with bobbing animation ───────────────────────────────
          Positioned(
            top: roadTop - scooterH + 4,
            left: (w - scooterW) / 2,
            width: scooterW,
            child: AnimatedBuilder(
              animation: _bob,
              builder: (context, child) => Transform.translate(
                offset: Offset(
                  0,
                  -3 * Curves.easeInOut.transform(_bob.value),
                ),
                child: child,
              ),
              child: Image.asset(
                'assets/images/taptapgo_scooter.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),

          // ── Loading bar + label ──────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: media.padding.bottom + 72,
            child: Column(
              children: [
                SizedBox(
                  width: 200,
                  height: 6,
                  child: AnimatedBuilder(
                    animation: _load,
                    builder: (context, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Stack(
                        children: [
                          Container(color: const Color(0x40FFFFFF)),
                          FractionallySizedBox(
                            widthFactor:
                                Curves.easeInOut.transform(_load.value),
                            child: Container(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'LOADING',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 5,
                    color: Color(0xFFD8FFF4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Glow + ring painter ───────────────────────────────────────────────────────
class _GlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.5);
    final glow = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x66FFFFFF), Color(0x00FFFFFF)],
      ).createShader(Rect.fromCircle(center: c, radius: 230));
    canvas.drawCircle(c, 230, glow);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(c, 190, ring..color = const Color(0x1FFFFFFF));
    canvas.drawCircle(c, 280, ring..color = const Color(0x12FFFFFF));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Scrolling road painter ────────────────────────────────────────────────────
class _RoadPainter extends CustomPainter {
  _RoadPainter(this.anim) : super(repaint: anim);

  final Animation<double> anim;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Road surface
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A5560), Color(0xFF032E37)],
        ).createShader(rect),
    );

    // Top edge highlight
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 3),
      Paint()..color = const Color(0x40FFFFFF),
    );

    // Scrolling dashed centre line
    const dash   = 34.0;
    const gap    = 26.0;
    const period = dash + gap;
    const y      = 56.0;

    final paint = Paint()
      ..color      = const Color(0x73FFFFFF)
      ..strokeWidth = 4
      ..strokeCap  = StrokeCap.round;

    var x = -anim.value * period;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dash, y), paint);
      x += period;
    }
  }

  @override
  bool shouldRepaint(covariant _RoadPainter oldDelegate) => false;
}

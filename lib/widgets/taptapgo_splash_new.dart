// TapTapGo Rider — animated splash / loading screen.
// Asset required: assets/images/taptapgo_scooter.png
// Already covered by the `- assets/images/` wildcard in pubspec.yaml.
//
// Choreography (about 2.8 s in total):
//   intro  0.0–1.1 s  wordmark and tagline fade in, the road rises, the scooter drives in and brakes
//   loop   while loading  pulse rings, drifting skyline, floating lights, speed streaks,
//                        a light sweep over the wordmark, the loading bar with its shimmer
//   exit   last 0.5 s  the scooter rides off to the right and the scene fades out
// With "reduce motion" on in the phone's settings, only the loading bar moves.

import 'dart:math' as math;
import 'package:flutter/material.dart';

class TapTapGoSplashScreen extends StatefulWidget {
  const TapTapGoSplashScreen({
    super.key,
    this.duration = const Duration(milliseconds: 2800),
    this.onFinished,
  });

  /// Total time on screen, ride-off included.
  final Duration duration;

  /// Called once when loading finishes.
  final VoidCallback? onFinished;

  @override
  State<TapTapGoSplashScreen> createState() => _TapTapGoSplashScreenState();
}

class _TapTapGoSplashScreenState extends State<TapTapGoSplashScreen>
    with TickerProviderStateMixin {
  static const _exitTime = Duration(milliseconds: 520);
  static const _mint = Color(0xFF9DFBE3);

  late final AnimationController _intro =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  late final AnimationController _load = AnimationController(
    vsync: this,
    duration: widget.duration > _exitTime * 2 ? widget.duration - _exitTime : widget.duration,
  );
  late final AnimationController _exit = AnimationController(vsync: this, duration: _exitTime);
  late final AnimationController _road =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _bob =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  late final AnimationController _loop =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 5200));

  bool _started = false;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (_reduceMotion) {
      _intro.value = 1;
    } else {
      _intro.forward();
      _road.repeat();
      _bob.repeat(reverse: true);
      _loop.repeat();
    }
    _load.forward().whenComplete(() async {
      if (!mounted) return;
      if (!_reduceMotion) await _exit.forward();
      if (mounted) widget.onFinished?.call();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _load.dispose();
    _exit.dispose();
    _road.dispose();
    _bob.dispose();
    _loop.dispose();
    super.dispose();
  }

  /// A slice of the intro, eased.
  double _in(double begin, double end, [Curve curve = Curves.easeOutCubic]) =>
      Interval(begin, end, curve: curve).transform(_intro.value);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final h = media.size.height;
    final scooterW = (w * 0.82).clamp(200.0, 360.0);
    final scooterH = scooterW * 571 / 800;
    final roadTop = h * 0.65;
    final center = Offset(w / 2, h * 0.5);

    return Scaffold(
      backgroundColor: const Color(0xFF032E37),
      body: AnimatedBuilder(
        animation: Listenable.merge([_intro, _exit]),
        builder: (context, _) {
          final exit = _exit.value;
          final fadeOut = 1 - const Interval(0.35, 1, curve: Curves.easeIn).transform(exit);

          return Stack(children: [
            // ── Background gradient ──
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF27E8C0), Color(0xFF0E9C92), Color(0xFF06545C), Color(0xFF032E37)],
                    stops: [0.0, 0.4, 0.75, 1.0],
                  ),
                ),
              ),
            ),

            // ── Glow, pulse rings and floating lights ──
            Positioned.fill(
              child: Opacity(
                opacity: _in(0, 0.45) * fadeOut,
                child: CustomPaint(painter: _AmbientPainter(_loop, center: center, skyBottom: roadTop)),
              ),
            ),

            // ── Skyline drifting behind the road ──
            Positioned(
              left: 0,
              right: 0,
              top: roadTop - 86,
              height: 86,
              child: Opacity(
                opacity: _in(0.15, 0.6) * fadeOut,
                child: CustomPaint(painter: _SkylinePainter(_loop)),
              ),
            ),

            // ── Wordmark (with a light sweep) and tagline ──
            Positioned(
              top: media.padding.top + h * 0.09,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: _in(0.08, 0.5) * fadeOut,
                child: Transform.translate(
                  offset: Offset(0, -18 * (1 - _in(0.08, 0.55))),
                  child: Column(children: [
                    _ShineSweep(animation: _loop, enabled: !_reduceMotion, child: const _Wordmark()),
                    const SizedBox(height: 14),
                    Opacity(
                      opacity: _in(0.3, 0.75),
                      child: Text(
                        'RIDER',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          // Letters close in as the tagline appears
                          letterSpacing: 11 + 10 * (1 - _in(0.3, 0.85)),
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),

            // ── Road: rises into place, dashes scroll ──
            Positioned(
              left: 0,
              right: 0,
              top: roadTop + 48 * (1 - _in(0, 0.45)),
              bottom: 0,
              child: Opacity(
                opacity: _in(0, 0.35),
                child: CustomPaint(painter: _RoadPainter(_road)),
              ),
            ),

            // ── Speed streaks behind the scooter ──
            Positioned(
              top: roadTop - scooterH * 0.62,
              left: 0,
              width: w / 2,
              height: scooterH * 0.5,
              child: Opacity(
                opacity: _in(0.55, 0.9) * (1 - exit),
                child: CustomPaint(painter: _StreakPainter(_road)),
              ),
            ),

            // ── Ground shadow under the scooter ──
            Positioned(
              top: roadTop - 8,
              left: (w - scooterW * 0.8) / 2 + _scooterX(w),
              width: scooterW * 0.8,
              height: 14,
              child: Opacity(
                opacity: _in(0.3, 0.8) * (1 - exit),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(50)),
                    boxShadow: [BoxShadow(color: Color(0x8C021A20), blurRadius: 14, spreadRadius: 2)],
                  ),
                ),
              ),
            ),

            // ── Scooter: drives in, brakes, bobs, rides off ──
            Positioned(
              top: roadTop - scooterH + 4,
              left: (w - scooterW) / 2 + _scooterX(w),
              width: scooterW,
              child: AnimatedBuilder(
                animation: _bob,
                builder: (context, child) {
                  final bob = Curves.easeInOut.transform(_bob.value);
                  // Leans back while arriving, forward while riding off
                  final arriving = 1 - _in(0.25, 0.9);
                  final lean = -0.05 * arriving + 0.07 * Curves.easeIn.transform(exit) + 0.006 * (bob - 0.5);
                  return Transform.translate(
                    offset: Offset(0, -3 * bob),
                    child: Transform.rotate(angle: lean, alignment: Alignment.bottomCenter, child: child),
                  );
                },
                child: Image.asset(
                  'assets/images/taptapgo_scooter.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),

            // ── Loading bar and percentage ──
            Positioned(
              left: 0,
              right: 0,
              bottom: media.padding.bottom + 72,
              child: Opacity(
                opacity: _in(0.55, 1) * fadeOut,
                child: _LoadingBar(load: _load, shimmer: _road, mint: _mint),
              ),
            ),
          ]);
        },
      ),
    );
  }

  /// Horizontal position of the scooter: in from the left (with a small braking overshoot),
  /// then off to the right.
  double _scooterX(double w) {
    final arrive = _in(0.22, 0.88, Curves.easeOutBack);
    final leave = Curves.easeInCubic.transform(_exit.value);
    return -w * 1.1 * (1 - arrive) + w * 1.2 * leave;
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) => const Text.rich(
        TextSpan(children: [
          TextSpan(text: 'TapTap'),
          TextSpan(text: 'Go', style: TextStyle(color: Color(0xFF9DFBE3))),
        ]),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 54,
          fontWeight: FontWeight.w700,
          height: 1,
          letterSpacing: -1.5,
          color: Colors.white,
          shadows: [
            Shadow(color: Color(0x4D021A20), offset: Offset(0, 3), blurRadius: 0),
            Shadow(color: Color(0x59021A20), offset: Offset(0, 10), blurRadius: 22),
          ],
        ),
      );
}

/// A soft band of light that passes over the child once per loop.
class _ShineSweep extends StatelessWidget {
  final Animation<double> animation;
  final bool enabled;
  final Widget child;
  const _ShineSweep({required this.animation, required this.enabled, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        // Sweep during the first 40% of each loop, rest otherwise
        final t = (animation.value / 0.4).clamp(0.0, 1.0);
        final x = -1.0 + 3.0 * Curves.easeInOut.transform(t);
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment(x - 0.6, -0.4),
            end: Alignment(x + 0.6, 0.4),
            colors: const [Color(0x00FFFFFF), Color(0x8CFFFFFF), Color(0x00FFFFFF)],
            stops: const [0.35, 0.5, 0.65],
          ).createShader(rect),
          child: child,
        );
      },
    );
  }
}

/// Rounded bar with a mint-to-white fill, a moving shimmer and the percentage under it.
class _LoadingBar extends StatelessWidget {
  final Animation<double> load;
  final Animation<double> shimmer;
  final Color mint;
  const _LoadingBar({required this.load, required this.shimmer, required this.mint});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge([load, shimmer]),
        builder: (context, _) {
          final p = Curves.easeInOut.transform(load.value);
          return Column(children: [
            Container(
              width: 210,
              height: 7,
              decoration: BoxDecoration(
                color: const Color(0x33FFFFFF),
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: p.clamp(0.02, 1.0),
                heightFactor: 1, // fill the track's height
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(colors: [mint, Colors.white]),
                    boxShadow: [BoxShadow(color: mint.withValues(alpha: 0.55), blurRadius: 10)],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: CustomPaint(painter: _BarShimmer(shimmer.value)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('LOADING',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 5, color: Color(0xFFD8FFF4))),
              const SizedBox(width: 6),
              SizedBox(
                width: 40,
                child: Text('${(p * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFeatures: [FontFeature.tabularFigures()],
                    )),
              ),
            ]),
          ]);
        },
      );
}

class _BarShimmer extends CustomPainter {
  final double t;
  const _BarShimmer(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final x = -40 + (size.width + 80) * t;
    final rect = Rect.fromLTWH(x - 20, 0, 40, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x00FFFFFF), Color(0xB3FFFFFF), Color(0x00FFFFFF)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_BarShimmer old) => old.t != t;
}

// ── Glow, pulse rings and floating lights ─────────────────────────────────────
class _AmbientPainter extends CustomPainter {
  _AmbientPainter(this.anim, {required this.center, required this.skyBottom}) : super(repaint: anim);

  final Animation<double> anim;
  final Offset center;
  final double skyBottom;

  /// Fixed "random" lights: x (0–1), speed, size, phase.
  static final List<List<double>> _lights = () {
    final r = math.Random(7);
    return List.generate(16, (_) => [r.nextDouble(), 0.5 + r.nextDouble(), 1.2 + r.nextDouble() * 2.2, r.nextDouble()]);
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;

    // Soft glow behind the scooter
    canvas.drawCircle(
      center,
      230,
      Paint()
        ..shader = const RadialGradient(colors: [Color(0x66FFFFFF), Color(0x00FFFFFF)])
            .createShader(Rect.fromCircle(center: center, radius: 230)),
    );

    // Two steady rings and three pulses spreading out from the centre
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, 190, ring..color = const Color(0x1FFFFFFF));
    canvas.drawCircle(center, 280, ring..color = const Color(0x12FFFFFF));
    for (var i = 0; i < 3; i++) {
      final p = (t * 1.5 + i / 3) % 1.0;
      final eased = Curves.easeOut.transform(p);
      canvas.drawCircle(
        center,
        140 + 220 * eased,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * (1 - p) + 0.4
          ..color = Colors.white.withValues(alpha: 0.22 * (1 - p)),
      );
    }

    // Lights drifting up through the sky
    final dot = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    for (final l in _lights) {
      final p = (t * l[1] + l[3]) % 1.0;
      final y = skyBottom - p * skyBottom * 0.95;
      final x = l[0] * size.width + math.sin((p + l[3]) * math.pi * 2) * 10;
      final fade = math.sin(p * math.pi); // in and out
      canvas.drawCircle(Offset(x, y), l[2], dot..color = Colors.white.withValues(alpha: 0.45 * fade));
    }
  }

  @override
  bool shouldRepaint(_AmbientPainter old) => old.center != center || old.skyBottom != skyBottom;
}

// ── Skyline silhouette, drifting slowly left ─────────────────────────────────
class _SkylinePainter extends CustomPainter {
  _SkylinePainter(this.anim) : super(repaint: anim);
  final Animation<double> anim;

  static const _tile = 360.0;

  /// Buildings across one tile: left, width, height (0–1).
  static final List<List<double>> _buildings = () {
    final r = math.Random(21);
    final list = <List<double>>[];
    var x = 0.0;
    while (x < _tile) {
      final bw = 18 + r.nextDouble() * 30;
      list.add([x, bw, 0.25 + r.nextDouble() * 0.75]);
      x += bw + 2 + r.nextDouble() * 6;
    }
    return list;
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final shift = -(anim.value * _tile);
    final far = Paint()..color = const Color(0xFF06545C).withValues(alpha: 0.35);
    final windows = Paint()..color = const Color(0x339DFBE3);
    for (var start = shift; start < size.width; start += _tile) {
      for (final b in _buildings) {
        final left = start + b[0];
        if (left + b[1] < 0 || left > size.width) continue;
        final top = size.height * (1 - b[2]);
        canvas.drawRRect(
          RRect.fromRectAndCorners(Rect.fromLTWH(left, top, b[1], size.height - top),
              topLeft: const Radius.circular(2), topRight: const Radius.circular(2)),
          far,
        );
        // A few lit windows
        for (var wy = top + 8; wy < size.height - 10; wy += 12) {
          if (((b[0] + wy) ~/ 7) % 3 != 0) continue;
          canvas.drawRect(Rect.fromLTWH(left + b[1] / 2 - 2, wy, 4, 4), windows);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Speed streaks moving left behind the scooter ──────────────────────────────
class _StreakPainter extends CustomPainter {
  _StreakPainter(this.anim) : super(repaint: anim);
  final Animation<double> anim;

  static const _rows = [0.18, 0.42, 0.66, 0.86];

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < _rows.length; i++) {
      final p = (anim.value + i * 0.27) % 1.0;
      final len = 26.0 + 22 * ((i * 37) % 3);
      final x = size.width * (1 - p) - len;
      final y = size.height * _rows[i];
      final rect = Rect.fromLTWH(x, y - 1.5, len, 3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()
          ..shader = LinearGradient(colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.55 * math.sin(p * math.pi)),
          ]).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Scrolling road ────────────────────────────────────────────────────────────
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

    // Top edge highlight, with a glint travelling along it
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 3), Paint()..color = const Color(0x40FFFFFF));
    final gx = size.width * (1 - anim.value);
    final glint = Rect.fromLTWH(gx - 60, 0, 120, 3);
    canvas.drawRect(
      glint,
      Paint()
        ..shader = const LinearGradient(colors: [Color(0x00FFFFFF), Color(0x99FFFFFF), Color(0x00FFFFFF)])
            .createShader(glint),
    );

    // Scrolling dashed centre line
    const dash = 34.0;
    const gap = 26.0;
    const period = dash + gap;
    const y = 56.0;
    final paint = Paint()
      ..color = const Color(0x73FFFFFF)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    var x = -anim.value * period;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dash, y), paint);
      x += period;
    }

    // Faster, fainter edge line nearer the viewer
    final edge = Paint()
      ..color = const Color(0x26FFFFFF)
      ..strokeWidth = 2;
    const period2 = 90.0;
    var x2 = -((anim.value * 1.6) % 1) * period2;
    while (x2 < size.width) {
      canvas.drawLine(Offset(x2, y + 70), Offset(x2 + 46, y + 70), edge);
      x2 += period2;
    }
  }

  @override
  bool shouldRepaint(covariant _RoadPainter oldDelegate) => false;
}

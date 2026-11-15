import 'package:flutter/material.dart';

/// Wraps each item of a page's list in [Reveal], one after another; spacers are left as they are.
List<Widget> revealAll(List<Widget> children, {int start = 0}) {
  var i = start;
  return [for (final c in children) c is SizedBox || c is Divider ? c : Reveal(index: i++, child: c)];
}

/// Fades and slides its child up into place the first time it is shown. Give each card or list
/// row its position as [index] and they arrive one after another (a short stagger, capped so long
/// lists do not wait). Plays once; taps work at once. Off when the phone asks for less motion.
class Reveal extends StatefulWidget {
  final Widget child;
  final int index;

  /// Pixels to slide up from.
  final double offset;

  const Reveal({super.key, required this.child, this.index = 0, this.offset = 14});

  static const _step = Duration(milliseconds: 55);
  static const _length = Duration(milliseconds: 420);
  static const _maxSteps = 8;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final int _steps = widget.index.clamp(0, Reveal._maxSteps);
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Reveal._length + Reveal._step * _steps,
  );
  // The delay is the first part of one controller (no timers, so tests never wait on one)
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Interval(
      (Reveal._step * _steps).inMilliseconds / _c.duration!.inMilliseconds,
      1,
      curve: Curves.easeOutCubic,
    ),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _t,
        child: widget.child,
        builder: (context, child) => Opacity(
          opacity: _t.value,
          child: Transform.translate(offset: Offset(0, widget.offset * (1 - _t.value)), child: child),
        ),
      );
}

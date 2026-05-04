import 'package:flutter/material.dart';

/// AnimatedDemo — wraps a CustomPainter that receives a 0→1 looping progress
/// value driven by a repeating [AnimationController].
///
/// Usage:
/// ```dart
/// AnimatedDemo(
///   period: const Duration(seconds: 2),
///   painter: (t) => MyPainter(t),
/// )
/// ```
class AnimatedDemo extends StatefulWidget {
  final Duration period;
  final CustomPainter Function(double t) painter;
  final Size canvasSize;

  const AnimatedDemo({
    super.key,
    required this.period,
    required this.painter,
    this.canvasSize = const Size(180, 150),
  });

  @override
  State<AnimatedDemo> createState() => _AnimatedDemoState();
}

class _AnimatedDemoState extends State<AnimatedDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.period)..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          size: widget.canvasSize,
          painter: widget.painter(_ctrl.value),
        ),
      );
}

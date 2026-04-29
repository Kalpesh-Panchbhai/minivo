import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A horizontal slider with a knob that:
/// 1. Snaps to one of N stops on tap.
/// 2. Slides continuously under the finger during drag (no mid-drag snapping).
/// 3. Spins (full circular rotation) proportionally to drag distance — every
///    ~50 px of horizontal travel rotates the knob ~1 turn. Spin momentum
///    decays after release using an `easeOut` curve (no recursive ticker).
/// 4. Settles to the nearest stop on release with a soft easeOutBack motion.
class SpinningSlider extends StatefulWidget {
  /// Number of stops. Positions are evenly spaced from `knobR` to
  /// `width - knobR`.
  final int stopCount;

  /// Currently active stop (driven by parent state).
  final int activeIndex;

  /// Called whenever the active stop changes.
  final ValueChanged<int> onChanged;

  /// Color of the active knob and the filled track gradient end-stop.
  final Color activeColor;

  /// Track gradient — colours of every stop from left (easy) to right (hard).
  final List<Color> stopColors;

  /// Optional widget rendered inside the knob.
  final Widget? knobChild;

  final double trackHeight;
  final double knobSize;

  const SpinningSlider({
    super.key,
    required this.stopCount,
    required this.activeIndex,
    required this.onChanged,
    required this.activeColor,
    required this.stopColors,
    this.knobChild,
    this.trackHeight = 44,
    this.knobSize = 36,
  });

  @override
  State<SpinningSlider> createState() => _SpinningSliderState();
}

class _SpinningSliderState extends State<SpinningSlider>
    with TickerProviderStateMixin {
  /// Knob center X in pixels during drag/settle. Null when idle.
  double? _dragX;

  /// Cumulative rotation of the knob, in radians. Updated live by drag and
  /// by the spin-decay animation.
  double _rotation = 0;

  /// Rotation snapshot at the moment the user lifts their finger.
  double _spinStartRot = 0;

  /// How much extra rotation to deliver during decay (rad). Sign matches
  /// drag direction so the knob "coasts" naturally.
  double _spinDelta = 0;

  /// Estimated angular velocity at release (rad/s). Positive = clockwise.
  double _angularVel = 0;

  /// Last finger position during a drag.
  double? _lastDragX;
  Duration? _lastFrameTime;

  /// Animation: 0.0 → 1.0 over a fixed duration with an easeOut curve.
  /// Drives the spin-decay AND the position-settle in lock-step.
  late final AnimationController _releaseCtrl;
  late final Animation<double> _easeOut;

  /// Settle endpoints for the knob position (local frame).
  double _settleFrom = 0;
  double _settleTo = 0;

  @override
  void initState() {
    super.initState();
    _releaseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _easeOut = CurvedAnimation(parent: _releaseCtrl, curve: Curves.easeOutCubic);
    _easeOut.addListener(_onReleaseTick);
    _releaseCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Drop dragX so the knob snaps to the activeIndex stop on next build.
        if (mounted) setState(() => _dragX = null);
      }
    });
  }

  void _onReleaseTick() {
    final p = _easeOut.value; // 0 → 1
    setState(() {
      // Spin: deliver _spinDelta over 0..1 with easing already applied.
      _rotation = _spinStartRot + _spinDelta * p;
      // Position: settle from current drag pos to nearest stop.
      _dragX = _settleFrom + (_settleTo - _settleFrom) * p;
    });
  }

  @override
  void dispose() {
    _easeOut.removeListener(_onReleaseTick);
    _releaseCtrl.dispose();
    super.dispose();
  }

  List<double> _stops(double width) {
    final r = widget.knobSize / 2;
    if (widget.stopCount == 1) return [width / 2];
    final span = width - 2 * r;
    return List.generate(
      widget.stopCount,
      (i) => r + span * i / (widget.stopCount - 1),
    );
  }

  int _nearestStop(double x, List<double> stops) {
    int best = 0;
    var bestDist = double.infinity;
    for (int i = 0; i < stops.length; i++) {
      final d = (stops[i] - x).abs();
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  void _snapTap(double x, List<double> stops) {
    final i = _nearestStop(x, stops);
    if (i != widget.activeIndex) widget.onChanged(i);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        final stops = _stops(width);
        final activeStopX = stops[widget.activeIndex];
        // While dragging or settling, knob follows _dragX; otherwise sit at
        // the active stop.
        final knobX = _dragX ?? activeStopX;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _snapTap(d.localPosition.dx, stops),
          onHorizontalDragStart: (d) {
            // Cancel any in-flight release animation so the user can grab
            // the knob mid-coast.
            _releaseCtrl.stop();
            _angularVel = 0;
            setState(() {
              _dragX = d.localPosition.dx.clamp(stops.first, stops.last);
              _lastDragX = _dragX;
              _lastFrameTime = Duration(
                microseconds: DateTime.now().microsecondsSinceEpoch,
              );
            });
            _snapTap(d.localPosition.dx, stops);
          },
          onHorizontalDragUpdate: (d) {
            final newX = d.localPosition.dx.clamp(stops.first, stops.last);
            final delta = newX - (_lastDragX ?? newX);

            // Knob rotation: ~1 turn per 50 px of horizontal travel.
            final rotDelta = delta / 50 * 2 * math.pi;
            _rotation += rotDelta;

            // Estimate angular velocity for momentum on release.
            final now = Duration(
              microseconds: DateTime.now().microsecondsSinceEpoch,
            );
            if (_lastFrameTime != null) {
              final dt = (now - _lastFrameTime!).inMicroseconds / 1e6;
              if (dt > 0) _angularVel = rotDelta / dt;
            }
            _lastFrameTime = now;
            _lastDragX = newX;

            setState(() => _dragX = newX);

            // Live update active index as the knob crosses each stop's
            // half-way line.
            final nearest = _nearestStop(newX, stops);
            if (nearest != widget.activeIndex) widget.onChanged(nearest);
          },
          onHorizontalDragEnd: (_) {
            _lastFrameTime = null;
            _lastDragX = null;

            // Configure the release animation: spin coasts for ~0.4 s of
            // flywheel inertia and the position settles to the nearest stop
            // — both driven by the same easeOut curve.
            _spinStartRot = _rotation;
            _spinDelta = _angularVel * 0.4;
            _angularVel = 0;

            final nearest = _nearestStop(knobX, stops);
            _settleFrom = knobX;
            _settleTo = stops[nearest];
            _releaseCtrl.forward(from: 0);
            if (nearest != widget.activeIndex) widget.onChanged(nearest);
          },
          onHorizontalDragCancel: () {
            _lastFrameTime = null;
            _lastDragX = null;
            setState(() => _dragX = null);
          },
          child: SizedBox(
            height: widget.trackHeight,
            width: width,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Track baseline.
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2DAEE),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                // Filled gradient up to current knob position.
                AnimatedContainer(
                  duration: _dragX == null
                      ? const Duration(milliseconds: 240)
                      : Duration.zero,
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.only(left: 4),
                  height: 14,
                  width: (knobX - 4).clamp(0.0, width - 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _gradientColorsForIndex(widget.activeIndex),
                    ),
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: [
                      BoxShadow(
                        color: widget.activeColor.withValues(alpha: 0.30),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
                // Stop dots.
                for (int i = 0; i < stops.length; i++)
                  Positioned(
                    left: stops[i] - 4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i <= widget.activeIndex
                            ? Colors.white
                            : const Color(0xFF8475C2).withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                // Knob — spins via Transform.rotate; position follows finger
                // during drag, then settles to nearest stop on release.
                Positioned(
                  left: knobX - widget.knobSize / 2,
                  child: Transform.rotate(
                    angle: _rotation,
                    child: Container(
                      width: widget.knobSize,
                      height: widget.knobSize,
                      decoration: BoxDecoration(
                        color: widget.activeColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: widget.activeColor.withValues(alpha: 0.40),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: widget.knobChild,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Color> _gradientColorsForIndex(int idx) {
    if (widget.stopColors.length <= 1) {
      return [widget.activeColor, widget.activeColor];
    }
    final colors = widget.stopColors.take(idx + 1).toList();
    return colors.length < 2 ? [colors.first, colors.first] : colors;
  }
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/services/ads_service.dart';
import '../../core/services/audio_service.dart';

class RewardedUndoButton extends StatefulWidget {
  final VoidCallback onUndo;
  final VoidCallback onExpired;
  final Color accentColor;

  const RewardedUndoButton({
    super.key,
    required this.onUndo,
    required this.onExpired,
    required this.accentColor,
  });

  @override
  State<RewardedUndoButton> createState() => _RewardedUndoButtonState();
}

class _RewardedUndoButtonState extends State<RewardedUndoButton>
    with TickerProviderStateMixin {
  static const _totalMs = 2000;

  late final AnimationController _ringCtrl;
  late final AnimationController _entryCtrl;
  late final AnimationController _pulseCtrl;
  bool _adTapped = false;
  int _secondsLeft = 2;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();

    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _totalMs),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed && !_adTapped) {
          widget.onExpired();
        }
      });

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _entryCtrl.forward();
    _ringCtrl.forward();

    _tickTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _secondsLeft = 1);
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _ringCtrl.dispose();
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onTap() {
    if (_adTapped) return;
    _adTapped = true;
    _ringCtrl.stop();
    _pulseCtrl.stop();
    _tickTimer?.cancel();
    AudioService().playTap();
    bool earned = false;
    AdsService().showRewarded(
      rewardType: RewardType.undo,
      onRewarded: (_) => earned = true,
      onComplete: () {
        if (earned) widget.onUndo();
      },
    );
  }

  static const _kBg = Color(0xFFFFD43B);
  static const _kFg = Color(0xFF5C4600);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _entryCtrl,
      builder: (context, child) {
        final t = Curves.elasticOut.transform(_entryCtrl.value.clamp(0.0, 1.0));
        return Transform.scale(
          scale: t,
          child: Opacity(opacity: _entryCtrl.value.clamp(0.0, 1.0), child: child),
        );
      },
      child: GestureDetector(
        onTap: _onTap,
        child: AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (context, child) {
            final shadowBlur = 14.0 + _pulseCtrl.value * 10.0;
            final shadowAlpha = 0.35 + _pulseCtrl.value * 0.15;
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: _kBg.withValues(alpha: shadowAlpha),
                    blurRadius: shadowBlur,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFE6BE00),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24, height: 24,
                  child: AnimatedBuilder(
                    animation: _ringCtrl,
                    builder: (context, _) => CustomPaint(
                      painter: _RingPainter(
                        progress: 1.0 - _ringCtrl.value,
                        color: _kFg,
                        trackColor: _kFg.withValues(alpha: 0.20),
                      ),
                      child: Center(
                        child: Text(
                          '$_secondsLeft',
                          style: const TextStyle(
                            color: _kFg,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.undo_rounded, size: 16, color: _kFg),
                const SizedBox(width: 4),
                const Text(
                  'UNDO',
                  style: TextStyle(
                    color: _kFg,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kFg.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded, size: 12, color: _kFg),
                      SizedBox(width: 2),
                      Text(
                        'AD',
                        style: TextStyle(
                          color: _kFg,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - 3) / 2;
    const strokeWidth = 2.5;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    final ringPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      ringPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

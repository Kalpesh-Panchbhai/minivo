import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> waterSortSteps() => [
  GameHowToPlayStep(
    text: 'Tap a tube to pick up the top color, then tap another tube to pour it in.',
    demo: AnimatedDemo(
      period: const Duration(seconds: 3),
      painter: (t) => _PourPainter(t),
      canvasSize: const Size(200, 160),
    ),
  ),
  GameHowToPlayStep(
    text: 'You can only pour into a tube with the same top color or an empty tube.',
    demo: AnimatedDemo(
      period: const Duration(seconds: 3),
      painter: (t) => _RulePainter(t),
      canvasSize: const Size(200, 160),
    ),
  ),
  GameHowToPlayStep(
    text: 'Sort all colors so each tube contains only one color. Watch an ad to unlock extra tube space!',
    demo: AnimatedDemo(
      period: const Duration(seconds: 3),
      painter: (t) => _SolvedPainter(t),
      canvasSize: const Size(200, 160),
    ),
  ),
];

class _PourPainter extends CustomPainter {
  final double t;
  _PourPainter(this.t);

  static const _red = Color(0xFFEF4444);
  static const _blue = Color(0xFF3B82F6);

  @override
  void paint(Canvas canvas, Size size) {
    final tubeW = 36.0;
    final tubeH = 90.0;
    final x1 = size.width * 0.3 - tubeW / 2;
    final x2 = size.width * 0.7 - tubeW / 2;
    final y = size.height * 0.35;

    _drawTubeOutline(canvas, x1, y, tubeW, tubeH);
    _drawTubeOutline(canvas, x2, y, tubeW, tubeH);

    final segH = tubeH / 4;

    if (t < 0.5) {
      _drawSeg(canvas, x1, y + tubeH - segH, tubeW, segH, _blue);
      _drawSeg(canvas, x1, y + tubeH - segH * 2, tubeW, segH, _red);
      _drawSeg(canvas, x2, y + tubeH - segH, tubeW, segH, _red);

      if (t > 0.2) {
        final selOffset = -8.0 * ((t - 0.2) / 0.3).clamp(0.0, 1.0);
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x1 - 1, y + selOffset - 1, tubeW + 2, tubeH + 2), const Radius.circular(6)),
          Paint()..color = Colors.white.withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = 2,
        );
      }
    } else {
      _drawSeg(canvas, x1, y + tubeH - segH, tubeW, segH, _blue);
      _drawSeg(canvas, x2, y + tubeH - segH, tubeW, segH, _red);
      _drawSeg(canvas, x2, y + tubeH - segH * 2, tubeW, segH, _red);
    }
  }

  void _drawTubeOutline(Canvas canvas, double x, double y, double w, double h) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(6)),
      Paint()..color = Colors.white.withValues(alpha: 0.15),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(6)),
      Paint()..color = Colors.white.withValues(alpha: 0.4)..style = PaintingStyle.stroke..strokeWidth = 1,
    );
  }

  void _drawSeg(Canvas canvas, double x, double y, double w, double h, Color c) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x + 2, y, w - 4, h - 2), const Radius.circular(3)),
      Paint()..color = c,
    );
  }

  @override
  bool shouldRepaint(_PourPainter old) => true;
}

class _RulePainter extends CustomPainter {
  final double t;
  _RulePainter(this.t);

  static const _red = Color(0xFFEF4444);
  static const _blue = Color(0xFF3B82F6);
  static const _green = Color(0xFF22C55E);

  @override
  void paint(Canvas canvas, Size size) {
    // Alternate between a valid pour (matching tops) and an invalid one.
    final valid = t < 0.5;
    final tubeW = 30.0, tubeH = 78.0, gap = 30.0;
    final totalW = tubeW * 2 + gap;
    final startX = (size.width - totalW) / 2;
    final y = size.height * 0.18;
    final segH = tubeH / 4;

    void outline(double x) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, tubeW, tubeH), const Radius.circular(6)),
        Paint()..color = Colors.white.withValues(alpha: 0.15),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, tubeW, tubeH), const Radius.circular(6)),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    void seg(double x, int slot, Color c) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x + 2, y + tubeH - (slot + 1) * segH, tubeW - 4, segH - 2),
            const Radius.circular(3)),
        Paint()..color = c,
      );
    }

    final x1 = startX, x2 = startX + tubeW + gap;
    outline(x1);
    outline(x2);
    // source (left): top = red
    seg(x1, 0, _blue);
    seg(x1, 1, _red);
    // dest (right): top red (valid) or blue (invalid)
    seg(x2, 0, valid ? _red : _blue);

    // pour arrow between tops
    final arrowY = y + 6;
    final ap = Paint()
      ..color = (valid ? _green : _red)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x1 + tubeW + 2, arrowY), Offset(x2 - 4, arrowY), ap);
    canvas.drawLine(Offset(x2 - 4, arrowY), Offset(x2 - 10, arrowY - 4), ap);
    canvas.drawLine(Offset(x2 - 4, arrowY), Offset(x2 - 10, arrowY + 4), ap);

    // verdict badge
    final icon = valid ? '✓' : '✗';
    final col = valid ? _green : _red;
    final ip = TextPainter(
      text: TextSpan(text: icon, style: TextStyle(color: col, fontSize: 26, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    )..layout();
    ip.paint(canvas, Offset(size.width / 2 - ip.width / 2, y + tubeH + 6));

    final label = valid ? 'Same top color → pour OK' : 'Different top color → blocked';
    final lp = TextPainter(
      text: TextSpan(
          text: label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    lp.paint(canvas, Offset(size.width / 2 - lp.width / 2, y + tubeH + 34));
  }

  @override
  bool shouldRepaint(_RulePainter old) => true;
}

class _SolvedPainter extends CustomPainter {
  final double t;
  _SolvedPainter(this.t);

  static const _colors = [Color(0xFFEF4444), Color(0xFF3B82F6), Color(0xFF22C55E)];

  @override
  void paint(Canvas canvas, Size size) {
    final tubeW = 32.0;
    final tubeH = 80.0;
    final gap = 12.0;
    final totalW = tubeW * 3 + gap * 2;
    final startX = (size.width - totalW) / 2;
    final y = size.height * 0.2;

    for (int i = 0; i < 3; i++) {
      final x = startX + i * (tubeW + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, tubeW, tubeH), const Radius.circular(6)),
        Paint()..color = Colors.white.withValues(alpha: 0.15),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, tubeW, tubeH), const Radius.circular(6)),
        Paint()..color = Colors.white.withValues(alpha: 0.4)..style = PaintingStyle.stroke..strokeWidth = 1,
      );

      final segH = tubeH / 4;
      for (int s = 0; s < 4; s++) {
        final sy = y + tubeH - (s + 1) * segH;
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x + 2, sy, tubeW - 4, segH - 2), const Radius.circular(2)),
          Paint()..color = _colors[i],
        );
      }
    }

    final scale = 0.8 + 0.2 * math.sin(t * math.pi * 2);
    final tp = TextPainter(
      text: const TextSpan(text: '✓ Sorted!', style: TextStyle(color: Color(0xFF22C55E), fontSize: 16, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(size.width / 2, y + tubeH + 20 + tp.height / 2);
    canvas.scale(scale);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SolvedPainter old) => true;
}

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
      canvasSize: const Size(200, 180),
    ),
  ),
  GameHowToPlayStep(
    text: 'You can only pour into a tube with the same top color or an empty tube.',
    demo: AnimatedDemo(
      period: const Duration(seconds: 3),
      painter: (t) => _RulePainter(t),
      canvasSize: const Size(200, 180),
    ),
  ),
  GameHowToPlayStep(
    text: 'Sort all colors so each tube holds only one color. Complete all tubes to win!',
    demo: AnimatedDemo(
      period: const Duration(seconds: 3),
      painter: (t) => _SolvedPainter(t),
      canvasSize: const Size(200, 180),
    ),
  ),
];

class _PourPainter extends CustomPainter {
  final double t;
  _PourPainter(this.t);

  static const _red = Color(0xFFE53935);
  static const _blue = Color(0xFF1E88E5);

  @override
  void paint(Canvas canvas, Size size) {
    final tubeW = 36.0;
    final tubeH = 90.0;
    final x1 = size.width * 0.3 - tubeW / 2;
    final x2 = size.width * 0.7 - tubeW / 2;
    final baseY = size.height * 0.35;
    final segH = tubeH / 4;

    if (t < 0.3) {
      final selectP = (t / 0.3).clamp(0.0, 1.0);
      final liftY = -10.0 * Curves.easeOut.transform(selectP);

      _drawTubeOutline(canvas, x1, baseY + liftY, tubeW, tubeH);
      _drawTubeOutline(canvas, x2, baseY, tubeW, tubeH);

      _drawSeg(canvas, x1, baseY + liftY + tubeH - segH, tubeW, segH, _blue);
      _drawSeg(canvas, x1, baseY + liftY + tubeH - segH * 2, tubeW, segH, _red);
      _drawSeg(canvas, x2, baseY + tubeH - segH, tubeW, segH, _red);

      final glowAlpha = (0.25 + 0.35 * selectP).clamp(0.0, 1.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x1 - 2, baseY + liftY - 2, tubeW + 4, tubeH + 4),
          const Radius.circular(8),
        ),
        Paint()
          ..color = Colors.white.withValues(alpha: glowAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    } else if (t < 0.7) {
      final pourP = ((t - 0.3) / 0.4).clamp(0.0, 1.0);
      final eased = Curves.easeInOut.transform(pourP);

      const liftY = -10.0;

      _drawTubeOutline(canvas, x1, baseY + liftY, tubeW, tubeH);
      _drawTubeOutline(canvas, x2, baseY, tubeW, tubeH);

      _drawSeg(canvas, x1, baseY + liftY + tubeH - segH, tubeW, segH, _blue);

      final srcRemain = segH * (1.0 - eased);
      if (srcRemain > 0.5) {
        _drawSeg(
          canvas,
          x1,
          baseY + liftY + tubeH - segH - srcRemain,
          tubeW,
          srcRemain,
          _red,
        );
      }

      _drawSeg(canvas, x2, baseY + tubeH - segH, tubeW, segH, _red);

      final dstGrow = segH * eased;
      if (dstGrow > 0.5) {
        _drawSeg(
          canvas,
          x2,
          baseY + tubeH - segH - dstGrow,
          tubeW,
          dstGrow,
          _red,
        );
      }

      final streamAlpha = (1.0 - (pourP - 0.85).clamp(0.0, 1.0) * 6.67).clamp(0.0, 1.0);
      if (streamAlpha > 0) {
        final srcTopY = baseY + liftY + tubeH - segH - srcRemain;
        final dstTopY = baseY + tubeH - segH - dstGrow;

        final streamX1 = x1 + tubeW / 2;
        final streamX2 = x2 + tubeW / 2;
        final streamTopY = math.min(srcTopY, baseY + liftY) - 6;

        final streamPaint = Paint()
          ..color = _red.withValues(alpha: 0.8 * streamAlpha)
          ..strokeWidth = 4.0
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

        final path = Path()
          ..moveTo(streamX1, srcTopY)
          ..lineTo(streamX1, streamTopY)
          ..quadraticBezierTo(
            (streamX1 + streamX2) / 2,
            streamTopY - 4,
            streamX2,
            streamTopY,
          )
          ..lineTo(streamX2, dstTopY);

        canvas.drawPath(path, streamPaint);
      }

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x1 - 2, baseY + liftY - 2, tubeW + 4, tubeH + 4),
          const Radius.circular(8),
        ),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5 * (1.0 - eased))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    } else {
      _drawTubeOutline(canvas, x1, baseY, tubeW, tubeH);
      _drawTubeOutline(canvas, x2, baseY, tubeW, tubeH);

      _drawSeg(canvas, x1, baseY + tubeH - segH, tubeW, segH, _blue);
      _drawSeg(canvas, x2, baseY + tubeH - segH, tubeW, segH, _red);
      _drawSeg(canvas, x2, baseY + tubeH - segH * 2, tubeW, segH, _red);
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
  bool shouldRepaint(_PourPainter old) => old.t != t;
}

class _RulePainter extends CustomPainter {
  final double t;
  _RulePainter(this.t);

  static const _red = Color(0xFFE53935);
  static const _blue = Color(0xFF1E88E5);
  static const _green = Color(0xFF43A047);

  @override
  void paint(Canvas canvas, Size size) {
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
    seg(x1, 0, _blue);
    seg(x1, 1, _red);
    seg(x2, 0, valid ? _red : _blue);

    final arrowY = y + 6;
    final ap = Paint()
      ..color = (valid ? _green : _red)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x1 + tubeW + 2, arrowY), Offset(x2 - 4, arrowY), ap);
    canvas.drawLine(Offset(x2 - 4, arrowY), Offset(x2 - 10, arrowY - 4), ap);
    canvas.drawLine(Offset(x2 - 4, arrowY), Offset(x2 - 10, arrowY + 4), ap);

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
  bool shouldRepaint(_RulePainter old) => old.t != t;
}

class _SolvedPainter extends CustomPainter {
  final double t;
  _SolvedPainter(this.t);

  static const _colors = [Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFF43A047)];

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
      text: const TextSpan(text: '✓ Sorted!', style: TextStyle(color: Color(0xFF43A047), fontSize: 16, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(size.width / 2, y + tubeH + 20 + tp.height / 2);
    canvas.scale(scale);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SolvedPainter old) => old.t != t;
}

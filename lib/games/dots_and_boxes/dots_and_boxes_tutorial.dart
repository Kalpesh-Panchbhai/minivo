import 'package:flutter/material.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> dotsAndBoxesSteps() {
  return const [
    GameHowToPlayStep(
      text: '✏️  Tap the gap between two dots to draw a line. '
          'Players take turns drawing one line at a time.',
      demo: _Step1Demo(),
    ),
    GameHowToPlayStep(
      text: '📦  Complete a box by drawing its 4th side! '
          'The box fills with your color and you score a point.',
      demo: _Step2Demo(),
    ),
    GameHowToPlayStep(
      text: '🔗  Chain reaction! If you complete a box you go again — '
          'keep going until you can\'t complete any more boxes.',
      demo: _Step3Demo(),
    ),
    GameHowToPlayStep(
      text: '🏆  When all boxes are filled the player with the most '
          'boxes wins. Plan ahead to avoid giving away chains!',
      demo: _Step4Demo(),
    ),
  ];
}

// ── Demo widgets (simple static illustrations) ────────────────────────────

class _Step1Demo extends StatelessWidget {
  const _Step1Demo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: CustomPaint(painter: _DrawLinePainter()),
    );
  }
}

class _DrawLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final step = size.width / 2;
    final dotR = 6.0;

    final linePaint = Paint()
      ..color = const Color(0xFF339AF0)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final dottedPaint = Paint()
      ..color = const Color(0xFF339AF0).withValues(alpha: 0.40)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()..color = const Color(0xFF333333);

    // Draw a 3×3 dot grid
    for (int r = 0; r <= 2; r++) {
      for (int c = 0; c <= 2; c++) {
        canvas.drawCircle(Offset(c * step, r * step), dotR, dotPaint);
      }
    }

    // Draw one solid line (top of top-left box)
    canvas.drawLine(Offset(0, 0), Offset(step, 0), linePaint);

    // Show a "pending" dotted line
    _drawDashed(canvas, Offset(0, step), Offset(step, step), dottedPaint);

    // Arrow hint
    final arrowPaint = Paint()
      ..color = const Color(0xFFFF6B6B)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(step * 0.5 + 18, step - 18), Offset(step * 0.5, step), arrowPaint);
  }

  void _drawDashed(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    final total = (p2 - p1).distance;
    final dir = (p2 - p1) / total;
    double drawn = 0;
    bool on = true;
    while (drawn < total) {
      final seg = on ? 6.0 : 4.0;
      final end = drawn + seg;
      if (on) {
        canvas.drawLine(p1 + dir * drawn, p1 + dir * end.clamp(0, total), paint);
      }
      drawn = end;
      on = !on;
    }
  }

  @override
  bool shouldRepaint(_DrawLinePainter old) => false;
}

class _Step2Demo extends StatelessWidget {
  const _Step2Demo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: CustomPaint(painter: _CompleteBoxPainter()),
    );
  }
}

class _CompleteBoxPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final step = size.width / 2;
    final dotR = 6.0;

    final linePaint = Paint()
      ..color = const Color(0xFF339AF0)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final lastLinePaint = Paint()
      ..color = const Color(0xFFFF6B6B)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final boxFill = Paint()
      ..color = const Color(0xFF339AF0).withValues(alpha: 0.30);

    final dotPaint = Paint()..color = const Color(0xFF333333);

    // Fill the completed box
    canvas.drawRect(Rect.fromLTWH(0, 0, step, step), boxFill);

    // Draw 3 existing lines
    canvas.drawLine(Offset(0, 0), Offset(step, 0), linePaint);
    canvas.drawLine(Offset(step, 0), Offset(step, step), linePaint);
    canvas.drawLine(Offset(0, 0), Offset(0, step), linePaint);

    // Draw the completing 4th line in P2 color
    canvas.drawLine(Offset(0, step), Offset(step, step), lastLinePaint);

    // Dots
    for (int r = 0; r <= 2; r++) {
      for (int c = 0; c <= 2; c++) {
        canvas.drawCircle(Offset(c * step, r * step), dotR, dotPaint);
      }
    }

    // P1 initial inside box
    final tp = TextPainter(
      text: const TextSpan(
        text: 'P1',
        style: TextStyle(
          color: Color(0xFF339AF0),
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(step / 2 - tp.width / 2, step / 2 - tp.height / 2));
  }

  @override
  bool shouldRepaint(_CompleteBoxPainter old) => false;
}

class _Step3Demo extends StatelessWidget {
  const _Step3Demo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: CustomPaint(painter: _ChainPainter()),
    );
  }
}

class _ChainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final step = size.width / 2;
    final dotR = 5.0;

    final p1Line = Paint()
      ..color = const Color(0xFF339AF0)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final p1Fill = Paint()
      ..color = const Color(0xFF339AF0).withValues(alpha: 0.25);

    final dotPaint = Paint()..color = const Color(0xFF333333);

    // Two adjacent boxes both claimed by P1 (chain)
    // Box 1 (top-left)
    canvas.drawRect(Rect.fromLTWH(0, 0, step, step), p1Fill);
    canvas.drawLine(Offset(0, 0), Offset(step, 0), p1Line);
    canvas.drawLine(Offset(step, 0), Offset(step, step), p1Line);
    canvas.drawLine(Offset(0, 0), Offset(0, step), p1Line);
    canvas.drawLine(Offset(0, step), Offset(step, step), p1Line);

    // Box 2 (top-right)
    canvas.drawRect(Rect.fromLTWH(step, 0, step, step), p1Fill);
    canvas.drawLine(Offset(step, 0), Offset(step * 2, 0), p1Line);
    canvas.drawLine(Offset(step * 2, 0), Offset(step * 2, step), p1Line);
    canvas.drawLine(Offset(step, step), Offset(step * 2, step), p1Line);

    // Chain arrow
    final arrowPaint = Paint()
      ..color = const Color(0xFFFF9900)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(step * 0.5, step + 14),
      Offset(step * 1.5, step + 14),
      arrowPaint,
    );
    canvas.drawLine(
      Offset(step * 1.5 - 8, step + 8),
      Offset(step * 1.5, step + 14),
      arrowPaint,
    );
    canvas.drawLine(
      Offset(step * 1.5 - 8, step + 20),
      Offset(step * 1.5, step + 14),
      arrowPaint,
    );

    for (int r = 0; r <= 2; r++) {
      for (int c = 0; c <= 2; c++) {
        canvas.drawCircle(Offset(c * step, r * step), dotR, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_ChainPainter old) => false;
}

class _Step4Demo extends StatelessWidget {
  const _Step4Demo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: CustomPaint(painter: _WinPainter()),
    );
  }
}

class _WinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final step = size.width / 2;
    final dotR = 5.0;

    final p1Line = Paint()
      ..color = const Color(0xFF339AF0)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final p2Line = Paint()
      ..color = const Color(0xFFFF6B6B)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final p1Fill = Paint()
      ..color = const Color(0xFF339AF0).withValues(alpha: 0.28);

    final p2Fill = Paint()
      ..color = const Color(0xFFFF6B6B).withValues(alpha: 0.28);

    final dotPaint = Paint()..color = const Color(0xFF333333);

    // 4 boxes: P1 claims 3, P2 claims 1
    final rects = [
      (Rect.fromLTWH(0, 0, step, step), true),
      (Rect.fromLTWH(step, 0, step, step), true),
      (Rect.fromLTWH(0, step, step, step), false),
      (Rect.fromLTWH(step, step, step, step), true),
    ];

    for (final (rect, isP1) in rects) {
      canvas.drawRect(rect, isP1 ? p1Fill : p2Fill);
      final lp = isP1 ? p1Line : p2Line;
      canvas.drawLine(rect.topLeft, rect.topRight, lp);
      canvas.drawLine(rect.topRight, rect.bottomRight, lp);
      canvas.drawLine(rect.bottomRight, rect.bottomLeft, lp);
      canvas.drawLine(rect.bottomLeft, rect.topLeft, lp);
    }

    // Dots
    for (int r = 0; r <= 2; r++) {
      for (int c = 0; c <= 2; c++) {
        canvas.drawCircle(Offset(c * step, r * step), dotR, dotPaint);
      }
    }

    // Score
    final tp = TextPainter(
      text: const TextSpan(
        children: [
          TextSpan(
            text: '3',
            style: TextStyle(
              color: Color(0xFF339AF0),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          TextSpan(
            text: ' vs ',
            style: TextStyle(
              color: Color(0xFF666666),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: '1',
            style: TextStyle(
              color: Color(0xFFFF6B6B),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(size.width / 2 - tp.width / 2, size.height - tp.height - 2),
    );
  }

  @override
  bool shouldRepaint(_WinPainter old) => false;
}

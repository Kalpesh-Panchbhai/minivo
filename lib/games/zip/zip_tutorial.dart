import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> zipSteps() => [
  GameHowToPlayStep(
    text: 'Draw a path through every cell in the grid. Swipe to connect cells.',
    demo: AnimatedDemo(
      period: const Duration(seconds: 3),
      painter: (t) => _DrawPathPainter(t),
      canvasSize: const Size(200, 160),
    ),
  ),
  GameHowToPlayStep(
    text: 'Numbered cells must be visited in order: 1 → 2 → 3 and so on.',
    demo: AnimatedDemo(
      period: const Duration(seconds: 3),
      painter: (t) => _NumberOrderPainter(t),
      canvasSize: const Size(200, 160),
    ),
  ),
  GameHowToPlayStep(
    text: 'Fill every cell to complete the puzzle. Backtrack by retracing your path!',
    demo: AnimatedDemo(
      period: const Duration(seconds: 3),
      painter: (t) => _CompletePainter(t),
      canvasSize: const Size(200, 160),
    ),
  ),
];

class _DrawPathPainter extends CustomPainter {
  final double t;
  _DrawPathPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cellS = 28.0;
    final gap = 4.0;
    final cols = 3, rows = 3;
    final totalW = cols * cellS + (cols - 1) * gap;
    final totalH = rows * cellS + (rows - 1) * gap;
    final ox = (size.width - totalW) / 2;
    final oy = (size.height - totalH) / 2;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(ox + c * (cellS + gap), oy + r * (cellS + gap), cellS, cellS),
          const Radius.circular(5),
        );
        canvas.drawRRect(rect, Paint()..color = Colors.white.withValues(alpha: 0.10));
        canvas.drawRRect(rect, Paint()..color = Colors.white.withValues(alpha: 0.25)..style = PaintingStyle.stroke..strokeWidth = 0.5);
      }
    }

    final pathCells = [
      [0, 0], [0, 1], [0, 2],
      [1, 2], [1, 1], [1, 0],
      [2, 0], [2, 1], [2, 2],
    ];
    final progress = (t * pathCells.length).clamp(0.0, pathCells.length.toDouble());
    final fullCells = progress.floor();

    final linePaint = Paint()
      ..color = const Color(0xFF818CF8)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < fullCells && i < pathCells.length; i++) {
      final r = pathCells[i][0], c = pathCells[i][1];
      final cx = ox + c * (cellS + gap) + cellS / 2;
      final cy = oy + r * (cellS + gap) + cellS / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(ox + c * (cellS + gap), oy + r * (cellS + gap), cellS, cellS),
          const Radius.circular(5),
        ),
        Paint()..color = const Color(0xFF818CF8).withValues(alpha: 0.30),
      );
      if (i > 0) {
        final pr = pathCells[i - 1][0], pc = pathCells[i - 1][1];
        final px = ox + pc * (cellS + gap) + cellS / 2;
        final py = oy + pr * (cellS + gap) + cellS / 2;
        canvas.drawLine(Offset(px, py), Offset(cx, cy), linePaint);
      }
    }

    if (fullCells > 0 && fullCells < pathCells.length) {
      final frac = progress - fullCells;
      final pr = pathCells[fullCells - 1][0], pc = pathCells[fullCells - 1][1];
      final nr = pathCells[fullCells][0], nc = pathCells[fullCells][1];
      final px = ox + pc * (cellS + gap) + cellS / 2;
      final py = oy + pr * (cellS + gap) + cellS / 2;
      final nx = ox + nc * (cellS + gap) + cellS / 2;
      final ny = oy + nr * (cellS + gap) + cellS / 2;
      canvas.drawLine(Offset(px, py), Offset(px + (nx - px) * frac, py + (ny - py) * frac), linePaint);
    }
  }

  @override
  bool shouldRepaint(_DrawPathPainter old) => true;
}

class _NumberOrderPainter extends CustomPainter {
  final double t;
  _NumberOrderPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final nums = ['1', '2', '3', '4'];
    final positions = [
      Offset(cx - 50, cy - 15),
      Offset(cx - 15, cy - 15),
      Offset(cx + 20, cy - 15),
      Offset(cx + 55, cy - 15),
    ];

    final activeIdx = (t * 4).floor().clamp(0, 3);

    for (int i = 0; i < 4; i++) {
      final isActive = i <= activeIdx;
      final pos = positions[i];
      canvas.drawCircle(
        pos,
        14,
        Paint()..color = isActive ? const Color(0xFF818CF8) : Colors.white.withValues(alpha: 0.15),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: nums[i],
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.4),
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));

      if (i > 0 && i <= activeIdx) {
        canvas.drawLine(
          Offset(positions[i - 1].dx + 14, positions[i - 1].dy),
          Offset(pos.dx - 14, pos.dy),
          Paint()..color = const Color(0xFF818CF8)..strokeWidth = 2..strokeCap = StrokeCap.round,
        );
      }
    }

    final label = '1 → 2 → 3 → 4';
    final ltp = TextPainter(
      text: TextSpan(text: label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    ltp.paint(canvas, Offset(cx - ltp.width / 2, cy + 28));
  }

  @override
  bool shouldRepaint(_NumberOrderPainter old) => true;
}

class _CompletePainter extends CustomPainter {
  final double t;
  _CompletePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final scale = 0.8 + 0.2 * math.sin(t * math.pi * 2);

    canvas.save();
    canvas.translate(cx, cy - 10);
    canvas.scale(scale);

    final checkPaint = Paint()
      ..color = const Color(0xFF22C55E)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(Offset.zero, 24, Paint()..color = const Color(0xFF22C55E).withValues(alpha: 0.2));
    canvas.drawCircle(Offset.zero, 24, Paint()..color = const Color(0xFF22C55E)..style = PaintingStyle.stroke..strokeWidth = 2);

    final checkPath = Path()
      ..moveTo(-10, 0)
      ..lineTo(-3, 8)
      ..lineTo(12, -8);
    canvas.drawPath(checkPath, checkPaint);

    canvas.restore();

    final tp = TextPainter(
      text: const TextSpan(text: 'Complete!', style: TextStyle(color: Color(0xFF22C55E), fontSize: 16, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy + 24));
  }

  @override
  bool shouldRepaint(_CompletePainter old) => true;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

const _kFlowColors = [
  Color(0xFFFF6B6B),
  Color(0xFF4ECDC4),
  Color(0xFFFFE66D),
];

const _kCellBg = Color(0xFFE8E8F0);

List<GameHowToPlayStep> colorConnectSteps() => [
      GameHowToPlayStep(
        text: 'Connect matching colored dots by drawing a path between them.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _CCBoardPainter(t, step: 0),
          canvasSize: const Size(200, 170),
        ),
      ),
      GameHowToPlayStep(
        text: 'Paths cannot cross or overlap. Fill every cell on the board.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 4),
          painter: (t) => _CCBoardPainter(t, step: 1),
          canvasSize: const Size(200, 170),
        ),
      ),
      GameHowToPlayStep(
        text: 'Complete all connections to solve the puzzle!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _CCBoardPainter(t, step: 2),
          canvasSize: const Size(200, 170),
        ),
      ),
    ];

class _CCBoardPainter extends CustomPainter {
  final double t;
  final int step;
  _CCBoardPainter(this.t, {required this.step});

  static const _n = 4;
  static const _cellS = 30.0;
  static const _gap = 4.0;

  static const _flows = [
    [[0, 0], [1, 0], [2, 0], [2, 1]],
    [[0, 3], [0, 2], [1, 2], [1, 3], [2, 3], [2, 2]],
    [[3, 0], [3, 1], [3, 2], [3, 3]],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final totalW = _n * _cellS + (_n - 1) * _gap;
    final totalH = _n * _cellS + (_n - 1) * _gap;
    final ox = (size.width - totalW) / 2;
    final oy = (size.height - totalH) / 2;

    Offset center(int r, int c) => Offset(
          ox + c * (_cellS + _gap) + _cellS / 2,
          oy + r * (_cellS + _gap) + _cellS / 2,
        );

    for (int r = 0; r < _n; r++) {
      for (int c = 0; c < _n; c++) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(ox + c * (_cellS + _gap), oy + r * (_cellS + _gap), _cellS, _cellS),
          const Radius.circular(6),
        );
        canvas.drawRRect(rect, Paint()..color = _kCellBg.withValues(alpha: 0.22));
        canvas.drawRRect(
            rect,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.25)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.8);
      }
    }

    for (int f = 0; f < _flows.length; f++) {
      final flow = _flows[f];
      final color = _kFlowColors[f];
      double frac;
      if (step == 0) {
        frac = f == 0 ? t : 0.0;
      } else if (step == 1) {
        final perFlow = 1.0 / _flows.length;
        final start = f * perFlow;
        frac = ((t - start) / perFlow).clamp(0.0, 1.0);
      } else {
        frac = 1.0;
      }

      final dotR = _cellS * 0.24;
      final first = center(flow.first[0], flow.first[1]);
      final last = center(flow.last[0], flow.last[1]);
      canvas.drawCircle(first, dotR, Paint()..color = color);
      canvas.drawCircle(last, dotR, Paint()..color = color);

      if (frac > 0 && flow.length > 1) {
        final drawn = (frac * (flow.length - 1)).clamp(0.0, (flow.length - 1).toDouble());
        final fullSegs = drawn.floor();
        final path = Path();
        final start = center(flow[0][0], flow[0][1]);
        path.moveTo(start.dx, start.dy);
        for (int i = 1; i <= fullSegs && i < flow.length; i++) {
          final p = center(flow[i][0], flow[i][1]);
          path.lineTo(p.dx, p.dy);
        }
        if (fullSegs < flow.length - 1) {
          final fr = drawn - fullSegs;
          final a = center(flow[fullSegs][0], flow[fullSegs][1]);
          final b = center(flow[fullSegs + 1][0], flow[fullSegs + 1][1]);
          path.lineTo(a.dx + (b.dx - a.dx) * fr, a.dy + (b.dy - a.dy) * fr);
        }
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = color.withValues(alpha: 0.85),
        );
      }
    }

    if (step == 2) {
      final scale = 0.85 + 0.15 * math.sin(t * math.pi * 2);
      final bc = Offset(ox + totalW - 6, oy - 2);
      canvas.save();
      canvas.translate(bc.dx, bc.dy);
      canvas.scale(scale);
      canvas.drawCircle(Offset.zero, 13, Paint()..color = const Color(0xFF6C63FF));
      final check = Path()
        ..moveTo(-5, 0)
        ..lineTo(-1.5, 4)
        ..lineTo(6, -4);
      canvas.drawPath(
          check,
          Paint()
            ..color = Colors.white
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CCBoardPainter old) => true;
}

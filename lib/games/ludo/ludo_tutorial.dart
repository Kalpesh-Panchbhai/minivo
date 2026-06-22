import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> ludoSteps() => [
      GameHowToPlayStep(
        text: 'Roll a 6 to release a token from your home area onto the board.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _ReleasePainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Roll the die and move your token clockwise by that many spaces.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _MovePainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Land on an opponent to send them home! You get an extra turn.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _CapturePainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Get all 4 tokens to the center finish area to win!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 4),
          painter: (t) => _WinPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
    ];

const _kRed = Color(0xFFE74C3C);
const _kBlue = Color(0xFF2980B9);
const _kGreen = Color(0xFF27AE60);
const _kYellow = Color(0xFFF1C40F);
const _kBoardBg = Color(0xFFF5F0E1);

void _drawToken(Canvas canvas, double cx, double cy, double r, Color color) {
  canvas.drawCircle(Offset(cx, cy + r * 0.12), r, Paint()..color = Colors.black.withValues(alpha: 0.2));
  canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color);
  canvas.drawCircle(
    Offset(cx, cy),
    r * 0.55,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );
}

void _drawDie(Canvas canvas, double cx, double cy, double s, int value) {
  final rect = RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset(cx, cy), width: s, height: s),
    Radius.circular(s * 0.15),
  );
  canvas.drawRRect(rect, Paint()..color = Colors.white);
  canvas.drawRRect(
    rect,
    Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0,
  );
  final dotR = s * 0.08;
  final dotP = Paint()..color = const Color(0xFF2C3E50);
  final positions = _dotPositions(value, cx, cy, s * 0.25);
  for (final p in positions) {
    canvas.drawCircle(p, dotR, dotP);
  }
}

List<Offset> _dotPositions(int value, double cx, double cy, double sp) {
  switch (value) {
    case 1:
      return [Offset(cx, cy)];
    case 2:
      return [Offset(cx - sp, cy - sp), Offset(cx + sp, cy + sp)];
    case 3:
      return [Offset(cx - sp, cy + sp), Offset(cx, cy), Offset(cx + sp, cy - sp)];
    case 4:
      return [Offset(cx - sp, cy - sp), Offset(cx + sp, cy - sp), Offset(cx - sp, cy + sp), Offset(cx + sp, cy + sp)];
    case 5:
      return [Offset(cx - sp, cy - sp), Offset(cx + sp, cy - sp), Offset(cx, cy), Offset(cx - sp, cy + sp), Offset(cx + sp, cy + sp)];
    case 6:
      return [
        Offset(cx - sp, cy - sp), Offset(cx + sp, cy - sp),
        Offset(cx - sp, cy), Offset(cx + sp, cy),
        Offset(cx - sp, cy + sp), Offset(cx + sp, cy + sp),
      ];
    default:
      return [];
  }
}

class _ReleasePainter extends CustomPainter {
  final double t;
  const _ReleasePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(bg, Paint()..color = _kBoardBg);

    final homeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(size.width * 0.25, size.height * 0.5), width: 60, height: 60),
      const Radius.circular(8),
    );
    canvas.drawRRect(homeRect, Paint()..color = _kRed.withValues(alpha: 0.15));
    canvas.drawRRect(
      homeRect,
      Paint()
        ..color = _kRed.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final dieT = (t * 3).clamp(0.0, 1.0);
    final moveT = ((t - 0.4) * 2.5).clamp(0.0, 1.0);
    final dieValue = dieT < 0.8 ? (1 + (dieT * 10).toInt() % 6) : 6;
    _drawDie(canvas, size.width * 0.75, size.height * 0.3, 36, dieValue);

    final startX = size.width * 0.25;
    final endX = size.width * 0.55;
    final eased = Curves.easeInOut.transform(moveT);
    final cx = startX + (endX - startX) * eased;
    _drawToken(canvas, cx, size.height * 0.5, 10, _kRed);
  }

  @override
  bool shouldRepaint(_ReleasePainter old) => old.t != t;
}

class _MovePainter extends CustomPainter {
  final double t;
  const _MovePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(bg, Paint()..color = _kBoardBg);

    final cellW = size.width / 6;
    final cy = size.height * 0.55;
    for (int i = 0; i < 6; i++) {
      final rect = Rect.fromLTWH(i * cellW + 2, cy - cellW / 2, cellW - 4, cellW - 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = i % 2 == 0 ? Colors.grey.shade200 : Colors.grey.shade100,
      );
    }

    final moveT = (t * 2).clamp(0.0, 1.0);
    final eased = Curves.easeInOut.transform(moveT);
    final startCell = 0.5;
    final endCell = 3.5;
    final curCell = startCell + (endCell - startCell) * eased;
    _drawToken(canvas, curCell * cellW + cellW / 2, cy, 10, _kBlue);

    _drawDie(canvas, size.width * 0.75, size.height * 0.18, 32, 3);
  }

  @override
  bool shouldRepaint(_MovePainter old) => old.t != t;
}

class _CapturePainter extends CustomPainter {
  final double t;
  const _CapturePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(bg, Paint()..color = _kBoardBg);

    final moveT = (t * 2).clamp(0.0, 1.0);
    final eased = Curves.easeInOut.transform(moveT);

    final targetX = size.width * 0.6;
    final cy = size.height * 0.55;

    final capturedAlpha = moveT > 0.6 ? 1.0 - ((moveT - 0.6) * 2.5).clamp(0.0, 1.0) : 1.0;
    _drawToken(canvas, targetX, cy, 10, _kGreen.withValues(alpha: capturedAlpha));

    final startX = size.width * 0.2;
    final curX = startX + (targetX - startX) * eased;
    final bounceY = -math.sin(eased * math.pi) * 15;
    _drawToken(canvas, curX, cy + bounceY, 10, _kRed);

    if (moveT > 0.7) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'CAPTURED!',
          style: TextStyle(
            color: _kRed.withValues(alpha: ((moveT - 0.7) * 3.3).clamp(0.0, 1.0)),
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.15));
    }
  }

  @override
  bool shouldRepaint(_CapturePainter old) => old.t != t;
}

class _WinPainter extends CustomPainter {
  final double t;
  const _WinPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(bg, Paint()..color = _kBoardBg);

    final cx = size.width / 2;
    final cy = size.height * 0.45;
    final r = 30.0;

    for (int i = 0; i < 4; i++) {
      final angle = (i / 4) * math.pi * 2 - math.pi / 2;
      final tokenR = r * 0.7;
      final arriveT = ((t * 2) - i * 0.15).clamp(0.0, 1.0);
      final eased = Curves.easeOutBack.transform(arriveT);
      final startDist = r * 2.5;
      final dist = startDist - (startDist - tokenR) * eased;
      final tx = cx + math.cos(angle) * dist;
      final ty = cy + math.sin(angle) * dist;
      _drawToken(canvas, tx, ty, 8, [_kRed, _kGreen, _kYellow, _kBlue][i]);
    }

    if (t > 0.6) {
      final celebT = ((t - 0.6) * 2.5).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: 'YOU WIN!',
          style: TextStyle(
            color: Colors.amber.withValues(alpha: celebT),
            fontWeight: FontWeight.w900,
            fontSize: 18,
            shadows: const [Shadow(color: Colors.black38, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.82));
    }
  }

  @override
  bool shouldRepaint(_WinPainter old) => old.t != t;
}

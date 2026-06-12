import 'dart:math' as math;

import 'package:flutter/material.dart';

Widget buildMinesweeperLogo(double size) {
  return SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      size: Size(size, size),
      painter: _MinesweeperLogoPainter(),
    ),
  );
}

class _MinesweeperLogoPainter extends CustomPainter {
  static const _kBg1 = Color(0xFF1A2744);
  static const _kBg2 = Color(0xFF0F1B33);
  static const _kAccent = Color(0xFF4A7CFF);
  static const _kMine = Color(0xFFEF4444);
  static const _kFlag = Color(0xFFFF9800);
  static const _kRevealed = Color(0xFFE8ECF0);
  static const _kHidden = Color(0xFFCCD5E0);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bgRect = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRect(
      bgRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [_kBg1, _kBg2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bgRect),
    );

    canvas.drawCircle(
      Offset(w * 0.5, h * 0.42),
      w * 0.45,
      Paint()
        ..shader = RadialGradient(
          colors: [_kAccent.withValues(alpha: 0.15), Colors.transparent],
        ).createShader(Rect.fromCircle(center: Offset(w * 0.5, h * 0.42), radius: w * 0.45)),
    );

    final gridSize = w * 0.62;
    final cellSize = gridSize / 4;
    final startX = (w - gridSize) / 2;
    final startY = h * 0.14;

    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        final x = startX + c * cellSize;
        final y = startY + r * cellSize;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 1, y + 1, cellSize - 2, cellSize - 2),
          Radius.circular(cellSize * 0.15),
        );

        final isRevealed = (r + c) % 3 == 0 || (r == 0 && c == 0) || (r == 2 && c == 1);
        final isMineCell = r == 1 && c == 2;
        final isFlagCell = r == 3 && c == 0;

        if (isMineCell) {
          canvas.drawRRect(rect, Paint()..color = _kMine.withValues(alpha: 0.85));
          _drawMineIcon(canvas, x + cellSize / 2, y + cellSize / 2, cellSize * 0.28);
        } else if (isFlagCell) {
          canvas.drawRRect(rect, Paint()..color = _kHidden);
          _drawFlag(canvas, x + cellSize / 2, y + cellSize / 2, cellSize * 0.28);
        } else if (isRevealed) {
          canvas.drawRRect(rect, Paint()..color = _kRevealed);
          final num = ((r * 4 + c) % 3) + 1;
          if (num > 0) {
            final tp = TextPainter(
              text: TextSpan(
                text: '$num',
                style: TextStyle(
                  color: _numberColor(num),
                  fontSize: cellSize * 0.45,
                  fontWeight: FontWeight.w900,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            tp.paint(canvas, Offset(x + cellSize / 2 - tp.width / 2, y + cellSize / 2 - tp.height / 2));
          }
        } else {
          canvas.drawRRect(rect, Paint()..color = _kHidden);
          canvas.drawRRect(
            rect,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.12)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.8,
          );
        }
      }
    }

    final textY = h - h * 0.18;
    final pillH = h * 0.16;
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w / 2, textY), width: w * 0.92, height: pillH),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      pillRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [_kAccent, Color(0xFF2A5CCC)],
        ).createShader(pillRect.outerRect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(pillRect.left, pillRect.top, pillRect.width, pillH * 0.45),
        const Radius.circular(8),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.14),
    );

    final tp = TextPainter(
      text: TextSpan(
        text: 'MINESWEEPER',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: w * 0.095,
          letterSpacing: 0.4,
          shadows: [Shadow(color: Colors.black.withValues(alpha: 0.30), offset: const Offset(0, 1), blurRadius: 2)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, textY - tp.height / 2));
  }

  void _drawMineIcon(Canvas canvas, double cx, double cy, double r) {
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = Colors.white);
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      canvas.drawLine(
        Offset(cx + math.cos(angle) * r * 0.5, cy + math.sin(angle) * r * 0.5),
        Offset(cx + math.cos(angle) * r * 1.3, cy + math.sin(angle) * r * 1.3),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawFlag(Canvas canvas, double cx, double cy, double r) {
    final pole = Paint()
      ..color = _kFlag
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, cy - r), Offset(cx, cy + r * 0.8), pole);
    final flag = Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + r * 0.9, cy - r * 0.45)
      ..lineTo(cx, cy - r * 0.05)
      ..close();
    canvas.drawPath(flag, Paint()..color = _kMine);
  }

  Color _numberColor(int n) {
    const colors = [Color(0xFF2196F3), Color(0xFF4CAF50), Color(0xFFF44336)];
    return colors[(n - 1).clamp(0, colors.length - 1)];
  }

  @override
  bool shouldRepaint(_MinesweeperLogoPainter old) => false;
}

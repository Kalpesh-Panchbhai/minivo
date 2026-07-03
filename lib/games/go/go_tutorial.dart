import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> goSteps() => [
      GameHowToPlayStep(
        text: 'Place stones on intersections. Black goes first, then alternate turns.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _PlacePainter(t),
          canvasSize: const Size(200, 180),
        ),
      ),
      GameHowToPlayStep(
        text: 'Surround opponent stones to capture them. Captured stones are removed.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 4),
          painter: (t) => _CapturePainter(t),
          canvasSize: const Size(200, 180),
        ),
      ),
      GameHowToPlayStep(
        text: 'Pass when you have no good moves. Two passes end the game.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 5),
          painter: (t) => _PassPainter(t),
          canvasSize: const Size(200, 180),
        ),
      ),
      GameHowToPlayStep(
        text: 'The player with the most territory + captures wins!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 5),
          painter: (t) => _ScorePainter(t),
          canvasSize: const Size(200, 180),
        ),
      ),
    ];

const _kBoard = Color(0xFFD4A76A);
const _kLine = Color(0xFF5D4037);

void _drawGrid(Canvas canvas, double left, double top, double cellSize, int lines) {
  final paint = Paint()
    ..color = _kLine.withValues(alpha: 0.4)
    ..strokeWidth = 1.0;
  for (int i = 0; i < lines; i++) {
    final offset = i * cellSize;
    canvas.drawLine(Offset(left, top + offset), Offset(left + (lines - 1) * cellSize, top + offset), paint);
    canvas.drawLine(Offset(left + offset, top), Offset(left + offset, top + (lines - 1) * cellSize), paint);
  }
}

void _drawStone(Canvas canvas, double cx, double cy, double r, bool isBlack, {double alpha = 1.0}) {
  final color = isBlack ? Colors.black.withValues(alpha: alpha) : Colors.white.withValues(alpha: alpha);
  canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color);
  canvas.drawCircle(Offset(cx, cy), r, Paint()..color = _kLine.withValues(alpha: 0.3 * alpha)..style = PaintingStyle.stroke..strokeWidth = 1.0);
}

class _PlacePainter extends CustomPainter {
  final double t;
  const _PlacePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = _kBoard);
    const lines = 5;
    final cellSize = size.width / (lines + 1);
    final left = cellSize;
    final top = (size.height - (lines - 1) * cellSize) / 2;
    _drawGrid(canvas, left, top, cellSize, lines);

    final phase = (t * 2).clamp(0.0, 1.0);
    final r = cellSize * 0.35;

    _drawStone(canvas, left + 1 * cellSize, top + 1 * cellSize, r, true);
    if (phase > 0.3) {
      _drawStone(canvas, left + 2 * cellSize, top + 2 * cellSize, r, false);
    }
    if (phase > 0.6) {
      final scale = Curves.elasticOut.transform(((phase - 0.6) / 0.4).clamp(0.0, 1.0));
      _drawStone(canvas, left + 3 * cellSize, top + 1 * cellSize, r * scale, true);
    }
  }

  @override
  bool shouldRepaint(_PlacePainter old) => old.t != t;
}

class _CapturePainter extends CustomPainter {
  final double t;
  const _CapturePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = _kBoard);
    const lines = 5;
    final cellSize = size.width / (lines + 1);
    final left = cellSize;
    final top = (size.height - (lines - 1) * cellSize) / 2;
    _drawGrid(canvas, left, top, cellSize, lines);
    final r = cellSize * 0.35;

    _drawStone(canvas, left + 1 * cellSize, top + 2 * cellSize, r, true);
    _drawStone(canvas, left + 3 * cellSize, top + 2 * cellSize, r, true);
    _drawStone(canvas, left + 2 * cellSize, top + 1 * cellSize, r, true);

    final captureT = (t * 2).clamp(0.0, 1.0);
    final capturedAlpha = captureT > 0.7 ? 1.0 - ((captureT - 0.7) / 0.3).clamp(0.0, 1.0) : 1.0;
    _drawStone(canvas, left + 2 * cellSize, top + 2 * cellSize, r, false, alpha: capturedAlpha);

    if (captureT > 0.4) {
      final eased = Curves.easeInOut.transform(((captureT - 0.4) / 0.3).clamp(0.0, 1.0));
      _drawStone(canvas, left + 2 * cellSize, top + 3 * cellSize, r * eased, true);
    }
  }

  @override
  bool shouldRepaint(_CapturePainter old) => old.t != t;
}

class _PassPainter extends CustomPainter {
  final double t;
  const _PassPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = _kBoard);
    const lines = 5;
    final cellSize = size.width / (lines + 1);
    final left = cellSize;
    final top = (size.height - (lines - 1) * cellSize) / 2;
    _drawGrid(canvas, left, top, cellSize, lines);
    final r = cellSize * 0.35;

    const stones = <(int, int, bool)>[
      (0, 0, true),  (0, 1, false), (0, 2, true),  (0, 3, false), (0, 4, true),
      (1, 0, false), (1, 1, true),  (1, 2, false), (1, 3, true),  (1, 4, false),
      (2, 0, true),  (2, 1, false),                 (2, 3, true),  (2, 4, false),
      (3, 0, false), (3, 1, true),  (3, 2, false),                 (3, 4, true),
      (4, 0, true),  (4, 1, false), (4, 2, true),  (4, 3, false),
    ];

    final stoneAlpha = t > 0.10 ? 0.55 : 1.0;
    for (final (row, col, isBlack) in stones) {
      _drawStone(canvas, left + col * cellSize, top + row * cellSize, r, isBlack, alpha: stoneAlpha);
    }

    if (t >= 0.10 && t < 0.40) {
      final p = ((t - 0.10) / 0.30).clamp(0.0, 1.0);
      final pulse = 0.6 + 0.4 * math.sin(p * math.pi * 3);
      _drawBanner(canvas, size, 'PASS', pulse, 26);
    } else if (t >= 0.40 && t < 0.65) {
      final p = ((t - 0.40) / 0.25).clamp(0.0, 1.0);
      final pulse = 0.6 + 0.4 * math.sin(p * math.pi * 3);
      _drawBanner(canvas, size, 'PASS \u00d72', pulse, 24);
    } else if (t >= 0.65) {
      final fade = ((t - 0.65) / 0.15).clamp(0.0, 1.0);
      _drawBanner(canvas, size, 'GAME OVER', fade, 22);
    }
  }

  void _drawBanner(Canvas canvas, Size size, String text, double alpha, double fontSize) {
    final bgRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.85,
      height: 36,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(8)),
      Paint()..color = _kBoard.withValues(alpha: 0.88 * alpha),
    );
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: _kLine.withValues(alpha: alpha),
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
  }

  @override
  bool shouldRepaint(_PassPainter old) => old.t != t;
}

class _ScorePainter extends CustomPainter {
  final double t;
  const _ScorePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = _kBoard);
    const lines = 5;
    final cellSize = size.width / (lines + 1);
    final left = cellSize;
    final top = 14.0;
    _drawGrid(canvas, left, top, cellSize, lines);
    final r = cellSize * 0.35;

    const stones = <(int, int, bool)>[
      (0, 0, true),  (0, 1, true),  (0, 2, true),  (0, 3, false), (0, 4, false),
      (1, 0, true),                  (1, 2, true),  (1, 3, false),
      (2, 0, true),  (2, 1, true),  (2, 2, true),  (2, 3, false), (2, 4, false),
      (3, 0, true),                  (3, 2, true),  (3, 3, false),
      (4, 0, true),  (4, 1, true),  (4, 2, true),  (4, 3, false), (4, 4, false),
    ];

    for (final (row, col, isBlack) in stones) {
      _drawStone(canvas, left + col * cellSize, top + row * cellSize, r, isBlack);
    }

    if (t > 0.25) {
      final tA = ((t - 0.25) / 0.20).clamp(0.0, 1.0);
      final markerS = cellSize * 0.30;
      for (final (row, col) in [(1, 1), (3, 1)]) {
        canvas.drawRect(
          Rect.fromCenter(center: Offset(left + col * cellSize, top + row * cellSize), width: markerS, height: markerS),
          Paint()..color = Colors.black.withValues(alpha: 0.4 * tA),
        );
      }
      for (final (row, col) in [(1, 4), (3, 4)]) {
        canvas.drawRect(
          Rect.fromCenter(center: Offset(left + col * cellSize, top + row * cellSize), width: markerS, height: markerS),
          Paint()..color = Colors.white.withValues(alpha: 0.55 * tA),
        );
        canvas.drawRect(
          Rect.fromCenter(center: Offset(left + col * cellSize, top + row * cellSize), width: markerS, height: markerS),
          Paint()..color = Colors.grey.withValues(alpha: 0.3 * tA)..style = PaintingStyle.stroke..strokeWidth = 1,
        );
      }
    }

    if (t > 0.50) {
      final sT = ((t - 0.50) / 0.20).clamp(0.0, 1.0);
      const barH = 24.0;
      final barY = size.height - barH - 4;
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(10, barY, size.width - 20, barH),
        const Radius.circular(6),
      );
      canvas.drawRRect(barRect, Paint()..color = _kBoard.withValues(alpha: 0.95 * sT));
      canvas.drawRRect(barRect, Paint()..color = _kLine.withValues(alpha: 0.12 * sT)..style = PaintingStyle.stroke..strokeWidth = 1);

      final showWinner = t > 0.75;
      if (showWinner) {
        final gT = ((t - 0.75) / 0.10).clamp(0.0, 1.0);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(12, barY + 2, (size.width - 24) * 0.45, barH - 4),
            const Radius.circular(4),
          ),
          Paint()..color = Colors.green.withValues(alpha: 0.22 * gT),
        );
      }

      _drawStone(canvas, 24, barY + barH / 2, 6, true, alpha: sT);
      final bTp = TextPainter(
        text: TextSpan(
          text: ' 15',
          style: TextStyle(color: Colors.black.withValues(alpha: sT), fontWeight: FontWeight.w800, fontSize: 13),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      bTp.paint(canvas, Offset(32, barY + (barH - bTp.height) / 2));

      if (showWinner) {
        final gT = ((t - 0.75) / 0.10).clamp(0.0, 1.0);
        final cTp = TextPainter(
          text: TextSpan(
            text: ' \u2713',
            style: TextStyle(color: Colors.green.withValues(alpha: gT), fontWeight: FontWeight.w900, fontSize: 14),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        cTp.paint(canvas, Offset(32 + bTp.width, barY + (barH - cTp.height) / 2));
      }

      _drawStone(canvas, size.width - 24, barY + barH / 2, 6, false, alpha: sT);
      final wTp = TextPainter(
        text: TextSpan(
          text: '10 ',
          style: TextStyle(color: _kLine.withValues(alpha: sT), fontWeight: FontWeight.w800, fontSize: 13),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      wTp.paint(canvas, Offset(size.width - 32 - wTp.width, barY + (barH - wTp.height) / 2));
    }
  }

  @override
  bool shouldRepaint(_ScorePainter old) => old.t != t;
}

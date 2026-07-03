import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_logo_living.dart';

Widget buildDinoRunLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Dino Run',
      bg: const [Color(0xFF374151), Color(0xFF111827)],
      accent: const Color(0xFF9CA3AF),
      period: const Duration(milliseconds: 3000),
      artBuilder: (t) => _DinoRunArtPainter(t),
    );

class _DinoRunArtPainter extends CustomPainter {
  final double t;
  const _DinoRunArtPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final artSize = w * 0.52;
    final zone = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.40),
      width: artSize,
      height: artSize,
    );
    final zoneRR = RRect.fromRectAndRadius(zone, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(zoneRR);

    canvas.drawRRect(zoneRR, Paint()..color = const Color(0xFF1A1A2E).withValues(alpha: 0.40));

    final groundY = zone.bottom - artSize * 0.15;
    canvas.drawLine(
      Offset(zone.left, groundY),
      Offset(zone.right, groundY),
      Paint()
        ..color = const Color(0xFF535353).withValues(alpha: 0.35)
        ..strokeWidth = 1.0,
    );

    for (int i = 0; i < 6; i++) {
      final dx = ((zone.left + artSize * 0.1 * i - t * artSize * 0.5) % (artSize * 0.6)) + zone.left;
      canvas.drawCircle(
        Offset(dx, groundY + 1.5),
        0.8,
        Paint()..color = const Color(0xFF535353).withValues(alpha: 0.15),
      );
    }

    final dinoX = zone.left + artSize * 0.30;
    double dinoBaseY = groundY;

    double jumpOffset = 0;
    if (t >= 0.15 && t < 0.55) {
      final p = ((t - 0.15) / 0.40).clamp(0.0, 1.0);
      jumpOffset = -math.sin(p * math.pi) * artSize * 0.45;
    }
    dinoBaseY += jumpOffset;

    final ds = artSize * 0.14;
    final bodyRect = Rect.fromLTWH(dinoX - ds * 0.5, dinoBaseY - ds * 1.8, ds * 1.0, ds * 1.2);
    canvas.drawRect(bodyRect, Paint()..color = const Color(0xFF535353).withValues(alpha: 0.85));

    final headRect = Rect.fromLTWH(dinoX, dinoBaseY - ds * 2.4, ds * 0.9, ds * 0.7);
    canvas.drawRect(headRect, Paint()..color = const Color(0xFF535353).withValues(alpha: 0.85));

    canvas.drawRect(
      Rect.fromLTWH(dinoX + ds * 0.55, dinoBaseY - ds * 2.3, ds * 0.15, ds * 0.15),
      Paint()..color = const Color(0xFF1F2937),
    );

    canvas.drawRect(
      Rect.fromLTWH(dinoX + ds * 0.2, dinoBaseY - ds * 1.4, ds * 0.35, ds * 0.2),
      Paint()..color = const Color(0xFF535353).withValues(alpha: 0.85),
    );

    final tailPath = Path()
      ..moveTo(dinoX - ds * 0.5, dinoBaseY - ds * 1.6)
      ..lineTo(dinoX - ds * 1.1, dinoBaseY - ds * 2.0)
      ..lineTo(dinoX - ds * 0.5, dinoBaseY - ds * 1.3);
    canvas.drawPath(tailPath, Paint()..color = const Color(0xFF535353).withValues(alpha: 0.85));

    final legPhase = t < 0.15 ? (t / 0.15) * 4 : (t > 0.55 ? ((t - 0.55) / 0.45) * 6 : 0.0);
    final legSwing = math.sin(legPhase * math.pi * 2) * ds * 0.2;
    final legPaint = Paint()
      ..color = const Color(0xFF535353).withValues(alpha: 0.85)
      ..strokeWidth = ds * 0.18
      ..strokeCap = StrokeCap.round;

    if (jumpOffset < -1) {
      canvas.drawLine(
        Offset(dinoX - ds * 0.15, dinoBaseY - ds * 0.6),
        Offset(dinoX - ds * 0.25, dinoBaseY - ds * 0.1),
        legPaint,
      );
      canvas.drawLine(
        Offset(dinoX + ds * 0.15, dinoBaseY - ds * 0.6),
        Offset(dinoX + ds * 0.25, dinoBaseY - ds * 0.1),
        legPaint,
      );
    } else {
      canvas.drawLine(
        Offset(dinoX - ds * 0.15, dinoBaseY - ds * 0.6),
        Offset(dinoX - ds * 0.15 + legSwing, dinoBaseY),
        legPaint,
      );
      canvas.drawLine(
        Offset(dinoX + ds * 0.15, dinoBaseY - ds * 0.6),
        Offset(dinoX + ds * 0.15 - legSwing, dinoBaseY),
        legPaint,
      );
    }

    double cactusX;
    cactusX = zone.right + artSize * 0.10 - t * artSize * 2.30;

    final cs = artSize * 0.08;
    if (cactusX > zone.left && cactusX < zone.right) {
      canvas.drawRect(
        Rect.fromLTWH(cactusX - cs * 0.2, groundY - cs * 2.0, cs * 0.4, cs * 2.0),
        Paint()..color = const Color(0xFF535353).withValues(alpha: 0.70),
      );
      canvas.drawRect(
        Rect.fromLTWH(cactusX + cs * 0.2, groundY - cs * 1.5, cs * 0.5, cs * 0.3),
        Paint()..color = const Color(0xFF535353).withValues(alpha: 0.70),
      );
      canvas.drawRect(
        Rect.fromLTWH(cactusX + cs * 0.5, groundY - cs * 1.8, cs * 0.3, cs * 0.6),
        Paint()..color = const Color(0xFF535353).withValues(alpha: 0.70),
      );
      canvas.drawRect(
        Rect.fromLTWH(cactusX - cs * 0.7, groundY - cs * 1.2, cs * 0.5, cs * 0.3),
        Paint()..color = const Color(0xFF535353).withValues(alpha: 0.70),
      );
      canvas.drawRect(
        Rect.fromLTWH(cactusX - cs * 0.7, groundY - cs * 1.6, cs * 0.3, cs * 0.7),
        Paint()..color = const Color(0xFF535353).withValues(alpha: 0.70),
      );
    }

    canvas.restore();
    canvas.drawRRect(
      zoneRR,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_DinoRunArtPainter old) => old.t != t;
}

Widget buildTicTacToeLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Tic Tac Toe',
      bg: const [Color(0xFF581C87), Color(0xFF3B0764)],
      accent: const Color(0xFFD946EF),
      period: const Duration(milliseconds: 3500),
      artBuilder: (t) => _TicTacToeArtPainter(t),
    );

class _TicTacToeArtPainter extends CustomPainter {
  final double t;
  const _TicTacToeArtPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final artSize = w * 0.52;
    final zone = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.40),
      width: artSize,
      height: artSize,
    );
    final zoneRR = RRect.fromRectAndRadius(zone, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(zoneRR);

    canvas.drawRRect(zoneRR, Paint()..color = const Color(0xFF3B0764).withValues(alpha: 0.30));

    final cellSize = artSize / 3;
    final linePaint = Paint()
      ..color = const Color(0xFF8475C2).withValues(alpha: 0.55)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (int i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(zone.left + cellSize * i, zone.top + cellSize * 0.1),
        Offset(zone.left + cellSize * i, zone.bottom - cellSize * 0.1),
        linePaint,
      );
      canvas.drawLine(
        Offset(zone.left + cellSize * 0.1, zone.top + cellSize * i),
        Offset(zone.right - cellSize * 0.1, zone.top + cellSize * i),
        linePaint,
      );
    }

    final marks = <List<dynamic>>[
      [1, 0, 'X', 0.0, 0.15],
      [0, 0, 'O', 0.15, 0.30],
      [1, 1, 'X', 0.30, 0.45],
      [0, 2, 'O', 0.45, 0.60],
      [1, 2, 'X', 0.60, 0.75],
    ];

    for (final m in marks) {
      final col = m[0] as int;
      final row = m[1] as int;
      final type = m[2] as String;
      final tStart = m[3] as double;
      final tEnd = m[4] as double;

      if (t < tStart) continue;
      final p = ((t - tStart) / (tEnd - tStart)).clamp(0.0, 1.0);
      final scale = Curves.elasticOut.transform(p.clamp(0.0, 1.0));
      final cx = zone.left + (col + 0.5) * cellSize;
      final cy = zone.top + (row + 0.5) * cellSize;
      final ms = cellSize * 0.28 * scale;

      if (type == 'X') {
        final xPaint = Paint()
          ..color = const Color(0xFFE85D75).withValues(alpha: 0.85)
          ..strokeWidth = cellSize * 0.08
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(cx - ms, cy - ms), Offset(cx + ms, cy + ms), xPaint);
        canvas.drawLine(Offset(cx + ms, cy - ms), Offset(cx - ms, cy + ms), xPaint);
      } else {
        canvas.drawCircle(
          Offset(cx, cy),
          ms,
          Paint()
            ..color = const Color(0xFF5BC0DE).withValues(alpha: 0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = cellSize * 0.08,
        );
      }
    }

    if (t >= 0.78) {
      final lp = ((t - 0.78) / 0.12).clamp(0.0, 1.0);
      final x1 = zone.left + 1.5 * cellSize;
      final y1 = zone.top + 0.5 * cellSize;
      final x2 = zone.left + 1.5 * cellSize;
      final y2 = zone.top + 2.5 * cellSize;
      final ex = x1 + (x2 - x1) * lp;
      final ey = y1 + (y2 - y1) * lp;
      canvas.drawLine(
        Offset(x1, y1),
        Offset(ex, ey),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.90)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        Offset(x1, y1),
        Offset(ex, ey),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    canvas.restore();
    canvas.drawRRect(
      zoneRR,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_TicTacToeArtPainter old) => old.t != t;
}

Widget buildCheckersLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Checkers',
      bg: const [Color(0xFF44271A), Color(0xFF2A1810)],
      accent: const Color(0xFFCD7F32),
      period: const Duration(milliseconds: 3500),
      artBuilder: (t) => _CheckersArtPainter(t),
    );

class _CheckersArtPainter extends CustomPainter {
  final double t;
  const _CheckersArtPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final artSize = w * 0.52;
    final zone = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.40),
      width: artSize,
      height: artSize,
    );
    final zoneRR = RRect.fromRectAndRadius(zone, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(zoneRR);

    final cellSize = artSize / 4;
    final lightPaint = Paint()..color = const Color(0xFFF5DEB3).withValues(alpha: 0.55);
    final darkPaint = Paint()..color = const Color(0xFF5D4037).withValues(alpha: 0.65);

    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        canvas.drawRect(
          Rect.fromLTWH(zone.left + c * cellSize, zone.top + r * cellSize, cellSize, cellSize),
          (r + c) % 2 == 0 ? lightPaint : darkPaint,
        );
      }
    }

    const redStartCol = 1, redStartRow = 2;
    const blackCol = 2, blackRow = 1;
    const redEndCol = 3, redEndRow = 0;

    double redC = redStartCol.toDouble(), redR = redStartRow.toDouble();
    double redJump = 0;
    double blackAlpha = 1.0;

    if (t < 0.3) {
      redC = redStartCol.toDouble();
      redR = redStartRow.toDouble();
    } else if (t < 0.6) {
      final p = Curves.easeInOut.transform(((t - 0.3) / 0.3).clamp(0.0, 1.0));
      redC = redStartCol + (redEndCol - redStartCol) * p;
      redR = redStartRow + (redEndRow - redStartRow) * p;
      redJump = -math.sin(p * math.pi) * cellSize * 0.8;
      blackAlpha = (1.0 - ((t - 0.3) / 0.3).clamp(0.0, 1.0) * 1.5).clamp(0.0, 1.0);
    } else if (t < 0.8) {
      redC = redEndCol.toDouble();
      redR = redEndRow.toDouble();
      final bp = ((t - 0.6) / 0.2).clamp(0.0, 1.0);
      redJump = math.sin(bp * math.pi) * cellSize * 0.08 * (1 - bp);
      blackAlpha = 0.0;
    } else {
      redC = redEndCol.toDouble();
      redR = redEndRow.toDouble();
      blackAlpha = 0.0;
    }

    if (blackAlpha > 0.01) {
      _drawPiece(canvas, zone, cellSize, blackCol.toDouble(), blackRow.toDouble(),
          const Color(0xFF333333), const Color(0xFF525252), blackAlpha);
    }

    _drawPiece(canvas, zone, cellSize, redC, redR, const Color(0xFFC62828), const Color(0xFFE53935), 1.0,
        jumpOffset: redJump);

    canvas.restore();
    canvas.drawRRect(
      zoneRR,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  void _drawPiece(Canvas canvas, Rect zone, double cellSize, double col, double row,
      Color darkC, Color lightC, double alpha, {double jumpOffset = 0}) {
    final cx = zone.left + (col + 0.5) * cellSize;
    final cy = zone.top + (row + 0.5) * cellSize + jumpOffset;
    final r = cellSize * 0.35;

    if (jumpOffset < -1) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, zone.top + (row + 0.5) * cellSize + cellSize * 0.1),
          width: r * 1.6,
          height: r * 0.4,
        ),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.2 * alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: [lightC.withValues(alpha: alpha), darkC.withValues(alpha: alpha)],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.65,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.15 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(_CheckersArtPainter old) => old.t != t;
}

Widget buildMemoryMatchLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Memory Match',
      bg: const [Color(0xFF1E3A5F), Color(0xFF0C1F3A)],
      accent: const Color(0xFF60A5FA),
      period: const Duration(milliseconds: 4000),
      artBuilder: (t) => _MemoryMatchArtPainter(t),
    );

class _MemoryMatchArtPainter extends CustomPainter {
  final double t;
  const _MemoryMatchArtPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final artSize = w * 0.52;
    final zone = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.40),
      width: artSize,
      height: artSize,
    );
    final zoneRR = RRect.fromRectAndRadius(zone, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(zoneRR);

    canvas.drawRRect(zoneRR, Paint()..color = const Color(0xFF0C1F3A).withValues(alpha: 0.30));

    final gap = artSize * 0.06;
    final cardW = (artSize - gap * 3) / 2;
    final cardH = cardW;
    final symbols = ['\u2605', '\u2665', '\u2666', '\u2605'];
    final cardFlipTimes = <List<double>>[
      [0.0, 0.2],
      [0.2, 0.4],
      [0.5, 0.7],
      [0.7, 0.9],
    ];
    final flipBackStart = 0.4;
    final flipBackEnd = 0.5;

    for (int i = 0; i < 4; i++) {
      final col = i % 2;
      final row = i ~/ 2;
      final cx = zone.left + gap + col * (cardW + gap) + cardW / 2;
      final cy = zone.top + gap + row * (cardH + gap) + cardH / 2;

      double scaleX = 1.0;
      bool showFront = false;

      if (i == 0) {
        if (t >= cardFlipTimes[0][0] && t < cardFlipTimes[0][1]) {
          final p = ((t - cardFlipTimes[0][0]) / (cardFlipTimes[0][1] - cardFlipTimes[0][0])).clamp(0.0, 1.0);
          scaleX = (1 - 2 * p).abs();
          showFront = p > 0.5;
        } else if (t >= cardFlipTimes[0][1] && t < flipBackStart) {
          showFront = true;
        } else if (t >= flipBackStart && t < flipBackEnd) {
          final p = ((t - flipBackStart) / (flipBackEnd - flipBackStart)).clamp(0.0, 1.0);
          scaleX = (1 - 2 * p).abs();
          showFront = p < 0.5;
        } else if (t >= cardFlipTimes[2][0] && t < cardFlipTimes[2][1]) {
          final p = ((t - cardFlipTimes[2][0]) / (cardFlipTimes[2][1] - cardFlipTimes[2][0])).clamp(0.0, 1.0);
          scaleX = (1 - 2 * p).abs();
          showFront = p > 0.5;
        } else if (t >= cardFlipTimes[2][1]) {
          showFront = true;
        }
      } else if (i == 1) {
        if (t >= cardFlipTimes[1][0] && t < cardFlipTimes[1][1]) {
          final p = ((t - cardFlipTimes[1][0]) / (cardFlipTimes[1][1] - cardFlipTimes[1][0])).clamp(0.0, 1.0);
          scaleX = (1 - 2 * p).abs();
          showFront = p > 0.5;
        } else if (t >= cardFlipTimes[1][1] && t < flipBackStart) {
          showFront = true;
        } else if (t >= flipBackStart && t < flipBackEnd) {
          final p = ((t - flipBackStart) / (flipBackEnd - flipBackStart)).clamp(0.0, 1.0);
          scaleX = (1 - 2 * p).abs();
          showFront = p < 0.5;
        }
      } else if (i == 3) {
        if (t >= cardFlipTimes[3][0] && t < cardFlipTimes[3][1]) {
          final p = ((t - cardFlipTimes[3][0]) / (cardFlipTimes[3][1] - cardFlipTimes[3][0])).clamp(0.0, 1.0);
          scaleX = (1 - 2 * p).abs();
          showFront = p > 0.5;
        } else if (t >= cardFlipTimes[3][1]) {
          showFront = true;
        }
      }

      canvas.save();
      canvas.translate(cx, cy);
      canvas.scale(scaleX, 1.0);

      final cardRect = Rect.fromCenter(center: Offset.zero, width: cardW, height: cardH);
      final cardRR = RRect.fromRectAndRadius(cardRect, const Radius.circular(4));

      if (showFront) {
        canvas.drawRRect(cardRR, Paint()..color = const Color(0xFFFAFDFF).withValues(alpha: 0.90));

        bool matched = false;
        if (i == 0 && t >= 0.9) matched = true;
        if (i == 3 && t >= 0.9) matched = true;

        if (matched) {
          final glowAlpha = 0.3 + 0.2 * math.sin((t - 0.9) / 0.1 * math.pi);
          canvas.drawRRect(
            cardRR,
            Paint()
              ..color = const Color(0xFF22C55E).withValues(alpha: glowAlpha)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
        }

        final tp = TextPainter(
          text: TextSpan(
            text: symbols[i],
            style: TextStyle(
              color: i == 0 || i == 3 ? const Color(0xFFFFD700) : const Color(0xFFE53935),
              fontSize: cardW * 0.45,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      } else {
        canvas.drawRRect(cardRR, Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF5C50A5), Color(0xFF4A6CF7), Color(0xFF3B5EE0)],
          ).createShader(cardRect));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: cardW * 0.7, height: cardH * 0.7),
            const Radius.circular(3),
          ),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.10)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );
        final tp = TextPainter(
          text: TextSpan(
            text: '?',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.30),
              fontSize: cardW * 0.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      }

      canvas.restore();
    }

    canvas.restore();
    canvas.drawRRect(
      zoneRR,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_MemoryMatchArtPainter old) => old.t != t;
}

Widget buildMinesweeperLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Minesweeper',
      bg: const [Color(0xFF1E3A5F), Color(0xFF0C1F3A)],
      accent: const Color(0xFF4A7CFF),
      period: const Duration(milliseconds: 3500),
      artBuilder: (t) => _MinesweeperArtPainter(t),
    );

class _MinesweeperArtPainter extends CustomPainter {
  final double t;
  const _MinesweeperArtPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final artSize = w * 0.52;
    final zone = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.40),
      width: artSize,
      height: artSize,
    );
    final zoneRR = RRect.fromRectAndRadius(zone, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(zoneRR);

    final cellSize = artSize / 3;
    final gap = 1.2;

    final revealedCells = <List<int>>[];
    if (t >= 0.0) {
      if (t >= 0.15) revealedCells.add([0, 0]);
      if (t >= 0.40) revealedCells.add([2, 1]);
    }
    final flagCell = t >= 0.60 ? [1, 2] : null;

    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        final cellRect = Rect.fromLTWH(
          zone.left + c * cellSize + gap / 2,
          zone.top + r * cellSize + gap / 2,
          cellSize - gap,
          cellSize - gap,
        );

        bool isRevealed = false;
        for (final rc in revealedCells) {
          if (rc[0] == c && rc[1] == r) {
            isRevealed = true;
            break;
          }
        }

        if (isRevealed) {
          final revealColor = (r + c) % 2 == 0 ? const Color(0xFFE8ECF2) : const Color(0xFFDEE3EB);
          canvas.drawRect(cellRect, Paint()..color = revealColor.withValues(alpha: 0.30));
        } else {
          final hiddenColor = (r + c) % 2 == 0 ? const Color(0xFFA8C4E0) : const Color(0xFF96B4D0);
          canvas.drawRect(cellRect, Paint()..color = hiddenColor.withValues(alpha: 0.55));
          final topLeft = Paint()
            ..color = Colors.white.withValues(alpha: 0.25)
            ..strokeWidth = 1.2;
          canvas.drawLine(cellRect.topLeft, cellRect.topRight, topLeft);
          canvas.drawLine(cellRect.topLeft, cellRect.bottomLeft, topLeft);
          final bottomRight = Paint()
            ..color = Colors.black.withValues(alpha: 0.25)
            ..strokeWidth = 1.2;
          canvas.drawLine(cellRect.bottomLeft, cellRect.bottomRight, bottomRight);
          canvas.drawLine(cellRect.topRight, cellRect.bottomRight, bottomRight);
        }
      }
    }

    if (t >= 0.15) {
      final p1 = ((t - 0.0) / 0.3).clamp(0.0, 1.0);
      final scale1 = Curves.elasticOut.transform(p1);
      final cx1 = zone.left + 0.5 * cellSize;
      final cy1 = zone.top + 0.5 * cellSize;
      final tp1 = TextPainter(
        text: TextSpan(
          text: '1',
          style: TextStyle(
            color: const Color(0xFF2196F3),
            fontSize: cellSize * 0.45 * scale1,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp1.paint(canvas, Offset(cx1 - tp1.width / 2, cy1 - tp1.height / 2));
    }

    if (t >= 0.40) {
      final p2 = ((t - 0.3) / 0.2).clamp(0.0, 1.0);
      final scale2 = Curves.elasticOut.transform(p2);
      final cx2 = zone.left + 2.5 * cellSize;
      final cy2 = zone.top + 1.5 * cellSize;
      final tp2 = TextPainter(
        text: TextSpan(
          text: '2',
          style: TextStyle(
            color: const Color(0xFF4CAF50),
            fontSize: cellSize * 0.45 * scale2,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp2.paint(canvas, Offset(cx2 - tp2.width / 2, cy2 - tp2.height / 2));
    }

    if (flagCell != null) {
      final fc = flagCell[0], fr = flagCell[1];
      final fx = zone.left + (fc + 0.5) * cellSize;
      final fy = zone.top + (fr + 0.5) * cellSize;
      final fs = cellSize * 0.25;

      final pulse = t >= 0.7 ? 1.0 + 0.08 * math.sin((t - 0.7) / 0.3 * math.pi * 4) : 1.0;

      canvas.drawRect(
        Rect.fromLTWH(fx, fy - fs * 0.9, fs * 0.08, fs * 1.8),
        Paint()..color = Colors.white.withValues(alpha: 0.80),
      );

      final flagPath = Path()
        ..moveTo(fx + fs * 0.08, fy - fs * 0.9 * pulse)
        ..lineTo(fx + fs * 0.8 * pulse, fy - fs * 0.4)
        ..lineTo(fx + fs * 0.08, fy + fs * 0.1);
      canvas.drawPath(flagPath, Paint()..color = const Color(0xFFEF4444).withValues(alpha: 0.90));

      canvas.drawRect(
        Rect.fromLTWH(fx - fs * 0.3, fy + fs * 0.9, fs * 0.7, fs * 0.15),
        Paint()..color = Colors.white.withValues(alpha: 0.50),
      );
    }

    canvas.restore();
    canvas.drawRRect(
      zoneRR,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_MinesweeperArtPainter old) => old.t != t;
}

Widget buildConnectFourLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Connect Four',
      bg: const [Color(0xFF1E3A5F), Color(0xFF0C1F3A)],
      accent: const Color(0xFF60A5FA),
      period: const Duration(milliseconds: 3500),
      artBuilder: (t) => _ConnectFourArtPainter(t),
    );

class _ConnectFourArtPainter extends CustomPainter {
  final double t;
  const _ConnectFourArtPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final artSize = w * 0.52;
    final zone = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.40),
      width: artSize,
      height: artSize,
    );
    final zoneRR = RRect.fromRectAndRadius(zone, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(zoneRR);

    final cols = 4, rows = 3;
    final cellSize = artSize / cols;
    final boardTop = zone.top + artSize * 0.12;
    final boardH = artSize * 0.88;
    final boardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(zone.left, boardTop, artSize, boardH),
      const Radius.circular(4),
    );

    canvas.drawRRect(boardRect, Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF4A7FE0), Color(0xFF3366CC), Color(0xFF2952A3)],
      ).createShader(boardRect.outerRect));

    final holePaint = Paint()
      ..color = const Color(0xFF0D2240).withValues(alpha: 0.70)
      ..blendMode = BlendMode.srcOver;
    final holeStroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    final rowH = boardH / rows;
    final holeR = math.min(cellSize, rowH) * 0.34;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final hx = zone.left + (c + 0.5) * cellSize;
        final hy = boardTop + (r + 0.5) * rowH;
        canvas.drawCircle(Offset(hx, hy), holeR, holePaint);
        canvas.drawCircle(Offset(hx, hy), holeR, holeStroke);
      }
    }

    const red = Color(0xFFE85D75);
    const yellow = Color(0xFFF5C542);

    void drawDisc(double hx, double hy, Color color, {double alpha = 1.0}) {
      canvas.drawCircle(
        Offset(hx, hy),
        holeR * 0.85,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.3),
            colors: [
              Color.lerp(color, Colors.white, 0.3)!.withValues(alpha: alpha),
              color.withValues(alpha: alpha),
            ],
          ).createShader(Rect.fromCircle(center: Offset(hx, hy), radius: holeR * 0.85)),
      );
      canvas.drawCircle(
        Offset(hx, hy),
        holeR * 0.85,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.15 * alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }

    // Pre-placed: 3 red in bottom row (cols 0-2), 2 yellow above (cols 0-1)
    drawDisc(zone.left + 0.5 * cellSize, boardTop + 2.5 * rowH, red);
    drawDisc(zone.left + 1.5 * cellSize, boardTop + 2.5 * rowH, red);
    drawDisc(zone.left + 2.5 * cellSize, boardTop + 2.5 * rowH, red);
    drawDisc(zone.left + 0.5 * cellSize, boardTop + 1.5 * rowH, yellow);
    drawDisc(zone.left + 1.5 * cellSize, boardTop + 1.5 * rowH, yellow);
    drawDisc(zone.left + 2.5 * cellSize, boardTop + 1.5 * rowH, yellow);

    // Animated: 4th red drops into col 3 to complete connect-four
    final hx = zone.left + 3.5 * cellSize;
    final targetY = boardTop + 2.5 * rowH;
    if (t < 0.45) {
      final p = (t / 0.45).clamp(0.0, 1.0);
      final gravity = Curves.bounceOut.transform(p);
      final discY = zone.top + (targetY - zone.top) * gravity;
      drawDisc(hx, discY, red);
    } else {
      drawDisc(hx, targetY, red);
      // Winning line across the 4 red discs in bottom row
      final lineP = ((t - 0.50) / 0.20).clamp(0.0, 1.0);
      if (lineP > 0) {
        final lx1 = zone.left + 0.5 * cellSize;
        final lx2 = zone.left + 3.5 * cellSize;
        final ly = boardTop + 2.5 * rowH;
        final endX = lx1 + (lx2 - lx1) * lineP;
        canvas.drawLine(
          Offset(lx1, ly), Offset(endX, ly),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.35 * lineP)
            ..strokeWidth = holeR * 1.6
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
        canvas.drawLine(
          Offset(lx1, ly), Offset(endX, ly),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.90 * lineP)
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    canvas.restore();
    canvas.drawRRect(
      zoneRR,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_ConnectFourArtPainter old) => old.t != t;
}

Widget buildDropMergeLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Drop Merge',
      bg: const [Color(0xFF7C2D12), Color(0xFF431407)],
      accent: const Color(0xFFFB923C),
      period: const Duration(milliseconds: 3500),
      artBuilder: (t) => _DropMergeArtPainter(t),
    );

class _DropMergeArtPainter extends CustomPainter {
  final double t;
  const _DropMergeArtPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final artSize = w * 0.52;
    final zone = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.40),
      width: artSize,
      height: artSize,
    );
    final zoneRR = RRect.fromRectAndRadius(zone, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(zoneRR);

    canvas.drawRRect(zoneRR, Paint()..color = const Color(0xFF431407).withValues(alpha: 0.30));

    final cols = 3;
    final colW = artSize / cols;
    final tileH = colW * 0.85;

    for (int c = 0; c < cols; c++) {
      canvas.drawLine(
        Offset(zone.left + (c + 1) * colW, zone.top),
        Offset(zone.left + (c + 1) * colW, zone.bottom),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.08)
          ..strokeWidth = 0.5,
      );
    }

    void drawTile(double cx, double cy, String label, double scale, Color color) {
      final tw = colW * 0.80 * scale;
      final th = tileH * 0.80 * scale;
      final tr = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: tw, height: th),
        const Radius.circular(5),
      );
      canvas.drawRRect(
        tr,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(color, Colors.white, 0.2)!,
              color,
            ],
          ).createShader(tr.outerRect),
      );
      canvas.drawRRect(
        tr,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.95),
            fontSize: th * 0.45,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    }

    final col0x = zone.left + 0.5 * colW;
    final col1x = zone.left + 1.5 * colW;
    final col2x = zone.left + 2.5 * colW;
    final bottomY = zone.bottom - tileH * 0.5;
    final midY = bottomY - tileH;

    drawTile(col2x, bottomY, '4', 1.0, const Color(0xFFFFE066));
    drawTile(col0x, bottomY, '8', 1.0, const Color(0xFFFFA94D));

    if (t < 0.15) {
      drawTile(col1x, bottomY, '2', 1.0, const Color(0xFFFFF3BF));
    } else if (t < 0.45) {
      drawTile(col1x, bottomY, '2', 1.0, const Color(0xFFFFF3BF));
      final p = Curves.bounceOut.transform(((t - 0.15) / 0.30).clamp(0.0, 1.0));
      final dropY = zone.top + tileH * 0.5 + (midY - zone.top - tileH * 0.5) * p;
      drawTile(col1x, dropY, '2', 1.0, const Color(0xFFFFF3BF));
    } else if (t < 0.60) {
      final p = ((t - 0.45) / 0.15).clamp(0.0, 1.0);
      final fallP = Curves.easeIn.transform(p);
      final dropY = midY + (bottomY - midY) * fallP;
      final fadeOld = (1.0 - p * 1.5).clamp(0.0, 1.0);
      if (fadeOld > 0) {
        drawTile(col1x, bottomY, '2', fadeOld, const Color(0xFFFFF3BF));
      }
      drawTile(col1x, dropY, '2', 1.0 - p * 0.5, const Color(0xFFFFF3BF));
      if (p > 0.7) {
        final popP = ((p - 0.7) / 0.3).clamp(0.0, 1.0);
        final scale = 1.0 + 0.22 * math.sin(popP * math.pi);
        drawTile(col1x, bottomY, '4', scale, const Color(0xFFFFE066));
      }
    } else {
      drawTile(col1x, bottomY, '4', 1.0, const Color(0xFFFFE066));
      if (t < 0.75) {
        final glow = math.sin((t - 0.60) / 0.15 * math.pi) * 0.20;
        if (glow > 0) {
          final glowRect = Rect.fromCenter(
            center: Offset(col1x, bottomY),
            width: colW * 0.85,
            height: tileH * 0.85,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(glowRect, const Radius.circular(5)),
            Paint()
              ..color = const Color(0xFFFFE066).withValues(alpha: glow)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
          );
        }
      }
    }

    canvas.restore();
    canvas.drawRRect(
      zoneRR,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_DropMergeArtPainter old) => old.t != t;
}

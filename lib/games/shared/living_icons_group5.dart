import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_logo_living.dart';

Widget buildMancalaLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Mancala',
      bg: const [Color(0xFF44271A), Color(0xFF2A1810)],
      accent: const Color(0xFFCD7F32),
      period: const Duration(milliseconds: 3500),
      artBuilder: (t) => _MancalaArtPainter(t),
    );

class _MancalaArtPainter extends CustomPainter {
  final double t;
  const _MancalaArtPainter(this.t);

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

    final boardW = artSize * 0.92;
    final boardH = artSize * 0.48;
    final boardRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: zone.center, width: boardW, height: boardH),
      Radius.circular(boardH * 0.5),
    );
    canvas.drawRRect(boardRect, Paint()..color = const Color(0xFF7B5B3A).withValues(alpha: 0.65));
    canvas.drawRRect(
      boardRect,
      Paint()
        ..color = const Color(0xFF5C3316).withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final cx = zone.center.dx;
    final cy = zone.center.dy;
    final pitR = artSize * 0.055;
    final storeW = artSize * 0.08;
    final storeH = boardH * 0.65;

    final leftStore = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx - boardW * 0.40, cy), width: storeW, height: storeH),
      Radius.circular(storeW * 0.5),
    );
    final rightStore = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx + boardW * 0.40, cy), width: storeW, height: storeH),
      Radius.circular(storeW * 0.5),
    );
    final storePaint = Paint()..color = const Color(0xFF4A2A10).withValues(alpha: 0.70);
    canvas.drawRRect(leftStore, storePaint);
    canvas.drawRRect(rightStore, storePaint);

    final pitSpacing = boardW * 0.20;
    final pitStartX = cx - pitSpacing;
    final topRowY = cy - boardH * 0.20;
    final botRowY = cy + boardH * 0.20;

    final pitCenters = <Offset>[];
    for (int i = 0; i < 3; i++) {
      pitCenters.add(Offset(pitStartX + i * pitSpacing, topRowY));
    }
    for (int i = 2; i >= 0; i--) {
      pitCenters.add(Offset(pitStartX + i * pitSpacing, botRowY));
    }

    final pitPaint = Paint()..color = const Color(0xFF5C3D24).withValues(alpha: 0.60);
    for (final pc in pitCenters) {
      canvas.drawCircle(pc, pitR, pitPaint);
    }

    final seedR = artSize * 0.016;
    final seedColor = const Color(0xFFD4A76A);

    final baseCounts = [3, 2, 4, 3, 2, 3];
    final seedOffsets = <List<Offset>>[];
    final rng = math.Random(42);
    for (int p = 0; p < 6; p++) {
      final offsets = <Offset>[];
      for (int s = 0; s < baseCounts[p]; s++) {
        final angle = s * (2 * math.pi / baseCounts[p]) + 0.3;
        final dist = pitR * 0.45;
        offsets.add(Offset(
          math.cos(angle) * dist + (rng.nextDouble() - 0.5) * pitR * 0.2,
          math.sin(angle) * dist + (rng.nextDouble() - 0.5) * pitR * 0.2,
        ));
      }
      seedOffsets.add(offsets);
    }

    const liftPit = 0;
    final liftCount = baseCounts[liftPit];
    final distributeTargets = [1, 2, 3];

    for (int p = 0; p < 6; p++) {
      final pc = pitCenters[p];
      if (p == liftPit) {
        if (t < 0.30) {
          final lift = Curves.easeOutCubic.transform(t / 0.30);
          for (int s = 0; s < liftCount; s++) {
            final so = seedOffsets[p][s];
            final sy = pc.dy + so.dy - lift * pitR * 1.8;
            canvas.drawCircle(Offset(pc.dx + so.dx, sy), seedR, Paint()..color = seedColor);
          }
        }
      } else if (distributeTargets.contains(p)) {
        for (final so in seedOffsets[p]) {
          canvas.drawCircle(Offset(pc.dx + so.dx, pc.dy + so.dy), seedR, Paint()..color = seedColor);
        }

        final targetIdx = distributeTargets.indexOf(p);
        final dropStart = 0.30 + targetIdx * (0.40 / distributeTargets.length);
        final dropEnd = dropStart + (0.40 / distributeTargets.length);
        if (t >= dropStart && t < 0.70) {
          final dp = ((t - dropStart) / (dropEnd - dropStart)).clamp(0.0, 1.0);
          final dropProgress = Curves.bounceOut.transform(dp);
          final startY = pitCenters[liftPit].dy - pitR * 1.8;
          final endY = pc.dy;
          final sy = startY + (endY - startY) * dropProgress;
          canvas.drawCircle(Offset(pc.dx, sy), seedR * 1.2, Paint()..color = seedColor);
        } else if (t >= 0.70) {
          canvas.drawCircle(Offset(pc.dx, pc.dy), seedR * 1.2, Paint()..color = seedColor);
        }
      } else {
        for (final so in seedOffsets[p]) {
          canvas.drawCircle(Offset(pc.dx + so.dx, pc.dy + so.dy), seedR, Paint()..color = seedColor);
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
  bool shouldRepaint(_MancalaArtPainter old) => old.t != t;
}

Widget buildReversiLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Reversi',
      bg: const [Color(0xFF14532D), Color(0xFF052E16)],
      accent: const Color(0xFF4ADE80),
      period: const Duration(milliseconds: 3500),
      artBuilder: (t) => _ReversiArtPainter(t),
    );

class _ReversiArtPainter extends CustomPainter {
  final double t;
  const _ReversiArtPainter(this.t);

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

    canvas.drawRRect(zoneRR, Paint()..color = const Color(0xFF2E7D32).withValues(alpha: 0.50));

    final cell = artSize / 4;
    final gridPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final gridPaint2 = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (int i = 0; i <= 4; i++) {
      canvas.drawLine(
        Offset(zone.left + i * cell, zone.top),
        Offset(zone.left + i * cell, zone.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(zone.left, zone.top + i * cell),
        Offset(zone.right, zone.top + i * cell),
        gridPaint,
      );
      canvas.drawLine(
        Offset(zone.left + i * cell, zone.top),
        Offset(zone.left + i * cell, zone.bottom),
        gridPaint2,
      );
      canvas.drawLine(
        Offset(zone.left, zone.top + i * cell),
        Offset(zone.right, zone.top + i * cell),
        gridPaint2,
      );
    }

    final discR = cell * 0.36;
    final blackPaint = Paint()..color = const Color(0xFF1A1A1A);
    final whitePaint = Paint()..color = const Color(0xFFFFFFFF);
    final blackBorder = Paint()
      ..color = const Color(0xFF333333)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    final whiteBorder = Paint()
      ..color = const Color(0xFFBBBBBB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    final staticBlack = [
      [1, 1],
      [2, 2],
    ];
    final staticWhite = [
      [2, 1],
      [1, 2],
    ];

    for (final pos in staticBlack) {
      final dx = zone.left + (pos[0] + 0.5) * cell;
      final dy = zone.top + (pos[1] + 0.5) * cell;
      canvas.drawCircle(Offset(dx, dy), discR, blackPaint);
      canvas.drawCircle(Offset(dx, dy), discR, blackBorder);
    }

    final flipDiscs = [
      [2, 1],
      [1, 2],
    ];

    const newDiscPos = [0, 0];
    final existingBlackAnchor = [2, 2];

    if (t < 0.30) {
      for (final pos in staticWhite) {
        final dx = zone.left + (pos[0] + 0.5) * cell;
        final dy = zone.top + (pos[1] + 0.5) * cell;
        canvas.drawCircle(Offset(dx, dy), discR, whitePaint);
        canvas.drawCircle(Offset(dx, dy), discR, whiteBorder);
      }

      final placeP = Curves.easeOutBack.transform(t / 0.30);
      final nx = zone.left + (newDiscPos[0] + 0.5) * cell;
      final ny = zone.top + (newDiscPos[1] + 0.5) * cell;
      canvas.drawCircle(Offset(nx, ny), discR * placeP, blackPaint);
      canvas.drawCircle(Offset(nx, ny), discR * placeP, blackBorder);
    } else if (t < 0.60) {
      final nx = zone.left + (newDiscPos[0] + 0.5) * cell;
      final ny = zone.top + (newDiscPos[1] + 0.5) * cell;
      canvas.drawCircle(Offset(nx, ny), discR, blackPaint);
      canvas.drawCircle(Offset(nx, ny), discR, blackBorder);

      for (int fi = 0; fi < flipDiscs.length; fi++) {
        final flipStart = 0.30 + fi * 0.15;
        final flipEnd = flipStart + 0.15;
        final pos = flipDiscs[fi];
        final dx = zone.left + (pos[0] + 0.5) * cell;
        final dy = zone.top + (pos[1] + 0.5) * cell;

        if (t < flipStart) {
          canvas.drawCircle(Offset(dx, dy), discR, whitePaint);
          canvas.drawCircle(Offset(dx, dy), discR, whiteBorder);
        } else if (t < flipEnd) {
          final fp = ((t - flipStart) / (flipEnd - flipStart)).clamp(0.0, 1.0);
          final scaleX = (math.cos(fp * math.pi)).abs();
          final isBlack = fp > 0.5;

          canvas.save();
          canvas.translate(dx, dy);
          canvas.scale(scaleX.clamp(0.05, 1.0), 1.0);
          canvas.drawCircle(Offset.zero, discR, isBlack ? blackPaint : whitePaint);
          canvas.drawCircle(Offset.zero, discR, isBlack ? blackBorder : whiteBorder);
          canvas.restore();

          if (fp > 0.45 && fp < 0.55) {
            canvas.drawCircle(
              Offset(dx, dy),
              discR * 1.4,
              Paint()
                ..color = Colors.white.withValues(alpha: 0.25 * (1 - (fp - 0.45) * 10))
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5,
            );
          }
        } else {
          canvas.drawCircle(Offset(dx, dy), discR, blackPaint);
          canvas.drawCircle(Offset(dx, dy), discR, blackBorder);
        }
      }

      for (final pos in staticWhite) {
        bool isFlip = false;
        for (final fp in flipDiscs) {
          if (fp[0] == pos[0] && fp[1] == pos[1]) {
            isFlip = true;
            break;
          }
        }
        if (isFlip) continue;
        final dx = zone.left + (pos[0] + 0.5) * cell;
        final dy = zone.top + (pos[1] + 0.5) * cell;
        canvas.drawCircle(Offset(dx, dy), discR, whitePaint);
        canvas.drawCircle(Offset(dx, dy), discR, whiteBorder);
      }

      _ensureAnchor(canvas, zone, cell, discR, existingBlackAnchor, blackPaint, blackBorder);
    } else {
      final nx = zone.left + (newDiscPos[0] + 0.5) * cell;
      final ny = zone.top + (newDiscPos[1] + 0.5) * cell;
      canvas.drawCircle(Offset(nx, ny), discR, blackPaint);
      canvas.drawCircle(Offset(nx, ny), discR, blackBorder);

      for (final pos in flipDiscs) {
        final dx = zone.left + (pos[0] + 0.5) * cell;
        final dy = zone.top + (pos[1] + 0.5) * cell;
        canvas.drawCircle(Offset(dx, dy), discR, blackPaint);
        canvas.drawCircle(Offset(dx, dy), discR, blackBorder);
      }

      _ensureAnchor(canvas, zone, cell, discR, existingBlackAnchor, blackPaint, blackBorder);
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

  void _ensureAnchor(Canvas canvas, Rect zone, double cell, double discR,
      List<int> pos, Paint fill, Paint border) {
    final dx = zone.left + (pos[0] + 0.5) * cell;
    final dy = zone.top + (pos[1] + 0.5) * cell;
    canvas.drawCircle(Offset(dx, dy), discR, fill);
    canvas.drawCircle(Offset(dx, dy), discR, border);
  }

  @override
  bool shouldRepaint(_ReversiArtPainter old) => old.t != t;
}

Widget buildGomokuLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Gomoku',
      bg: const [Color(0xFF1E3A5F), Color(0xFF0C1F3A)],
      accent: const Color(0xFF60A5FA),
      period: const Duration(milliseconds: 4000),
      artBuilder: (t) => _GomokuArtPainter(t),
    );

class _GomokuArtPainter extends CustomPainter {
  final double t;
  const _GomokuArtPainter(this.t);

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

    canvas.drawRRect(zoneRR, Paint()..color = const Color(0xFFDCEAF8).withValues(alpha: 0.15));

    final gridN = 5;
    final margin = artSize * 0.10;
    final step = (artSize - margin * 2) / (gridN - 1);
    final linePaint = Paint()
      ..color = const Color(0xFF4A90D9).withValues(alpha: 0.20)
      ..strokeWidth = 0.5;

    for (int i = 0; i < gridN; i++) {
      final x = zone.left + margin + i * step;
      canvas.drawLine(Offset(x, zone.top + margin), Offset(x, zone.bottom - margin), linePaint);
      final y = zone.top + margin + i * step;
      canvas.drawLine(Offset(zone.left + margin, y), Offset(zone.right - margin, y), linePaint);
    }

    final starPaint = Paint()..color = const Color(0xFF4A90D9).withValues(alpha: 0.35);
    final starR = step * 0.06;
    canvas.drawCircle(Offset(zone.left + margin + 2 * step, zone.top + margin + 2 * step), starR, starPaint);

    Offset gridPos(int col, int row) => Offset(
          zone.left + margin + col * step,
          zone.top + margin + row * step,
        );

    final stoneR = step * 0.38;
    final blackPaint = Paint()..color = const Color(0xFF212121);
    final whitePaint = Paint()..color = Colors.white;
    final blackHighlight = Paint()..color = const Color(0xFF444444);
    final whiteHighlight = Paint()..color = Colors.white;
    final whiteStroke = Paint()
      ..color = const Color(0xFFCBD5E1).withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    void drawStone(Offset pos, bool isBlack, double scale) {
      final r = stoneR * scale;
      final fill = isBlack ? blackPaint : whitePaint;
      final highlight = isBlack ? blackHighlight : whiteHighlight;
      canvas.drawCircle(
        pos.translate(0.8, 0.8),
        r,
        Paint()..color = Colors.black.withValues(alpha: 0.25),
      );
      canvas.drawCircle(pos, r, fill);
      if (!isBlack) canvas.drawCircle(pos, r, whiteStroke);
      canvas.drawCircle(
        pos.translate(-r * 0.25, -r * 0.25),
        r * 0.18,
        highlight,
      );
    }

    final preBlack = [
      [1, 1],
      [2, 2],
    ];
    final preWhite = [
      [0, 1],
      [1, 3],
    ];
    for (final s in preBlack) {
      drawStone(gridPos(s[0], s[1]), true, 1.0);
    }
    for (final s in preWhite) {
      drawStone(gridPos(s[0], s[1]), false, 1.0);
    }

    final animated = [
      [3, 3, true, 0.0, 0.20],
      [2, 3, false, 0.20, 0.40],
      [4, 4, true, 0.40, 0.60],
      [3, 4, false, 0.60, 0.70],
      [0, 0, true, 0.70, 0.80],
    ];

    final winLine = [
      [0, 0],
      [1, 1],
      [2, 2],
      [3, 3],
      [4, 4],
    ];

    for (final a in animated) {
      final col = a[0] as int;
      final row = a[1] as int;
      final isBlack = a[2] as bool;
      final tStart = a[3] as double;
      final tEnd = a[4] as double;
      if (t >= tStart) {
        final p = ((t - tStart) / (tEnd - tStart)).clamp(0.0, 1.0);
        final scale = Curves.easeOutBack.transform(p);
        drawStone(gridPos(col, row), isBlack, scale.clamp(0.0, 1.2));
      }
    }

    if (t >= 0.80) {
      final lp = ((t - 0.80) / 0.10).clamp(0.0, 1.0);
      if (t <= 0.90) {
        final start = gridPos(winLine.first[0], winLine.first[1]);
        final end = gridPos(winLine.last[0], winLine.last[1]);
        final current = Offset(
          start.dx + (end.dx - start.dx) * lp,
          start.dy + (end.dy - start.dy) * lp,
        );
        canvas.drawLine(
          start,
          current,
          Paint()
            ..color = const Color(0xFFFBBF24).withValues(alpha: 0.45)
            ..strokeWidth = step * 0.12
            ..strokeCap = StrokeCap.round,
        );
      } else {
        final start = gridPos(winLine.first[0], winLine.first[1]);
        final end = gridPos(winLine.last[0], winLine.last[1]);
        final pulse = 0.70 + 0.15 * math.sin((t - 0.90) / 0.10 * math.pi * 2);
        canvas.drawLine(
          start,
          end,
          Paint()
            ..color = const Color(0xFFFCD34D).withValues(alpha: pulse)
            ..strokeWidth = step * 0.12
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
  bool shouldRepaint(_GomokuArtPainter old) => old.t != t;
}

Widget buildNumberSequenceLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Number Sequence',
      bg: const [Color(0xFF312E81), Color(0xFF1E1B4B)],
      accent: const Color(0xFF818CF8),
      period: const Duration(milliseconds: 3500),
      artBuilder: (t) => _NumberSequenceArtPainter(t),
    );

class _NumberSequenceArtPainter extends CustomPainter {
  final double t;
  const _NumberSequenceArtPainter(this.t);

  static const _bubbleColors = [
    Color(0xFF6366F1),
    Color(0xFF8B5CF6),
    Color(0xFF06B6D4),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
  ];

  static const _numbers = [
    [0.25, 0.22, 12.0, -8.0, '1'],
    [0.72, 0.35, 14.0, 5.0, '2'],
    [0.40, 0.58, 11.0, -12.0, '3'],
    [0.18, 0.75, 13.0, 7.0, '4'],
    [0.78, 0.70, 10.0, -5.0, '5'],
    [0.55, 0.20, 12.0, 10.0, '6'],
  ];

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

    final stepDuration = 0.15;

    for (int i = 0; i < _numbers.length; i++) {
      final n = _numbers[i];
      final nx = zone.left + (n[0] as double) * artSize;
      final ny = zone.top + (n[1] as double) * artSize;
      final fontSize = artSize * (n[2] as double) / 100.0;
      final rotation = (n[3] as double) * math.pi / 180.0;
      final label = n[4] as String;

      final disappearStart = i * stepDuration;
      final disappearEnd = disappearStart + stepDuration;

      double scale = 1.0;
      double alpha = 1.0;
      double rippleProgress = -1.0;

      if (t >= disappearStart && t < disappearEnd) {
        final p = ((t - disappearStart) / (disappearEnd - disappearStart)).clamp(0.0, 1.0);
        scale = 1.0 - Curves.easeInBack.transform(p);
        alpha = 1.0 - p;
        rippleProgress = p;
      } else if (t >= disappearEnd) {
        scale = 0.0;
        alpha = 0.0;
        if (t < disappearEnd + 0.08) {
          rippleProgress = ((t - disappearEnd) / 0.08).clamp(0.0, 1.0) * 0.5 + 0.5;
        }
      }

      if (rippleProgress >= 0) {
        final rp = rippleProgress.clamp(0.0, 1.0);
        canvas.drawCircle(
          Offset(nx, ny),
          artSize * 0.08 * rp,
          Paint()
            ..color = _bubbleColors[i].withValues(alpha: 0.45 * (1.0 - rp))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0 * (1.0 - rp) + 0.5,
        );
      }

      if (alpha > 0.01) {
        canvas.save();
        canvas.translate(nx, ny);
        canvas.rotate(rotation);
        canvas.scale(scale.clamp(0.0, 1.0));

        final bgCircleR = fontSize * 1.1;
        canvas.drawCircle(
          Offset.zero,
          bgCircleR,
          Paint()..color = _bubbleColors[i].withValues(alpha: 0.25 * alpha),
        );
        canvas.drawCircle(
          Offset.zero,
          bgCircleR,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.15 * alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );

        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: alpha),
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));

        canvas.restore();
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
  bool shouldRepaint(_NumberSequenceArtPainter old) => old.t != t;
}

Widget buildGoLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Go',
      bg: const [Color(0xFF44271A), Color(0xFF2A1810)],
      accent: const Color(0xFFCD7F32),
      period: const Duration(milliseconds: 3500),
      artBuilder: (t) => _GoArtPainter(t),
    );

class _GoArtPainter extends CustomPainter {
  final double t;
  const _GoArtPainter(this.t);

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

    canvas.drawRRect(zoneRR, Paint()..color = const Color(0xFFD4A76A).withValues(alpha: 0.30));

    final gridN = 5;
    final margin = artSize * 0.10;
    final step = (artSize - margin * 2) / (gridN - 1);
    final linePaint = Paint()
      ..color = const Color(0xFF5D4037).withValues(alpha: 0.45)
      ..strokeWidth = 0.6;

    for (int i = 0; i < gridN; i++) {
      final x = zone.left + margin + i * step;
      canvas.drawLine(Offset(x, zone.top + margin), Offset(x, zone.bottom - margin), linePaint);
      final y = zone.top + margin + i * step;
      canvas.drawLine(Offset(zone.left + margin, y), Offset(zone.right - margin, y), linePaint);
    }

    final starR = step * 0.06;
    final starPaint = Paint()..color = const Color(0xFF5D4037).withValues(alpha: 0.50);
    canvas.drawCircle(
      Offset(zone.left + margin + 2 * step, zone.top + margin + 2 * step),
      starR,
      starPaint,
    );

    Offset gridPos(int col, int row) => Offset(
          zone.left + margin + col * step,
          zone.top + margin + row * step,
        );

    final stoneR = step * 0.40;

    void drawStone(Offset pos, bool isBlack, double scale, [double alpha = 1.0]) {
      final r = stoneR * scale;
      if (r < 0.5) return;
      final fill = Paint()
        ..color = (isBlack ? const Color(0xFF212121) : const Color(0xFFF5F5F5))
            .withValues(alpha: alpha);
      canvas.drawCircle(
        pos.translate(0.6, 0.6),
        r,
        Paint()..color = Colors.black.withValues(alpha: 0.20 * alpha),
      );
      canvas.drawCircle(pos, r, fill);
      if (!isBlack) {
        canvas.drawCircle(pos, r, Paint()
          ..color = Colors.grey.withValues(alpha: 0.30 * alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5);
      }
      final hlColor = isBlack
          ? const Color(0xFF444444).withValues(alpha: alpha)
          : Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(
        pos.translate(-r * 0.22, -r * 0.22),
        r * 0.16,
        Paint()..color = hlColor,
      );
    }

    final preBlack = [
      [1, 2],
      [2, 1],
      [3, 2],
    ];
    final preWhite = [
      [2, 2],
      [2, 3],
    ];
    const newBlackPos = [3, 3];
    final capturedWhite = [
      [2, 2],
      [2, 3],
    ];

    for (final s in preBlack) {
      drawStone(gridPos(s[0], s[1]), true, 1.0);
    }

    if (t < 0.30) {
      for (final s in preWhite) {
        drawStone(gridPos(s[0], s[1]), false, 1.0);
      }

      final placeP = Curves.easeOutBack.transform((t / 0.30).clamp(0.0, 1.0));
      drawStone(gridPos(newBlackPos[0], newBlackPos[1]), true, placeP.clamp(0.0, 1.2));
    } else if (t < 0.60) {
      for (final s in preWhite) {
        drawStone(gridPos(s[0], s[1]), false, 1.0);
      }
      drawStone(gridPos(newBlackPos[0], newBlackPos[1]), true, 1.0);

      final surroundP = ((t - 0.30) / 0.30).clamp(0.0, 1.0);
      if (surroundP > 0.5) {
        final glowP = ((surroundP - 0.5) * 2).clamp(0.0, 1.0);
        for (final cw in capturedWhite) {
          final pos = gridPos(cw[0], cw[1]);
          canvas.drawCircle(
            pos,
            stoneR * 1.3,
            Paint()
              ..color = const Color(0xFFCD7F32).withValues(alpha: 0.25 * glowP)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
        }
      }
    } else if (t < 0.80) {
      final fadeP = ((t - 0.60) / 0.20).clamp(0.0, 1.0);
      for (final s in preWhite) {
        drawStone(gridPos(s[0], s[1]), false, 1.0 - fadeP * 0.3, 1.0 - fadeP);
      }
      drawStone(gridPos(newBlackPos[0], newBlackPos[1]), true, 1.0);

      if (fadeP > 0.3) {
        final textP = ((fadeP - 0.3) / 0.7).clamp(0.0, 1.0);
        final midX = (gridPos(capturedWhite[0][0], capturedWhite[0][1]).dx +
                gridPos(capturedWhite[1][0], capturedWhite[1][1]).dx) /
            2;
        final midY = gridPos(capturedWhite[0][0], capturedWhite[0][1]).dy;
        final floatY = midY - step * 0.6 * textP;
        final tp = TextPainter(
          text: TextSpan(
            text: '+2',
            style: TextStyle(
              color: const Color(0xFFFFD700).withValues(alpha: 1.0 - textP * 0.6),
              fontSize: step * 0.35,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(midX - tp.width / 2, floatY - tp.height / 2));
      }
    } else {
      drawStone(gridPos(newBlackPos[0], newBlackPos[1]), true, 1.0);
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
  bool shouldRepaint(_GoArtPainter old) => old.t != t;
}

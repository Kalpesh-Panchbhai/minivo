import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_logo_living.dart';

Widget buildSlidingPuzzleLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Sliding Puzzle',
      bg: const [Color(0xFF4C1D95), Color(0xFF2E1065)],
      accent: const Color(0xFFA78BFA),
      period: const Duration(milliseconds: 3000),
      artBuilder: (t) => _SlidingPuzzleArtPainter(t),
    );

class _SlidingPuzzleArtPainter extends CustomPainter {
  final double t;
  const _SlidingPuzzleArtPainter(this.t);

  static const _tileColors = [
    Color(0xFF8B5CF6), Color(0xFFA78BFA), Color(0xFF7C3AED),
    Color(0xFF6D28D9), Color(0xFF9333EA), Color(0xFFC084FC),
    Color(0xFFD946EF), Color(0xFF7E22CE),
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

    final rrect = RRect.fromRectAndRadius(zone, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(rrect);

    canvas.drawRect(zone, Paint()..color = const Color(0xFF1A0F2E).withValues(alpha: 0.5));

    final cellW = zone.width / 3;
    final cellH = zone.height / 3;

    // Nearly solved state: 8 needs to slide left into empty space
    // Initial: [1,2,3 / 4,5,6 / 7, ,8]  →  Final: [1,2,3 / 4,5,6 / 7,8, ]
    final labels = ['1', '2', '3', '4', '5', '6', '7', '', '8'];

    double tile8OffsetX = 0;
    bool solved = false;

    if (t < 0.35) {
      // Waiting phase - show almost-solved board
    } else if (t < 0.60) {
      // Tile 8 slides left into empty space
      final p = Curves.easeInOut.transform(((t - 0.35) / 0.25).clamp(0.0, 1.0));
      tile8OffsetX = -p * cellW;
    } else {
      tile8OffsetX = -cellW;
      solved = true;
    }

    for (int i = 0; i < 9; i++) {
      if (labels[i].isEmpty) continue;
      final r = i ~/ 3;
      final c = i % 3;
      double ox = 0, oy = 0;
      if (labels[i] == '8') ox = tile8OffsetX;

      final tx = zone.left + c * cellW + ox;
      final ty = zone.top + r * cellH + oy;
      final tileRect = Rect.fromLTWH(tx + 1.5, ty + 1.5, cellW - 3, cellH - 3);
      final tileRR = RRect.fromRectAndRadius(tileRect, Radius.circular(cellW * 0.12));

      final colorIdx = (int.parse(labels[i]) - 1) % _tileColors.length;
      final tileColor = _tileColors[colorIdx];

      // Tile gradient
      canvas.drawRRect(tileRR, Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            Color.lerp(tileColor, Colors.white, 0.15)!.withValues(alpha: 0.90),
            tileColor.withValues(alpha: 0.90),
          ],
        ).createShader(tileRect));

      // Glass highlight (top 35%)
      final highlightRect = Rect.fromLTWH(
        tileRect.left, tileRect.top,
        tileRect.width, tileRect.height * 0.35,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(highlightRect,
          topLeft: Radius.circular(cellW * 0.12),
          topRight: Radius.circular(cellW * 0.12)),
        Paint()..color = Colors.white.withValues(alpha: 0.15),
      );

      // Border
      canvas.drawRRect(tileRR, Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke ..strokeWidth = 0.5);

      // Number
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: TextStyle(
          color: Colors.white.withValues(alpha: 0.95),
          fontSize: cellW * 0.38, fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(tx + (cellW - tp.width) / 2, ty + (cellH - tp.height) / 2));
    }

    // Win celebration glow
    if (solved && t < 0.85) {
      final glowP = ((t - 0.60) / 0.25).clamp(0.0, 1.0);
      canvas.drawRRect(rrect, Paint()
        ..color = Colors.white.withValues(alpha: 0.12 * math.sin(glowP * math.pi))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }

    canvas.restore();
    canvas.drawRRect(rrect, Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke ..strokeWidth = 0.8);
  }

  @override
  bool shouldRepaint(_SlidingPuzzleArtPainter old) => old.t != t;
}

Widget buildHangmanLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Hangman',
      bg: const [Color(0xFF312E81), Color(0xFF1E1B4B)],
      accent: const Color(0xFF818CF8),
      period: const Duration(milliseconds: 3500),
      artBuilder: (t) => _HangmanArtPainter(t),
    );

class _HangmanArtPainter extends CustomPainter {
  final double t;
  const _HangmanArtPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final artSize = w * 0.52;
    final zone = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.40), width: artSize, height: artSize);
    final rrect = RRect.fromRectAndRadius(zone, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(rrect);

    // Gallows
    final linePaint = Paint()
      ..color = const Color(0xFF8B6914) ..strokeWidth = 1.5 ..strokeCap = StrokeCap.round;
    final postX = zone.left + zone.width * 0.25;
    final postTop = zone.top + zone.height * 0.12;
    final postBot = zone.top + zone.height * 0.52;
    canvas.drawLine(Offset(postX, postTop), Offset(postX, postBot), linePaint);
    final beamEnd = zone.left + zone.width * 0.65;
    canvas.drawLine(Offset(postX, postTop), Offset(beamEnd, postTop), linePaint);

    // Rope + Head (visible after wrong guess at t >= 0.35)
    if (t >= 0.35) {
      final headAlpha = ((t - 0.35) / 0.10).clamp(0.0, 1.0);
      final ropeEnd = postTop + zone.height * 0.08;
      canvas.drawLine(Offset(beamEnd, postTop), Offset(beamEnd, ropeEnd),
        Paint()..color = const Color(0xFF6B5B3A).withValues(alpha: headAlpha)
          ..strokeWidth = 1.5..strokeCap = StrokeCap.round);
      final headR = zone.height * 0.055;
      final headCy = ropeEnd + headR;
      // Head shadow
      canvas.drawCircle(Offset(beamEnd, headCy + 1), headR,
        Paint()..color = Colors.black.withValues(alpha: 0.08 * headAlpha));
      // Head
      canvas.drawCircle(Offset(beamEnd, headCy), headR,
        Paint()..color = const Color(0xFFF5D0A9).withValues(alpha: headAlpha));
      canvas.drawCircle(Offset(beamEnd, headCy), headR,
        Paint()..color = const Color(0xFFBE8C5E).withValues(alpha: headAlpha)
          ..style = PaintingStyle.stroke..strokeWidth = 1.2);
      // Eyes
      final eyeR = headR * 0.12;
      final eyeSpacing = headR * 0.35;
      canvas.drawCircle(Offset(beamEnd - eyeSpacing, headCy - headR * 0.1), eyeR,
        Paint()..color = const Color(0xFF2D2D2D).withValues(alpha: headAlpha));
      canvas.drawCircle(Offset(beamEnd + eyeSpacing, headCy - headR * 0.1), eyeR,
        Paint()..color = const Color(0xFF2D2D2D).withValues(alpha: headAlpha));
      // Worried mouth
      final mouthPath = Path()
        ..moveTo(beamEnd - headR * 0.2, headCy + headR * 0.35)
        ..quadraticBezierTo(beamEnd, headCy + headR * 0.22, beamEnd + headR * 0.2, headCy + headR * 0.35);
      canvas.drawPath(mouthPath, Paint()
        ..color = const Color(0xFFBE8C5E).withValues(alpha: headAlpha)
        ..style = PaintingStyle.stroke..strokeWidth = 1.0..strokeCap = StrokeCap.round);
    }

    // Letter blanks
    final blanksY = zone.top + zone.height * 0.75;
    const letters = ['H', 'E', 'L', 'P'];
    final thresholds = [0.0, 0.20, 0.55, 0.70];
    final blankW = zone.width * 0.12;
    final blankGap = zone.width * 0.04;
    final totalW = letters.length * blankW + (letters.length - 1) * blankGap;
    final startX = zone.left + (zone.width - totalW) / 2;
    final blankPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85) ..strokeWidth = 1.5 ..strokeCap = StrokeCap.round;
    for (int i = 0; i < letters.length; i++) {
      final bx = startX + i * (blankW + blankGap);
      canvas.drawLine(Offset(bx, blanksY + 2), Offset(bx + blankW, blanksY + 2), blankPaint);
      if (t >= thresholds[i]) {
        final p = ((t - thresholds[i]) / 0.12).clamp(0.0, 1.0);
        final tp = TextPainter(
          text: TextSpan(text: letters[i], style: TextStyle(
            color: Colors.white.withValues(alpha: p),
            fontSize: blankW * 0.75, fontWeight: FontWeight.w700)),
          textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, Offset(
          bx + (blankW - tp.width) / 2,
          blanksY - tp.height - 2 - (1 - p) * zone.height * 0.05));
      }
    }

    // Wrong letter "X" flash (t 0.35 - 0.50)
    if (t >= 0.35 && t < 0.50) {
      final flashP = ((t - 0.35) / 0.15).clamp(0.0, 1.0);
      final flashAlpha = flashP < 0.5 ? flashP * 2 : (1.0 - flashP) * 2;
      final wrongX = zone.left + zone.width * 0.5;
      final wrongY = zone.top + zone.height * 0.55;
      final wrongTp = TextPainter(
        text: TextSpan(text: 'X', style: TextStyle(
          color: const Color(0xFFEF4444).withValues(alpha: flashAlpha.clamp(0.0, 1.0)),
          fontSize: zone.width * 0.10, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr)..layout();
      wrongTp.paint(canvas, Offset(wrongX - wrongTp.width / 2, wrongY - wrongTp.height / 2));
    }

    // Win checkmark
    if (t >= 0.82) {
      final cp = ((t - 0.82) / 0.12).clamp(0.0, 1.0);
      final scale = Curves.elasticOut.transform(cp);
      final checkX = zone.left + zone.width * 0.5;
      final checkY = zone.top + zone.height * 0.52;
      final checkSize = zone.width * 0.12 * scale;
      final checkPaint = Paint()
        ..color = const Color(0xFF4ADE80).withValues(alpha: cp)
        ..strokeWidth = 2.0 ..strokeCap = StrokeCap.round ..style = PaintingStyle.stroke;
      final checkPath = Path()
        ..moveTo(checkX - checkSize * 0.5, checkY)
        ..lineTo(checkX - checkSize * 0.1, checkY + checkSize * 0.4)
        ..lineTo(checkX + checkSize * 0.5, checkY - checkSize * 0.3);
      canvas.drawPath(checkPath, checkPaint);
    }

    canvas.restore();
    canvas.drawRRect(rrect, Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke ..strokeWidth = 0.8);
  }

  @override
  bool shouldRepaint(_HangmanArtPainter old) => old.t != t;
}

Widget buildTapTapDashLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Tap Tap Dash',
      bg: const [Color(0xFF0E4D64), Color(0xFF062C3A)],
      accent: const Color(0xFF22D3EE),
      period: const Duration(milliseconds: 3000),
      artBuilder: (t) => _TapTapDashArtPainter(t),
    );

class _TapTapDashArtPainter extends CustomPainter {
  final double t;
  const _TapTapDashArtPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final artSize = w * 0.52;
    final zone = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.40),
      width: artSize,
      height: artSize,
    );

    final rrect = RRect.fromRectAndRadius(zone, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(rrect);

    final seg = zone.width * 0.28;
    final points = <Offset>[
      Offset(zone.left + zone.width * 0.15, zone.top + zone.height * 0.20),
    ];
    final dirs = [
      Offset(1, 1),
      Offset(1, -1),
      Offset(1, 1),
      Offset(1, -1),
    ];

    for (final d in dirs) {
      final last = points.last;
      final norm = math.sqrt(d.dx * d.dx + d.dy * d.dy);
      points.add(Offset(last.dx + d.dx / norm * seg, last.dy + d.dy / norm * seg));
    }

    final totalLen = (points.length - 1) * seg;
    final ballDist = t * totalLen;

    final pathPaint = Paint()
      ..color = const Color(0xFF00D4FF).withValues(alpha: 0.25)
      ..strokeWidth = zone.width * 0.08
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = const Color(0xFF00D4FF).withValues(alpha: 0.5)
      ..strokeWidth = zone.width * 0.08
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], pathPaint);
    }

    double traveled = 0;
    Offset ballPos = points[0];
    for (int i = 0; i < points.length - 1; i++) {
      final segLen = seg;
      if (traveled + segLen >= ballDist) {
        final frac = (ballDist - traveled) / segLen;
        ballPos = Offset(
          points[i].dx + (points[i + 1].dx - points[i].dx) * frac,
          points[i].dy + (points[i + 1].dy - points[i].dy) * frac,
        );

        final litPath = Path()..moveTo(points[0].dx, points[0].dy);
        for (int j = 0; j <= i; j++) {
          litPath.lineTo(points[j + 1].dx, points[j + 1].dy);
        }
        if (i < points.length - 1) {
          litPath.lineTo(ballPos.dx, ballPos.dy);
        }
        canvas.drawPath(litPath, glowPaint);
        break;
      }
      traveled += segLen;
    }
    if (ballDist >= totalLen) {
      ballPos = points.last;
    }

    for (int trail = 3; trail >= 1; trail--) {
      final trailDist = ballDist - trail * seg * 0.08;
      if (trailDist < 0) continue;
      double td = 0;
      Offset tp = points[0];
      for (int i = 0; i < points.length - 1; i++) {
        if (td + seg >= trailDist) {
          final f = (trailDist - td) / seg;
          tp = Offset(
            points[i].dx + (points[i + 1].dx - points[i].dx) * f,
            points[i].dy + (points[i + 1].dy - points[i].dy) * f,
          );
          break;
        }
        td += seg;
      }
      canvas.drawCircle(
        tp,
        zone.width * 0.025 * (1 - trail * 0.2),
        Paint()..color = Colors.white.withValues(alpha: 0.3 - trail * 0.08),
      );
    }

    canvas.drawCircle(
      ballPos,
      zone.width * 0.04,
      Paint()
        ..color = const Color(0xFF00D4FF).withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      ballPos,
      zone.width * 0.028,
      Paint()..color = Colors.white,
    );

    canvas.restore();

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_TapTapDashArtPainter old) => old.t != t;
}

Widget buildWhackAMoleLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Whack-a-Mole',
      bg: const [Color(0xFF7C2D12), Color(0xFF431407)],
      accent: const Color(0xFFFB923C),
      period: const Duration(milliseconds: 3500),
      artBuilder: (t) => _WhackAMoleArtPainter(t),
    );

class _WhackAMoleArtPainter extends CustomPainter {
  final double t;
  const _WhackAMoleArtPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final artSize = w * 0.52;
    final zone = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.40),
      width: artSize,
      height: artSize,
    );

    final rrect = RRect.fromRectAndRadius(zone, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(rrect);

    final holeY = zone.top + zone.height * 0.72;
    final holeW = zone.width * 0.22;
    final holeH = zone.height * 0.08;
    final holePositions = [
      zone.left + zone.width * 0.18,
      zone.left + zone.width * 0.50,
      zone.left + zone.width * 0.82,
    ];

    double centerMoleRise = 0;
    double rightMoleRise = 0;
    bool showHammer = false;
    double hammerAngle = 0;
    bool showBam = false;

    if (t < 0.2) {
      centerMoleRise = Curves.easeOut.transform((t / 0.2).clamp(0.0, 1.0));
    } else if (t < 0.4) {
      centerMoleRise = 1.0;
    } else if (t < 0.5) {
      centerMoleRise = 1.0;
      showHammer = true;
      final hp = ((t - 0.4) / 0.1).clamp(0.0, 1.0);
      hammerAngle = Curves.easeIn.transform(hp) * 0.6;
      if (hp > 0.7) showBam = true;
    } else if (t < 0.7) {
      final dp = ((t - 0.5) / 0.2).clamp(0.0, 1.0);
      centerMoleRise = 1.0 - Curves.easeIn.transform(dp);
    } else if (t < 0.9) {
      final rp = ((t - 0.7) / 0.15).clamp(0.0, 1.0);
      rightMoleRise = Curves.easeOut.transform(rp);
    } else {
      final dp = ((t - 0.9) / 0.1).clamp(0.0, 1.0);
      rightMoleRise = 1.0 - Curves.easeIn.transform(dp);
    }

    void drawMole(double cx, double rise) {
      if (rise <= 0) return;
      final moleR = holeW * 0.35;
      final moleY = holeY - moleR * 1.2 * rise;

      canvas.save();
      canvas.clipRect(Rect.fromLTWH(
        cx - holeW * 0.5,
        zone.top,
        holeW,
        holeY - holeH * 0.2 - zone.top,
      ));

      canvas.drawCircle(
        Offset(cx, moleY),
        moleR,
        Paint()..color = const Color(0xFFA07250),
      );
      canvas.drawCircle(
        Offset(cx, moleY),
        moleR * 0.75,
        Paint()..color = const Color(0xFFB8845C).withValues(alpha: 0.6),
      );

      final eyeOff = moleR * 0.28;
      final eyeR = moleR * 0.12;
      canvas.drawCircle(Offset(cx - eyeOff, moleY - eyeOff * 0.3), eyeR,
          Paint()..color = Colors.black);
      canvas.drawCircle(Offset(cx + eyeOff, moleY - eyeOff * 0.3), eyeR,
          Paint()..color = Colors.black);

      canvas.drawCircle(
        Offset(cx, moleY + moleR * 0.2),
        moleR * 0.12,
        Paint()..color = const Color(0xFFEF9A9A),
      );

      canvas.restore();
    }

    drawMole(holePositions[1], centerMoleRise);
    drawMole(holePositions[2], rightMoleRise);

    for (final hx in holePositions) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(hx, holeY), width: holeW, height: holeH),
        Paint()..color = const Color(0xFF1C0E04).withValues(alpha: 0.8),
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(hx, holeY), width: holeW, height: holeH),
        Paint()
          ..color = const Color(0xFF8D6E63).withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }

    if (showHammer) {
      final hammerCx = holePositions[1] + holeW * 0.5;
      final hammerCy = holeY - zone.height * 0.35;

      canvas.save();
      canvas.translate(hammerCx, hammerCy);
      canvas.rotate(hammerAngle);

      final handlePaint = Paint()..color = const Color(0xFF8B6914);
      canvas.drawLine(
        Offset.zero,
        Offset(0, zone.height * 0.25),
        handlePaint..strokeWidth = zone.width * 0.03,
      );

      final headW = zone.width * 0.12;
      final headH = zone.width * 0.07;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: headW, height: headH),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFF757575),
      );

      canvas.restore();
    }

    if (showBam) {
      final bamX = holePositions[1];
      final bamY = holeY - zone.height * 0.18;
      final starR = zone.width * 0.08;
      final starPaint = Paint()..color = const Color(0xFFFFEB3B).withValues(alpha: 0.8);
      final starPath = Path();
      for (int i = 0; i < 8; i++) {
        final angle = i * math.pi / 4 - math.pi / 2;
        final r = i.isEven ? starR : starR * 0.45;
        final px = bamX + r * math.cos(angle);
        final py = bamY + r * math.sin(angle);
        if (i == 0) {
          starPath.moveTo(px, py);
        } else {
          starPath.lineTo(px, py);
        }
      }
      starPath.close();
      canvas.drawPath(starPath, starPaint);
    }

    canvas.restore();

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_WhackAMoleArtPainter old) => old.t != t;
}

Widget buildColorTapLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Color Tap',
      bg: const [Color(0xFF7C2D12), Color(0xFF431407)],
      accent: const Color(0xFFFB923C),
      period: const Duration(milliseconds: 3500),
      artBuilder: (t) => _ColorTapArtPainter(t),
    );

class _ColorTapArtPainter extends CustomPainter {
  final double t;
  const _ColorTapArtPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final artSize = w * 0.52;
    final zone = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.40),
      width: artSize,
      height: artSize,
    );

    final rrect = RRect.fromRectAndRadius(zone, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(rrect);

    final targetLabelTp = TextPainter(
      text: TextSpan(
        text: 'TARGET',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: zone.width * 0.08,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    targetLabelTp.paint(
      canvas,
      Offset(
        zone.left + (zone.width - targetLabelTp.width) / 2,
        zone.top + zone.height * 0.08,
      ),
    );

    const orange = Color(0xFFEF4444);
    const blue = Color(0xFF3B82F6);
    final squareSize = zone.width * 0.14;
    final squareRect = Rect.fromCenter(
      center: Offset(zone.left + zone.width * 0.5, zone.top + zone.height * 0.24),
      width: squareSize,
      height: squareSize,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(squareRect, const Radius.circular(3)),
      Paint()..color = orange,
    );

    Color circleColor;
    if (t < 0.3) {
      circleColor = orange;
    } else if (t < 0.5) {
      circleColor = blue;
    } else if (t < 0.7) {
      circleColor = blue;
    } else {
      circleColor = orange;
    }

    final circleCenter = Offset(
      zone.left + zone.width * 0.5,
      zone.top + zone.height * 0.58,
    );
    final circleR = zone.width * 0.18;

    canvas.drawCircle(circleCenter, circleR, Paint()..color = circleColor);
    canvas.drawCircle(
      circleCenter,
      circleR,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    bool isMatch = (t < 0.3) || (t >= 0.7);

    if (isMatch) {
      final checkFade = t < 0.3
          ? ((t / 0.15).clamp(0.0, 1.0))
          : (((t - 0.7) / 0.15).clamp(0.0, 1.0));
      final checkSize = zone.width * 0.08;
      final cx = circleCenter.dx;
      final cy = zone.top + zone.height * 0.82;

      final checkPaint = Paint()
        ..color = const Color(0xFF22C55E).withValues(alpha: checkFade)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final checkPath = Path()
        ..moveTo(cx - checkSize * 0.5, cy)
        ..lineTo(cx - checkSize * 0.1, cy + checkSize * 0.4)
        ..lineTo(cx + checkSize * 0.5, cy - checkSize * 0.3);
      canvas.drawPath(checkPath, checkPaint);
    }

    if (t >= 0.5 && t < 0.7) {
      final skipFade = ((t - 0.5) / 0.1).clamp(0.0, 1.0) *
          (1.0 - ((t - 0.6) / 0.1).clamp(0.0, 1.0));
      final skipTp = TextPainter(
        text: TextSpan(
          text: 'SKIP',
          style: TextStyle(
            color: const Color(0xFFEF4444).withValues(alpha: skipFade),
            fontSize: zone.width * 0.12,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      skipTp.paint(
        canvas,
        Offset(
          zone.left + (zone.width - skipTp.width) / 2,
          zone.top + zone.height * 0.80,
        ),
      );
    }

    canvas.restore();

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_ColorTapArtPainter old) => old.t != t;
}

Widget buildDotsAndBoxesLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Dots & Boxes',
      bg: const [Color(0xFF1E3A5F), Color(0xFF0C1F3A)],
      accent: const Color(0xFF60A5FA),
      period: const Duration(milliseconds: 3500),
      artBuilder: (t) => _DotsAndBoxesArtPainter(t),
    );

class _DotsAndBoxesArtPainter extends CustomPainter {
  final double t;
  const _DotsAndBoxesArtPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final artSize = w * 0.52;
    final zone = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.40), width: artSize, height: artSize);
    final rrect = RRect.fromRectAndRadius(zone, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(rrect);

    // 3×3 dots grid (2×2 boxes) - properly spaced within zone
    final gap = zone.width * 0.35;
    final dotR = zone.width * 0.03;
    final margin = (zone.width - gap * 2) / 2;
    final dots = <List<Offset>>[];
    for (int r = 0; r < 3; r++) {
      final row = <Offset>[];
      for (int c = 0; c < 3; c++) {
        row.add(Offset(
          zone.left + margin + c * gap,
          zone.top + margin + r * gap));
      }
      dots.add(row);
    }

    // Ghost lines (undrawn) - dashed
    final ghostPaint = Paint()
      ..color = const Color(0xFFCBDEF7).withValues(alpha: 0.25)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    // All possible lines as ghost
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 2; c++) {
        _drawDashedLine(canvas, dots[r][c], dots[r][c + 1], ghostPaint);
      }
    }
    for (int r = 0; r < 2; r++) {
      for (int c = 0; c < 3; c++) {
        _drawDashedLine(canvas, dots[r][c], dots[r + 1][c], ghostPaint);
      }
    }

    // Pre-drawn lines (P1 blue) - 3 sides of box [0,0]
    final p1Paint = Paint()
      ..color = const Color(0xFF4DABF7).withValues(alpha: 0.8)
      ..strokeWidth = 2.5 ..strokeCap = StrokeCap.round;
    canvas.drawLine(dots[0][0], dots[0][1], p1Paint);  // top
    canvas.drawLine(dots[0][0], dots[1][0], p1Paint);  // left
    canvas.drawLine(dots[1][0], dots[1][1], p1Paint);  // bottom

    // Animated lines
    final animPaint = Paint()
      ..color = const Color(0xFF4DABF7).withValues(alpha: 0.9)
      ..strokeWidth = 2.5 ..strokeCap = StrokeCap.round;

    // Line 1 (t 0-0.25): Complete box [0,0] right side
    if (t >= 0.0) {
      final p1 = (t / 0.25).clamp(0.0, 1.0);
      final end = Offset.lerp(dots[0][1], dots[1][1], p1)!;
      canvas.drawLine(dots[0][1], end, animPaint);

      // Fill box [0,0] when complete
      if (p1 >= 1.0) {
        canvas.drawRect(
          Rect.fromPoints(dots[0][0], dots[1][1]),
          Paint()..color = const Color(0xFF4DABF7).withValues(alpha: 0.15));
        // "P1" label
        final tp = TextPainter(
          text: TextSpan(text: 'P1', style: TextStyle(
            color: const Color(0xFF4DABF7).withValues(alpha: 0.7),
            fontSize: gap * 0.22, fontWeight: FontWeight.w900)),
          textDirection: TextDirection.ltr)..layout();
        final boxCenter = Offset(
          (dots[0][0].dx + dots[1][1].dx) / 2,
          (dots[0][0].dy + dots[1][1].dy) / 2);
        tp.paint(canvas, Offset(boxCenter.dx - tp.width / 2, boxCenter.dy - tp.height / 2));
      }
    }

    // Line 2 (t 0.30-0.55): P2 draws top of box [0,1]
    final p2Paint = Paint()
      ..color = const Color(0xFFFF6B6B).withValues(alpha: 0.9)
      ..strokeWidth = 2.5 ..strokeCap = StrokeCap.round;
    if (t >= 0.30) {
      final p2 = ((t - 0.30) / 0.25).clamp(0.0, 1.0);
      final end = Offset.lerp(dots[0][1], dots[0][2], p2)!;
      canvas.drawLine(dots[0][1], end, p2Paint);
    }

    // Line 3 (t 0.55-0.80): P2 draws right side of box [0,1]
    if (t >= 0.55) {
      final p3 = ((t - 0.55) / 0.25).clamp(0.0, 1.0);
      final end = Offset.lerp(dots[0][2], dots[1][2], p3)!;
      canvas.drawLine(dots[0][2], end, p2Paint);

      // Fill box [0,1] when complete (needs bottom too which is dots[1][1]-dots[1][2])
      if (p3 >= 1.0) {
        // Draw the bottom line too
        canvas.drawLine(dots[1][1], dots[1][2], p2Paint);
        canvas.drawRect(
          Rect.fromPoints(dots[0][1], dots[1][2]),
          Paint()..color = const Color(0xFFFF6B6B).withValues(alpha: 0.15));
        final tp = TextPainter(
          text: TextSpan(text: 'P2', style: TextStyle(
            color: const Color(0xFFFF6B6B).withValues(alpha: 0.7),
            fontSize: gap * 0.22, fontWeight: FontWeight.w900)),
          textDirection: TextDirection.ltr)..layout();
        final boxCenter = Offset(
          (dots[0][1].dx + dots[1][2].dx) / 2,
          (dots[0][1].dy + dots[1][2].dy) / 2);
        tp.paint(canvas, Offset(boxCenter.dx - tp.width / 2, boxCenter.dy - tp.height / 2));
      }
    }

    // Draw dots on top
    for (final row in dots) {
      for (final dot in row) {
        canvas.drawCircle(dot, dotR + 1, Paint()..color = const Color(0xFF1D3D6B).withValues(alpha: 0.15));
        canvas.drawCircle(Offset(dot.dx, dot.dy + 0.5), dotR, Paint()..color = const Color(0xFF1D3D6B).withValues(alpha: 0.3));
        canvas.drawCircle(dot, dotR, Paint()..color = const Color(0xFF1D3D6B));
        canvas.drawCircle(Offset(dot.dx - dotR * 0.25, dot.dy - dotR * 0.25), dotR * 0.3,
          Paint()..color = Colors.white.withValues(alpha: 0.5));
      }
    }

    canvas.restore();
    canvas.drawRRect(rrect, Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke ..strokeWidth = 0.8);
  }

  void _drawDashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    final ux = dx / len, uy = dy / len;
    const dashLen = 3.0, gapLen = 4.0;
    double d = 0;
    while (d < len) {
      final end = (d + dashLen).clamp(0.0, len);
      canvas.drawLine(
        Offset(from.dx + ux * d, from.dy + uy * d),
        Offset(from.dx + ux * end, from.dy + uy * end),
        paint);
      d += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(_DotsAndBoxesArtPainter old) => old.t != t;
}

Widget buildDodgeBallLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Dodge Ball',
      bg: const [Color(0xFF0E4D64), Color(0xFF062C3A)],
      accent: const Color(0xFF22D3EE),
      period: const Duration(milliseconds: 3000),
      artBuilder: (t) => _DodgeBallArtPainter(t),
    );

class _DodgeBallArtPainter extends CustomPainter {
  final double t;
  const _DodgeBallArtPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final artSize = w * 0.52;
    final zone = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.40),
      width: artSize,
      height: artSize,
    );

    final rrect = RRect.fromRectAndRadius(zone, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(rrect);

    final ballBaseX = zone.left + zone.width * 0.5;
    final ballY = zone.top + zone.height * 0.82;
    final ballR = zone.width * 0.055;

    double ballX;
    if (t < 0.3) {
      ballX = ballBaseX;
    } else if (t < 0.5) {
      final p = Curves.easeInOut.transform(((t - 0.3) / 0.2).clamp(0.0, 1.0));
      ballX = ballBaseX - zone.width * 0.25 * p;
    } else if (t < 0.7) {
      ballX = ballBaseX - zone.width * 0.25;
    } else if (t < 0.9) {
      final p = Curves.easeInOut.transform(((t - 0.7) / 0.2).clamp(0.0, 1.0));
      ballX = ballBaseX - zone.width * 0.25 + zone.width * 0.45 * p;
    } else {
      ballX = ballBaseX + zone.width * 0.20;
    }

    final obstW = zone.width * 0.15;
    final obstH = zone.height * 0.06;
    final obstPaint = Paint()..color = const Color(0xFFFF6B6B).withValues(alpha: 0.85);

    final obs1StartY = zone.top - obstH;
    final obs1EndY = zone.top + zone.height + obstH;
    double obs1Y;
    if (t < 0.5) {
      obs1Y = obs1StartY + (obs1EndY - obs1StartY) * (t / 0.5);
    } else {
      obs1Y = obs1EndY;
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(ballBaseX, obs1Y),
          width: obstW,
          height: obstH,
        ),
        const Radius.circular(3),
      ),
      obstPaint,
    );

    final obs2X = ballBaseX + zone.width * 0.2;
    double obs2Y;
    if (t < 0.3) {
      obs2Y = obs1StartY;
    } else if (t < 0.9) {
      obs2Y = obs1StartY + (obs1EndY - obs1StartY) * ((t - 0.3) / 0.6);
    } else {
      obs2Y = obs1EndY;
    }
    obstPaint.color = const Color(0xFFFFD93D).withValues(alpha: 0.85);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(obs2X, obs2Y),
          width: obstW,
          height: obstH,
        ),
        const Radius.circular(3),
      ),
      obstPaint,
    );

    final obs3X = ballBaseX - zone.width * 0.22;
    double obs3Y;
    if (t < 0.15) {
      obs3Y = obs1StartY;
    } else if (t < 0.65) {
      obs3Y = obs1StartY + (obs1EndY - obs1StartY) * ((t - 0.15) / 0.5);
    } else {
      obs3Y = obs1EndY;
    }
    obstPaint.color = const Color(0xFFFF9FF3).withValues(alpha: 0.85);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(obs3X, obs3Y),
          width: obstW,
          height: obstH,
        ),
        const Radius.circular(3),
      ),
      obstPaint,
    );

    canvas.drawCircle(
      Offset(ballX, ballY),
      ballR * 2.5,
      Paint()
        ..color = const Color(0xFF00D4FF).withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    if (t >= 0.3 && t < 0.9) {
      final trailDir = t < 0.5 ? -1.0 : 1.0;
      for (int i = 1; i <= 3; i++) {
        canvas.drawCircle(
          Offset(ballX + trailDir * i * ballR * 0.8, ballY),
          ballR * (1 - i * 0.25),
          Paint()..color = const Color(0xFF00D4FF).withValues(alpha: 0.15 - i * 0.04),
        );
      }
    }

    canvas.drawCircle(
      Offset(ballX, ballY),
      ballR,
      Paint()..color = const Color(0xFF66E5FF),
    );
    canvas.drawCircle(
      Offset(ballX - ballR * 0.25, ballY - ballR * 0.25),
      ballR * 0.3,
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );

    canvas.restore();

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_DodgeBallArtPainter old) => old.t != t;
}

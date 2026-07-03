import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_logo_living.dart';

Widget buildQueensLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Queens',
      bg: const [Color(0xFF581C87), Color(0xFF3B0764)],
      accent: const Color(0xFFC084FC),
      period: const Duration(milliseconds: 3000),
      artBuilder: (t) => _QueensArtPainter(t),
    );

class _QueensArtPainter extends CustomPainter {
  final double t;
  const _QueensArtPainter(this.t);

  static const _queenPositions = [
    [0, 1],
    [1, 3],
    [2, 0],
    [3, 2],
  ];

  static const _regionColors = [
    Color(0xFFFF6B6B),
    Color(0xFF339AF0),
    Color(0xFF51CF66),
    Color(0xFFFFD43B),
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
    final rr = RRect.fromRectAndRadius(zone, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(rr);

    final cellSize = zone.width / 4;

    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        final qi = (r < 2 ? 0 : 2) + (c < 2 ? 0 : 1);
        canvas.drawRect(
          Rect.fromLTWH(
              zone.left + c * cellSize, zone.top + r * cellSize, cellSize, cellSize),
          Paint()..color = _regionColors[qi].withValues(alpha: 0.25),
        );
      }
    }

    final gridPaint = Paint()
      ..color = const Color(0xFF2D2D3F).withValues(alpha: 0.5)
      ..strokeWidth = 0.5;
    for (int i = 1; i < 4; i++) {
      canvas.drawLine(Offset(zone.left + i * cellSize, zone.top),
          Offset(zone.left + i * cellSize, zone.bottom), gridPaint);
      canvas.drawLine(Offset(zone.left, zone.top + i * cellSize),
          Offset(zone.right, zone.top + i * cellSize), gridPaint);
    }

    final shimmer = t >= 0.75 ? math.sin(((t - 0.75) / 0.25) * math.pi) : 0.0;

    for (int i = 0; i < 4; i++) {
      final tStart = i * 0.25;
      final tEnd = tStart + 0.25;
      if (t < tStart) continue;
      final p = ((t - tStart) / (tEnd - tStart)).clamp(0.0, 1.0);
      final scale = Curves.elasticOut.transform(p.clamp(0.0, 1.0));

      final col = _queenPositions[i][0];
      final row = _queenPositions[i][1];
      final cx = zone.left + (col + 0.5) * cellSize;
      final cy = zone.top + (row + 0.5) * cellSize;

      canvas.save();
      canvas.translate(cx, cy);
      canvas.scale(scale, scale);

      final crownColor =
          Color.lerp(const Color(0xFFFFD700), Colors.white, shimmer * 0.5)!;
      _drawCrown(canvas, cellSize * 0.32, crownColor);

      if (shimmer > 0) {
        canvas.drawCircle(
          Offset.zero,
          cellSize * 0.3 * shimmer,
          Paint()
            ..color = const Color(0xFFFFD700).withValues(alpha: 0.3 * shimmer)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }

      canvas.restore();
    }

    canvas.restore();

    canvas.drawRRect(
      rr,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  void _drawCrown(Canvas canvas, double r, Color color) {
    final path = Path()
      ..moveTo(-r, r * 0.5)
      ..lineTo(-r, -r * 0.2)
      ..lineTo(-r * 0.5, r * 0.1)
      ..lineTo(0, -r * 0.5)
      ..lineTo(r * 0.5, r * 0.1)
      ..lineTo(r, -r * 0.2)
      ..lineTo(r, r * 0.5)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_QueensArtPainter old) => old.t != t;
}

Widget buildTangoLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Tango',
      bg: const [Color(0xFF78350F), Color(0xFF451A03)],
      accent: const Color(0xFFFBBF24),
      period: const Duration(milliseconds: 3000),
      artBuilder: (t) => _TangoArtPainter(t),
    );

class _TangoArtPainter extends CustomPainter {
  final double t;
  const _TangoArtPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final artSize = w * 0.52;
    final zone = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.40),
      width: artSize,
      height: artSize,
    );
    final rr = RRect.fromRectAndRadius(zone, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(rr);

    canvas.drawRRect(rr, Paint()..color = const Color(0xFFFFF8E7).withValues(alpha: 0.12));

    final cellSize = zone.width / 4;
    final gridPaint = Paint()
      ..color = const Color(0xFFD4C5A0).withValues(alpha: 0.2)
      ..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      canvas.drawLine(Offset(zone.left + i * cellSize, zone.top),
          Offset(zone.left + i * cellSize, zone.bottom), gridPaint);
      canvas.drawLine(Offset(zone.left, zone.top + i * cellSize),
          Offset(zone.right, zone.top + i * cellSize), gridPaint);
    }

    const placements = [
      [0, 0, true],
      [0, 1, false],
      [1, 0, false],
      [1, 1, true],
    ];
    const timings = [0.0, 0.2, 0.4, 0.6];

    for (int i = 0; i < placements.length; i++) {
      final tStart = timings[i];
      final tEnd = tStart + 0.2;
      if (t < tStart) continue;
      final p = ((t - tStart) / (tEnd - tStart)).clamp(0.0, 1.0);
      final scale = Curves.elasticOut.transform(p);

      final col = placements[i][0] as int;
      final row = placements[i][1] as int;
      final isSun = placements[i][2] as bool;

      final cx = zone.left + (col + 0.5) * cellSize;
      final cy = zone.top + (row + 0.5) * cellSize;

      canvas.save();
      canvas.translate(cx, cy);
      canvas.scale(scale, scale);

      final pulse = t >= 0.8
          ? math.sin(((t - 0.8) / 0.2) * math.pi * 2) * 0.1
          : 0.0;

      if (isSun) {
        _drawSun(canvas, cellSize * (0.25 + pulse));
      } else {
        _drawMoon(canvas, cellSize * (0.25 + pulse));
      }
      canvas.restore();
    }

    canvas.restore();

    canvas.drawRRect(
      rr,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  void _drawSun(Canvas canvas, double r) {
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()..color = const Color(0xFFFFA726),
    );
    canvas.drawCircle(
      Offset.zero,
      r * 1.5,
      Paint()
        ..color = const Color(0xFFFFA726).withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    final rayPaint = Paint()
      ..color = const Color(0xFFFFA726).withValues(alpha: 0.7)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      canvas.drawLine(
        Offset(math.cos(angle) * r * 1.2, math.sin(angle) * r * 1.2),
        Offset(math.cos(angle) * r * 1.6, math.sin(angle) * r * 1.6),
        rayPaint,
      );
    }
  }

  void _drawMoon(Canvas canvas, double r) {
    final moonPath = Path()
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: r));
    final cutout = Path()
      ..addOval(
          Rect.fromCircle(center: Offset(r * 0.45, -r * 0.3), radius: r * 0.75));
    final crescent = Path.combine(PathOperation.difference, moonPath, cutout);
    canvas.drawPath(crescent, Paint()..color = const Color(0xFF7C4DFF).withValues(alpha: 0.9));
    canvas.drawCircle(
      Offset.zero,
      r * 1.3,
      Paint()
        ..color = const Color(0xFF7C4DFF).withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  @override
  bool shouldRepaint(_TangoArtPainter old) => old.t != t;
}

Widget buildLudoLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Ludo',
      bg: const [Color(0xFF2D1B69), Color(0xFF1A0F3E)],
      accent: const Color(0xFF6C5CE7),
      period: const Duration(milliseconds: 3500),
      artBuilder: (t) => _LudoArtPainter(t),
    );

class _LudoArtPainter extends CustomPainter {
  final double t;
  const _LudoArtPainter(this.t);

  static const _red = Color(0xFFE74C3C);
  static const _blue = Color(0xFF2980B9);
  static const _green = Color(0xFF27AE60);
  static const _yellow = Color(0xFFF1C40F);

  static const _homeLanePath = [
    [0.133, 0.5],
    [0.267, 0.5],
    [0.4, 0.5],
    [0.5, 0.5],
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
    final rr = RRect.fromRectAndRadius(zone, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(rr);

    final half = artSize / 2;
    final cx = zone.left + half;
    final cy = zone.top + half;
    final u = artSize / 15;

    canvas.drawRect(zone, Paint()..color = const Color(0xFFF5F0E1).withValues(alpha: 0.50));

    final homeSize = u * 6;
    _drawHomeBase(canvas, zone.left, zone.top, homeSize, _red);
    _drawHomeBase(canvas, zone.left + u * 9, zone.top, homeSize, _blue);
    _drawHomeBase(canvas, zone.left, zone.top + u * 9, homeSize, _green);
    _drawHomeBase(canvas, zone.left + u * 9, zone.top + u * 9, homeSize, _yellow);

    final armW = u * 3;
    final trackPaint = Paint()..color = const Color(0xFFF5F0E1).withValues(alpha: 0.25);
    canvas.drawRect(Rect.fromLTWH(cx - armW / 2, zone.top + homeSize, armW, u * 3), trackPaint);
    canvas.drawRect(Rect.fromLTWH(cx - armW / 2, zone.top + u * 9, armW, u * 3), trackPaint);
    canvas.drawRect(Rect.fromLTWH(zone.left + homeSize, cy - armW / 2, u * 3, armW), trackPaint);
    canvas.drawRect(Rect.fromLTWH(zone.left + u * 9, cy - armW / 2, u * 3, armW), trackPaint);

    final homeLanePaint = Paint()..color = _red.withValues(alpha: 0.25);
    for (int i = 1; i <= 5; i++) {
      canvas.drawRect(
        Rect.fromLTWH(zone.left + i * u, cy - u * 0.5, u, u),
        homeLanePaint,
      );
    }

    final centerSize = u * 3;
    final centerRect = Rect.fromCenter(center: Offset(cx, cy), width: centerSize, height: centerSize);
    final triPaint = [_yellow, _blue, _red, _green];
    final triAngles = [0.0, math.pi / 2, math.pi, 3 * math.pi / 2];
    for (int i = 0; i < 4; i++) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(triAngles[i]);
      final tri = Path()
        ..moveTo(0, 0)
        ..lineTo(-centerSize / 2, -centerSize / 2)
        ..lineTo(centerSize / 2, -centerSize / 2)
        ..close();
      canvas.drawPath(tri, Paint()..color = triPaint[i].withValues(alpha: 0.50));
      canvas.restore();
    }
    canvas.drawRect(centerRect, Paint()
      ..color = const Color(0xFF2C3E50).withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5);

    final steps = _homeLanePath.length - 1;
    final moveT = (t / 0.75).clamp(0.0, 1.0);
    final rawIdx = moveT * steps;
    final idx = rawIdx.floor().clamp(0, steps - 1);
    final nextIdx = (idx + 1).clamp(0, steps);
    final frac = rawIdx - idx;

    final tx = zone.left + (_homeLanePath[idx][0] + (_homeLanePath[nextIdx][0] - _homeLanePath[idx][0]) * frac) * artSize;
    final ty = zone.top + (_homeLanePath[idx][1] + (_homeLanePath[nextIdx][1] - _homeLanePath[idx][1]) * frac) * artSize;

    final tokenR = u * 0.9;
    canvas.drawCircle(Offset(tx, ty + 1), tokenR,
      Paint()..color = Colors.black.withValues(alpha: 0.18));
    canvas.drawCircle(Offset(tx, ty), tokenR,
      Paint()..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        colors: [Color.lerp(_red, Colors.white, 0.25)!, _red, Color.lerp(_red, Colors.black, 0.15)!],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(tx, ty), radius: tokenR)));
    canvas.drawCircle(Offset(tx, ty), tokenR * 0.55,
      Paint()..color = Colors.white.withValues(alpha: 0.30)..style = PaintingStyle.stroke..strokeWidth = 0.6);
    canvas.drawCircle(Offset(tx - tokenR * 0.2, ty - tokenR * 0.2), tokenR * 0.15,
      Paint()..color = Colors.white.withValues(alpha: 0.40));

    if (t >= 0.75) {
      final burstT = ((t - 0.75) / 0.25).clamp(0.0, 1.0);
      final burstR = u * 4 * burstT;
      for (int i = 0; i < 8; i++) {
        final angle = i * math.pi / 4 + burstT * math.pi * 0.3;
        final sx = cx + math.cos(angle) * burstR;
        final sy = cy + math.sin(angle) * burstR;
        canvas.drawCircle(Offset(sx, sy), 1.5 * (1 - burstT),
          Paint()..color = Colors.white.withValues(alpha: 0.7 * (1 - burstT)));
      }
      final starScale = Curves.elasticOut.transform(burstT);
      final starTp = TextPainter(
        text: TextSpan(text: '★', style: TextStyle(
          color: const Color(0xFFFFD700).withValues(alpha: burstT < 0.5 ? burstT * 2 : 1.0),
          fontSize: u * 2.5 * starScale)),
        textDirection: TextDirection.ltr)..layout();
      starTp.paint(canvas, Offset(cx - starTp.width / 2, cy - starTp.height / 2));
    }

    canvas.restore();

    canvas.drawRRect(rr, Paint()
      ..color = const Color(0xFF2C3E50).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8);
  }

  void _drawHomeBase(Canvas canvas, double x, double y, double sz, Color color) {
    canvas.drawRect(Rect.fromLTWH(x, y, sz, sz), Paint()..color = color.withValues(alpha: 0.30));
    final inner = sz * 0.55;
    final margin = (sz - inner) / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x + margin, y + margin, inner, inner), const Radius.circular(2)),
      Paint()..color = Colors.white.withValues(alpha: 0.25));
    final dotR = inner * 0.15;
    final dotOff = inner * 0.25;
    final dotCx = x + sz / 2;
    final dotCy = y + sz / 2;
    for (final off in [[-dotOff, -dotOff], [dotOff, -dotOff], [-dotOff, dotOff], [dotOff, dotOff]]) {
      canvas.drawCircle(Offset(dotCx + off[0], dotCy + off[1]), dotR,
        Paint()..color = color.withValues(alpha: 0.40));
    }
  }

  @override
  bool shouldRepaint(_LudoArtPainter old) => old.t != t;
}

Widget buildPatchesLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Patches',
      bg: const [Color(0xFF312E81), Color(0xFF1E1B4B)],
      accent: const Color(0xFF818CF8),
      period: const Duration(milliseconds: 3000),
      artBuilder: (t) => _PatchesArtPainter(t),
    );

class _PatchesArtPainter extends CustomPainter {
  final double t;
  const _PatchesArtPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final artSize = w * 0.52;
    final zone = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.40),
      width: artSize,
      height: artSize,
    );
    final rr = RRect.fromRectAndRadius(zone, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(rr);

    canvas.drawRRect(rr, Paint()..color = const Color(0xFFF8FAFC).withValues(alpha: 0.08));

    final cellSize = zone.width / 4;
    final gridPaint = Paint()
      ..color = const Color(0xFFCBD5E1).withValues(alpha: 0.12)
      ..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      canvas.drawLine(Offset(zone.left + i * cellSize, zone.top),
          Offset(zone.left + i * cellSize, zone.bottom), gridPaint);
      canvas.drawLine(Offset(zone.left, zone.top + i * cellSize),
          Offset(zone.right, zone.top + i * cellSize), gridPaint);
    }

    _drawPatch(canvas, zone, cellSize, 0, 0, 2, 1, const Color(0xFFBFDBFE), 0.0, 0.25);
    _drawPatch(canvas, zone, cellSize, 2, 0, 1, 2, const Color(0xFFBBF7D0), 0.25, 0.5);
    _drawPatch(canvas, zone, cellSize, 0, 1, 2, 2, const Color(0xFFDDD6FE), 0.5, 0.75);

    if (t >= 0.75) {
      final p = ((t - 0.75) / 0.25).clamp(0.0, 1.0);
      final scale = Curves.easeOut.transform(p);
      final remaining = [
        [2, 2, 2, 1, const Color(0xFFFECACA)],
        [3, 0, 1, 1, const Color(0xFFFDE68A)],
        [0, 3, 2, 1, const Color(0xFFBBF7D0)],
        [2, 3, 2, 1, const Color(0xFFFDE68A)],
        [3, 1, 1, 1, const Color(0xFFBFDBFE)],
      ];
      for (final r in remaining) {
        final col = r[0] as int;
        final row = r[1] as int;
        final cw = r[2] as int;
        final ch = r[3] as int;
        final color = r[4] as Color;
        final rect = Rect.fromLTWH(
          zone.left + col * cellSize,
          zone.top + row * cellSize,
          cw * cellSize,
          ch * cellSize,
        );
        final center = rect.center;
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.scale(scale, scale);
        canvas.translate(-center.dx, -center.dy);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.deflate(1), const Radius.circular(2)),
          Paint()..color = color.withValues(alpha: 0.55 * scale),
        );
        canvas.restore();
      }

      if (p > 0.5) {
        final glow = (p - 0.5) * 2;
        canvas.drawRRect(
          rr,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.08 * math.sin(glow * math.pi))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
    }

    canvas.restore();

    canvas.drawRRect(
      rr,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  void _drawPatch(Canvas canvas, Rect zone, double cellSize, int col, int row,
      int cw, int ch, Color color, double tStart, double tEnd) {
    if (t < tStart) return;
    final p = ((t - tStart) / (tEnd - tStart)).clamp(0.0, 1.0);
    final scale = Curves.easeOutBack.transform(p);
    final rect = Rect.fromLTWH(
      zone.left + col * cellSize,
      zone.top + row * cellSize,
      cw * cellSize,
      ch * cellSize,
    );
    final center = rect.center;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale, scale);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(1), const Radius.circular(2)),
      Paint()..color = color.withValues(alpha: 0.55),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(1), const Radius.circular(2)),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PatchesArtPainter old) => old.t != t;
}

Widget buildColorConnectLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Color Connect',
      bg: const [Color(0xFF312E81), Color(0xFF1E1B4B)],
      accent: const Color(0xFF818CF8),
      period: const Duration(milliseconds: 3500),
      artBuilder: (t) => _ColorConnectArtPainter(t),
    );

class _ColorConnectArtPainter extends CustomPainter {
  final double t;
  const _ColorConnectArtPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final artSize = w * 0.52;
    final zone = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.40),
      width: artSize,
      height: artSize,
    );
    final rr = RRect.fromRectAndRadius(zone, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(rr);

    canvas.drawRRect(rr, Paint()..color = const Color(0xFFF0F1F8).withValues(alpha: 0.08));

    final cellSize = zone.width / 4;
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      canvas.drawLine(Offset(zone.left + i * cellSize, zone.top),
          Offset(zone.left + i * cellSize, zone.bottom), gridPaint);
      canvas.drawLine(Offset(zone.left, zone.top + i * cellSize),
          Offset(zone.right, zone.top + i * cellSize), gridPaint);
    }

    final dotR = cellSize * 0.22;

    Offset cellCenter(int col, int row) =>
        Offset(zone.left + (col + 0.5) * cellSize, zone.top + (row + 0.5) * cellSize);

    final redA = cellCenter(0, 0);
    final redB = cellCenter(3, 3);
    final blueA = cellCenter(3, 0);
    final blueB = cellCenter(0, 3);

    const redPathCells = [
      [0, 0], [1, 0], [2, 0], [2, 1], [2, 2], [3, 2], [3, 3],
    ];
    const bluePathCells = [
      [3, 0], [3, 1], [2, 1], [1, 1], [0, 1], [0, 2], [0, 3],
    ];

    final redLineT = (t / 0.5).clamp(0.0, 1.0);
    if (redLineT > 0) {
      _drawPathLine(canvas, zone, cellSize, redPathCells, redLineT,
          const Color(0xFFFF6B6B).withValues(alpha: 0.6));
    }

    final blueLineT = ((t - 0.5) / 0.4).clamp(0.0, 1.0);
    if (blueLineT > 0) {
      _drawPathLine(canvas, zone, cellSize, bluePathCells, blueLineT,
          const Color(0xFF4ECDC4).withValues(alpha: 0.6));
    }

    if (t >= 0.9) {
      final glow = math.sin(((t - 0.9) / 0.1) * math.pi);
      _drawPathLine(canvas, zone, cellSize, redPathCells, 1.0,
          const Color(0xFFFF6B6B).withValues(alpha: 0.3 * glow),
          strokeWidth: 3.0);
      _drawPathLine(canvas, zone, cellSize, bluePathCells, 1.0,
          const Color(0xFF4ECDC4).withValues(alpha: 0.3 * glow),
          strokeWidth: 3.0);
    }

    canvas.drawCircle(redA, dotR, Paint()..color = const Color(0xFFFF6B6B));
    canvas.drawCircle(redB, dotR, Paint()..color = const Color(0xFFFF6B6B));
    canvas.drawCircle(blueA, dotR, Paint()..color = const Color(0xFF4ECDC4));
    canvas.drawCircle(blueB, dotR, Paint()..color = const Color(0xFF4ECDC4));

    canvas.restore();

    canvas.drawRRect(
      rr,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  void _drawPathLine(Canvas canvas, Rect zone, double cellSize,
      List<List<int>> cells, double progress, Color color,
      {double strokeWidth = 1.5}) {
    if (cells.length < 2) return;
    final totalSegs = cells.length - 1;
    final drawn = progress * totalSegs;

    final path = Path();
    final first = Offset(
        zone.left + (cells[0][0] + 0.5) * cellSize,
        zone.top + (cells[0][1] + 0.5) * cellSize);
    path.moveTo(first.dx, first.dy);

    for (int i = 0; i < totalSegs; i++) {
      if (i >= drawn) break;
      final seg = (drawn - i).clamp(0.0, 1.0);
      final from = Offset(
          zone.left + (cells[i][0] + 0.5) * cellSize,
          zone.top + (cells[i][1] + 0.5) * cellSize);
      final to = Offset(
          zone.left + (cells[i + 1][0] + 0.5) * cellSize,
          zone.top + (cells[i + 1][1] + 0.5) * cellSize);
      final end = Offset.lerp(from, to, seg)!;
      path.lineTo(end.dx, end.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ColorConnectArtPainter old) => old.t != t;
}

Widget buildArrowPuzzleLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Arrow Puzzle',
      bg: const [Color(0xFF4C1D95), Color(0xFF2E1065)],
      accent: const Color(0xFFA78BFA),
      period: const Duration(milliseconds: 3000),
      artBuilder: (t) => _ArrowPuzzleArtPainter(t),
    );

class _ArrowPuzzleArtPainter extends CustomPainter {
  final double t;
  const _ArrowPuzzleArtPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final artSize = w * 0.52;
    final zone = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.40),
      width: artSize,
      height: artSize,
    );
    final rr = RRect.fromRectAndRadius(zone, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(rr);

    final cx = zone.center.dx;
    final cy = zone.center.dy;
    final arrowSize = artSize * 0.22;

    final arrows = [
      _ArrowDef(Offset(cx, cy - arrowSize * 0.45), -math.pi / 2, const Color(0xFF3B82F6)),
      _ArrowDef(Offset(cx + arrowSize * 0.45, cy), 0, const Color(0xFF7C3AED)),
      _ArrowDef(Offset(cx, cy + arrowSize * 0.45), math.pi / 2, const Color(0xFFF97316)),
      _ArrowDef(Offset(cx - arrowSize * 0.45, cy), math.pi, const Color(0xFF0D9488)),
    ];

    double topAlpha = 1.0;
    double topOffY = 0.0;
    if (t >= 0.2 && t < 0.5) {
      final p = ((t - 0.2) / 0.3).clamp(0.0, 1.0);
      final ease = Curves.easeIn.transform(p);
      topOffY = -artSize * 0.6 * ease;
      topAlpha = 1.0 - ease;
    } else if (t >= 0.5) {
      topAlpha = 0.0;
    }

    double rightAlpha = 1.0;
    double rightOffX = 0.0;
    if (t >= 0.5 && t < 0.8) {
      final p = ((t - 0.5) / 0.3).clamp(0.0, 1.0);
      final ease = Curves.easeIn.transform(p);
      rightOffX = artSize * 0.6 * ease;
      rightAlpha = 1.0 - ease;
    } else if (t >= 0.8) {
      rightAlpha = 0.0;
    }

    if (topAlpha > 0) {
      _drawArrow(canvas, arrows[0].pos.translate(0, topOffY), arrows[0].angle,
          arrowSize, arrows[0].color.withValues(alpha: topAlpha));
    }
    if (rightAlpha > 0) {
      _drawArrow(canvas, arrows[1].pos.translate(rightOffX, 0), arrows[1].angle,
          arrowSize, arrows[1].color.withValues(alpha: rightAlpha));
    }
    _drawArrow(canvas, arrows[2].pos, arrows[2].angle, arrowSize, arrows[2].color);
    _drawArrow(canvas, arrows[3].pos, arrows[3].angle, arrowSize, arrows[3].color);

    canvas.restore();

    canvas.drawRRect(
      rr,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  void _drawArrow(
      Canvas canvas, Offset center, double angle, double s, Color color) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final bodyPath = Path()
      ..moveTo(-s * 0.45, 0)
      ..lineTo(s * 0.15, 0);
    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = color
        ..strokeWidth = s * 0.16
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    final headPath = Path()
      ..moveTo(s * 0.50, 0)
      ..lineTo(s * 0.12, -s * 0.22)
      ..quadraticBezierTo(s * 0.22, 0, s * 0.12, s * 0.22)
      ..close();
    canvas.drawPath(headPath, Paint()..color = color);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ArrowPuzzleArtPainter old) => old.t != t;
}

class _ArrowDef {
  final Offset pos;
  final double angle;
  final Color color;
  const _ArrowDef(this.pos, this.angle, this.color);
}

Widget buildFlappyTapLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Flappy Tap',
      bg: const [Color(0xFF4A9FD4), Color(0xFF71B9E8)],
      accent: const Color(0xFF4ECDC4),
      period: const Duration(milliseconds: 3500),
      artBuilder: (t) => _FlappyTapArtPainter(t),
    );

class _FlappyTapArtPainter extends CustomPainter {
  final double t;
  const _FlappyTapArtPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final artSize = w * 0.52;
    final zone = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.40),
      width: artSize,
      height: artSize,
    );
    final rr = RRect.fromRectAndRadius(zone, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(rr);

    canvas.drawRRect(
        rr, Paint()..color = const Color(0xFF87CEEB).withValues(alpha: 0.15));

    final pipeW = artSize * 0.18;
    final pipeX = zone.left + artSize * 0.55;
    final gapCenter = zone.top + artSize * 0.48;
    final gapH = artSize * 0.28;

    final pipePaint = Paint()..color = const Color(0xFF66BB6A).withValues(alpha: 0.7);
    final pipeEdge = Paint()
      ..color = const Color(0xFF388E3C).withValues(alpha: 0.8);
    final lipH = artSize * 0.04;

    canvas.drawRect(
        Rect.fromLTWH(pipeX, zone.top, pipeW, gapCenter - gapH / 2 - zone.top),
        pipePaint);
    canvas.drawRect(
        Rect.fromLTWH(pipeX - 2, gapCenter - gapH / 2 - lipH, pipeW + 4, lipH),
        pipeEdge);

    canvas.drawRect(
        Rect.fromLTWH(pipeX, gapCenter + gapH / 2, pipeW, zone.bottom - gapCenter - gapH / 2),
        pipePaint);
    canvas.drawRect(
        Rect.fromLTWH(pipeX - 2, gapCenter + gapH / 2, pipeW + 4, lipH),
        pipeEdge);

    final birdR = artSize * 0.06;
    final birdAlpha = t < 0.06
        ? (t / 0.06).clamp(0.0, 1.0)
        : (t > 0.92 ? ((1.0 - t) / 0.08).clamp(0.0, 1.0) : 1.0);

    double birdX, birdY;
    if (t < 0.35) {
      final p = t / 0.35;
      birdX = zone.left + artSize * (-0.05 + 0.55 * p);
      birdY = gapCenter + math.sin(p * math.pi * 3) * artSize * 0.06;
    } else if (t < 0.65) {
      final p = (t - 0.35) / 0.30;
      birdX = zone.left + artSize * (0.50 + 0.20 * p);
      birdY = gapCenter + math.sin(p * math.pi * 2) * artSize * 0.08;
    } else {
      final p = (t - 0.65) / 0.35;
      birdX = zone.left + artSize * (0.70 + 0.35 * p);
      birdY = gapCenter + math.sin(p * math.pi) * artSize * 0.05;
    }

    final wingFlap = math.sin(t * math.pi * 12);
    final birdPaintAlpha = birdAlpha;

    canvas.drawCircle(
      Offset(birdX, birdY),
      birdR,
      Paint()..color = const Color(0xFFFFD700).withValues(alpha: birdPaintAlpha),
    );

    canvas.drawCircle(
      Offset(birdX - birdR * 0.3, birdY - birdR * 0.2),
      birdR * 0.15,
      Paint()..color = const Color(0xFF1A1A2E).withValues(alpha: birdPaintAlpha),
    );

    final beakPath = Path()
      ..moveTo(birdX + birdR * 0.7, birdY)
      ..lineTo(birdX + birdR * 1.4, birdY + birdR * 0.15)
      ..lineTo(birdX + birdR * 0.7, birdY + birdR * 0.3)
      ..close();
    canvas.drawPath(beakPath, Paint()..color = const Color(0xFFFF8C00).withValues(alpha: birdPaintAlpha));

    final wingY = birdY + wingFlap * birdR * 0.3;
    final wingPath = Path()
      ..moveTo(birdX - birdR * 0.3, birdY)
      ..quadraticBezierTo(
          birdX - birdR * 1.0, wingY - birdR * 0.5, birdX - birdR * 0.5, wingY)
      ..lineTo(birdX - birdR * 0.1, birdY + birdR * 0.1)
      ..close();
    canvas.drawPath(
        wingPath, Paint()..color = const Color(0xFFE6B800).withValues(alpha: 0.8 * birdPaintAlpha));

    canvas.restore();

    canvas.drawRRect(
      rr,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_FlappyTapArtPainter old) => old.t != t;
}

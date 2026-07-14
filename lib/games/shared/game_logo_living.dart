import 'dart:math' as math;
import 'package:flutter/material.dart';

Widget buildLivingPreviewLogo({
  required double size,
  required String title,
  required List<Color> bg,
  required Color accent,
  required CustomPainter Function(double t) artBuilder,
  Duration period = const Duration(seconds: 3),
}) {
  return SizedBox(
    width: size,
    height: size,
    child: _LivingPreviewLogo(
      size: size,
      title: title,
      bg: bg,
      accent: accent,
      artBuilder: artBuilder,
      period: period,
    ),
  );
}

class _LivingPreviewLogo extends StatefulWidget {
  final double size;
  final String title;
  final List<Color> bg;
  final Color accent;
  final CustomPainter Function(double t) artBuilder;
  final Duration period;

  const _LivingPreviewLogo({
    required this.size,
    required this.title,
    required this.bg,
    required this.accent,
    required this.artBuilder,
    required this.period,
  });

  @override
  State<_LivingPreviewLogo> createState() => _LivingPreviewLogoState();
}

class _LivingPreviewLogoState extends State<_LivingPreviewLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.period);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour the OS / test "disable animations" flag — without this the
    // perpetual repeat() keeps scheduling frames, so `pumpAndSettle` in widget
    // tests never returns (and reduced-motion users would still see motion).
    final disabled = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disabled) {
      if (_ctrl.isAnimating) _ctrl.stop();
    } else {
      if (!_ctrl.isAnimating) _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _LivingBgPainter(
          bg: widget.bg,
          accent: widget.accent,
          title: widget.title,
          size: widget.size,
          t: _ctrl.value,
        ),
        foregroundPainter: widget.artBuilder(_ctrl.value),
      ),
    );
  }
}

class _LivingBgPainter extends CustomPainter {
  final List<Color> bg;
  final Color accent;
  final String title;
  final double size;
  final double t;

  _LivingBgPainter({
    required this.bg,
    required this.accent,
    required this.title,
    required this.size,
    required this.t,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: bg,
        ).createShader(rect),
    );

    final pulse = math.sin(t * 2 * math.pi);
    final glowAlpha = 0.30 + 0.15 * pulse;
    final glowRadius = w * (0.48 + 0.06 * pulse);
    final glowC = Offset(w * 0.5, h * 0.40);
    canvas.drawCircle(
      glowC,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: glowAlpha),
            accent.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: glowC, radius: glowRadius)),
    );

    for (int i = 0; i < 8; i++) {
      final speed = 0.3 + i * 0.12;
      final phase = i * 1.37;
      final px = w * (0.12 + 0.76 * ((math.sin(t * 2 * math.pi * speed + phase) + 1) / 2));
      final py = h * (0.08 + 0.62 * ((math.cos(t * 2 * math.pi * speed * 0.7 + phase + 0.5) + 1) / 2));
      final pa = 0.08 + 0.07 * math.sin(t * 2 * math.pi * speed * 1.5 + phase);
      final pr = 0.8 + 0.6 * ((i % 3) / 2);
      canvas.drawCircle(
        Offset(px, py),
        pr,
        Paint()..color = Colors.white.withValues(alpha: pa),
      );
    }

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.40),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.07), Colors.transparent],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.40)),
    );

    final shelfTop = h * 0.78;
    canvas.drawRect(
      Rect.fromLTWH(0, shelfTop, w, h - shelfTop),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.32)],
        ).createShader(Rect.fromLTWH(0, shelfTop, w, h - shelfTop)),
    );

    canvas.drawLine(
      Offset(w * 0.12, shelfTop),
      Offset(w * 0.88, shelfTop),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..strokeWidth = 0.5,
    );

    final maxTextW = w * 0.80;
    double fs = this.size * 0.092;
    late TextPainter tp;
    while (true) {
      tp = TextPainter(
        text: TextSpan(
          text: title,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: fs,
            letterSpacing: 0.6,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.60),
                blurRadius: 5,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '\u2026',
      )..layout(maxWidth: maxTextW);
      if (!tp.didExceedMaxLines && tp.width <= maxTextW) break;
      fs -= 1;
      if (fs <= this.size * 0.05) {
        tp.layout(maxWidth: maxTextW);
        break;
      }
    }
    final textX = (w - tp.width) / 2;
    final textY = h - tp.height - h * 0.05;
    tp.paint(canvas, Offset(textX, textY));

    final underlineY = textY + tp.height + h * 0.015;
    double lineStart, lineEnd;
    if (t < 0.15) {
      final p = (t / 0.15).clamp(0.0, 1.0);
      lineStart = textX;
      lineEnd = textX + tp.width * p;
    } else if (t < 0.85) {
      lineStart = textX;
      lineEnd = textX + tp.width;
    } else {
      final p = ((t - 0.85) / 0.15).clamp(0.0, 1.0);
      lineStart = textX + tp.width * p;
      lineEnd = textX + tp.width;
    }
    canvas.drawLine(
      Offset(lineStart, underlineY),
      Offset(lineEnd, underlineY),
      Paint()
        ..color = accent.withValues(alpha: 0.70)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _LivingBgPainter old) =>
      old.t != t || old.title != title || old.accent != accent;
}

// ---------------------------------------------------------------------------
// Sample 1: Chess — rook delivers checkmate
// ---------------------------------------------------------------------------

Widget buildChessLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Chess',
      bg: const [Color(0xFF2D3436), Color(0xFF1A1A2E)],
      accent: const Color(0xFFD4AF37),
      period: const Duration(milliseconds: 3000),
      artBuilder: (t) => _ChessArtPainter(t),
    );

class _ChessArtPainter extends CustomPainter {
  final double t;
  const _ChessArtPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final artSize = w * 0.52;
    final zone = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.40),
      width: artSize,
      height: artSize,
    );

    final boardRR = RRect.fromRectAndRadius(zone, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(boardRR);

    final cellSize = zone.width / 3;
    final light = Paint()..color = const Color(0xFFF0D9B5).withValues(alpha: 0.65);
    final dark = Paint()..color = const Color(0xFFB58863).withValues(alpha: 0.65);

    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        canvas.drawRect(
          Rect.fromLTWH(zone.left + c * cellSize, zone.top + r * cellSize, cellSize, cellSize),
          (r + c) % 2 == 0 ? light : dark,
        );
      }
    }

    // Checkmate scenario:
    // Black king at (0,0), White queen at (0,1), White rook moves (2,2) → (2,0)
    // After move: King trapped — checkmate!

    // Rook movement
    double rookCol = 2, rookRow;
    bool checkmated = false;
    if (t < 0.30) {
      rookRow = 2;
    } else if (t < 0.55) {
      final p = Curves.easeInOutCubic.transform(((t - 0.30) / 0.25).clamp(0.0, 1.0));
      rookRow = 2 - 2 * p;
    } else {
      rookRow = 0;
      checkmated = true;
    }

    // Check/checkmate highlight on king square
    if (t >= 0.50) {
      final pulse = math.sin((t - 0.50) * math.pi * 4) * 0.15 + 0.30;
      canvas.drawRect(
        Rect.fromLTWH(zone.left, zone.top, cellSize, cellSize),
        Paint()..color = Colors.red.withValues(alpha: pulse.clamp(0.0, 1.0)),
      );
    }

    // Move highlight on rook destination
    if (t >= 0.30 && t < 0.70) {
      final p = ((t - 0.30) / 0.40).clamp(0.0, 1.0);
      canvas.drawRect(
        Rect.fromLTWH(zone.left + 2 * cellSize, zone.top, cellSize, cellSize),
        Paint()..color = const Color(0xFFCDD26A).withValues(alpha: 0.35 * p),
      );
    }

    canvas.restore();

    canvas.drawRRect(boardRR, Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0);

    // Draw pieces as circles with unicode chars (matching game style)
    // Black king at (0,0)
    _drawPiece(canvas, zone.left + 0.5 * cellSize, zone.top + 0.5 * cellSize,
      cellSize * 0.34, '♚', false);
    // White queen at (0,1)
    _drawPiece(canvas, zone.left + 0.5 * cellSize, zone.top + 1.5 * cellSize,
      cellSize * 0.34, '♕', true);
    // White rook (animated)
    _drawPiece(canvas, zone.left + (rookCol + 0.5) * cellSize, zone.top + (rookRow + 0.5) * cellSize,
      cellSize * 0.34, '♖', true);

    // Checkmate celebration
    if (checkmated && t >= 0.65) {
      final celebP = ((t - 0.65) / 0.20).clamp(0.0, 1.0);
      final scale = Curves.elasticOut.transform(celebP);
      final cx = zone.left + artSize * 0.5;
      final cy = zone.top + artSize * 0.5;
      // Gold checkmate badge
      final badgeW = artSize * 0.40 * scale;
      final badgeH = artSize * 0.14 * scale;
      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + artSize * 0.35), width: badgeW, height: badgeH),
        const Radius.circular(10));
      canvas.drawRRect(badgeRect, Paint()
        ..color = const Color(0xFFD4AF37).withValues(alpha: 0.90 * celebP));
      final tp = TextPainter(
        text: TextSpan(text: '✓ Mate', style: TextStyle(
          color: Colors.white.withValues(alpha: celebP),
          fontSize: badgeH * 0.55, fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy + artSize * 0.35 - tp.height / 2));
    }
  }

  void _drawPiece(Canvas canvas, double cx, double cy, double r, String symbol, bool isWhite) {
    canvas.drawCircle(Offset(cx, cy + 1.5), r, Paint()..color = Colors.black.withValues(alpha: 0.22));
    final color = isWhite ? const Color(0xFFF5F0E1) : const Color(0xFF2D3436);
    canvas.drawCircle(Offset(cx, cy), r, Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        colors: [Color.lerp(color, Colors.white, 0.25)!, color, Color.lerp(color, Colors.black, 0.15)!],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)));
    canvas.drawCircle(Offset(cx, cy), r * 0.72, Paint()
      ..color = (isWhite ? const Color(0xFFD4AF37) : const Color(0xFF636E72)).withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0);
    canvas.drawCircle(Offset(cx - r * 0.25, cy - r * 0.28), r * 0.12,
      Paint()..color = Colors.white.withValues(alpha: 0.35));
    final tp = TextPainter(
      text: TextSpan(text: symbol, style: TextStyle(
        color: isWhite ? const Color(0xFF3E2723) : const Color(0xFFF0D9B5),
        fontSize: r * 1.1, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_ChessArtPainter old) => old.t != t;
}

// ---------------------------------------------------------------------------
// Sample 2: Snake — slithers and eats apple
// ---------------------------------------------------------------------------

Widget buildSnakeLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Snake',
      bg: const [Color(0xFF115E59), Color(0xFF042F2E)],
      accent: const Color(0xFF2DD4BF),
      period: const Duration(milliseconds: 3500),
      artBuilder: (t) => _SnakeArtPainter(t),
    );

class _SnakeArtPainter extends CustomPainter {
  final double t;
  const _SnakeArtPainter(this.t);

  static const _path = [
    [1, 0], [2, 0], [3, 0], [3, 1], [3, 2], [2, 2], [1, 2], [0, 2], [0, 3], [1, 3],
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

    canvas.drawRRect(
      zoneRR,
      Paint()..color = const Color(0xFFE6FCF5).withValues(alpha: 0.12),
    );

    final cols = 5, rows = 5;
    final cellW = zone.width / cols;
    final cellH = zone.height / rows;

    final dotPaint = Paint()..color = const Color(0xFF20C997).withValues(alpha: 0.08);
    for (int r = 1; r < rows; r++) {
      for (int c = 1; c < cols; c++) {
        canvas.drawCircle(
          Offset(zone.left + c * cellW, zone.top + r * cellH),
          0.8,
          dotPaint,
        );
      }
    }

    final totalSteps = _path.length.toDouble();
    final headProgress = t * totalSteps;
    final headIdx = headProgress.floor().clamp(0, _path.length - 1);
    final headFrac = headProgress - headIdx;
    const snakeLen = 4;

    final applePos = [1, 3];
    bool appleEaten = false;
    for (int i = 0; i <= headIdx; i++) {
      if (_path[i][0] == applePos[0] && _path[i][1] == applePos[1]) {
        appleEaten = true;
        break;
      }
    }

    if (!appleEaten) {
      final ax = zone.left + (applePos[0] + 0.5) * cellW;
      final ay = zone.top + (applePos[1] + 0.5) * cellH;
      final ar = cellW * 0.28;
      canvas.drawCircle(
        Offset(ax, ay),
        ar * 1.6,
        Paint()
          ..color = const Color(0xFFEF4444).withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(Offset(ax, ay), ar, Paint()..color = const Color(0xFFEF4444));
      canvas.drawCircle(
        Offset(ax - ar * 0.25, ay - ar * 0.25),
        ar * 0.2,
        Paint()..color = Colors.white.withValues(alpha: 0.5),
      );
    } else {
      final eatT = ((headProgress - 5) / 1.5).clamp(0.0, 1.0);
      if (eatT > 0 && eatT < 1) {
        final ax = zone.left + (applePos[0] + 0.5) * cellW;
        final ay = zone.top + (applePos[1] + 0.5) * cellH;
        canvas.drawCircle(
          Offset(ax, ay),
          cellW * 0.5 * eatT,
          Paint()
            ..color = const Color(0xFF4ADE80).withValues(alpha: 0.3 * (1 - eatT))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        final tp = TextPainter(
          text: TextSpan(
            text: '+1',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 1 - eatT),
              fontSize: cellW * 0.3,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(ax - tp.width / 2, ay - cellH * 0.5 - eatT * cellH * 0.4));
      }
    }

    // Build smooth segment centers
    final centers = <Offset>[];
    for (int i = 0; i < snakeLen; i++) {
      final segIdx = headIdx - i;
      if (segIdx < 0) continue;
      final nextIdx = segIdx + 1;
      double sx, sy;
      if (i == 0 && nextIdx < _path.length) {
        final cur = _path[segIdx]; final nxt = _path[nextIdx];
        sx = zone.left + (cur[0] + (nxt[0] - cur[0]) * headFrac + 0.5) * cellW;
        sy = zone.top + (cur[1] + (nxt[1] - cur[1]) * headFrac + 0.5) * cellH;
      } else {
        sx = zone.left + (_path[segIdx][0] + 0.5) * cellW;
        sy = zone.top + (_path[segIdx][1] + 0.5) * cellH;
      }
      centers.add(Offset(sx, sy));
    }

    if (centers.length >= 2) {
      double lerp(double a, double b, double t) => a + (b - a) * t;
      final n = centers.length;
      // Build quadratic bezier sub-paths through midpoints
      final segs = <(Offset, Offset, Offset, double)>[];
      for (int i = 0; i < n - 1; i++) {
        final from = i == 0 ? centers[0] : Offset.lerp(centers[i - 1], centers[i], 0.5)!;
        final to = i == n - 2 ? centers.last : Offset.lerp(centers[i], centers[i + 1], 0.5)!;
        final ctl = centers[i];
        final tFromHead = i / (n - 1);
        segs.add((from, ctl, to, tFromHead));
      }

      // Outer dark stroke — tapers from head to tail
      final outer = Paint()
        ..color = const Color(0xFF099268)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      for (final (from, ctl, to, p) in segs) {
        outer.strokeWidth = lerp(cellW * 0.85, cellW * 0.45, p);
        final path = Path()..moveTo(from.dx, from.dy)..quadraticBezierTo(ctl.dx, ctl.dy, to.dx, to.dy);
        canvas.drawPath(path, outer);
      }

      // Inner highlight stroke
      final inner = Paint()
        ..color = const Color(0xFF20C997)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      for (final (from, ctl, to, p) in segs) {
        inner.strokeWidth = lerp(cellW * 0.55, cellW * 0.22, p);
        final path = Path()..moveTo(from.dx, from.dy)..quadraticBezierTo(ctl.dx, ctl.dy, to.dx, to.dy);
        canvas.drawPath(path, inner);
      }
    } else if (centers.isNotEmpty) {
      canvas.drawCircle(centers.first, cellW * 0.42, Paint()..color = const Color(0xFF099268));
      canvas.drawCircle(centers.first, cellW * 0.28, Paint()..color = const Color(0xFF20C997));
    }

    // Head
    if (centers.isNotEmpty) {
      final head = centers.first;
      canvas.drawCircle(head, cellW * 0.44, Paint()..color = const Color(0xFF099268));
      canvas.drawCircle(Offset(head.dx - cellW * 0.08, head.dy - cellW * 0.08),
        cellW * 0.12, Paint()..color = const Color(0xFF20C997).withValues(alpha: 0.45));

      // Eyes
      final segIdx = headIdx;
      final nextIdx = segIdx + 1;
      double dx = 0, dy = 0;
      if (nextIdx < _path.length) {
        dx = (_path[nextIdx][0] - _path[segIdx][0]).toDouble();
        dy = (_path[nextIdx][1] - _path[segIdx][1]).toDouble();
      }
      final eyeOff = cellW * 0.16;
      final eyeR = cellW * 0.08;
      Offset e1, e2;
      if (dx.abs() > dy.abs()) {
        e1 = Offset(head.dx + dx * eyeOff * 0.3, head.dy - eyeOff);
        e2 = Offset(head.dx + dx * eyeOff * 0.3, head.dy + eyeOff);
      } else {
        e1 = Offset(head.dx - eyeOff, head.dy + dy * eyeOff * 0.3);
        e2 = Offset(head.dx + eyeOff, head.dy + dy * eyeOff * 0.3);
      }
      canvas.drawCircle(e1, eyeR, Paint()..color = Colors.white);
      canvas.drawCircle(e2, eyeR, Paint()..color = Colors.white);
      canvas.drawCircle(e1.translate(dx * eyeR * 0.3, dy * eyeR * 0.3),
        eyeR * 0.5, Paint()..color = const Color(0xFF0B2E1A));
      canvas.drawCircle(e2.translate(dx * eyeR * 0.3, dy * eyeR * 0.3),
        eyeR * 0.5, Paint()..color = const Color(0xFF0B2E1A));
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
  bool shouldRepaint(_SnakeArtPainter old) => old.t != t;
}

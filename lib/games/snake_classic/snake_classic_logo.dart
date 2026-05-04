import 'package:flutter/material.dart';

/// Snake Classic brand logo. Renders as a [size]×[size] square that fills the
/// host tile (mosaic_game_tile, game_card, home_screen, etc.).
///
/// Design mirrors the in-game look: a smooth bezier-tapered snake body with
/// a head bulge and an apple drawn in the same red+glow+highlight+leaf
/// style as the playing-field food. The brand stays white-on-green for
/// silhouette legibility at the 60×60 home thumbnail size — using the
/// in-game dark green on its own dark green background would crush the
/// shape.
///
/// Referenced from `GameRegistry`'s `snake_classic` entry as a const tear-off
/// so it can sit inside `const GameInfo(...)`.
Widget buildSnakeLogo(double size) {
  return Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF20C997), Color(0xFF099268)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: ClipRect(
      child: CustomPaint(
        size: Size(size, size),
        painter: _SnakeLogoPainter(),
      ),
    ),
  );
}

class _SnakeLogoPainter extends CustomPainter {
  // Logical 6×6 grid. Snake centers run head→tail (matches the in-game
  // painter's convention so we can reuse the same drawing algorithm).
  // Layout: head at (4, 2) with the body curling down-and-left to the
  // tail at (0, 4) — a clear "S" silhouette aimed at the apple above.
  static const _cells = <(int, int)>[
    (4, 2), // head
    (3, 2),
    (2, 2),
    (2, 3),
    (2, 4),
    (1, 4),
    (0, 4), // tail
  ];

  static const _appleCellX = 5;
  static const _appleCellY = 1;

  // In-game palette so the apple matches the gameplay food exactly.
  static const _foodColor = Color(0xFFEF4444);
  static const _foodGlow  = Color(0xFFFFB4B4);
  static const _leafColor = Color(0xFF22C55E);
  static const _eyeColor  = Color(0xFF1B3A2A);

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static const _textColor = Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    final cs = size.width / 6;

    // Snake centers in pixel space.
    final centers = <Offset>[
      for (final (x, y) in _cells)
        Offset((x + 0.5) * cs, (y + 0.5) * cs),
    ];

    // Sub-segments — each runs from midpoint(i-1, i) through centers[i]
    // (control point) to midpoint(i, i+1). Endpoints clamp to head/tail.
    // This is the same algorithm the in-game painter uses, so logo and
    // gameplay share the same tapered, smoothly-curved silhouette.
    final n = centers.length;
    final segs = <(Offset, Offset, Offset, double)>[];
    for (int i = 0; i < n - 1; i++) {
      final from = i == 0
          ? centers[0]
          : Offset.lerp(centers[i - 1], centers[i], 0.5)!;
      final to = i == n - 2
          ? centers.last
          : Offset.lerp(centers[i], centers[i + 1], 0.5)!;
      final ctl = centers[i];
      segs.add((from, ctl, to, i / (n - 1)));
    }

    // Body — single tapered white stroke for high contrast on the
    // green gradient. Width tapers from 0.82×cs at the head to
    // 0.42×cs at the tail.
    final body = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final (from, ctl, to, p) in segs) {
      body.strokeWidth = _lerp(cs * 0.82, cs * 0.42, p);
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(ctl.dx, ctl.dy, to.dx, to.dy);
      canvas.drawPath(path, body);
    }

    // Head bulge — slightly larger circle for a distinct silhouette.
    final head = centers.first;
    canvas.drawCircle(head, cs * 0.45, Paint()..color = Colors.white);

    // Single eye, oriented toward the apple (up-right).
    canvas.drawCircle(
      Offset(head.dx + cs * 0.15, head.dy - cs * 0.10),
      cs * 0.09,
      Paint()..color = _eyeColor,
    );

    // Apple — same construction as the in-game painter's food: outer
    // glow, body, highlight blip, leaf. Top-right corner of the logo.
    final apple = Offset((_appleCellX + 0.5) * cs, (_appleCellY + 0.5) * cs);
    canvas.drawCircle(
      apple, cs * 0.55,
      Paint()
        ..color = _foodColor.withValues(alpha: 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cs * 0.30),
    );
    canvas.drawCircle(apple, cs * 0.36, Paint()..color = _foodColor);
    canvas.drawCircle(
      Offset(apple.dx - cs * 0.10, apple.dy - cs * 0.10),
      cs * 0.11,
      Paint()..color = _foodGlow.withValues(alpha: 0.85),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(apple.dx + cs * 0.08, apple.dy - cs * 0.34),
        width: cs * 0.22, height: cs * 0.11,
      ),
      Paint()..color = _leafColor,
    );

    // Game name at bottom
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'SNAKE',
        style: TextStyle(
          color: _textColor,
          fontWeight: FontWeight.w900,
          fontSize: size.width * 0.18,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        size.height - textPainter.height - size.height * 0.03,
      ),
    );
  }

  @override
  bool shouldRepaint(_SnakeLogoPainter old) => false;
}

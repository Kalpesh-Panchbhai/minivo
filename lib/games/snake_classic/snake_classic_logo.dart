import 'package:flutter/material.dart';

/// Snake Classic brand logo. Renders as a [size]×[size] square that fills the
/// host tile (mosaic_game_tile, game_card, home_screen, etc.).
///
/// Design: green gradient field with a stylised pixel snake snaking across
/// and a red apple in the corner. `CustomPaint` keeps the elements crisp at
/// any size from the 60×60 home thumbnail to the 96×96 detail-screen badge.
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
    child: CustomPaint(
      size: Size(size, size),
      painter: _SnakeLogoPainter(),
    ),
  );
}

class _SnakeLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Logical 6×6 grid keeps the snake recognisable at any rendered size.
    final cs = size.width / 6;
    final inset = cs * 0.10;

    // Snake body — S-curve from left to right.
    const cells = <(int, int)>[
      (0, 4), (1, 4), (2, 4),  // bottom run
      (2, 3),                   // turn up
      (2, 2), (3, 2), (4, 2),  // middle run (head at end)
    ];

    final body = Paint()..color = Colors.white;
    for (int i = 0; i < cells.length - 1; i++) {
      final (x, y) = cells[i];
      final r = Rect.fromLTWH(
        x * cs + inset, y * cs + inset,
        cs - 2 * inset, cs - 2 * inset,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(cs * 0.24)),
        body,
      );
    }

    // Snake head — same shape but with an eye dot for character.
    final (hx, hy) = cells.last;
    final headRect = Rect.fromLTWH(
      hx * cs + inset, hy * cs + inset,
      cs - 2 * inset, cs - 2 * inset,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(headRect, Radius.circular(cs * 0.24)),
      body,
    );
    canvas.drawCircle(
      Offset((hx + 0.72) * cs, (hy + 0.40) * cs),
      cs * 0.09,
      Paint()..color = const Color(0xFF1B3A2A),
    );

    // Apple — top-right corner with a tiny green leaf.
    final apple = Offset(5 * cs, 1 * cs);
    canvas.drawCircle(
      apple, cs * 0.32,
      Paint()..color = const Color(0xFFEF4444),
    );
    // Highlight blip
    canvas.drawCircle(
      Offset(apple.dx - cs * 0.10, apple.dy - cs * 0.10),
      cs * 0.08,
      Paint()..color = const Color(0xFFFFB4B4),
    );
    // Leaf
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(apple.dx + cs * 0.10, apple.dy - cs * 0.32),
        width: cs * 0.20, height: cs * 0.10,
      ),
      Paint()..color = const Color(0xFF22C55E),
    );
  }

  @override
  bool shouldRepaint(_SnakeLogoPainter old) => false;
}

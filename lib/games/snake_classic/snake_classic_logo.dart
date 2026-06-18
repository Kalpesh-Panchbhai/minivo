import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildSnakeLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Snake Classic',
      bg: const [Color(0xFF115E59), Color(0xFF042F2E)],
      accent: const Color(0xFF2DD4BF),
      art: _snakeArt,
    );

void _snakeArt(Canvas canvas, Rect zone) {
  const n = 5;
  final cs = zone.width / n;
  Offset gridCenter(int x, int y) =>
      Offset(zone.left + (x + 0.5) * cs, zone.top + (y + 0.5) * cs);

  // faint background grid
  final grid = Paint()
    ..color = Colors.white.withValues(alpha: 0.08)
    ..strokeWidth = 1;
  for (int i = 1; i < n; i++) {
    final x = zone.left + i * cs;
    final y = zone.top + i * cs;
    canvas.drawLine(Offset(x, zone.top), Offset(x, zone.bottom), grid);
    canvas.drawLine(Offset(zone.left, y), Offset(zone.right, y), grid);
  }

  // snake body cells, head first → tail last (an S-curve)
  const cells = <(int, int)>[
    (3, 3), // head
    (2, 3),
    (1, 3),
    (1, 2),
    (1, 1),
    (2, 1),
    (3, 1), // tail
  ];
  final centers = [for (final (x, y) in cells) gridCenter(x, y)];

  // body as a single rounded tapered stroke
  final body = Paint()
    ..color = const Color(0xFF4ADE80)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = cs * 0.62;
  final path = Path()..moveTo(centers.first.dx, centers.first.dy);
  for (int i = 1; i < centers.length; i++) {
    path.lineTo(centers[i].dx, centers[i].dy);
  }
  canvas.drawPath(path, body);
  // brighter highlight along the body
  canvas.drawPath(
    path,
    Paint()
      ..color = const Color(0xFFBBF7D0).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = cs * 0.22,
  );

  // head
  final head = centers.first;
  canvas.drawCircle(head, cs * 0.36, Paint()..color = const Color(0xFF22C55E));
  // eye facing right (toward apple)
  canvas.drawCircle(
    Offset(head.dx + cs * 0.14, head.dy - cs * 0.10),
    cs * 0.09,
    Paint()..color = Colors.white,
  );
  canvas.drawCircle(
    Offset(head.dx + cs * 0.17, head.dy - cs * 0.10),
    cs * 0.045,
    Paint()..color = const Color(0xFF0B2E1A),
  );

  // red apple ahead of the head
  final apple = gridCenter(4, 3);
  canvas.drawCircle(
    apple,
    cs * 0.40,
    Paint()
      ..color = const Color(0xFFEF4444).withValues(alpha: 0.30)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, cs * 0.18),
  );
  canvas.drawCircle(apple, cs * 0.26, Paint()..color = const Color(0xFFEF4444));
  canvas.drawCircle(
    Offset(apple.dx - cs * 0.08, apple.dy - cs * 0.08),
    cs * 0.08,
    Paint()..color = const Color(0xFFFFC4C4).withValues(alpha: 0.9),
  );
  // leaf
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(apple.dx + cs * 0.06, apple.dy - cs * 0.26),
      width: cs * 0.18,
      height: cs * 0.09,
    ),
    Paint()..color = const Color(0xFF22C55E),
  );
}

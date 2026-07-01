import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildCheckersLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Checkers',
      bg: const [Color(0xFF44271A), Color(0xFF2A1810)],
      accent: const Color(0xFFCD7F32),
      art: _checkersArt,
    );

void _checkersArt(Canvas canvas, Rect zone) {
  final s = zone.width;
  final cx = zone.center.dx;
  final cy = zone.center.dy;

  final cellSize = s * 0.28;
  final boardLeft = cx - cellSize;
  final boardTop = cy - cellSize * 0.15;
  final light = Paint()..color = const Color(0xFFF5DEB3);
  final dark = Paint()..color = const Color(0xFF6B4226);
  for (int r = 0; r < 2; r++) {
    for (int c = 0; c < 2; c++) {
      final isDark = (r + c) % 2 == 1;
      canvas.drawRect(
        Rect.fromLTWH(boardLeft + c * cellSize, boardTop + r * cellSize,
            cellSize, cellSize),
        isDark ? dark : light,
      );
    }
  }
  canvas.drawRect(
    Rect.fromLTWH(boardLeft, boardTop, cellSize * 2, cellSize * 2),
    Paint()
      ..color = const Color(0xFF3E2015)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.025,
  );

  final discX = cx;
  final discBottomY = boardTop + cellSize * 0.95;
  final discR = s * 0.18;
  final rimW = s * 0.025;

  canvas.drawOval(
    Rect.fromCenter(
        center: Offset(discX, discBottomY + discR * 0.15),
        width: discR * 2.2,
        height: discR * 0.6),
    Paint()..color = Colors.black.withValues(alpha: 0.30),
  );

  final darkDiscY = discBottomY;
  canvas.drawCircle(
      Offset(discX, darkDiscY), discR, Paint()..color = const Color(0xFF1F2937));
  canvas.drawCircle(
    Offset(discX, darkDiscY),
    discR - rimW,
    Paint()
      ..color = const Color(0xFF374151)
      ..style = PaintingStyle.stroke
      ..strokeWidth = rimW,
  );
  canvas.drawCircle(
    Offset(discX - discR * 0.28, darkDiscY - discR * 0.28),
    discR * 0.18,
    Paint()..color = Colors.white.withValues(alpha: 0.20),
  );

  final redDiscY = discBottomY - discR * 0.70;
  canvas.drawCircle(
      Offset(discX, redDiscY), discR, Paint()..color = const Color(0xFFCC3333));
  canvas.drawCircle(
    Offset(discX, redDiscY),
    discR - rimW,
    Paint()
      ..color = const Color(0xFFE55555)
      ..style = PaintingStyle.stroke
      ..strokeWidth = rimW,
  );
  canvas.drawCircle(
    Offset(discX, redDiscY),
    discR * 0.55,
    Paint()
      ..color = const Color(0xFFDD4444)
      ..style = PaintingStyle.stroke
      ..strokeWidth = rimW * 0.7,
  );
  canvas.drawCircle(
    Offset(discX - discR * 0.28, redDiscY - discR * 0.28),
    discR * 0.20,
    Paint()..color = Colors.white.withValues(alpha: 0.35),
  );
}

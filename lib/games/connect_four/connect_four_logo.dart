import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildConnectFourLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Connect Four',
      bg: const [Color(0xFF1E3A5F), Color(0xFF0C1F3A)],
      accent: const Color(0xFF60A5FA),
      art: _connectFourArt,
    );

void _connectFourArt(Canvas canvas, Rect zone) {
  final s = zone.width;
  final h = zone.height;

  const cols = 5;
  const rows = 4;

  final boardPad = s * 0.03;
  final boardRect = Rect.fromLTWH(
    zone.left + boardPad,
    zone.top + boardPad,
    s - boardPad * 2,
    h - boardPad * 2,
  );

  final boardRR = RRect.fromRectAndRadius(boardRect, Radius.circular(s * 0.08));
  canvas.drawRRect(
    boardRR.shift(const Offset(0, 2)),
    Paint()..color = Colors.black.withValues(alpha: 0.30),
  );
  canvas.drawRRect(
    boardRR,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [
          Color(0xFF4A7FE0),
          Color(0xFF3366CC),
          Color(0xFF2952A3),
        ],
      ).createShader(boardRect),
  );
  canvas.drawRRect(
    boardRR,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.015,
  );

  final cellPadX = s * 0.08;
  final cellPadY = h * 0.08;
  final innerW = boardRect.width - cellPadX * 2;
  final innerH = boardRect.height - cellPadY * 2;
  final cellW = innerW / cols;
  final cellH = innerH / rows;
  final holeR = (cellW < cellH ? cellW : cellH) * 0.36;

  // 0=empty, 1=red (player1), 2=yellow (player2)
  // Winning diagonal: red at (3,0),(2,1),(1,2),(0,3) — row,col
  const grid = [
    [0, 0, 0, 1, 2],
    [0, 0, 1, 2, 0],
    [0, 1, 2, 1, 0],
    [1, 2, 2, 0, 0],
  ];

  const winCells = {(3, 0), (2, 1), (1, 2), (0, 3)};

  const red = Color(0xFFE85D75);
  const yellow = Color(0xFFF5C542);
  const emptyDark = Color(0xFF0D2240);
  const emptyLight = Color(0xFF1A3A7A);

  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      final center = Offset(
        boardRect.left + cellPadX + cellW * (c + 0.5),
        boardRect.top + cellPadY + cellH * (r + 0.5),
      );
      final v = grid[r][c];

      if (v == 0) {
        canvas.drawCircle(
          center,
          holeR,
          Paint()
            ..shader = RadialGradient(
              colors: const [emptyDark, emptyLight],
            ).createShader(
                Rect.fromCircle(center: center, radius: holeR)),
        );
        continue;
      }

      final isWin = winCells.contains((r, c));
      final baseColor = v == 1 ? red : yellow;
      final lightColor = v == 1
          ? const Color(0xFFFF8A9E)
          : const Color(0xFFFDE68A);

      if (isWin) {
        canvas.drawCircle(
          center,
          holeR * 1.30,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.55)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }

      canvas.drawCircle(
        center,
        holeR,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.35),
            colors: [lightColor, baseColor],
          ).createShader(
              Rect.fromCircle(center: center, radius: holeR)),
      );

      canvas.drawCircle(
        center,
        holeR,
        Paint()
          ..color = baseColor.withValues(alpha: 0.50)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.008,
      );

      canvas.drawCircle(
        center.translate(-holeR * 0.25, -holeR * 0.25),
        holeR * 0.20,
        Paint()..color = Colors.white.withValues(alpha: 0.70),
      );
    }
  }
}

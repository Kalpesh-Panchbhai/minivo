import 'package:flutter/material.dart';

Widget buildSudokuLogo(double size) {
  return Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF4F46E5), Color(0xFF6366F1), Color(0xFF818CF8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: CustomPaint(
      size: Size(size, size),
      painter: _SudokuLogoPainter(),
    ),
  );
}

class _SudokuLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Subtle radial glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFA5B4FC).withValues(alpha: 0.30),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(w / 2, h * 0.38), radius: w * 0.52));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), glowPaint);

    // Grid occupies top 74% of the logo
    final gridSize = w * 0.78;
    final gridLeft = (w - gridSize) / 2;
    final gridTop  = h * 0.05;
    final cellSize = gridSize / 9;

    // Grid data — a real partially-filled Sudoku snapshot
    // 0 = empty, shown as blank cell
    const grid = [
      [5, 3, 0, 0, 7, 0, 0, 0, 0],
      [6, 0, 0, 1, 9, 5, 0, 0, 0],
      [0, 9, 8, 0, 0, 0, 0, 6, 0],
      [8, 0, 0, 0, 6, 0, 0, 0, 3],
      [4, 0, 0, 8, 0, 3, 0, 0, 1],
      [7, 0, 0, 0, 2, 0, 0, 0, 6],
      [0, 6, 0, 0, 0, 0, 2, 8, 0],
      [0, 0, 0, 4, 1, 9, 0, 0, 5],
      [0, 0, 0, 0, 8, 0, 0, 7, 9],
    ];

    // Cells that form the "highlighted" top-left box (completed)
    const highlightBox = {0, 1, 2}; // box row indices with box col indices 0,1,2

    // Draw cell backgrounds
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final cellRect = Rect.fromLTWH(
          gridLeft + c * cellSize,
          gridTop  + r * cellSize,
          cellSize,
          cellSize,
        );
        final inHighlightBox = highlightBox.contains(r) && highlightBox.contains(c);
        if (inHighlightBox && grid[r][c] != 0) {
          // Completed box — warm accent tint
          canvas.drawRect(
            cellRect,
            Paint()..color = const Color(0xFFA5B4FC).withValues(alpha: 0.32),
          );
        } else if (grid[r][c] != 0) {
          // Given cell — slight white tint
          canvas.drawRect(
            cellRect,
            Paint()..color = Colors.white.withValues(alpha: 0.10),
          );
        }
      }
    }

    // Draw grid lines
    final thinLine = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 0.5;
    final thickLine = Paint()
      ..color = Colors.white.withValues(alpha: 0.70)
      ..strokeWidth = 1.8;

    for (int i = 0; i <= 9; i++) {
      final x = gridLeft + i * cellSize;
      final y = gridTop  + i * cellSize;
      final linePaint = i % 3 == 0 ? thickLine : thinLine;
      // vertical
      canvas.drawLine(Offset(x, gridTop), Offset(x, gridTop + gridSize), linePaint);
      // horizontal
      canvas.drawLine(Offset(gridLeft, y), Offset(gridLeft + gridSize, y), linePaint);
    }

    // Draw numbers
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (grid[r][c] == 0) continue;
        final inHighlightBox = highlightBox.contains(r) && highlightBox.contains(c);
        final numColor = inHighlightBox
            ? Colors.white
            : Colors.white.withValues(alpha: 0.70);
        final tp = TextPainter(
          text: TextSpan(
            text: '${grid[r][c]}',
            style: TextStyle(
              color: numColor,
              fontSize: cellSize * 0.55,
              fontWeight: inHighlightBox ? FontWeight.w900 : FontWeight.w600,
              height: 1,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(
            gridLeft + c * cellSize + (cellSize - tp.width) / 2,
            gridTop  + r * cellSize + (cellSize - tp.height) / 2,
          ),
        );
      }
    }

    // Glow on the highlighted top-left box
    final boxGlow = Paint()
      ..color = const Color(0xFF818CF8).withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(gridLeft - 1, gridTop - 1, cellSize * 3 + 2, cellSize * 3 + 2),
        const Radius.circular(4),
      ),
      boxGlow,
    );

    // "SUDOKU" text at bottom
    _drawGameName(canvas, w, h);
  }

  void _drawGameName(Canvas canvas, double w, double h) {
    void paintText(String text, double fontSize, Color color, double yPos) {
      // Shadow
      final shadow = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: Colors.black.withValues(alpha: 0.35),
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      shadow.paint(canvas, Offset((w - shadow.width) / 2 + 1, yPos + 1.5));

      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((w - tp.width) / 2, yPos));
    }

    paintText('SUDOKU', w * 0.115, Colors.white, h * 0.795);
  }

  @override
  bool shouldRepaint(_SudokuLogoPainter old) => false;
}

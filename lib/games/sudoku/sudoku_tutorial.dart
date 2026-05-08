import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

const _kAccent   = Color(0xFF6366F1);
const _kAccentLt = Color(0xFF818CF8);
const _kBg       = Color(0xFF1E1B4B); // deep indigo dark

List<GameHowToPlayStep> sudokuSteps() => [
      GameHowToPlayStep(
        text: 'Tap a cell — the row, column, and 3×3 box highlight to help you focus.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _SelectCellPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Tap a number on the keypad to place it in the selected cell.',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 2600),
          painter: (t) => _EnterNumberPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Every row, column, and box must contain 1–9 with no repeats. Conflicts flash red.',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 2800),
          painter: (t) => _ConflictPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Your time IS your score — finish faster for a better result. Keep mistakes at zero for a perfect run!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _ScorePainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
    ];

// ── Shared drawing helpers ──────────────────────────────────────────────────

void _drawDarkBg(Canvas canvas, Size size) {
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size.width, size.height),
    Paint()..color = _kBg,
  );
  // Subtle radial glow center
  canvas.drawCircle(
    Offset(size.width / 2, size.height * 0.48),
    size.width * 0.55,
    Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.03),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width / 2, size.height * 0.48),
        radius: size.width * 0.55,
      )),
  );
}

// Draws a compact 9×9 Sudoku grid centered in the canvas.
// Returns: {gridLeft, gridTop, cellSize}.
Map<String, double> _drawGrid(
  Canvas canvas,
  Size size, {
  required double gridSize,
  double topFraction = 0.08,
  Set<int> highlightRows = const {},
  Set<int> highlightCols = const {},
  Set<int> highlightBoxes = const {},
  int selRow = -1,
  int selCol = -1,
  Map<String, String> cells = const {},   // 'r,c' -> digit string
  Map<String, Color> cellColors = const {}, // override fill
}) {
  final cellSize = gridSize / 9;
  final gridLeft = (size.width - gridSize) / 2;
  final gridTop  = size.height * topFraction;

  // Cell backgrounds
  for (int r = 0; r < 9; r++) {
    for (int c = 0; c < 9; c++) {
      final rect = Rect.fromLTWH(
        gridLeft + c * cellSize,
        gridTop  + r * cellSize,
        cellSize,
        cellSize,
      );
      Color fill = Colors.white.withValues(alpha: 0.04);
      final box = (r ~/ 3) * 3 + (c ~/ 3);
      if (cellColors.containsKey('$r,$c')) {
        fill = cellColors['$r,$c']!;
      } else if (r == selRow && c == selCol) {
        fill = _kAccent.withValues(alpha: 0.55);
      } else if (highlightRows.contains(r) || highlightCols.contains(c) || highlightBoxes.contains(box)) {
        fill = _kAccentLt.withValues(alpha: 0.16);
      }
      canvas.drawRect(rect, Paint()..color = fill);
    }
  }

  // Grid lines
  final thin = Paint()
    ..color = Colors.white.withValues(alpha: 0.18)
    ..strokeWidth = 0.5;
  final thick = Paint()
    ..color = Colors.white.withValues(alpha: 0.55)
    ..strokeWidth = 1.4;

  for (int i = 0; i <= 9; i++) {
    final lp = i % 3 == 0 ? thick : thin;
    final x = gridLeft + i * cellSize;
    final y = gridTop  + i * cellSize;
    canvas.drawLine(Offset(x, gridTop), Offset(x, gridTop + gridSize), lp);
    canvas.drawLine(Offset(gridLeft, y), Offset(gridLeft + gridSize, y), lp);
  }

  // Digits
  for (final entry in cells.entries) {
    final parts = entry.key.split(',');
    final r = int.parse(parts[0]);
    final c = int.parse(parts[1]);
    final box = (r ~/ 3) * 3 + (c ~/ 3);
    final isHighlighted = highlightRows.contains(r) ||
        highlightCols.contains(c) ||
        highlightBoxes.contains(box);
    final isSelected = r == selRow && c == selCol;
    Color textColor = isSelected
        ? Colors.white
        : isHighlighted
            ? Colors.white.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.65);
    if (cellColors.containsKey('$r,$c')) {
      textColor = Colors.white;
    }
    final tp = TextPainter(
      text: TextSpan(
        text: entry.value,
        style: TextStyle(
          color: textColor,
          fontSize: cellSize * 0.58,
          fontWeight: FontWeight.w800,
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

  return {'gridLeft': gridLeft, 'gridTop': gridTop, 'cellSize': cellSize};
}

// ── Step 1: Select cell → highlights propagate ──────────────────────────────

class _SelectCellPainter extends CustomPainter {
  final double t;
  const _SelectCellPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawDarkBg(canvas, size);

    // We animate two phases:
    // 0.0–0.35: grid appears, nothing selected
    // 0.35–1.0: cell r=4,c=4 selected, row/col/box highlights spread in

    final phase = t;
    final gridSize = size.width * 0.82;
    final selRow = 4, selCol = 4;

    final highlightAlpha = phase < 0.35 ? 0.0 : ((phase - 0.35) / 0.3).clamp(0.0, 1.0);

    // Highlight spread: only show when selected
    final showSel = phase >= 0.35;

    _drawGrid(
      canvas, size,
      gridSize: gridSize,
      topFraction: 0.06,
      highlightRows: showSel ? {selRow} : {},
      highlightCols: showSel ? {selCol} : {},
      highlightBoxes: showSel ? {(selRow ~/ 3) * 3 + (selCol ~/ 3)} : {},
      selRow: showSel ? selRow : -1,
      selCol: showSel ? selCol : -1,
      cells: const {
        '0,0': '5', '0,1': '3', '0,4': '7',
        '1,0': '6', '1,3': '1', '1,4': '9', '1,5': '5',
        '2,1': '9', '2,2': '8', '2,7': '6',
        '3,0': '8', '3,4': '6', '3,8': '3',
        '4,0': '4', '4,3': '8', '4,5': '3', '4,8': '1',
        '5,0': '7', '5,4': '2', '5,8': '6',
      },
    );

    // Label at bottom
    if (highlightAlpha > 0) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'ROW  •  COL  •  BOX',
          style: TextStyle(
            color: _kAccentLt.withValues(alpha: highlightAlpha * 0.85),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.90));
    }
  }

  @override
  bool shouldRepaint(covariant _SelectCellPainter old) => old.t != t;
}

// ── Step 2: Tap a number → it appears in the cell ──────────────────────────

class _EnterNumberPainter extends CustomPainter {
  final double t;
  const _EnterNumberPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawDarkBg(canvas, size);

    // Phase 0.0–0.38: grid shown, cell selected but empty
    // Phase 0.38–0.60: button "7" tap ripple
    // Phase 0.60–1.00: "7" pops into cell with scale bounce

    const selRow = 2, selCol = 6;
    const tapKeyIdx = 6; // 0-based → digit 7

    final gridSize = size.width * 0.76;
    final showDigit = t >= 0.60;

    // Draw grid WITHOUT the entered digit — we draw it separately with scale
    final info = _drawGrid(
      canvas, size,
      gridSize: gridSize,
      topFraction: 0.04,
      highlightRows: {selRow},
      highlightCols: {selCol},
      highlightBoxes: {(selRow ~/ 3) * 3 + (selCol ~/ 3)},
      selRow: selRow,
      selCol: selCol,
      cells: const {
        '0,0': '5', '0,1': '3', '0,4': '7',
        '1,0': '6', '1,3': '1', '1,4': '9', '1,5': '5',
        '2,1': '9', '2,2': '8', '2,7': '6',
        // selRow,selCol intentionally omitted — drawn below with transform
      },
    );

    final gridLeft = info['gridLeft']!;
    final gridTop  = info['gridTop']!;
    final cellSize = info['cellSize']!;

    // Draw entered digit with scale-pop transform
    if (showDigit) {
      final popT = ((t - 0.60) / 0.18).clamp(0.0, 1.0);
      final scale = 1.0 + math.sin(popT * math.pi) * 0.38;
      final cx = gridLeft + selCol * cellSize + cellSize / 2;
      final cy = gridTop  + selRow * cellSize + cellSize / 2;

      canvas.save();
      canvas.translate(cx, cy);
      canvas.scale(scale);
      final tp = TextPainter(
        text: const TextSpan(
          text: '7',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    // Keypad row at bottom
    final keypadY = size.height * 0.87;
    final btnSize = (size.width - 20) / 9;
    const keypadLeft = 10.0;

    for (int i = 0; i < 9; i++) {
      final digit = i + 1;
      final bx = keypadLeft + i * btnSize + btnSize / 2;
      final isTapped = i == tapKeyIdx && t >= 0.30 && t < 0.60;
      final tapT = isTapped ? ((t - 0.30) / 0.12).clamp(0.0, 1.0) : 0.0;
      final isActivated = i == tapKeyIdx && showDigit;

      final btnAlpha = isActivated ? 0.55 : (0.18 + tapT * 0.28);

      final rrect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(bx, keypadY), width: btnSize - 3, height: btnSize - 1),
        const Radius.circular(5),
      );
      canvas.drawRRect(rrect, Paint()..color = _kAccent.withValues(alpha: btnAlpha));

      if (isTapped) {
        final rippleR = btnSize * 0.5 + tapT * btnSize * 0.5;
        canvas.drawCircle(
          Offset(bx, keypadY),
          rippleR,
          Paint()
            ..color = _kAccentLt.withValues(alpha: (1 - tapT) * 0.40)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }

      final tp = TextPainter(
        text: TextSpan(
          text: '$digit',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75 + tapT * 0.25),
            fontSize: btnSize * 0.52,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(bx - tp.width / 2, keypadY - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _EnterNumberPainter old) => old.t != t;
}

// ── Step 3: Conflict — two same digits in same row flash red ────────────────

class _ConflictPainter extends CustomPainter {
  final double t;
  const _ConflictPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawDarkBg(canvas, size);

    // Phase 0.0–0.45: grid shown with "5" in row 0 col 0 and col 3 (conflict)
    // Phase 0.45–0.72: both cells flash red
    // Phase 0.72–1.0: fade back, eraser label fades in

    const conflictRow = 0;
    const conflictCols = [0, 3];

    final flashPhase = t >= 0.45 && t < 0.72 ? (t - 0.45) / 0.27 : 0.0;
    final flashAlpha = math.sin(flashPhase * math.pi * 3).abs() * 0.7;

    final Map<String, Color> cellColors = {};
    if (flashAlpha > 0) {
      for (final c in conflictCols) {
        cellColors['$conflictRow,$c'] =
            const Color(0xFFEF4444).withValues(alpha: flashAlpha);
      }
    }

    _drawGrid(
      canvas, size,
      gridSize: size.width * 0.82,
      topFraction: 0.06,
      cells: const {
        '0,0': '5', '0,1': '3', '0,3': '5', '0,4': '7',
        '1,0': '6', '1,3': '1', '1,4': '9', '1,5': '5',
        '2,1': '9', '2,2': '8', '2,7': '6',
        '3,0': '8', '3,4': '6', '3,8': '3',
      },
      cellColors: cellColors,
    );

    // Label
    final labelAlpha = flashAlpha > 0
        ? flashAlpha
        : (t > 0.72 ? ((t - 0.72) / 0.28).clamp(0.0, 1.0) : 0.0);
    if (labelAlpha > 0) {
      final isConflict = flashAlpha > 0;
      final label = isConflict ? '× CONFLICT' : '× COUNTS AS A MISTAKE';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: const Color(0xFFEF4444).withValues(alpha: labelAlpha * 0.90),
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.90));
    }
  }

  @override
  bool shouldRepaint(covariant _ConflictPainter old) => old.t != t;
}

// ── Step 4: Timer is the score — finish fast ───────────────────────────────

class _ScorePainter extends CustomPainter {
  final double t;
  const _ScorePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawDarkBg(canvas, size);

    final cx = size.width / 2;

    // Timer counts up — shows time pressure
    final seconds = (t * 90).floor();
    final mm = seconds ~/ 60;
    final ss = seconds % 60;
    final timeStr = '${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';

    // Mistakes accumulate mid-way through to show penalty
    final mistakes = t > 0.55 ? (((t - 0.55) / 0.15).clamp(0.0, 1.0) * 2).floor() : 0;

    // HUD pill — two columns: TIME | MISTAKES
    const pillH = 46.0;
    const pillW = 140.0;
    final pillTop = size.height * 0.08;
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, pillTop + pillH / 2), width: pillW, height: pillH),
      const Radius.circular(14),
    );
    canvas.drawRRect(pillRect, Paint()..color = Colors.white.withValues(alpha: 0.10));
    canvas.drawRRect(pillRect, Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0);

    void drawPillCol(String label, String value, double colCx, Color valColor) {
      final ltp = TextPainter(
        text: TextSpan(text: label, style: TextStyle(
          color: Colors.white.withValues(alpha: 0.45),
          fontSize: 7, fontWeight: FontWeight.w700, letterSpacing: 0.8,
        )),
        textDirection: TextDirection.ltr,
      )..layout();
      ltp.paint(canvas, Offset(colCx - ltp.width / 2, pillTop + 7));

      final vtp = TextPainter(
        text: TextSpan(text: value, style: TextStyle(
          color: valColor,
          fontSize: 14, fontWeight: FontWeight.w900, height: 1,
        )),
        textDirection: TextDirection.ltr,
      )..layout();
      vtp.paint(canvas, Offset(colCx - vtp.width / 2, pillTop + 20));
    }

    // Single divider between TIME and MISTAKES
    final divX = cx;
    final divPaint = Paint()..color = Colors.white.withValues(alpha: 0.15)..strokeWidth = 1;
    canvas.drawLine(Offset(divX, pillTop + 8), Offset(divX, pillTop + pillH - 8), divPaint);

    // Time turns orange when mistakes happen
    final timeColor = mistakes > 0
        ? const Color(0xFFFBBF24)
        : Colors.white;
    drawPillCol('TIME', timeStr, cx - pillW / 4, timeColor);
    drawPillCol('MISTAKES', '$mistakes', cx + pillW / 4,
        mistakes > 0 ? const Color(0xFFEF4444) : Colors.white);

    // Grid below (mostly complete)
    _drawGrid(
      canvas, size,
      gridSize: size.width * 0.78,
      topFraction: 0.40,
      cells: const {
        '0,0': '5', '0,1': '3', '0,2': '4', '0,3': '6', '0,4': '7', '0,5': '8', '0,6': '9', '0,7': '1', '0,8': '2',
        '1,0': '6', '1,1': '7', '1,2': '2', '1,3': '1', '1,4': '9', '1,5': '5', '1,6': '3', '1,7': '4', '1,8': '8',
        '2,0': '1', '2,1': '9', '2,2': '8', '2,3': '3', '2,4': '4', '2,5': '2', '2,6': '5', '2,7': '6', '2,8': '7',
        '3,0': '8', '3,1': '5', '3,2': '9', '3,3': '7', '3,4': '6', '3,5': '1', '3,6': '4', '3,7': '2', '3,8': '3',
        '4,0': '4', '4,1': '2', '4,2': '6', '4,3': '8', '4,4': '5', '4,5': '3', '4,6': '7', '4,7': '9', '4,8': '1',
        '5,0': '7', '5,1': '1', '5,2': '3', '5,3': '9', '5,4': '2', '5,5': '4', '5,6': '8', '5,7': '5', '5,8': '6',
        '6,0': '9', '6,1': '6', '6,2': '1', '6,3': '5', '6,4': '3', '6,5': '7', '6,6': '2', '6,7': '8', '6,8': '4',
        '7,0': '2', '7,1': '8', '7,2': '7', '7,3': '4', '7,4': '1', '7,5': '9', '7,6': '6', '7,7': '3', '7,8': '5',
        '8,0': '3', '8,1': '4', '8,2': '5', '8,3': '2', '8,4': '8', '8,5': '6', '8,6': '1', '8,7': '7', '8,8': '9',
      },
    );

    // "COMPLETE!" banner pulsing at very end
    if (t > 0.85) {
      final bannerAlpha = ((t - 0.85) / 0.15).clamp(0.0, 1.0);
      final pulse = 1.0 + math.sin(t * math.pi * 6) * 0.04;
      final tp = TextPainter(
        text: TextSpan(
          text: '🎉  COMPLETE!',
          style: TextStyle(
            color: const Color(0xFF4ADE80).withValues(alpha: bannerAlpha),
            fontSize: 13 * pulse,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.90));
    }
  }

  @override
  bool shouldRepaint(covariant _ScorePainter old) => old.t != t;
}

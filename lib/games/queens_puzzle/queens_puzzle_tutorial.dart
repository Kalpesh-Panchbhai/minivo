import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

const _kAccent = Color(0xFFD4A0FF);
const _kQueenYellow = Color(0xFFFFD43B);
const _kGreen = Color(0xFF22C55E);
const _kRed = Color(0xFFEF4444);

const _regionColors = [
  Color(0xFFFF6B6B),
  Color(0xFF51CF66),
  Color(0xFF339AF0),
  Color(0xFFFFD43B),
  Color(0xFFCC5DE8),
];

// Real 5x5 board from level 3 easy.
// Queens at: row 0→col 1, row 1→col 3, row 2→col 0, row 3→col 4, row 4→col 2
const _n = 5;
const _queenPositions = [
  [0, 1],
  [1, 3],
  [2, 0],
  [3, 4],
  [4, 2],
];

// Region assignments for each cell (row-major).
// region 0: (0,1)               — queen region
// region 1: (0,2),(0,3),(0,4),(1,2),(1,3),(1,4),(2,3),(2,4),(3,3)
// region 2: (0,0),(2,0)         — queen region
// region 3: (3,0),(3,1),(3,2),(3,4),(4,0),(4,1)
// region 4: (4,2),(4,3),(4,4)
const _regionOf = [
  2, 0, 1, 1, 1,
  2, 2, 1, 1, 1,
  2, 1, 1, 1, 3,
  3, 3, 3, 3, 3,
  3, 3, 4, 4, 4,
];

// A WRONG placement for the "conflict" demo: put two queens in same row (row 1)
// Queen in region 0 placed at (0,1) ✓
// Queen in region 1 placed at (1,2) — but queen in region 2 also needs row 1...
// This shows adjacent queens touching diagonally.
const _wrongQueen0 = [0, 1]; // region 0 — correct
const _wrongQueen1 = [1, 2]; // region 1 — wrong: adjacent diag to (0,1)

List<GameHowToPlayStep> queensPuzzleSteps() => [
      GameHowToPlayStep(
        text:
            'Each colored region needs exactly one queen. Tap a cell to place.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 5),
          painter: (t) => _QueensTutorialPainter(t, step: 0),
          canvasSize: const Size(210, 210),
        ),
      ),
      GameHowToPlayStep(
        text: 'No two queens may share a row or column.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _QueensTutorialPainter(t, step: 1),
          canvasSize: const Size(210, 210),
        ),
      ),
      GameHowToPlayStep(
        text:
            'Queens cannot touch — not even 1 cell diagonally! '
            'But 2+ cells apart on the same diagonal is fine.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _QueensTutorialPainter(t, step: 2),
          canvasSize: const Size(210, 210),
        ),
      ),
      GameHowToPlayStep(
        text:
            'Long-press to mark cells with ✕ to help you eliminate spots. '
            'Place all queens correctly to win!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 4),
          painter: (t) => _QueensTutorialPainter(t, step: 3),
          canvasSize: const Size(210, 210),
        ),
      ),
    ];

class _QueensTutorialPainter extends CustomPainter {
  final double t;
  final int step;

  _QueensTutorialPainter(this.t, {required this.step});

  @override
  void paint(Canvas canvas, Size size) {
    const cellS = 32.0, gap = 2.5;
    final totalW = _n * cellS + (_n - 1) * gap;
    final totalH = _n * cellS + (_n - 1) * gap;
    final ox = (size.width - totalW) / 2;
    final oy = (size.height - totalH) / 2;

    Rect cellRect(int r, int c) => Rect.fromLTWH(
          ox + c * (cellS + gap),
          oy + r * (cellS + gap),
          cellS,
          cellS,
        );

    // Draw all region cells
    for (int r = 0; r < _n; r++) {
      for (int c = 0; c < _n; c++) {
        final reg = _regionOf[r * _n + c];
        final rect = cellRect(r, c);
        final rr = RRect.fromRectAndRadius(rect, const Radius.circular(5));
        canvas.drawRRect(
            rr, Paint()..color = _regionColors[reg].withValues(alpha: 0.22));
        canvas.drawRRect(
            rr,
            Paint()
              ..color = _regionColors[reg].withValues(alpha: 0.50)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2);
      }
    }

    switch (step) {
      case 0:
        _paintStep0(canvas, cellRect, cellS, ox, totalW, oy);
      case 1:
        _paintStep1(canvas, cellRect, cellS, ox, totalW, oy, totalH);
      case 2:
        _paintStep2(canvas, cellRect, cellS);
      case 3:
        _paintStep3(canvas, cellRect, cellS, ox, totalW, oy);
    }
  }

  // Step 0: Animate placing queens one at a time into their regions
  void _paintStep0(Canvas canvas, Rect Function(int, int) cellRect,
      double cellS, double ox, double totalW, double oy) {
    final queensToShow = (t * (_queenPositions.length + 1))
        .floor()
        .clamp(0, _queenPositions.length);

    for (int i = 0; i < queensToShow; i++) {
      final qr = _queenPositions[i][0], qc = _queenPositions[i][1];
      _drawQueen(canvas, cellRect(qr, qc).center, cellS);
    }

    // Animated finger tapping the next queen position
    if (queensToShow < _queenPositions.length) {
      final nextQ = _queenPositions[queensToShow];
      final ctr = cellRect(nextQ[0], nextQ[1]).center;
      final frac = (t * (_queenPositions.length + 1)) % 1.0;

      // Finger approaches from below
      final fingerY = ctr.dy + 18 * (1 - frac);
      final fingerAlpha = frac.clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(ctr.dx, fingerY),
        5,
        Paint()..color = Colors.white.withValues(alpha: fingerAlpha),
      );
      canvas.drawCircle(
        Offset(ctr.dx, fingerY),
        5,
        Paint()
          ..color = _kAccent.withValues(alpha: fingerAlpha * 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // Pulse ring around target cell
      final pulseR = cellS * 0.35 + cellS * 0.06 * math.sin(frac * math.pi);
      canvas.drawCircle(
        ctr,
        pulseR,
        Paint()
          ..color = _kAccent.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    // "1 queen per region" label
    final placed = queensToShow.clamp(0, _n);
    _drawLabel(canvas, '$placed/$_n placed', ox + totalW / 2, oy - 12,
        _kAccent, 10);
  }

  // Step 1: Show all queens placed, highlight row & column for one queen at a time
  void _paintStep1(Canvas canvas, Rect Function(int, int) cellRect,
      double cellS, double ox, double totalW, double oy, double totalH) {
    // Draw all queens
    for (final q in _queenPositions) {
      _drawQueen(canvas, cellRect(q[0], q[1]).center, cellS);
    }

    // Cycle through queens, highlighting their row & column
    final idx = (t * _queenPositions.length).floor().clamp(0, _n - 1);
    final qr = _queenPositions[idx][0], qc = _queenPositions[idx][1];

    // Highlight row
    for (int c = 0; c < _n; c++) {
      if (c == qc) continue;
      final rect = cellRect(qr, c);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        Paint()..color = _kAccent.withValues(alpha: 0.18),
      );
    }
    // Highlight column
    for (int r = 0; r < _n; r++) {
      if (r == qr) continue;
      final rect = cellRect(r, qc);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        Paint()..color = _kAccent.withValues(alpha: 0.18),
      );
    }

    // Draw "only 1" indicator arrows
    final queenCenter = cellRect(qr, qc).center;
    _drawArrowLine(canvas, queenCenter, Offset(queenCenter.dx, oy - 2), _kAccent);
    _drawArrowLine(canvas, queenCenter,
        Offset(ox - 4, queenCenter.dy), _kAccent);

    _drawLabel(canvas, 'Only one per row & column', ox + totalW / 2,
        oy + totalH + 10, _kAccent, 9);
  }

  // Step 2: Three phases showing the diagonal rule:
  //   0.0–0.33  → 1-cell diagonal = WRONG (red conflict)
  //   0.33–0.66 → 2+ cells diagonal = OK (green, allowed)
  //   0.66–1.0  → full correct solution with safe zones
  void _paintStep2(Canvas canvas, Rect Function(int, int) cellRect,
      double cellS) {
    if (t < 0.33) {
      // Phase 1: Two queens 1 cell apart diagonally — NOT ALLOWED
      final q0 = _wrongQueen0, q1 = _wrongQueen1;
      _drawQueen(canvas, cellRect(q0[0], q0[1]).center, cellS);
      _drawQueen(canvas, cellRect(q1[0], q1[1]).center, cellS);

      // Highlight all 8 neighbors of queen 0 as blocked
      final qr = q0[0], qc = q0[1];
      for (int dr = -1; dr <= 1; dr++) {
        for (int dc = -1; dc <= 1; dc++) {
          if (dr == 0 && dc == 0) continue;
          final nr = qr + dr, nc = qc + dc;
          if (nr < 0 || nr >= _n || nc < 0 || nc >= _n) continue;
          final rect = cellRect(nr, nc);
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(5)),
            Paint()..color = _kRed.withValues(alpha: 0.18),
          );
          final ctr = rect.center;
          final xs = cellS * 0.12;
          final xPaint = Paint()
            ..color = _kRed.withValues(alpha: 0.45)
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(Offset(ctr.dx - xs, ctr.dy - xs),
              Offset(ctr.dx + xs, ctr.dy + xs), xPaint);
          canvas.drawLine(Offset(ctr.dx + xs, ctr.dy - xs),
              Offset(ctr.dx - xs, ctr.dy + xs), xPaint);
        }
      }

      // Pulsing red conflict line
      final c0 = cellRect(q0[0], q0[1]).center;
      final c1 = cellRect(q1[0], q1[1]).center;
      final pulse = 0.6 + 0.4 * math.sin(t * 6 * math.pi);
      canvas.drawLine(c0, c1,
        Paint()
          ..color = _kRed.withValues(alpha: pulse * 0.7)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );

      _drawBadge(canvas, c1.translate(cellS * 0.55, -cellS * 0.4),
          '✕ 1 CELL', _kRed, 8);
    } else if (t < 0.66) {
      // Phase 2: Two queens 2+ cells apart diagonally — ALLOWED
      // Use queens at (0,1) and (2,3) — 2 cells apart diagonally
      const okQ0 = [0, 1];
      const okQ1 = [2, 3];
      _drawQueen(canvas, cellRect(okQ0[0], okQ0[1]).center, cellS);
      _drawQueen(canvas, cellRect(okQ1[0], okQ1[1]).center, cellS);

      // Draw a green dashed-style line between them
      final c0 = cellRect(okQ0[0], okQ0[1]).center;
      final c1 = cellRect(okQ1[0], okQ1[1]).center;
      canvas.drawLine(c0, c1,
        Paint()
          ..color = _kGreen.withValues(alpha: 0.45)
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round,
      );

      // Green rings around both queens
      canvas.drawCircle(c0, cellS * 0.38,
        Paint()
          ..color = _kGreen.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
      canvas.drawCircle(c1, cellS * 0.38,
        Paint()
          ..color = _kGreen.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );

      // "2 cells" distance label at midpoint
      final mid = Offset((c0.dx + c1.dx) / 2, (c0.dy + c1.dy) / 2);
      _drawBadge(canvas, mid.translate(cellS * 0.55, -cellS * 0.15),
          '✓ 2+ CELLS', _kGreen, 8);
    } else {
      // Phase 3: Full correct solution with safe zone highlight
      for (final q in _queenPositions) {
        _drawQueen(canvas, cellRect(q[0], q[1]).center, cellS);
      }

      final focus = ((t - 0.66) * 3 * _n).floor().clamp(0, _n - 1);
      final qr = _queenPositions[focus][0], qc = _queenPositions[focus][1];
      for (int dr = -1; dr <= 1; dr++) {
        for (int dc = -1; dc <= 1; dc++) {
          if (dr == 0 && dc == 0) continue;
          final nr = qr + dr, nc = qc + dc;
          if (nr < 0 || nr >= _n || nc < 0 || nc >= _n) continue;
          final hasOtherQueen =
              _queenPositions.any((q) => q[0] == nr && q[1] == nc);
          if (hasOtherQueen) continue;
          final rect = cellRect(nr, nc);
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(5)),
            Paint()..color = _kGreen.withValues(alpha: 0.15),
          );
        }
      }
      canvas.drawCircle(
        cellRect(qr, qc).center, cellS * 0.38,
        Paint()
          ..color = _kGreen.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
      _drawBadge(canvas,
          cellRect(qr, qc).center.translate(cellS * 0.5, -cellS * 0.4),
          '✓ SAFE', _kGreen, 8);
    }
  }

  // Step 3: Show X-markers being placed to eliminate cells, then final solution
  void _paintStep3(Canvas canvas, Rect Function(int, int) cellRect,
      double cellS, double ox, double totalW, double oy) {
    // X markers that a player might place to eliminate impossible cells
    const xPositions = [
      [0, 0], // same row as queen (0,1)
      [0, 2], // adjacent to queen (0,1)
      [1, 0], // region 2, but row/col conflict
      [1, 2], // adjacent to (0,1) diagonally
      [2, 1], // adjacent to (2,0) and same col as (0,1)
    ];

    final xCount = (t * (xPositions.length + _n + 1))
        .floor()
        .clamp(0, xPositions.length);
    final queenCount =
        ((t * (xPositions.length + _n + 1)) - xPositions.length)
            .floor()
            .clamp(0, _n);

    // Draw X markers
    for (int i = 0; i < xCount; i++) {
      final xr = xPositions[i][0], xc = xPositions[i][1];
      final ctr = cellRect(xr, xc).center;
      final xs = cellS * 0.18;
      final xPaint = Paint()
        ..color = const Color(0xFF6B7280).withValues(alpha: 0.55)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(ctr.dx - xs, ctr.dy - xs),
          Offset(ctr.dx + xs, ctr.dy + xs), xPaint);
      canvas.drawLine(Offset(ctr.dx + xs, ctr.dy - xs),
          Offset(ctr.dx - xs, ctr.dy + xs), xPaint);
    }

    // Draw queens placed so far
    for (int i = 0; i < queenCount; i++) {
      final qr = _queenPositions[i][0], qc = _queenPositions[i][1];
      _drawQueen(canvas, cellRect(qr, qc).center, cellS);
    }

    // Win badge when all queens are placed
    if (queenCount >= _n) {
      final pulse = 0.85 + 0.15 * math.sin(t * math.pi * 6);
      final bc = Offset(ox + totalW - 4, oy - 4);
      canvas.save();
      canvas.translate(bc.dx, bc.dy);
      canvas.scale(pulse);
      canvas.drawCircle(Offset.zero, 13, Paint()..color = _kGreen);
      final check = Path()
        ..moveTo(-5, 0)
        ..lineTo(-1.5, 4)
        ..lineTo(6, -4);
      canvas.drawPath(
          check,
          Paint()
            ..color = Colors.white
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke);
      canvas.restore();
    }
  }

  // ── HELPERS ──

  void _drawQueen(Canvas canvas, Offset ctr, double cellS) {
    final cr = cellS * 0.30;
    canvas.drawCircle(
        ctr.translate(0, 1), cr, Paint()..color = Colors.black.withValues(alpha: 0.15));
    canvas.drawCircle(ctr, cr, Paint()..color = _kQueenYellow);
    _drawCrown(canvas, ctr, cr * 0.7);
  }

  void _drawCrown(Canvas canvas, Offset ctr, double s) {
    final path = Path();
    final cx = ctr.dx, cy = ctr.dy;
    path.moveTo(cx - s, cy + s * 0.35);
    path.lineTo(cx - s, cy - s * 0.2);
    path.lineTo(cx - s * 0.5, cy + s * 0.1);
    path.lineTo(cx, cy - s * 0.55);
    path.lineTo(cx + s * 0.5, cy + s * 0.1);
    path.lineTo(cx + s, cy - s * 0.2);
    path.lineTo(cx + s, cy + s * 0.35);
    path.close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  void _drawLabel(
      Canvas canvas, String text, double cx, double cy, Color color, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: fontSize,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  void _drawBadge(
      Canvas canvas, Offset pos, String text, Color color, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
          height: 1,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final pad = 4.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: pos, width: tp.width + pad * 2, height: tp.height + pad * 2),
      const Radius.circular(6),
    );
    canvas.drawRRect(rect, Paint()..color = color);
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
  }

  void _drawArrowLine(Canvas canvas, Offset from, Offset to, Color color) {
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = color.withValues(alpha: 0.25)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_QueensTutorialPainter old) => true;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

const _kSun = Color(0xFFFFB300);
const _kMoon = Color(0xFF5C6BC0);
const _kGrid = Color(0xFFD4C5A0);
const _kCellBg = Color(0xFFFFF8E7);
const _kGreen = Color(0xFF22C55E);
const _kRed = Color(0xFFEF4444);

const _n = 6;
const _demoSize = Size(200, 200);

List<GameHowToPlayStep> tangoTutorialSteps() => [
      GameHowToPlayStep(
        text:
            'Tap a cell to place a Sun ☀️. Tap again for Moon 🌙. '
            'Tap once more to clear.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 4),
          painter: (t) => _TangoPainter(t, step: 0),
          canvasSize: _demoSize,
        ),
      ),
      GameHowToPlayStep(
        text:
            'Every row and column must have an equal number of Suns and Moons.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 5),
          painter: (t) => _TangoPainter(t, step: 1),
          canvasSize: _demoSize,
        ),
      ),
      GameHowToPlayStep(
        text:
            'No three identical symbols in a row — horizontally or vertically!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 5),
          painter: (t) => _TangoPainter(t, step: 2),
          canvasSize: _demoSize,
        ),
      ),
      GameHowToPlayStep(
        text:
            '"=" means the two cells must match. "×" means they must differ.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 5),
          painter: (t) => _TangoPainter(t, step: 3),
          canvasSize: _demoSize,
        ),
      ),
    ];

class _TangoPainter extends CustomPainter {
  final double t;
  final int step;

  _TangoPainter(this.t, {required this.step});

  static const _cellS = 26.0;
  static const _gap = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final totalW = _n * _cellS + (_n - 1) * _gap;
    final totalH = _n * _cellS + (_n - 1) * _gap;
    final ox = (size.width - totalW) / 2;
    final oy = (size.height - totalH) / 2;

    Rect cellRect(int r, int c) => Rect.fromLTWH(
          ox + c * (_cellS + _gap),
          oy + r * (_cellS + _gap),
          _cellS,
          _cellS,
        );

    switch (step) {
      case 0:
        _paintStep0(canvas, size, cellRect, ox, oy, totalW, totalH);
      case 1:
        _paintStep1(canvas, size, cellRect, ox, oy, totalW, totalH);
      case 2:
        _paintStep2(canvas, size, cellRect, ox, oy, totalW, totalH);
      case 3:
        _paintStep3(canvas, size, cellRect, ox, oy, totalW, totalH);
    }
  }

  void _drawGrid(Canvas canvas, Rect Function(int, int) cellRect,
      {List<int>? board, Set<int>? highlightGreen, Set<int>? highlightRed}) {
    for (int r = 0; r < _n; r++) {
      for (int c = 0; c < _n; c++) {
        final idx = r * _n + c;
        final rect = cellRect(r, c);
        final rr = RRect.fromRectAndRadius(rect, const Radius.circular(4));

        Color bg = _kCellBg;
        if (highlightGreen != null && highlightGreen.contains(idx)) {
          bg = _kGreen.withValues(alpha: 0.15);
        } else if (highlightRed != null && highlightRed.contains(idx)) {
          bg = _kRed.withValues(alpha: 0.15);
        }

        canvas.drawRRect(rr, Paint()..color = bg);
        canvas.drawRRect(
            rr,
            Paint()
              ..color = _kGrid.withValues(alpha: 0.6)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0);

        if (board != null) {
          final val = board[idx];
          if (val == 1) _drawSun(canvas, rect.center, _cellS * 0.32);
          if (val == 2) _drawMoon(canvas, rect.center, _cellS * 0.30);
        }
      }
    }
  }

  // Step 0: Tap cycle — empty → Sun → Moon → empty on a single cell
  void _paintStep0(Canvas canvas, Size size, Rect Function(int, int) cellRect,
      double ox, double oy, double totalW, double totalH) {
    _drawGrid(canvas, cellRect);

    const targetR = 2, targetC = 3;
    final ctr = cellRect(targetR, targetC).center;

    // 4 phases: 0=empty, 1=sun appears, 2=moon appears, 3=clear
    final phase = (t * 4).floor() % 4;
    final frac = (t * 4) % 1.0;

    // Draw the symbol in the target cell
    if (phase == 1) {
      final scale = Curves.elasticOut.transform(math.min(frac * 2, 1.0));
      canvas.save();
      canvas.translate(ctr.dx, ctr.dy);
      canvas.scale(scale);
      canvas.translate(-ctr.dx, -ctr.dy);
      _drawSun(canvas, ctr, _cellS * 0.32);
      canvas.restore();
    } else if (phase == 2) {
      final scale = Curves.elasticOut.transform(math.min(frac * 2, 1.0));
      canvas.save();
      canvas.translate(ctr.dx, ctr.dy);
      canvas.scale(scale);
      canvas.translate(-ctr.dx, -ctr.dy);
      _drawMoon(canvas, ctr, _cellS * 0.30);
      canvas.restore();
    }

    // Tap ripple at phase transitions
    double rippleT = -1;
    if (frac < 0.35) rippleT = frac / 0.35;
    if (rippleT >= 0) {
      final rippleR = _cellS * 0.2 + _cellS * 0.5 * rippleT;
      final alpha = (1.0 - rippleT) * 0.4;
      canvas.drawCircle(
        ctr,
        rippleR,
        Paint()
          ..color = const Color(0xFF8B7355).withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    // Finger indicator
    final fingerY = ctr.dy + 20 - 6 * math.sin(frac * math.pi);
    final fingerAlpha = 0.5 + 0.3 * math.sin(frac * math.pi);
    _drawFinger(canvas, Offset(ctr.dx + 2, fingerY), fingerAlpha);

    // Label
    final labels = ['Empty', 'Sun ☀️', 'Moon 🌙', 'Clear'];
    _drawLabel(canvas, labels[phase], ox + totalW / 2, oy + totalH + 8,
        const Color(0xFF8B7355), 9);
  }

  // Step 1: Show a partially filled row, then fill to demonstrate balance
  void _paintStep1(Canvas canvas, Size size, Rect Function(int, int) cellRect,
      double ox, double oy, double totalW, double totalH) {
    // Animate filling row 0 one by one, then show count
    final stepsTotal = 7; // 6 cells + 1 hold
    final progress = (t * stepsTotal).floor().clamp(0, stepsTotal);

    final board = List<int>.filled(_n * _n, 0);
    final row0 = [1, 2, 1, 2, 1, 2]; // balanced row

    for (int c = 0; c < math.min(progress, _n); c++) {
      board[c] = row0[c];
    }

    // Also fill column 0 partially for column demo
    final col0 = [1, 2, 1, 2, 1, 2];
    for (int r = 0; r < math.min(progress, _n); r++) {
      board[r * _n] = col0[r];
    }

    // Highlight row 0 and col 0
    final highlightGreen = <int>{};
    for (int c = 0; c < _n; c++) {
      highlightGreen.add(c);
    }
    for (int r = 0; r < _n; r++) {
      highlightGreen.add(r * _n);
    }

    _drawGrid(canvas, cellRect, board: board, highlightGreen: highlightGreen);

    // Row count label
    if (progress >= _n) {
      int rowSuns = 0, rowMoons = 0;
      for (int c = 0; c < _n; c++) {
        if (board[c] == 1) rowSuns++;
        if (board[c] == 2) rowMoons++;
      }
      final rowLabel = 'Row: $rowSuns☀ = $rowMoons🌙';
      _drawBadge(canvas, Offset(ox + totalW + 2, oy + _cellS / 2),
          rowLabel, _kGreen, 7, anchor: 0.0);

      int colSuns = 0, colMoons = 0;
      for (int r = 0; r < _n; r++) {
        if (board[r * _n] == 1) colSuns++;
        if (board[r * _n] == 2) colMoons++;
      }
      final colLabel = 'Col: $colSuns☀ = $colMoons🌙';
      _drawBadge(canvas, Offset(ox - 2, oy + totalH / 2),
          colLabel, _kGreen, 7, anchor: 1.0);
    }

    // Animate placement of next cell
    if (progress < _n) {
      final frac = (t * stepsTotal) % 1.0;
      final ctr = cellRect(0, progress).center;
      final scale = Curves.elasticOut.transform(math.min(frac * 2.5, 1.0));
      if (scale > 0.01) {
        canvas.save();
        canvas.translate(ctr.dx, ctr.dy);
        canvas.scale(scale);
        canvas.translate(-ctr.dx, -ctr.dy);
        if (row0[progress] == 1) {
          _drawSun(canvas, ctr, _cellS * 0.32);
        } else {
          _drawMoon(canvas, ctr, _cellS * 0.30);
        }
        canvas.restore();
      }
    }

    _drawLabel(canvas, '3 Suns + 3 Moons per line', ox + totalW / 2,
        oy + totalH + 8, _kGreen, 8.5);
  }

  // Step 2: Show wrong (3-in-a-row) vs correct (alternating) pattern
  void _paintStep2(Canvas canvas, Size size, Rect Function(int, int) cellRect,
      double ox, double oy, double totalW, double totalH) {
    final showWrong = t < 0.5;

    if (showWrong) {
      // Phase 1: 3 suns in a row — WRONG
      final board = List<int>.filled(_n * _n, 0);
      // Row 2: three suns in a row at cols 1,2,3
      board[2 * _n + 1] = 1;
      board[2 * _n + 2] = 1;
      board[2 * _n + 3] = 1;
      // Some context
      board[2 * _n + 0] = 2;
      board[2 * _n + 4] = 2;

      final badCells = {2 * _n + 1, 2 * _n + 2, 2 * _n + 3};

      _drawGrid(canvas, cellRect, board: board, highlightRed: badCells);

      // Red border around the 3 bad cells
      final pulse = 0.6 + 0.4 * math.sin(t * 12 * math.pi);
      for (final idx in badCells) {
        final r = idx ~/ _n, c = idx % _n;
        final rect = cellRect(r, c);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          Paint()
            ..color = _kRed.withValues(alpha: pulse * 0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
      }

      // ✕ WRONG badge
      final midCell = cellRect(2, 2).center;
      _drawBadge(canvas, Offset(midCell.dx, oy + _cellS * 0.8 - 2),
          '✕ WRONG', _kRed, 9);

      _drawLabel(canvas, '3 identical in a row!', ox + totalW / 2,
          oy + totalH + 8, _kRed, 8.5);
    } else {
      // Phase 2: alternating pattern — CORRECT
      final board = List<int>.filled(_n * _n, 0);
      // Row 2: alternating
      board[2 * _n + 0] = 1;
      board[2 * _n + 1] = 2;
      board[2 * _n + 2] = 1;
      board[2 * _n + 3] = 2;
      board[2 * _n + 4] = 1;
      board[2 * _n + 5] = 2;
      // Column 0: alternating
      board[0 * _n] = 1;
      board[1 * _n] = 2;
      board[3 * _n] = 2;
      board[4 * _n] = 1;
      board[5 * _n] = 2;

      final goodCells = <int>{};
      for (int c = 0; c < _n; c++) {
        goodCells.add(2 * _n + c);
      }

      _drawGrid(canvas, cellRect, board: board, highlightGreen: goodCells);

      // Green border on good cells
      for (final idx in goodCells) {
        final r = idx ~/ _n, c = idx % _n;
        final rect = cellRect(r, c);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          Paint()
            ..color = _kGreen.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
      }

      // ✓ CORRECT badge
      final midCell = cellRect(2, 2).center;
      _drawBadge(canvas, Offset(midCell.dx + 4, oy + _cellS * 0.8 - 2),
          '✓ CORRECT', _kGreen, 9);

      _drawLabel(canvas, 'No 3 in a row!', ox + totalW / 2,
          oy + totalH + 8, _kGreen, 8.5);
    }
  }

  // Step 3: = and × clue markers between cells
  void _paintStep3(Canvas canvas, Size size, Rect Function(int, int) cellRect,
      double ox, double oy, double totalW, double totalH) {
    // Clue definitions: [row, col, direction(0=right,1=down), type(0='=',1='×')]
    const clues = [
      [1, 2, 0, 0], // (1,2)=(1,3) means match — both should be same
      [3, 0, 0, 1], // (3,0)×(3,1) means differ — must be different
      [0, 4, 1, 0], // (0,4)=(1,4) vertical match
      [4, 3, 0, 1], // (4,3)×(4,4) horizontal differ
    ];

    // Build board: animate placing symbols that satisfy clues
    final stepsTotal = clues.length + 1;
    final progress = (t * stepsTotal).floor().clamp(0, stepsTotal);

    final board = List<int>.filled(_n * _n, 0);
    // Place symbols for each resolved clue
    for (int i = 0; i < math.min(progress, clues.length); i++) {
      final clue = clues[i];
      final r = clue[0], c = clue[1], dir = clue[2], type = clue[3];
      final r2 = dir == 0 ? r : r + 1;
      final c2 = dir == 0 ? c + 1 : c;
      if (type == 0) {
        // = clue: both same
        board[r * _n + c] = 1;
        board[r2 * _n + c2] = 1;
      } else {
        // × clue: must differ
        board[r * _n + c] = 1;
        board[r2 * _n + c2] = 2;
      }
    }

    _drawGrid(canvas, cellRect, board: board);

    // Draw clue markers
    for (int i = 0; i < clues.length; i++) {
      final clue = clues[i];
      final r = clue[0], c = clue[1], dir = clue[2], type = clue[3];
      final rect1 = cellRect(r, c);
      final r2 = dir == 0 ? r : r + 1;
      final c2 = dir == 0 ? c + 1 : c;
      final rect2 = cellRect(r2, c2);
      final mid = Offset(
        (rect1.center.dx + rect2.center.dx) / 2,
        (rect1.center.dy + rect2.center.dy) / 2,
      );

      final resolved = i < progress;
      final clueColor = resolved ? _kGreen : const Color(0xFF8B7355);
      final label = type == 0 ? '=' : '×';

      // Clue circle background
      canvas.drawCircle(mid, 7, Paint()..color = Colors.white);
      canvas.drawCircle(
          mid,
          7,
          Paint()
            ..color = clueColor.withValues(alpha: 0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2);

      // Clue text
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: clueColor,
            fontWeight: FontWeight.w900,
            fontSize: 9,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(mid.dx - tp.width / 2, mid.dy - tp.height / 2));

      // Green glow on satisfied clues
      if (resolved) {
        final glowAlpha =
            0.15 + 0.1 * math.sin((t - i * 0.1) * math.pi * 4);
        canvas.drawCircle(
            mid, 10, Paint()..color = _kGreen.withValues(alpha: glowAlpha));
      }
    }

    // Animate the current placement
    if (progress < clues.length) {
      final frac = (t * stepsTotal) % 1.0;
      final clue = clues[progress];
      final r = clue[0], c = clue[1], dir = clue[2], type = clue[3];
      final r2 = dir == 0 ? r : r + 1;
      final c2 = dir == 0 ? c + 1 : c;

      final scale = Curves.elasticOut.transform(math.min(frac * 2.5, 1.0));
      if (scale > 0.01) {
        final ctr1 = cellRect(r, c).center;
        canvas.save();
        canvas.translate(ctr1.dx, ctr1.dy);
        canvas.scale(scale);
        canvas.translate(-ctr1.dx, -ctr1.dy);
        _drawSun(canvas, ctr1, _cellS * 0.32);
        canvas.restore();

        final ctr2 = cellRect(r2, c2).center;
        canvas.save();
        canvas.translate(ctr2.dx, ctr2.dy);
        canvas.scale(scale);
        canvas.translate(-ctr2.dx, -ctr2.dy);
        if (type == 0) {
          _drawSun(canvas, ctr2, _cellS * 0.32);
        } else {
          _drawMoon(canvas, ctr2, _cellS * 0.30);
        }
        canvas.restore();
      }
    }

    _drawLabel(canvas, 'Clues link neighbors', ox + totalW / 2,
        oy + totalH + 8, const Color(0xFF8B7355), 8.5);
  }

  // ── DRAWING HELPERS ──

  void _drawSun(Canvas canvas, Offset ctr, double r) {
    // Rays
    final rayPaint = Paint()
      ..color = _kSun.withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final inner = r * 1.15;
      final outer = r * 1.5;
      canvas.drawLine(
        Offset(ctr.dx + inner * math.cos(angle),
            ctr.dy + inner * math.sin(angle)),
        Offset(ctr.dx + outer * math.cos(angle),
            ctr.dy + outer * math.sin(angle)),
        rayPaint,
      );
    }
    // Body
    canvas.drawCircle(
        ctr.translate(0, 0.5), r, Paint()..color = Colors.black.withValues(alpha: 0.1));
    canvas.drawCircle(ctr, r, Paint()..color = _kSun);
    // Inner highlight
    canvas.drawCircle(
        ctr.translate(-r * 0.2, -r * 0.2),
        r * 0.35,
        Paint()..color = Colors.white.withValues(alpha: 0.4));
  }

  void _drawMoon(Canvas canvas, Offset ctr, double r) {
    // Shadow
    canvas.drawCircle(
        ctr.translate(0, 0.5), r, Paint()..color = Colors.black.withValues(alpha: 0.1));
    // Main moon circle
    canvas.drawCircle(ctr, r, Paint()..color = _kMoon);
    // Crescent cutout — draw a circle offset to carve out the crescent
    canvas.drawCircle(
        ctr.translate(r * 0.4, -r * 0.3),
        r * 0.7,
        Paint()
          ..color = _kCellBg
          ..blendMode = BlendMode.srcATop);
    // Since blendMode won't work well on canvas directly, simulate crescent:
    // Redraw the crescent manually using path
    _drawCrescentPath(canvas, ctr, r);
  }

  void _drawCrescentPath(Canvas canvas, Offset ctr, double r) {
    // Clear the moon we just drew and redraw as crescent
    // Draw background circle to cover
    canvas.drawCircle(ctr, r + 0.5, Paint()..color = _kCellBg);

    final path = Path();
    // Outer arc (full moon edge)
    path.addArc(
      Rect.fromCircle(center: ctr, radius: r),
      -math.pi * 0.65,
      math.pi * 1.3,
    );
    // Inner arc (cutout) — shifted right and up
    final cutCenter = ctr.translate(r * 0.35, -r * 0.15);
    final cutR = r * 0.75;
    // We need to connect the arcs to form a closed crescent
    path.arcTo(
      Rect.fromCircle(center: cutCenter, radius: cutR),
      math.pi * 0.65,
      -math.pi * 1.3,
      false,
    );
    path.close();

    canvas.drawPath(
        path, Paint()..color = Colors.black.withValues(alpha: 0.08));
    canvas.drawPath(path, Paint()..color = _kMoon);
    // Highlight
    canvas.drawCircle(
        ctr.translate(-r * 0.15, -r * 0.25),
        r * 0.2,
        Paint()..color = Colors.white.withValues(alpha: 0.3));
  }

  void _drawFinger(Canvas canvas, Offset pos, double alpha) {
    canvas.drawCircle(
      pos,
      5,
      Paint()..color = Colors.white.withValues(alpha: alpha),
    );
    canvas.drawCircle(
      pos,
      5,
      Paint()
        ..color = const Color(0xFF8B7355).withValues(alpha: alpha * 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // Small dot in center
    canvas.drawCircle(
      pos,
      1.5,
      Paint()..color = const Color(0xFF8B7355).withValues(alpha: alpha * 0.5),
    );
  }

  void _drawLabel(Canvas canvas, String text, double cx, double cy,
      Color color, double fontSize) {
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

  void _drawBadge(Canvas canvas, Offset pos, String text, Color color,
      double fontSize, {double anchor = 0.5}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
          height: 1,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final pad = 4.0;
    final w = tp.width + pad * 2;
    final h = tp.height + pad * 2;
    final left = pos.dx - w * anchor;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, pos.dy - h / 2, w, h),
      const Radius.circular(6),
    );
    canvas.drawRRect(rect, Paint()..color = color);
    tp.paint(canvas, Offset(left + pad, pos.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_TangoPainter old) => old.t != t;
}

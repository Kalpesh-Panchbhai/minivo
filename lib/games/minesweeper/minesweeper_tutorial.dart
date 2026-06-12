import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> minesweeperSteps() => [
      GameHowToPlayStep(
        text: 'Tap any cell to reveal it. Numbers show how many mines touch that cell.',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 4000),
          painter: (t) => _Step1Painter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Use numbers to deduce safe cells. A "1" means exactly one mine in the 8 neighbors.',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 4000),
          painter: (t) => _Step2Painter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Switch to Flag mode to mark mines. Or long-press any hidden cell to flag it.',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 3500),
          painter: (t) => _Step3Painter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Reveal all safe cells to win! Be fast — less time means more points.',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 4000),
          painter: (t) => _Step4Painter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
    ];

const _kHiddenA = Color(0xFFA8C4E0);
const _kHiddenB = Color(0xFF9EBCD8);
const _kRevealedA = Color(0xFFE8ECF2);
const _kRevealedB = Color(0xFFDEE3EB);
const _kMineRed = Color(0xFFEF4444);
const _kFlagRed = Color(0xFFEF4444);
const _kBg = Color(0xFF1E293B);
const _kAccent = Color(0xFF4A7CFF);
const _kGreen = Color(0xFF22C55E);
const _kAmber = Color(0xFFF59E0B);

const _numColors = [
  Color(0xFF2196F3),
  Color(0xFF4CAF50),
  Color(0xFFF44336),
  Color(0xFF9C27B0),
];

void _bg(Canvas c, Size s) {
  c.drawRect(Rect.fromLTWH(0, 0, s.width, s.height), Paint()..color = _kBg);
  c.drawCircle(
    Offset(s.width * 0.5, s.height * 0.45),
    s.width * 0.5,
    Paint()
      ..shader = RadialGradient(colors: [
        _kAccent.withValues(alpha: 0.07),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(
        center: Offset(s.width * 0.5, s.height * 0.45),
        radius: s.width * 0.5,
      )),
  );
}

void _grid(
  Canvas canvas,
  Size size,
  List<List<int>> data, {
  int rows = 4,
  int cols = 4,
  int hlR = -1,
  int hlC = -1,
  Color hlColor = _kAccent,
  double tapT = -1,
}) {
  final cell = math.min(size.width * 0.85 / cols, size.height * 0.70 / rows);
  final ox = (size.width - cell * cols) / 2;
  final oy = (size.height - cell * rows) / 2 - 4;

  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      final x = ox + c * cell;
      final y = oy + r * cell;
      final even = (r + c) % 2 == 0;
      final rect = Rect.fromLTWH(x + 0.5, y + 0.5, cell - 1, cell - 1);
      final v = data[r][c];

      if (v == 0) {
        canvas.drawRect(rect, Paint()..color = even ? _kHiddenA : _kHiddenB);
      } else if (v == -1) {
        canvas.drawRect(rect, Paint()..color = _kMineRed);
        _mine(canvas, x + cell / 2, y + cell / 2, cell * 0.22, Colors.white);
      } else if (v == -2) {
        canvas.drawRect(rect, Paint()..color = even ? _kHiddenA : _kHiddenB);
        _flag(canvas, x + cell / 2, y + cell / 2, cell * 0.36);
      } else if (v == -3) {
        canvas.drawRect(rect, Paint()..color = const Color(0xFFFF2020));
        _mine(canvas, x + cell / 2, y + cell / 2, cell * 0.22, const Color(0xFFFFEB3B));
      } else {
        canvas.drawRect(rect, Paint()..color = even ? _kRevealedA : _kRevealedB);
        if (v > 0 && v < 9) {
          final tp = TextPainter(
            text: TextSpan(
              text: '$v',
              style: TextStyle(
                color: _numColors[(v - 1).clamp(0, 3)],
                fontSize: cell * 0.46,
                fontWeight: FontWeight.w900,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(x + cell / 2 - tp.width / 2, y + cell / 2 - tp.height / 2));
        }
      }

      if (r == hlR && c == hlC) {
        canvas.drawRect(
          rect,
          Paint()
            ..color = hlColor.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
        if (tapT >= 0) {
          final cx = x + cell / 2;
          final cy = y + cell / 2;
          canvas.drawCircle(
            Offset(cx, cy),
            cell * 0.4 + tapT * cell * 0.6,
            Paint()
              ..color = hlColor.withValues(alpha: (1 - tapT) * 0.30)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }
      }
    }
  }
}

void _mine(Canvas c, double cx, double cy, double r, Color color) {
  c.drawCircle(Offset(cx, cy), r, Paint()..color = color);
  for (int i = 0; i < 8; i++) {
    final a = i * math.pi / 4;
    c.drawLine(
      Offset(cx + math.cos(a) * r * 0.7, cy + math.sin(a) * r * 0.7),
      Offset(cx + math.cos(a) * r * 1.35, cy + math.sin(a) * r * 1.35),
      Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }
}

void _flag(Canvas c, double cx, double cy, double s) {
  final px = cx - s * 0.05;
  c.drawLine(
    Offset(px, cy - s * 0.45),
    Offset(px, cy + s * 0.45),
    Paint()
      ..color = const Color(0xFF475569)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round,
  );
  final path = Path()
    ..moveTo(px, cy - s * 0.45)
    ..lineTo(px + s * 0.50, cy - s * 0.22)
    ..lineTo(px, cy)
    ..close();
  c.drawPath(path, Paint()..color = _kFlagRed);
}

void _label(Canvas c, Size s, String text, Color color, {double y = 0.90}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final maxW = s.width - 8;
  if (tp.width > maxW) {
    c.save();
    c.clipRect(Rect.fromLTWH(4, 0, maxW, s.height));
    tp.paint(c, Offset(s.width / 2 - tp.width / 2, s.height * y - tp.height / 2));
    c.restore();
  } else {
    tp.paint(c, Offset(s.width / 2 - tp.width / 2, s.height * y - tp.height / 2));
  }
}

class _Step1Painter extends CustomPainter {
  final double t;
  const _Step1Painter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _bg(canvas, size);

    final d = List.generate(4, (_) => List.filled(4, 0));

    final phase = (t * 3).floor().clamp(0, 2);
    final sub = (t * 3) % 1.0;

    if (phase >= 1) {
      d[1][1] = 1;
    }
    if (phase >= 2) {
      d[0][0] = 10; d[0][1] = 1;  d[0][2] = 10; d[0][3] = 10;
      d[1][0] = 1;  d[1][1] = 1;  d[1][2] = 2;  d[1][3] = 10;
      d[2][0] = 10; d[2][1] = 10; d[2][2] = 10; d[2][3] = 10;
    }

    int hr = -1, hc = -1;
    double tap = -1;
    if (phase == 0) {
      hr = 1; hc = 1; tap = sub;
    } else if (phase == 1) {
      hr = 1; hc = 1;
    }

    _grid(canvas, size, d, hlR: hr, hlC: hc, tapT: tap);

    if (phase == 0) {
      _label(canvas, size, 'TAP TO REVEAL', _kAccent);
    } else if (phase == 1) {
      _label(canvas, size, '"1" = 1 MINE NEARBY', const Color(0xFF2196F3));
    } else {
      _label(canvas, size, 'SAFE NEIGHBORS OPEN TOO', _kGreen);
    }
  }

  @override
  bool shouldRepaint(covariant _Step1Painter o) => o.t != t;
}

class _Step2Painter extends CustomPainter {
  final double t;
  const _Step2Painter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _bg(canvas, size);

    final d = [
      [10,  1,  0,  10],
      [ 1,  1,  0,   1],
      [10, 10, 10,  10],
      [10, 10, 10,  10],
    ];

    final phase = (t * 3).floor().clamp(0, 2);

    int hr = -1, hc = -1;
    Color hcol = _kAccent;

    if (phase == 0) {
      hr = 0; hc = 1;
    } else if (phase == 1) {
      hr = 0; hc = 2;
      hcol = _kFlagRed;
    } else {
      d[0][2] = -2;
      hr = 1; hc = 2;
      hcol = _kFlagRed;
    }

    _grid(canvas, size, d, hlR: hr, hlC: hc, hlColor: hcol);

    if (phase == 0) {
      _label(canvas, size, '"1" ALREADY SEES 1 MINE', const Color(0xFF2196F3));
    } else if (phase == 1) {
      _label(canvas, size, 'THAT HIDDEN CELL IS A MINE!', _kAmber);
    } else {
      _label(canvas, size, 'FLAG IT!', _kFlagRed);
    }
  }

  @override
  bool shouldRepaint(covariant _Step2Painter o) => o.t != t;
}

class _Step3Painter extends CustomPainter {
  final double t;
  const _Step3Painter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _bg(canvas, size);

    final d = [
      [10,  1,  0,   1],
      [ 1,  2,  0,   2],
      [10, 10,  10, 10],
      [10, 10,  10, 10],
    ];

    final phase = (t * 3).floor().clamp(0, 2);
    final sub = (t * 3) % 1.0;

    if (phase >= 1) d[0][2] = -2;
    if (phase >= 2) d[1][2] = -2;

    int hr = -1, hc = -1;
    double tap = -1;
    if (phase == 0) { hr = 0; hc = 2; tap = sub; }
    if (phase == 1) { hr = 1; hc = 2; tap = sub; }

    _grid(canvas, size, d, hlR: hr, hlC: hc, hlColor: _kFlagRed, tapT: tap);

    final btnY = size.height * 0.90;
    final bw = 80.0;
    final bh = 18.0;
    final br = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(size.width / 2, btnY), width: bw, height: bh),
      const Radius.circular(9),
    );
    canvas.drawRRect(br, Paint()..color = Colors.white.withValues(alpha: 0.12));

    final half = bw / 2;
    final flagR = RRect.fromRectAndRadius(
      Rect.fromLTWH(br.left + half + 1, br.top + 1, half - 2, bh - 2),
      const Radius.circular(8),
    );
    canvas.drawRRect(flagR, Paint()..color = _kFlagRed.withValues(alpha: 0.80));

    final dtP = TextPainter(
      text: TextSpan(text: 'Dig', style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 8, fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    dtP.paint(canvas, Offset(br.left + half / 2 - dtP.width / 2, btnY - dtP.height / 2));

    final ftP = TextPainter(
      text: const TextSpan(text: 'Flag', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    ftP.paint(canvas, Offset(br.left + half + half / 2 - ftP.width / 2, btnY - ftP.height / 2));
  }

  @override
  bool shouldRepaint(covariant _Step3Painter o) => o.t != t;
}

class _Step4Painter extends CustomPainter {
  final double t;
  const _Step4Painter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _bg(canvas, size);

    final d = [
      [10,  1,  -2,  1],
      [ 1,  2,  -2,  2],
      [ 0, 10,  10, 10],
      [10, 10,  10, 10],
    ];

    final progress = t.clamp(0.0, 1.0);

    if (progress > 0.20) d[2][0] = 1;
    if (progress > 0.55) {
      d[2][0] = 1;
    }

    _grid(canvas, size, d,
      hlR: progress < 0.20 ? 2 : -1,
      hlC: progress < 0.20 ? 0 : -1,
      tapT: progress < 0.20 ? (progress / 0.20) : -1,
    );

    if (progress > 0.65) {
      final a = ((progress - 0.65) / 0.35).clamp(0.0, 1.0);

      _label(canvas, size, 'YOU WIN!', _kGreen.withValues(alpha: a), y: 0.90);

      for (int i = 0; i < 8; i++) {
        final ang = i * math.pi / 4 + progress * math.pi * 6;
        final rad = 20.0 + a * 30;
        final px = size.width / 2 + math.cos(ang) * rad;
        final py = size.height * 0.42 + math.sin(ang) * rad * 0.7;
        canvas.drawCircle(
          Offset(px, py),
          2.5,
          Paint()..color = [_kAccent, _kGreen, _kAmber, _kMineRed][i % 4].withValues(alpha: a * 0.65),
        );
      }
    } else {
      final secs = (8 + (progress * 15).floor());
      _label(canvas, size, '00:${secs.toString().padLeft(2, '0')}', Colors.white.withValues(alpha: 0.6), y: 0.90);
    }
  }

  @override
  bool shouldRepaint(covariant _Step4Painter o) => o.t != t;
}

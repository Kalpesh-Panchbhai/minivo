import 'dart:math';

import 'package:flutter/material.dart';
import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> hangmanSteps() => [
      GameHowToPlayStep(
        text: 'Guess the hidden word by tapping letters one at a time.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 4),
          painter: (t) => _GuessPainter(t),
          canvasSize: const Size(200, 180),
        ),
      ),
      GameHowToPlayStep(
        text:
            'Correct letters fill in the blanks. Wrong guesses draw the hangman!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 4),
          painter: (t) => _WrongPainter(t),
          canvasSize: const Size(200, 180),
        ),
      ),
      GameHowToPlayStep(
        text: 'Solve the word before 6 wrong guesses to win!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 4),
          painter: (t) => _WinPainter(t),
          canvasSize: const Size(200, 180),
        ),
      ),
    ];

const _kAccent = Color(0xFF6C63FF);
const _kText = Color(0xFF3730A3);
const _kBg = Color(0xFFF0EEFF);
const _kKeyBg = Color(0xFFE0DDFF);
const _kKeyLetters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
const _kKeyLetters2 = ['I', 'J', 'K', 'L', 'M', 'N', 'O', 'P'];

void _drawGallows(Canvas canvas, Size size, int errors) {
  final paint = Paint()
    ..color = _kText.withValues(alpha: 0.6)
    ..strokeWidth = 2.5
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  final baseY = size.height * 0.52;
  final postX = size.width * 0.25;
  final topY = size.height * 0.08;
  final beamEndX = size.width * 0.55;

  canvas.drawLine(
      Offset(size.width * 0.12, baseY), Offset(size.width * 0.42, baseY), paint);
  canvas.drawLine(Offset(postX, baseY), Offset(postX, topY), paint);
  canvas.drawLine(Offset(postX, topY), Offset(beamEndX, topY), paint);
  canvas.drawLine(
      Offset(beamEndX, topY), Offset(beamEndX, topY + 12), paint);

  if (errors < 1) return;

  final headCy = topY + 22;
  final headR = 10.0;
  if (errors >= 1) {
    canvas.drawCircle(Offset(beamEndX, headCy), headR, paint);
  }
  if (errors >= 2) {
    canvas.drawLine(Offset(beamEndX, headCy + headR),
        Offset(beamEndX, headCy + headR + 22), paint);
  }
  if (errors >= 3) {
    canvas.drawLine(Offset(beamEndX, headCy + headR + 8),
        Offset(beamEndX - 12, headCy + headR + 20), paint);
  }
  if (errors >= 4) {
    canvas.drawLine(Offset(beamEndX, headCy + headR + 8),
        Offset(beamEndX + 12, headCy + headR + 20), paint);
  }
  if (errors >= 5) {
    canvas.drawLine(Offset(beamEndX, headCy + headR + 22),
        Offset(beamEndX - 10, headCy + headR + 36), paint);
  }
  if (errors >= 6) {
    canvas.drawLine(Offset(beamEndX, headCy + headR + 22),
        Offset(beamEndX + 10, headCy + headR + 36), paint);
  }
}

void _drawKeyRow(
  Canvas canvas,
  Size size, {
  required List<String> letters,
  required double y,
  required double keyW,
  required double keyH,
  required double gap,
  String? highlightKey,
  double highlightT = 0.0,
  List<String> usedKeys = const [],
}) {
  final totalW = letters.length * keyW + (letters.length - 1) * gap;
  var x = (size.width - totalW) / 2;

  for (final letter in letters) {
    final isHighlight = letter == highlightKey && highlightT > 0;
    final isUsed = usedKeys.contains(letter);

    final keyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, keyW, keyH),
      const Radius.circular(4),
    );

    final bgColor = isHighlight
        ? Color.lerp(_kKeyBg, _kAccent, highlightT)!
        : isUsed
            ? _kKeyBg.withValues(alpha: 0.4)
            : _kKeyBg;
    canvas.drawRRect(keyRect, Paint()..color = bgColor);

    canvas.drawRRect(
      keyRect,
      Paint()
        ..color = _kText.withValues(alpha: isUsed ? 0.15 : 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    final textColor = isHighlight
        ? Color.lerp(_kText, Colors.white, highlightT)!
        : isUsed
            ? _kText.withValues(alpha: 0.3)
            : _kText;
    final tp = TextPainter(
      text: TextSpan(
        text: letter,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w800,
          fontSize: 9,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x + (keyW - tp.width) / 2, y + (keyH - tp.height) / 2));

    if (isHighlight && highlightT > 0.2) {
      final rippleR = highlightT * keyW * 1.2;
      final rippleAlpha = (1.0 - highlightT).clamp(0.0, 0.5);
      canvas.drawCircle(
        Offset(x + keyW / 2, y + keyH / 2),
        rippleR,
        Paint()..color = _kAccent.withValues(alpha: rippleAlpha),
      );
    }

    x += keyW + gap;
  }
}

void _drawWordBlanks(Canvas canvas, Size size, String display, double y) {
  final tp = TextPainter(
    text: TextSpan(
      text: display,
      style: TextStyle(
        color: _kText,
        fontWeight: FontWeight.w900,
        fontSize: 14,
        letterSpacing: 2,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, Offset((size.width - tp.width) / 2, y));
}

class _GuessPainter extends CustomPainter {
  final double t;
  const _GuessPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = _kBg);

    _drawGallows(canvas, size, 0);

    String display;
    String? highlightKey;
    double highlightT = 0.0;
    List<String> usedKeys = [];

    if (t < 0.3) {
      display = '_ _ _ _ _';
    } else if (t < 0.5) {
      final tapT = ((t - 0.3) / 0.2).clamp(0.0, 1.0);
      highlightKey = 'H';
      highlightT = tapT;
      display = tapT > 0.7 ? 'H _ _ _ _' : '_ _ _ _ _';
    } else if (t < 0.7) {
      usedKeys = ['H'];
      display = 'H _ _ _ _';
    } else if (t < 0.9) {
      final tapT = ((t - 0.7) / 0.2).clamp(0.0, 1.0);
      usedKeys = ['H'];
      highlightKey = 'L';
      highlightT = tapT;
      display = tapT > 0.7 ? 'H _ L L _' : 'H _ _ _ _';
    } else {
      usedKeys = ['H'];
      display = 'H _ L L _';
    }

    _drawWordBlanks(canvas, size, display, size.height * 0.58);

    final keyY1 = size.height * 0.72;
    final keyY2 = size.height * 0.85;
    const keyW = 18.0;
    const keyH = 16.0;
    const gap = 3.5;

    String? hlRow1 = _kKeyLetters.contains(highlightKey ?? '') ? highlightKey : null;
    String? hlRow2 = _kKeyLetters2.contains(highlightKey ?? '') ? highlightKey : null;

    _drawKeyRow(canvas, size,
        letters: _kKeyLetters,
        y: keyY1,
        keyW: keyW,
        keyH: keyH,
        gap: gap,
        highlightKey: hlRow1,
        highlightT: highlightT,
        usedKeys: usedKeys);
    _drawKeyRow(canvas, size,
        letters: _kKeyLetters2,
        y: keyY2,
        keyW: keyW,
        keyH: keyH,
        gap: gap,
        highlightKey: hlRow2,
        highlightT: highlightT,
        usedKeys: usedKeys.where((k) => _kKeyLetters2.contains(k)).toList());
  }

  @override
  bool shouldRepaint(_GuessPainter old) => old.t != t;
}

class _WrongPainter extends CustomPainter {
  final double t;
  const _WrongPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = _kBg);
    final errors = (t * 6).floor().clamp(0, 6);
    _drawGallows(canvas, size, errors);

    final tp = TextPainter(
      text: TextSpan(
        text: '$errors / 6 wrong',
        style: TextStyle(
          color: errors >= 4
              ? Colors.red.withValues(alpha: 0.8)
              : _kText.withValues(alpha: 0.6),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.58));

    final wrongLetters = ['X', 'Z', 'Q', 'J', 'V', 'W'];
    final shown = wrongLetters.sublist(0, errors.clamp(0, wrongLetters.length));
    if (shown.isNotEmpty) {
      final wrongTp = TextPainter(
        text: TextSpan(
          text: shown.join('  '),
          style: TextStyle(
            color: Colors.red.withValues(alpha: 0.45),
            fontWeight: FontWeight.w800,
            fontSize: 10,
            decoration: TextDecoration.lineThrough,
            decorationColor: Colors.red.withValues(alpha: 0.4),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      wrongTp.paint(
          canvas, Offset((size.width - wrongTp.width) / 2, size.height * 0.70));
    }

    final keyY1 = size.height * 0.80;
    const keyW = 18.0;
    const keyH = 16.0;
    const gap = 3.5;

    final currentWrong = errors > 0 && errors <= wrongLetters.length
        ? wrongLetters[errors - 1]
        : null;
    final errFrac = (t * 6) - (t * 6).floor();
    final tapT = errors < 6 ? (errFrac < 0.5 ? errFrac * 2 : 1.0 - (errFrac - 0.5) * 2) : 0.0;

    final wrongRow = ['Q', 'V', 'W', 'X', 'Y', 'Z', 'J', 'K'];
    _drawKeyRow(canvas, size,
        letters: wrongRow,
        y: keyY1,
        keyW: keyW,
        keyH: keyH,
        gap: gap,
        highlightKey: currentWrong,
        highlightT: tapT.clamp(0.0, 1.0),
        usedKeys: shown);
  }

  @override
  bool shouldRepaint(_WrongPainter old) => old.t != t;
}

const _kWinKeyRow1 = ['Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X'];

class _WinPainter extends CustomPainter {
  final double t;
  const _WinPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = _kBg);

    _drawGallows(canvas, size, 2);

    String display;
    String? highlightKey;
    double highlightT = 0.0;
    List<String> usedKeys = ['F', 'L', 'U', 'T', 'E'];
    bool showCelebration = false;

    if (t < 0.3) {
      display = 'F L U T T E _';
    } else if (t < 0.55) {
      final tapT = ((t - 0.3) / 0.25).clamp(0.0, 1.0);
      highlightKey = 'R';
      highlightT = tapT;
      display = tapT > 0.6 ? 'F L U T T E R' : 'F L U T T E _';
    } else {
      display = 'F L U T T E R';
      usedKeys = ['F', 'L', 'U', 'T', 'E', 'R'];
      showCelebration = true;
    }

    _drawWordBlanks(canvas, size, display, size.height * 0.55);

    final keyY = size.height * 0.82;
    const keyW = 18.0;
    const keyH = 16.0;
    const gap = 3.5;

    _drawKeyRow(canvas, size,
        letters: _kWinKeyRow1,
        y: keyY,
        keyW: keyW,
        keyH: keyH,
        gap: gap,
        highlightKey: highlightKey,
        highlightT: highlightT,
        usedKeys: usedKeys.where((k) => _kWinKeyRow1.contains(k)).toList());

    if (showCelebration) {
      final celebT = ((t - 0.55) / 0.45).clamp(0.0, 1.0);

      final glowAlpha = (0.25 * sin(celebT * pi * 3) + 0.25).clamp(0.0, 0.5);
      final wordTp = TextPainter(
        text: TextSpan(
          text: 'F L U T T E R',
          style: TextStyle(
            color: _kText,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final wordX = (size.width - wordTp.width) / 2;
      final wordY = size.height * 0.55;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
              wordX - 8, wordY - 4, wordTp.width + 16, wordTp.height + 8),
          const Radius.circular(6),
        ),
        Paint()..color = Colors.green.withValues(alpha: glowAlpha),
      );

      final checkSize = 18.0 * celebT.clamp(0.0, 1.0);
      final checkX = size.width * 0.5;
      final checkY = size.height * 0.40;

      final circlePaint = Paint()
        ..color = Colors.green.withValues(alpha: (0.8 * celebT).clamp(0.0, 0.8));
      canvas.drawCircle(Offset(checkX, checkY), checkSize * 0.7, circlePaint);

      if (celebT > 0.3) {
        final checkPaint = Paint()
          ..color = Colors.white
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        final path = Path()
          ..moveTo(checkX - 5, checkY)
          ..lineTo(checkX - 1, checkY + 4)
          ..lineTo(checkX + 6, checkY - 4);
        canvas.drawPath(path, checkPaint);
      }

      if (celebT > 0.4) {
        final solvedAlpha = ((celebT - 0.4) / 0.3).clamp(0.0, 1.0);
        final solvedTp = TextPainter(
          text: TextSpan(
            text: 'SOLVED!',
            style: TextStyle(
              color: Colors.green.withValues(alpha: solvedAlpha),
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 1.5,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        solvedTp.paint(
          canvas,
          Offset((size.width - solvedTp.width) / 2, size.height * 0.27),
        );
      }

      if (celebT > 0.2) {
        _drawSparkles(canvas, size, celebT);
      }
    }
  }

  void _drawSparkles(Canvas canvas, Size size, double celebT) {
    final sparkPaint = Paint()..style = PaintingStyle.fill;
    final rng = [
      Offset(size.width * 0.15, size.height * 0.30),
      Offset(size.width * 0.85, size.height * 0.28),
      Offset(size.width * 0.20, size.height * 0.50),
      Offset(size.width * 0.82, size.height * 0.48),
      Offset(size.width * 0.35, size.height * 0.22),
      Offset(size.width * 0.70, size.height * 0.22),
    ];
    final colors = [
      Colors.amber,
      Colors.green,
      _kAccent,
      Colors.amber,
      Colors.green,
      _kAccent,
    ];

    for (var i = 0; i < rng.length; i++) {
      final delay = i * 0.12;
      final st = ((celebT - delay) / 0.5).clamp(0.0, 1.0);
      if (st <= 0) continue;

      final fade = st < 0.5 ? st * 2 : 2.0 - st * 2;
      final r = 2.0 + st * 2.0;
      sparkPaint.color = colors[i].withValues(alpha: (fade * 0.7).clamp(0.0, 1.0));

      final pos = Offset(
        rng[i].dx,
        rng[i].dy - st * 8,
      );
      canvas.drawCircle(pos, r, sparkPaint);

      final starPath = Path();
      for (var j = 0; j < 4; j++) {
        final angle = j * pi / 2;
        final dx2 = pos.dx + cos(angle) * (r + 2);
        final dy2 = pos.dy + sin(angle) * (r + 2);
        if (j == 0) {
          starPath.moveTo(dx2, dy2);
        } else {
          starPath.lineTo(dx2, dy2);
        }
      }
      starPath.close();
      sparkPaint.color = colors[i].withValues(alpha: (fade * 0.35).clamp(0.0, 1.0));
      canvas.drawPath(starPath, sparkPaint);
    }
  }

  @override
  bool shouldRepaint(_WinPainter old) => old.t != t;
}

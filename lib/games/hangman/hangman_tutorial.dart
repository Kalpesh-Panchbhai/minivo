import 'package:flutter/material.dart';
import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> hangmanSteps() => [
      GameHowToPlayStep(
        text: 'Guess the hidden word by tapping letters one at a time.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _GuessPainter(t),
          canvasSize: const Size(200, 130),
        ),
      ),
      GameHowToPlayStep(
        text: 'Correct letters fill in the blanks. Wrong guesses draw the hangman!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 4),
          painter: (t) => _WrongPainter(t),
          canvasSize: const Size(200, 130),
        ),
      ),
      GameHowToPlayStep(
        text: 'Solve the word before 6 wrong guesses to win!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _WinPainter(t),
          canvasSize: const Size(200, 130),
        ),
      ),
    ];

const _kAccent = Color(0xFF6C63FF);
const _kText = Color(0xFF3730A3);

void _drawGallows(Canvas canvas, Size size, int errors) {
  final paint = Paint()
    ..color = _kText.withValues(alpha: 0.6)
    ..strokeWidth = 2.5
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  final baseY = size.height * 0.75;
  final postX = size.width * 0.25;
  final topY = size.height * 0.12;
  final beamEndX = size.width * 0.55;

  canvas.drawLine(Offset(size.width * 0.12, baseY), Offset(size.width * 0.42, baseY), paint);
  canvas.drawLine(Offset(postX, baseY), Offset(postX, topY), paint);
  canvas.drawLine(Offset(postX, topY), Offset(beamEndX, topY), paint);
  canvas.drawLine(Offset(beamEndX, topY), Offset(beamEndX, topY + 12), paint);

  if (errors < 1) return;

  final headCy = topY + 22;
  final headR = 10.0;
  if (errors >= 1) canvas.drawCircle(Offset(beamEndX, headCy), headR, paint);
  if (errors >= 2) canvas.drawLine(Offset(beamEndX, headCy + headR), Offset(beamEndX, headCy + headR + 22), paint);
  if (errors >= 3) canvas.drawLine(Offset(beamEndX, headCy + headR + 8), Offset(beamEndX - 12, headCy + headR + 20), paint);
  if (errors >= 4) canvas.drawLine(Offset(beamEndX, headCy + headR + 8), Offset(beamEndX + 12, headCy + headR + 20), paint);
  if (errors >= 5) canvas.drawLine(Offset(beamEndX, headCy + headR + 22), Offset(beamEndX - 10, headCy + headR + 36), paint);
  if (errors >= 6) canvas.drawLine(Offset(beamEndX, headCy + headR + 22), Offset(beamEndX + 10, headCy + headR + 36), paint);
}

class _GuessPainter extends CustomPainter {
  final double t;
  const _GuessPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFFF0EEFF));
    _drawGallows(canvas, size, 0);

    final blanks = '_ _ _ _ _';
    final revealed = (t * 2).clamp(0.0, 1.0);
    final text = revealed > 0.5 ? 'H _ L L O' : blanks;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: _kText, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.82));
  }

  @override
  bool shouldRepaint(_GuessPainter old) => old.t != t;
}

class _WrongPainter extends CustomPainter {
  final double t;
  const _WrongPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFFF0EEFF));
    final errors = (t * 6).floor().clamp(0, 6);
    _drawGallows(canvas, size, errors);

    final tp = TextPainter(
      text: TextSpan(
        text: '$errors / 6 wrong',
        style: TextStyle(
          color: errors >= 4 ? Colors.red.withValues(alpha: 0.8) : _kText.withValues(alpha: 0.6),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.85));
  }

  @override
  bool shouldRepaint(_WrongPainter old) => old.t != t;
}

class _WinPainter extends CustomPainter {
  final double t;
  const _WinPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFFF0EEFF));
    _drawGallows(canvas, size, 2);

    if (t > 0.4) {
      final alpha = ((t - 0.4) / 0.6).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: 'F L U T T E R',
          style: TextStyle(
            color: Colors.green.withValues(alpha: alpha),
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.5));
    }
  }

  @override
  bool shouldRepaint(_WinPainter old) => old.t != t;
}

import 'package:flutter/material.dart';

/// Flappy Tap brand logo. Renders as a [size]×[size] square that fills the
/// host tile (mosaic_game_tile, game_card, home_screen, etc.).
///
/// Design: sky blue gradient background with a yellow bird silhouette and
/// two green pipe shapes. "FLAPPY TAP" text at the bottom.
Widget buildFlappyTapLogo(double size) {
  return Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF87CEEB), Color(0xFF4FA8D1)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
    child: ClipRect(
      child: CustomPaint(
        size: Size(size, size),
        painter: _FlappyTapLogoPainter(),
      ),
    ),
  );
}

class _FlappyTapLogoPainter extends CustomPainter {
  static const _birdColor  = Color(0xFFFFD700);
  static const _pipeColor  = Color(0xFF4CAF50);
  static const _pipeDark   = Color(0xFF388E3C);
  static const _textColor  = Color(0xFFFFFFFF);
  static const _eyeColor   = Color(0xFF1A1A2E);
  static const _beakColor  = Color(0xFFFF8C00);

  @override
  void paint(Canvas canvas, Size size) {
    final cs = size.width / 6; // logical cell size

    // ── Left pipe (bottom half only, gap above) ───────────────────────────
    _drawPipe(canvas, size, cs,
      pipeX: cs * 0.2,
      pipeWidth: cs * 0.9,
      topOfPipe: size.height * 0.55,
      isBottom: true,
    );

    // ── Right pipe (top half only, gap below) ────────────────────────────
    _drawPipe(canvas, size, cs,
      pipeX: cs * 3.9,
      pipeWidth: cs * 0.9,
      topOfPipe: 0,
      bottomOfPipe: size.height * 0.30,
      isBottom: false,
    );

    // ── Bird (yellow circle + wing + eye + beak) ─────────────────────────
    _drawBird(canvas, size, cs);

    // ── "FLAPPY TAP" label at bottom ─────────────────────────────────────
    final fontSize = size.width * 0.135;
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'FLAPPY TAP',
        style: TextStyle(
          color: _textColor,
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        size.height - textPainter.height - size.height * 0.03,
      ),
    );
  }

  void _drawPipe(
    Canvas canvas,
    Size size,
    double cs, {
    required double pipeX,
    required double pipeWidth,
    required double topOfPipe,
    double? bottomOfPipe,
    required bool isBottom,
  }) {
    final bottom = bottomOfPipe ?? size.height * 0.88;
    final capH = cs * 0.28;
    final capExtra = cs * 0.10; // cap is slightly wider than pipe

    // Pipe body
    final bodyRect = Rect.fromLTRB(pipeX, topOfPipe, pipeX + pipeWidth, bottom);
    canvas.drawRRect(
      RRect.fromRectAndCorners(bodyRect,
        topLeft: isBottom ? Radius.zero : const Radius.circular(4),
        topRight: isBottom ? Radius.zero : const Radius.circular(4),
        bottomLeft: isBottom ? const Radius.circular(4) : Radius.zero,
        bottomRight: isBottom ? const Radius.circular(4) : Radius.zero,
      ),
      Paint()..color = _pipeColor,
    );

    // Cap
    final capY = isBottom ? topOfPipe - capH : bottom;
    final capRect = Rect.fromLTRB(
      pipeX - capExtra,
      capY,
      pipeX + pipeWidth + capExtra,
      capY + capH,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(capRect, const Radius.circular(5)),
      Paint()..color = _pipeDark,
    );

    // Highlight stripe on pipe body
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = cs * 0.12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(pipeX + cs * 0.16, topOfPipe + (isBottom ? capH + cs * 0.1 : cs * 0.1)),
      Offset(pipeX + cs * 0.16, bottom - (isBottom ? cs * 0.1 : capH + cs * 0.1)),
      highlightPaint,
    );
  }

  void _drawBird(Canvas canvas, Size size, double cs) {
    final cx = size.width * 0.52;
    final cy = size.height * 0.40;
    final r  = cs * 0.62;

    // Shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + 3, cy + r * 0.85),
        width: r * 1.8, height: r * 0.55),
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );

    // Tail feather 1 (behind body)
    final tailPath = Path()
      ..moveTo(cx - r * 0.85, cy)
      ..lineTo(cx - r * 1.6, cy - r * 0.35)
      ..lineTo(cx - r * 1.35, cy + r * 0.20)
      ..close();
    canvas.drawPath(tailPath, Paint()..color = const Color(0xFFE6B800));
    // Tail feather 2
    final tailPath2 = Path()
      ..moveTo(cx - r * 0.80, cy + r * 0.10)
      ..lineTo(cx - r * 1.5, cy + r * 0.45)
      ..lineTo(cx - r * 1.15, cy + r * 0.55)
      ..close();
    canvas.drawPath(tailPath2, Paint()..color = const Color(0xFFD4A000));

    // Wing (animated-style, mid-position)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - r * 0.18, cy - r * 0.18),
        width: r * 1.4, height: r * 0.7),
      Paint()..color = const Color(0xFFE6B800),
    );

    // Body — golden oval (wider than tall)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy),
        width: r * 2.2, height: r * 2.0),
      Paint()..color = _birdColor,
    );

    // Belly highlight
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + r * 0.15, cy + r * 0.18),
        width: r * 1.4, height: r * 1.2),
      Paint()..color = const Color(0xFFFFF0A0),
    );

    // Eye white
    canvas.drawCircle(
      Offset(cx + r * 0.50, cy - r * 0.25),
      r * 0.32,
      Paint()..color = Colors.white,
    );
    // Pupil
    canvas.drawCircle(
      Offset(cx + r * 0.55, cy - r * 0.22),
      r * 0.16,
      Paint()..color = _eyeColor,
    );
    // Eye shine
    canvas.drawCircle(
      Offset(cx + r * 0.60, cy - r * 0.30),
      r * 0.07,
      Paint()..color = Colors.white,
    );

    // Beak
    final beakPath = Path()
      ..moveTo(cx + r * 0.7, cy)
      ..lineTo(cx + r * 1.3, cy - r * 0.12)
      ..lineTo(cx + r * 1.3, cy + r * 0.18)
      ..close();
    canvas.drawPath(beakPath, Paint()..color = _beakColor);

    // Cheek blush
    canvas.drawCircle(
      Offset(cx + r * 0.35, cy + r * 0.22),
      r * 0.14,
      Paint()..color = const Color(0xFFFF8080).withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_FlappyTapLogoPainter old) => false;
}

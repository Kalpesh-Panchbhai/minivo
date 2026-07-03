import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> solitaireSteps() => [
      GameHowToPlayStep(
        text: 'Build tableau columns in descending order, alternating colors.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _TableauPainter(t),
          canvasSize: const Size(200, 180),
        ),
      ),
      GameHowToPlayStep(
        text: 'Tap the stock pile to draw cards. Move them to the tableau or foundations.',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 2800),
          painter: (t) => _StockPainter(t),
          canvasSize: const Size(200, 180),
        ),
      ),
      GameHowToPlayStep(
        text: 'Stack Aces up to Kings on foundation piles to win!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _FoundationPainter(t),
          canvasSize: const Size(200, 180),
        ),
      ),
    ];

const _kBg = Color(0xFF0B3D2E);
const _kCard = Color(0xFFF9FAFB);
const _kRed = Color(0xFFE53E3E);
const _kBlack = Color(0xFF1A1A2E);
const _kAccent = Color(0xFF22C55E);
const _kCardBack = Color(0xFF2563EB);

double _ease(double v) => v < 0.5 ? 2 * v * v : -1 + (4 - 2 * v) * v;

void _drawBg(Canvas canvas, Size size) {
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size.width, size.height),
    Paint()..color = _kBg,
  );
  canvas.drawCircle(
    Offset(size.width / 2, size.height * 0.5),
    size.width * 0.5,
    Paint()
      ..shader = RadialGradient(
        colors: [_kAccent.withValues(alpha: 0.08), Colors.transparent],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width / 2, size.height * 0.5),
          radius: size.width * 0.5,
        ),
      ),
  );
}

void _drawMiniCard(
  Canvas canvas,
  double x,
  double y,
  double w,
  double h,
  String label,
  Color color, {
  bool faceDown = false,
}) {
  final rect = RRect.fromRectAndRadius(
    Rect.fromLTWH(x, y, w, h),
    Radius.circular(w * 0.12),
  );
  canvas.drawRRect(rect, Paint()..color = Colors.black.withValues(alpha: 0.15));
  if (faceDown) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y - 0.5, w, h),
        Radius.circular(w * 0.12),
      ),
      Paint()..color = _kCardBack,
    );
  } else {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y - 0.5, w, h),
        Radius.circular(w * 0.12),
      ),
      Paint()..color = _kCard,
    );
    if (label.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: color,
            fontSize: w * 0.42,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(x + w / 2 - tp.width / 2, y + h / 2 - tp.height / 2),
      );
    }
  }
}

void _drawEmptySlot(Canvas canvas, double x, double y, double w, double h) {
  final rect = RRect.fromRectAndRadius(
    Rect.fromLTWH(x, y, w, h),
    Radius.circular(w * 0.12),
  );
  canvas.drawRRect(
    rect,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );
}

class _TableauPainter extends CustomPainter {
  final double t;
  const _TableauPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBg(canvas, size);
    final cw = size.width * 0.18;
    final ch = cw * 1.4;
    final startX = size.width * 0.12;
    final startY = size.height * 0.15;

    _drawMiniCard(canvas, startX, startY, cw, ch, 'K', _kBlack);
    _drawMiniCard(canvas, startX, startY + ch * 0.3, cw, ch, 'Q', _kRed);

    final moveT = _ease(t.clamp(0.0, 1.0));
    final destX = startX;
    final destY = startY + ch * 0.6;
    final srcX = size.width * 0.6;
    final srcY = size.height * 0.2;
    final curX = srcX + (destX - srcX) * moveT;
    final curY = srcY + (destY - srcY) * moveT;
    _drawMiniCard(canvas, curX, curY, cw, ch, 'J', _kBlack);

    final tp = TextPainter(
      text: TextSpan(
        text: 'K → Q → J',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(size.width / 2 - tp.width / 2, size.height * 0.88),
    );
  }

  @override
  bool shouldRepaint(covariant _TableauPainter old) => old.t != t;
}

class _StockPainter extends CustomPainter {
  final double t;
  const _StockPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBg(canvas, size);
    final cw = size.width * 0.18;
    final ch = cw * 1.4;

    final stockX = size.width * 0.15;
    final stockY = size.height * 0.28;
    final wasteX = size.width * 0.45;
    final wasteY = stockY;

    _drawMiniCard(
      canvas, stockX - 2, stockY + 4, cw, ch, '', Colors.transparent,
      faceDown: true,
    );
    _drawMiniCard(
      canvas, stockX - 1, stockY + 2, cw, ch, '', Colors.transparent,
      faceDown: true,
    );

    if (t <= 0.3) {
      _drawMiniCard(
        canvas, stockX, stockY, cw, ch, '', Colors.transparent,
        faceDown: true,
      );
    } else if (t <= 0.6) {
      final slideT = _ease(((t - 0.3) / 0.3).clamp(0.0, 1.0));
      final curX = stockX + (wasteX - stockX) * slideT;
      final curY = stockY + (wasteY - stockY) * slideT;
      _drawMiniCard(canvas, curX, curY, cw, ch, '7♥', _kRed);
    } else {
      _drawMiniCard(canvas, wasteX, wasteY, cw, ch, '7♥', _kRed);
    }

    final tp = TextPainter(
      text: TextSpan(
        text: 'Tap stock to draw',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(size.width / 2 - tp.width / 2, size.height * 0.88),
    );
  }

  @override
  bool shouldRepaint(covariant _StockPainter old) => old.t != t;
}

class _FoundationPainter extends CustomPainter {
  final double t;
  const _FoundationPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBg(canvas, size);
    final cw = size.width * 0.16;
    final ch = cw * 1.4;
    const gap = 8.0;
    final totalW = 4 * cw + 3 * gap;
    final baseX = (size.width - totalW) / 2;
    final baseY = size.height * 0.15;

    for (int i = 0; i < 4; i++) {
      _drawEmptySlot(canvas, baseX + i * (cw + gap), baseY, cw, ch);
    }

    final x0 = baseX;
    final x1 = baseX + (cw + gap);
    final x2 = baseX + 2 * (cw + gap);

    _drawMiniCard(canvas, x1, baseY, cw, ch, 'A♥', _kRed);
    _drawMiniCard(canvas, x2, baseY, cw, ch, 'A♦', _kRed);

    final srcY = size.height * 0.7;

    if (t <= 0.2) {
      final p = _ease((t / 0.2).clamp(0.0, 1.0));
      _drawMiniCard(
        canvas, x0, srcY + (baseY - srcY) * p, cw, ch, 'A♠', _kBlack,
      );
    } else {
      _drawMiniCard(canvas, x0, baseY, cw, ch, 'A♠', _kBlack);
    }

    if (t > 0.3) {
      if (t <= 0.5) {
        final p = _ease(((t - 0.3) / 0.2).clamp(0.0, 1.0));
        _drawMiniCard(
          canvas, x0, srcY + (baseY - srcY) * p, cw, ch, '2♠', _kBlack,
        );
      } else {
        _drawMiniCard(canvas, x0, baseY, cw, ch, '2♠', _kBlack);
      }
    }

    if (t > 0.55) {
      if (t <= 0.75) {
        final p = _ease(((t - 0.55) / 0.2).clamp(0.0, 1.0));
        _drawMiniCard(
          canvas, x0, srcY + (baseY - srcY) * p, cw, ch, '3♠', _kBlack,
        );
      } else {
        _drawMiniCard(canvas, x0, baseY, cw, ch, '3♠', _kBlack);
      }
    }

    if (t > 0.8) {
      final alpha = ((t - 0.8) / 0.2).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: 'YOU WIN!',
          style: TextStyle(
            color: _kAccent.withValues(alpha: alpha),
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(size.width / 2 - tp.width / 2, size.height * 0.78),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FoundationPainter old) => old.t != t;
}

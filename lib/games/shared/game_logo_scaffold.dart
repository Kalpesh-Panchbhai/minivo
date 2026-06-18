import 'package:flutter/material.dart';

/// Paints a game's semantic art inside [zone] (a square-ish rect centered in the
/// upper area of the card). Implementations draw relative to [zone].
typedef LogoArtPainter = void Function(Canvas canvas, Rect zone);

/// Shared "Glass Spotlight" logo for every game card — guarantees a consistent,
/// premium look: a themed gradient background, a soft accent spotlight behind a
/// centered hero art, and the game name on a frosted glass bar at the bottom.
///
/// Each game supplies only: [title], a 2-tone [bg] gradient, an [accent] color,
/// and an [art] painter. Layout (name position/size, art zone, glass bar) is
/// identical across all games.
Widget buildGlassSpotlightLogo({
  required double size,
  required String title,
  required List<Color> bg,
  required Color accent,
  required LogoArtPainter art,
}) {
  return SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      size: Size(size, size),
      painter: _GlassSpotlightPainter(
          title: title, bg: bg, accent: accent, art: art),
    ),
  );
}

class _GlassSpotlightPainter extends CustomPainter {
  final String title;
  final List<Color> bg;
  final Color accent;
  final LogoArtPainter art;

  _GlassSpotlightPainter({
    required this.title,
    required this.bg,
    required this.accent,
    required this.art,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;

    // 1. themed gradient background
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: bg,
        ).createShader(rect),
    );

    // 2. accent spotlight glow behind the art
    final glowC = Offset(w * 0.5, h * 0.40);
    canvas.drawCircle(
      glowC,
      w * 0.46,
      Paint()
        ..shader = RadialGradient(
          colors: [accent.withValues(alpha: 0.50), accent.withValues(alpha: 0.0)],
        ).createShader(Rect.fromCircle(center: glowC, radius: w * 0.46)),
    );

    // 3. top sheen
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.55),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.07), Colors.transparent],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.55)),
    );

    // 4. hero art (centered, upper-middle) over a soft contact shadow
    final artSize = w * 0.54;
    final zone = Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.39), width: artSize, height: artSize);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.5, zone.bottom - artSize * 0.04),
          width: artSize * 0.82,
          height: artSize * 0.20),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    art(canvas, zone);

    // 5. frosted glass bar with the name
    final barH = h * 0.185;
    final barTop = h - barH - h * 0.055;
    final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.06, barTop, w * 0.88, barH), Radius.circular(h * 0.045));
    canvas.drawRRect(barRect, Paint()..color = Colors.white.withValues(alpha: 0.16));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(barRect.left, barTop, barRect.width, barH * 0.5),
            Radius.circular(h * 0.045)),
        Paint()..color = Colors.white.withValues(alpha: 0.10));
    canvas.drawRRect(
        barRect,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);

    // accent dot
    final dotR = barH * 0.15;
    final dotC = Offset(barRect.left + barH * 0.34, barTop + barH / 2);
    canvas.drawCircle(dotC, dotR, Paint()..color = accent);

    // name (auto-fit single line)
    final textLeft = dotC.dx + dotR + w * 0.035;
    final maxTextW = barRect.right - textLeft - w * 0.04;
    double fs = h * 0.082;
    late TextPainter tp;
    while (true) {
      tp = TextPainter(
        text: TextSpan(
          text: title.toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: fs,
            letterSpacing: 0.3,
            shadows: [
              Shadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 2, offset: const Offset(0, 1))
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: maxTextW);
      if (tp.didExceedMaxLines == false && tp.width <= maxTextW) break;
      fs -= 1;
      if (fs <= h * 0.05) {
        tp.layout(maxWidth: maxTextW);
        break;
      }
    }
    tp.paint(canvas, Offset(textLeft, barTop + barH / 2 - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _GlassSpotlightPainter old) =>
      old.title != title || old.accent != accent;
}

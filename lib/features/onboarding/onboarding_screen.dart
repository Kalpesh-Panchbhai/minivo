import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_strings.dart';
import '../../core/services/score_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  int _currentPage = 0;
  late final AnimationController _floatCtrl;
  late final AnimationController _particleCtrl;

  static const _pages = <_PageData>[
    _PageData(
      title: AppStrings.onboarding1Title,
      desc: AppStrings.onboarding1Desc,
      gradient: [Color(0xFF6C63FF), Color(0xFF9B93FF)],
      accent: Color(0xFF6C63FF),
    ),
    _PageData(
      title: AppStrings.onboarding2Title,
      desc: AppStrings.onboarding2Desc,
      gradient: [Color(0xFFFF6B6B), Color(0xFFFF9E9E)],
      accent: Color(0xFFFF6B6B),
    ),
    _PageData(
      title: AppStrings.onboarding3Title,
      desc: AppStrings.onboarding3Desc,
      gradient: [Color(0xFF51CF66), Color(0xFF82E096)],
      accent: Color(0xFF51CF66),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _floatCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    ScoreService().setOnboardingSeen();
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    final isLast = _currentPage == _pages.length - 1;
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: page.gradient,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _particleCtrl,
            builder: (_, _) => CustomPaint(
              size: screenSize,
              painter: _ParticlePainter(
                t: _particleCtrl.value,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: TextButton(
                      onPressed: _finish,
                      style: TextButton.styleFrom(
                        foregroundColor:
                            Colors.white.withValues(alpha: 0.85),
                      ),
                      child: const Text(
                        AppStrings.skip,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (i) =>
                        setState(() => _currentPage = i),
                    itemBuilder: (_, index) =>
                        _OnboardingPageContent(
                      index: index,
                      data: _pages[index],
                      floatAnimation: _floatCtrl,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) {
                          final active = i == _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin:
                                const EdgeInsets.symmetric(horizontal: 4),
                            width: active ? 28 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: active
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 28),
                      GestureDetector(
                        onTap: _onNext,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: isLast ? 200 : 64,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Colors.black.withValues(alpha: 0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: isLast
                                ? Text(
                                    AppStrings.getStarted,
                                    style: TextStyle(
                                      color: page.accent,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  )
                                : Icon(
                                    Icons.arrow_forward_rounded,
                                    color: page.accent,
                                    size: 24,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPageContent extends StatelessWidget {
  final int index;
  final _PageData data;
  final Animation<double> floatAnimation;

  const _OnboardingPageContent({
    required this.index,
    required this.data,
    required this.floatAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.04),
          AnimatedBuilder(
            animation: floatAnimation,
            builder: (_, _) {
              final float =
                  math.sin(floatAnimation.value * math.pi) * 8;
              return Transform.translate(
                offset: Offset(0, float),
                child: SizedBox(
                  width: 260,
                  height: 260,
                  child: CustomPaint(
                    painter: _illustrationPainter(
                        index, floatAnimation.value),
                  ),
                ),
              );
            },
          )
              .animate(key: ValueKey('ill$index'))
              .scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1, 1),
                duration: 600.ms,
                curve: Curves.easeOutBack,
              )
              .fadeIn(duration: 400.ms),
          const SizedBox(height: 40),
          Text(
            data.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          )
              .animate(key: ValueKey('t$index'))
              .fadeIn(delay: 200.ms, duration: 400.ms)
              .slideY(begin: 0.3, delay: 200.ms, duration: 400.ms),
          const SizedBox(height: 14),
          Text(
            data.desc,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          )
              .animate(key: ValueKey('d$index'))
              .fadeIn(delay: 350.ms, duration: 400.ms),
        ],
      ),
    );
  }

  CustomPainter _illustrationPainter(int page, double t) {
    switch (page) {
      case 0:
        return _ControllerPainter(t);
      case 1:
        return _TrophyPainter(t);
      case 2:
        return _BoltPainter(t);
      default:
        return _ControllerPainter(t);
    }
  }
}

class _PageData {
  final String title;
  final String desc;
  final List<Color> gradient;
  final Color accent;

  const _PageData({
    required this.title,
    required this.desc,
    required this.gradient,
    required this.accent,
  });
}

class _ParticlePainter extends CustomPainter {
  final double t;
  final Color color;
  _ParticlePainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final rng = math.Random(42);
    for (var i = 0; i < 25; i++) {
      final x = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final speed = 0.3 + rng.nextDouble() * 0.7;
      final r = 2.0 + rng.nextDouble() * 4;
      final y = (baseY - t * speed * size.height) % size.height;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => old.t != t;
}

class _ControllerPainter extends CustomPainter {
  final double t;
  _ControllerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final float = math.sin(t * math.pi);

    canvas.drawCircle(
      Offset(cx, cy),
      size.width * 0.44,
      Paint()..color = Colors.white.withValues(alpha: 0.10),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      size.width * 0.36,
      Paint()..color = Colors.white.withValues(alpha: 0.08),
    );

    final bodyW = size.width * 0.62;
    final bodyH = size.height * 0.30;
    final bodyRect =
        Rect.fromCenter(center: Offset(cx, cy), width: bodyW, height: bodyH);

    final gripW = bodyW * 0.22;
    final gripH = bodyH * 1.15;
    for (final side in [-1.0, 1.0]) {
      final gripCx = cx + side * bodyW * 0.40;
      final gripCy = cy + bodyH * 0.18;
      final gripRect = Rect.fromCenter(
        center: Offset(gripCx, gripCy),
        width: gripW,
        height: gripH,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            gripRect.shift(const Offset(0, 4)),
            Radius.circular(gripW * 0.45)),
        Paint()..color = Colors.black.withValues(alpha: 0.08),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            gripRect, Radius.circular(gripW * 0.45)),
        Paint()
          ..shader = LinearGradient(
            colors: [Colors.white, const Color(0xFFF0F0F8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(gripRect),
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
          bodyRect.shift(const Offset(0, 5)),
          Radius.circular(bodyH * 0.38)),
      Paint()..color = Colors.black.withValues(alpha: 0.10),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(bodyH * 0.38)),
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white, const Color(0xFFF2F2FA)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(bodyRect),
    );

    final dpadX = cx - bodyW * 0.18;
    final dpadY = cy;
    final dpadArm = bodyH * 0.14;
    final dpadPaint = Paint()..color = const Color(0xFFD0D0DD);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(dpadX, dpadY),
            width: dpadArm,
            height: dpadArm * 2.8),
        Radius.circular(dpadArm * 0.25),
      ),
      dpadPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(dpadX, dpadY),
            width: dpadArm * 2.8,
            height: dpadArm),
        Radius.circular(dpadArm * 0.25),
      ),
      dpadPaint,
    );

    final btnX = cx + bodyW * 0.18;
    final btnY = cy;
    final btnR = bodyH * 0.08;
    final gap = btnR * 2.4;
    const colors = [
      Color(0xFFFF6B6B),
      Color(0xFF51CF66),
      Color(0xFFFFD43B),
      Color(0xFF339AF0),
    ];
    final offsets = [
      Offset(0, -gap),
      Offset(gap, 0),
      Offset(0, gap),
      Offset(-gap, 0),
    ];
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset(btnX, btnY) + offsets[i],
        btnR,
        Paint()..color = colors[i],
      );
    }

    _drawStar(canvas, cx - bodyW * 0.52, cy - bodyH * 0.95 + float * 5,
        14, const Color(0xFFFFD43B));
    _drawHeart(canvas, cx + bodyW * 0.50, cy + bodyH * 0.90 - float * 4,
        12, const Color(0xFFFF6B6B));
    _drawDice(canvas, cx + bodyW * 0.48, cy - bodyH * 0.90 + float * 6,
        16);
    _drawPuzzle(canvas, cx - bodyW * 0.48, cy + bodyH * 0.95 - float * 3,
        14, const Color(0xFF51CF66));
  }

  void _drawStar(
      Canvas canvas, double cx, double cy, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final oa = (i * 72 - 90) * math.pi / 180;
      final ia = ((i * 72) + 36 - 90) * math.pi / 180;
      if (i == 0) {
        path.moveTo(cx + r * math.cos(oa), cy + r * math.sin(oa));
      } else {
        path.lineTo(cx + r * math.cos(oa), cy + r * math.sin(oa));
      }
      path.lineTo(
          cx + r * 0.4 * math.cos(ia), cy + r * 0.4 * math.sin(ia));
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _drawHeart(
      Canvas canvas, double cx, double cy, double r, Color color) {
    final path = Path();
    path.moveTo(cx, cy + r * 0.7);
    path.cubicTo(cx - r * 1.2, cy - r * 0.2, cx - r * 0.6, cy - r, cx,
        cy - r * 0.4);
    path.cubicTo(cx + r * 0.6, cy - r, cx + r * 1.2, cy - r * 0.2, cx,
        cy + r * 0.7);
    canvas.drawPath(path, Paint()..color = color);
  }

  void _drawDice(Canvas canvas, double cx, double cy, double r) {
    final rect = Rect.fromCenter(
        center: Offset(cx, cy), width: r * 1.6, height: r * 1.6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(r * 0.25)),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(r * 0.25)),
      Paint()
        ..color = const Color(0xFFE0E0E8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final dp = Paint()..color = const Color(0xFF2D2D3A);
    final dr = r * 0.12;
    final sp = r * 0.35;
    canvas.drawCircle(Offset(cx - sp, cy - sp), dr, dp);
    canvas.drawCircle(Offset(cx, cy), dr, dp);
    canvas.drawCircle(Offset(cx + sp, cy + sp), dr, dp);
  }

  void _drawPuzzle(
      Canvas canvas, double cx, double cy, double r, Color color) {
    final rect = Rect.fromCenter(
        center: Offset(cx, cy), width: r * 1.6, height: r * 1.6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(r * 0.2)),
      Paint()..color = color,
    );
    canvas.drawCircle(
        Offset(cx, cy - r * 0.8 - r * 0.2), r * 0.25,
        Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _ControllerPainter old) => old.t != t;
}

class _TrophyPainter extends CustomPainter {
  final double t;
  _TrophyPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final float = math.sin(t * math.pi);

    canvas.drawCircle(
      Offset(cx, cy),
      size.width * 0.44,
      Paint()..color = Colors.white.withValues(alpha: 0.10),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      size.width * 0.36,
      Paint()..color = Colors.white.withValues(alpha: 0.08),
    );

    final baseW = size.width * 0.24;
    final baseH = size.height * 0.04;
    final baseY = cy + size.height * 0.22;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, baseY), width: baseW, height: baseH),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFDAA520),
    );

    final stemW = size.width * 0.06;
    final stemH = size.height * 0.10;
    final stemY = baseY - stemH / 2 - baseH / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, stemY), width: stemW, height: stemH),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFDAA520),
    );

    final cupTop = stemY - stemH / 2;
    final cupW = size.width * 0.34;
    final cupH = size.height * 0.28;

    final cupPath = Path();
    cupPath.moveTo(cx - cupW / 2, cupTop - cupH);
    cupPath.lineTo(cx - cupW * 0.35, cupTop);
    cupPath.quadraticBezierTo(cx, cupTop + cupH * 0.08,
        cx + cupW * 0.35, cupTop);
    cupPath.lineTo(cx + cupW / 2, cupTop - cupH);
    cupPath.close();

    canvas.save();
    canvas.translate(0, 5);
    canvas.drawPath(
        cupPath, Paint()..color = Colors.black.withValues(alpha: 0.08));
    canvas.restore();

    canvas.drawPath(
      cupPath,
      Paint()
        ..shader = LinearGradient(
          colors: [const Color(0xFFFFD700), const Color(0xFFDAA520)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTRB(
            cx - cupW / 2, cupTop - cupH, cx + cupW / 2, cupTop)),
    );

    for (final side in [-1.0, 1.0]) {
      final hPath = Path();
      final hx = cx + side * cupW / 2;
      final hy = cupTop - cupH * 0.72;
      hPath.moveTo(hx, hy);
      hPath.quadraticBezierTo(
          hx + side * cupW * 0.22, hy + cupH * 0.35, hx, hy + cupH * 0.5);
      canvas.drawPath(
        hPath,
        Paint()
          ..color = const Color(0xFFDAA520)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
    }

    _drawStar(canvas, cx, cupTop - cupH * 0.55, 14, Colors.white);

    _drawStar(canvas, cx - size.width * 0.34, cy - size.height * 0.26 + float * 5,
        10, const Color(0xFFFFD43B));
    _drawStar(canvas, cx + size.width * 0.36, cy - size.height * 0.22 - float * 4,
        8, const Color(0xFFFFD43B));
    _drawStar(canvas, cx - size.width * 0.18, cy - size.height * 0.38 + float * 3,
        7, Colors.white.withValues(alpha: 0.75));
    _drawStar(canvas, cx + size.width * 0.22, cy - size.height * 0.36 - float * 6,
        9, Colors.white.withValues(alpha: 0.65));

    final rng = math.Random(7);
    const confettiColors = [
      Color(0xFFFF6B6B),
      Color(0xFF51CF66),
      Color(0xFFFFD43B),
      Color(0xFF339AF0),
      Colors.white,
    ];
    for (var i = 0; i < 14; i++) {
      final sx = cx + (rng.nextDouble() - 0.5) * size.width * 0.85;
      final sy = cy +
          (rng.nextDouble() - 0.5) * size.height * 0.75 +
          float * (rng.nextDouble() * 6 - 3);
      final sr = 2.0 + rng.nextDouble() * 3;
      canvas.drawCircle(
        Offset(sx, sy),
        sr,
        Paint()
          ..color =
              confettiColors[i % confettiColors.length].withValues(alpha: 0.55),
      );
    }
  }

  void _drawStar(
      Canvas canvas, double cx, double cy, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final oa = (i * 72 - 90) * math.pi / 180;
      final ia = ((i * 72) + 36 - 90) * math.pi / 180;
      if (i == 0) {
        path.moveTo(cx + r * math.cos(oa), cy + r * math.sin(oa));
      } else {
        path.lineTo(cx + r * math.cos(oa), cy + r * math.sin(oa));
      }
      path.lineTo(
          cx + r * 0.4 * math.cos(ia), cy + r * 0.4 * math.sin(ia));
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrophyPainter old) => old.t != t;
}

class _BoltPainter extends CustomPainter {
  final double t;
  _BoltPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final float = math.sin(t * math.pi);

    canvas.drawCircle(
      Offset(cx, cy),
      size.width * 0.44,
      Paint()..color = Colors.white.withValues(alpha: 0.10),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      size.width * 0.36,
      Paint()..color = Colors.white.withValues(alpha: 0.08),
    );

    final boltW = size.width * 0.26;
    final boltH = size.height * 0.48;
    final topY = cy - boltH / 2;

    final boltPath = Path();
    boltPath.moveTo(cx + boltW * 0.12, topY);
    boltPath.lineTo(cx - boltW * 0.32, cy + boltH * 0.05);
    boltPath.lineTo(cx + boltW * 0.06, cy + boltH * 0.05);
    boltPath.lineTo(cx - boltW * 0.12, topY + boltH);
    boltPath.lineTo(cx + boltW * 0.32, cy - boltH * 0.05);
    boltPath.lineTo(cx - boltW * 0.06, cy - boltH * 0.05);
    boltPath.close();

    canvas.save();
    canvas.translate(3, 5);
    canvas.drawPath(
        boltPath, Paint()..color = Colors.black.withValues(alpha: 0.10));
    canvas.restore();

    canvas.drawPath(
      boltPath,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white, const Color(0xFFF0F0F5)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(
            Rect.fromLTWH(cx - boltW, topY, boltW * 2, boltH)),
    );

    canvas.drawPath(
      boltPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25 + float * 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 16),
    );

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.40)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final lines = [
      [cx - boltW * 1.3, cy - boltH * 0.15, 28.0],
      [cx + boltW * 1.3, cy + boltH * 0.10, 22.0],
      [cx - boltW * 1.1, cy + boltH * 0.22, 20.0],
      [cx + boltW * 1.2, cy - boltH * 0.28, 24.0],
      [cx - boltW * 1.0, cy - boltH * 0.32, 16.0],
      [cx + boltW * 1.0, cy + boltH * 0.30, 18.0],
    ];
    for (final l in lines) {
      final lx = l[0] + float * 3;
      canvas.drawLine(
          Offset(lx, l[1]), Offset(lx + l[2], l[1]), linePaint);
    }

    const sparkleColors = [
      Colors.white,
      Color(0xFFFFD43B),
      Color(0xFF51CF66),
    ];
    final rng = math.Random(13);
    for (var i = 0; i < 10; i++) {
      final sx = cx + (rng.nextDouble() - 0.5) * size.width * 0.85;
      final sy = cy + (rng.nextDouble() - 0.5) * size.height * 0.65;
      final sr = 2.0 + rng.nextDouble() * 3;
      final alpha = 0.35 + math.sin(t * math.pi + i * 0.8) * 0.3;
      canvas.drawCircle(
        Offset(sx + float * 2, sy),
        sr,
        Paint()
          ..color = sparkleColors[i % sparkleColors.length]
              .withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BoltPainter old) => old.t != t;
}

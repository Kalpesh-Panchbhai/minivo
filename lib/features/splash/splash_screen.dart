import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_strings.dart';
import '../../core/services/score_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _particleCtrl;

  @override
  void initState() {
    super.initState();
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..repeat();
    _navigate();
  }

  @override
  void dispose() {
    _particleCtrl.dispose();
    super.dispose();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    final seen = ScoreService().hasSeenOnboarding();
    if (seen) {
      context.go('/home');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF7B73FF), Color(0xFF5248E0)],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _particleCtrl,
            builder: (_, _) => CustomPaint(
              size: screenSize,
              painter: _ParticlePainter(t: _particleCtrl.value),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CustomPaint(
                    painter: _LogoPainter(),
                  ),
                )
                    .animate()
                    .scale(
                      begin: const Offset(0.5, 0.5),
                      end: const Offset(1, 1),
                      duration: 700.ms,
                      curve: Curves.easeOutBack,
                    )
                    .fadeIn(duration: 400.ms),
                const SizedBox(height: 28),
                const Text(
                  AppStrings.appName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    height: 1.1,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 500.ms)
                    .slideY(
                        begin: 0.3,
                        end: 0,
                        delay: 300.ms,
                        duration: 500.ms),
                const SizedBox(height: 8),
                Text(
                  AppStrings.appTagline,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ).animate().fadeIn(delay: 600.ms, duration: 500.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = size.width;

    final bgRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, s, s),
      Radius.circular(s * 0.27),
    );
    canvas.drawRRect(
      bgRRect.shift(const Offset(0, 4)),
      Paint()..color = Colors.black.withValues(alpha: 0.15),
    );
    canvas.drawRRect(bgRRect, Paint()..color = Colors.white);

    final bodyW = s * 0.54;
    final bodyH = s * 0.24;
    final bodyRect =
        Rect.fromCenter(center: Offset(cx, cy), width: bodyW, height: bodyH);

    final gripW = bodyW * 0.20;
    final gripH = bodyH * 1.05;
    for (final side in [-1.0, 1.0]) {
      final gripCx = cx + side * bodyW * 0.40;
      final gripCy = cy + bodyH * 0.20;
      final gripRect = Rect.fromCenter(
        center: Offset(gripCx, gripCy),
        width: gripW,
        height: gripH,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            gripRect, Radius.circular(gripW * 0.45)),
        Paint()
          ..shader = LinearGradient(
            colors: [const Color(0xFF6C63FF), const Color(0xFF5248E0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(gripRect),
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(bodyH * 0.38)),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF5248E0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(bodyRect),
    );

    final dpadX = cx - bodyW * 0.18;
    final dpadY = cy;
    final dpadArm = bodyH * 0.14;
    final dpadPaint = Paint()..color = Colors.white.withValues(alpha: 0.85);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(dpadX, dpadY),
            width: dpadArm,
            height: dpadArm * 2.6),
        Radius.circular(dpadArm * 0.25),
      ),
      dpadPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(dpadX, dpadY),
            width: dpadArm * 2.6,
            height: dpadArm),
        Radius.circular(dpadArm * 0.25),
      ),
      dpadPaint,
    );

    final btnX = cx + bodyW * 0.18;
    final btnY = cy;
    final btnR = bodyH * 0.09;
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
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => false;
}

class _ParticlePainter extends CustomPainter {
  final double t;
  _ParticlePainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.08);
    final rng = math.Random(42);
    for (var i = 0; i < 20; i++) {
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

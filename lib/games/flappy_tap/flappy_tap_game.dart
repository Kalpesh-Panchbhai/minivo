import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../game_wrapper.dart';

class FlappyTapGame extends FlameGame with TapCallbacks, HasCollisionDetection {
  late _Bird bird;
  late GameWrapperState wrapper;
  final List<_PipePair> _pipes = [];
  double _pipeTimer = 0;
  final _rand = Random();
  bool _started = false;

  static const double gravity = 900;
  static const double jumpForce = -350;
  static const double pipeSpeed = 180;
  static const double pipeGap = 160;
  static const double pipeWidth = 60;
  static const double pipeInterval = 1.8;

  @override
  Color backgroundColor() => const Color(0xFF87CEEB);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    bird = _Bird();
    add(bird);

    // Ground
    add(_Ground(size));
  }

  void setWrapper(GameWrapperState w) {
    wrapper = w;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (wrapper.state == GameState.playing) {
      bird.jump();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (wrapper.state != GameState.playing) {
      if (wrapper.state == GameState.ready && _started) {
        _reset();
      }
      return;
    }

    _started = true;

    // Bird physics
    bird.velocity += gravity * dt;
    bird.position.y += bird.velocity * dt;

    // Spawn pipes
    _pipeTimer += dt;
    if (_pipeTimer >= pipeInterval) {
      _pipeTimer = 0;
      _spawnPipe();
    }

    // Move pipes & check score
    for (final pipe in _pipes) {
      pipe.topPipe.position.x -= pipeSpeed * dt;
      pipe.bottomPipe.position.x -= pipeSpeed * dt;

      if (!pipe.scored && pipe.topPipe.position.x + pipeWidth < bird.position.x) {
        pipe.scored = true;
        wrapper.incrementScore();
      }
    }

    // Remove off-screen pipes
    _pipes.removeWhere((p) {
      if (p.topPipe.position.x < -pipeWidth) {
        p.topPipe.removeFromParent();
        p.bottomPipe.removeFromParent();
        return true;
      }
      return false;
    });

    // Collision detection
    if (_checkCollision()) {
      wrapper.endGame();
    }
  }

  void _spawnPipe() {
    final gapY = 100 + _rand.nextDouble() * (size.y - 300);

    final top = _PipeComponent(
      position: Vector2(size.x, 0),
      size: Vector2(pipeWidth, gapY - pipeGap / 2),
      color: const Color(0xFF4CAF50),
    );
    final bottom = _PipeComponent(
      position: Vector2(size.x, gapY + pipeGap / 2),
      size: Vector2(pipeWidth, size.y - gapY - pipeGap / 2),
      color: const Color(0xFF4CAF50),
    );

    add(top);
    add(bottom);
    _pipes.add(_PipePair(top, bottom));
  }

  bool _checkCollision() {
    // Ground / ceiling
    if (bird.position.y > size.y - 60 || bird.position.y < 0) return true;

    // Pipes
    for (final pipe in _pipes) {
      final px = pipe.topPipe.position.x;
      if (bird.position.x + 15 > px && bird.position.x - 15 < px + pipeWidth) {
        if (bird.position.y - 15 < pipe.topPipe.size.y ||
            bird.position.y + 15 > pipe.bottomPipe.position.y) {
          return true;
        }
      }
    }
    return false;
  }

  void _reset() {
    _started = false;
    _pipeTimer = 0;
    for (final p in _pipes) {
      p.topPipe.removeFromParent();
      p.bottomPipe.removeFromParent();
    }
    _pipes.clear();
    bird.position = Vector2(size.x * 0.3, size.y * 0.4);
    bird.velocity = 0;
  }
}

class _Bird extends PositionComponent {
  double velocity = 0;

  @override
  Future<void> onLoad() async {
    final game = findParent<FlappyTapGame>()!;
    position = Vector2(game.size.x * 0.3, game.size.y * 0.4);
    size = Vector2(30, 30);
    anchor = Anchor.center;
  }

  void jump() {
    velocity = FlappyTapGame.jumpForce;
  }

  @override
  void render(Canvas canvas) {
    // Bird body
    final paint = Paint()..color = const Color(0xFFFFD700);
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), 15, paint);

    // Eye
    final eyePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(size.x / 2 + 5, size.y / 2 - 4), 5, eyePaint);
    final pupilPaint = Paint()..color = Colors.black;
    canvas.drawCircle(Offset(size.x / 2 + 7, size.y / 2 - 4), 2.5, pupilPaint);

    // Beak
    final beakPaint = Paint()..color = const Color(0xFFFF6B00);
    final beakPath = Path()
      ..moveTo(size.x / 2 + 12, size.y / 2)
      ..lineTo(size.x / 2 + 22, size.y / 2 + 2)
      ..lineTo(size.x / 2 + 12, size.y / 2 + 5)
      ..close();
    canvas.drawPath(beakPath, beakPaint);

    // Wing
    final wingPaint = Paint()..color = const Color(0xFFFFB300);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x / 2 - 5, size.y / 2 + 3),
        width: 14,
        height: 8,
      ),
      wingPaint,
    );
  }
}

class _PipeComponent extends PositionComponent {
  final Color color;

  _PipeComponent({
    required super.position,
    required super.size,
    required this.color,
  });

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = color;
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      paint,
    );

    // Pipe cap
    final capPaint = Paint()..color = const Color(0xFF388E3C);
    final isTop = position.y == 0;
    if (isTop) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-4, size.y - 24, size.x + 8, 24),
          const Radius.circular(4),
        ),
        capPaint,
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-4, 0, size.x + 8, 24),
          const Radius.circular(4),
        ),
        capPaint,
      );
    }
  }
}

class _Ground extends PositionComponent {
  final Vector2 gameSize;

  _Ground(this.gameSize) {
    position = Vector2(0, gameSize.y - 60);
    size = Vector2(gameSize.x, 60);
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = const Color(0xFF8B6914);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);

    // Grass
    final grassPaint = Paint()..color = const Color(0xFF4CAF50);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, 12), grassPaint);
  }
}

class _PipePair {
  final _PipeComponent topPipe;
  final _PipeComponent bottomPipe;
  bool scored = false;
  _PipePair(this.topPipe, this.bottomPipe);
}

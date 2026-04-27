import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../game_wrapper.dart';
import '../../core/services/audio_service.dart';

class FlappyTapGame extends FlameGame with TapCallbacks, HasCollisionDetection {
  late _Bird bird;
  late GameWrapperState wrapper;
  final List<_PipePair> _pipes = [];
  double _pipeTimer = 0;
  final _rand = Random();
  bool _started = false;
  double _graceTimer = 0;
  double _gameTime = 0;
  final AudioService _audio = AudioService();
  bool _hasPlayedGameOver = false;

  static const double gravity = 800;
  static const double jumpForce = -320;
  static const double pipeSpeed = 160;
  static const double pipeGap = 150;
  static const double pipeWidth = 60;
  static const double pipeInterval = 2.0;
  static const double gracePeriod = 0.8;
  static const double birdRadius = 15;

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
      _audio.playTap();
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

    _gameTime += dt;

    if (!_started) {
      _started = true;
      _graceTimer = 0;
      bird.position = Vector2(size.x * 0.25, size.y * 0.5);
      bird.velocity = 0;
      bird.rotation = 0;
    }

    _graceTimer += dt;

    // Bird physics with rotation
    bird.velocity += gravity * dt;
    bird.position.y += bird.velocity * dt;
    
    // Update bird rotation based on velocity
    bird.rotation = bird.velocity * 0.003;
    bird.rotation = bird.rotation.clamp(-0.5, 0.5);

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
        _audio.playScore();
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

    // Collision detection (skip during grace period)
    if (_graceTimer > gracePeriod && _checkCollision()) {
      if (!_hasPlayedGameOver) {
        _audio.playGameOver();
        _hasPlayedGameOver = true;
      }
      wrapper.endGame();
    }
  }

  void _spawnPipe() {
    final minGapY = pipeGap + 50;
    final maxGapY = size.y - pipeGap - 100;
    final gapY = minGapY + _rand.nextDouble() * (maxGapY - minGapY);

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
    if (bird.position.y > size.y - 60 || bird.position.y < -birdRadius) return true;

    // Pipes
    for (final pipe in _pipes) {
      final px = pipe.topPipe.position.x;
      if (bird.position.x + birdRadius > px && bird.position.x - birdRadius < px + pipeWidth) {
        if (bird.position.y - birdRadius < pipe.topPipe.size.y ||
            bird.position.y + birdRadius > pipe.bottomPipe.position.y) {
          return true;
        }
      }
    }
    return false;
  }

  void _reset() {
    _started = false;
    _pipeTimer = 0;
    _gameTime = 0;
    _hasPlayedGameOver = false;
    for (final p in _pipes) {
      p.topPipe.removeFromParent();
      p.bottomPipe.removeFromParent();
    }
    _pipes.clear();
    bird.position = Vector2(size.x * 0.25, size.y * 0.5);
    bird.velocity = 0;
    bird.rotation = 0;
  }
}

class _Bird extends PositionComponent {
  double velocity = 0;
  double rotation = 0;

  @override
  Future<void> onLoad() async {
    final game = findParent<FlappyTapGame>()!;
    position = Vector2(game.size.x * 0.25, game.size.y * 0.5);
    size = Vector2(30, 30);
    anchor = Anchor.center;
  }

  void jump() {
    velocity = FlappyTapGame.jumpForce;
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(rotation);
    canvas.translate(-size.x / 2, -size.y / 2);

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

    canvas.restore();
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

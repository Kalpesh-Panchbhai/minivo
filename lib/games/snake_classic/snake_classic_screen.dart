import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/services/audio_service.dart';
import '../framework/game_definition.dart';
import '../framework/game_scaffold.dart';
import '../framework/game_session.dart';
import '../shared/animated_background.dart';
import 'snake_classic_definition.dart';

// ── Snake brand colors ─────────────────────────────────────────────────────
const Color _kSnakeGreen = Color(0xFF20C997);
const Color _kSnakeDark  = Color(0xFF099268);

// ── Game constants ─────────────────────────────────────────────────────────
const int _kBoardN = 15;
const int _kInitialLen = 3;
const Color _kBoardBg   = Color(0xFFE6FCF5);
const Color _kFoodColor = Color(0xFFEF4444);
const Color _kFoodGlow  = Color(0xFFFFB4B4);

// ── Per-difficulty config (keyed by DifficultyDef.key) ─────────────────────
class _SnakeConfig {
  // Speed model: snake starts at [startMs] and gets [deltaPerApple] ms
  // faster per apple eaten, capped at [floorMs]. Easy stays constant
  // (delta = 0), so casual players never feel chased.
  final int startMs;
  final int deltaPerApple;
  final int floorMs;
  final int pointsPerFood;
  const _SnakeConfig({
    required this.startMs,
    required this.deltaPerApple,
    required this.floorMs,
    required this.pointsPerFood,
  });

  int tickMsForApples(int apples) {
    final raw = startMs - deltaPerApple * apples;
    return raw < floorMs ? floorMs : raw;
  }
}

const Map<String, _SnakeConfig> _kConfigs = {
  'easy':   _SnakeConfig(startMs: 280, deltaPerApple: 0, floorMs: 280, pointsPerFood: 5),
  'medium': _SnakeConfig(startMs: 220, deltaPerApple: 1, floorMs: 190, pointsPerFood: 10),
  'hard':   _SnakeConfig(startMs: 170, deltaPerApple: 2, floorMs: 130, pointsPerFood: 20),
};

_SnakeConfig _configFor(DifficultyDef d) =>
    _kConfigs[d.key] ?? _kConfigs['medium']!;

// ── Direction enum ─────────────────────────────────────────────────────────
enum _Dir { up, down, left, right }

extension _DirX on _Dir {
  int get dx => switch (this) {
        _Dir.left  => -1,
        _Dir.right => 1,
        _ => 0,
      };
  int get dy => switch (this) {
        _Dir.up   => -1,
        _Dir.down => 1,
        _ => 0,
      };
  bool isOpposite(_Dir other) => switch (this) {
        _Dir.up    => other == _Dir.down,
        _Dir.down  => other == _Dir.up,
        _Dir.left  => other == _Dir.right,
        _Dir.right => other == _Dir.left,
      };
}

// ════════════════════════════════════════════════════════════════
// Root screen — thin wrapper around GameScaffold
// ════════════════════════════════════════════════════════════════

class SnakeClassicScreen extends StatelessWidget {
  const SnakeClassicScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      GameScaffold(definition: snakeClassicGame);
}

// ════════════════════════════════════════════════════════════════
// Board — playing-state widget driven by GameSession
// ════════════════════════════════════════════════════════════════

class SnakeClassicBoard extends StatefulWidget {
  final GameSession session;
  const SnakeClassicBoard({required this.session, super.key});

  @override
  State<SnakeClassicBoard> createState() => _SnakeClassicBoardState();
}

class _SnakeClassicBoardState extends State<SnakeClassicBoard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Snake state
  final _rng = math.Random();
  List<math.Point<int>> _snake = const [];
  List<math.Point<int>> _prevSnake = const [];
  _Dir _dir = _Dir.right;
  _Dir? _pendingDir;
  List<math.Point<int>> _foods = const [];

  bool _gameOver = false;

  // Apples eaten this run — drives speed progression.
  int _applesEaten = 0;

  // Eat-animation state.
  final List<_EatEffect> _eatEffects = [];
  int? _lastEatTimeMs;

  // Swipe gesture state
  double _dragDx = 0;
  double _dragDy = 0;

  late final AnimationController _tickCtrl;
  StreamSubscription<bool>? _pauseSub;

  DifficultyDef get _diff => widget.session.difficulty;
  _SnakeConfig get _cfg => _configFor(_diff);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tickCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    )..addStatusListener(_onTickComplete);

    _pauseSub = widget.session.pauseStream.listen((paused) {
      if (!mounted || _gameOver) return;
      if (paused) {
        if (_tickCtrl.isAnimating) _tickCtrl.stop();
      } else {
        if (!_tickCtrl.isAnimating) _tickCtrl.forward(from: _tickCtrl.value);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startGame();
    });
  }

  @override
  void dispose() {
    _pauseSub?.cancel();
    _tickCtrl.removeStatusListener(_onTickComplete);
    _tickCtrl.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_gameOver) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      if (_tickCtrl.isAnimating) _tickCtrl.stop();
    } else if (state == AppLifecycleState.resumed) {
      if (!_tickCtrl.isAnimating && !_gameOver && !widget.session.isPaused) {
        _tickCtrl.forward(from: _tickCtrl.value);
      }
    }
  }

  void _onTickComplete(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (!mounted || _gameOver) return;
    if (widget.session.isPaused) return;
    _tick();
    if (mounted && !_gameOver) {
      _tickCtrl.forward(from: 0);
    }
  }

  // ── Game start ───────────────────────────────────────────────────────────

  void _startGame() {
    final mid = _kBoardN ~/ 2;
    final initial = <math.Point<int>>[
      for (int i = 0; i < _kInitialLen; i++)
        math.Point(mid + (_kInitialLen - 1 - i), mid),
    ];

    setState(() {
      _snake = initial;
      _prevSnake = List<math.Point<int>>.from(initial);
      _dir = _Dir.right;
      _pendingDir = null;
      _foods = _spawnFoods(initial, []);
      _gameOver = false;
      _applesEaten = 0;
      _eatEffects.clear();
      _lastEatTimeMs = null;
    });

    _tickCtrl.duration = Duration(milliseconds: _cfg.tickMsForApples(0));
    _tickCtrl.forward(from: 0);
  }

  // ── Food spawning ────────────────────────────────────────────────────────

  List<math.Point<int>> _spawnFoods(
    List<math.Point<int>> snake,
    List<math.Point<int>> existingFoods,
  ) {
    final occupied = {...snake.toSet(), ...existingFoods.toSet()};
    final empties = <math.Point<int>>[];
    for (int x = 0; x < _kBoardN; x++) {
      for (int y = 0; y < _kBoardN; y++) {
        final p = math.Point(x, y);
        if (!occupied.contains(p)) empties.add(p);
      }
    }
    final result = List<math.Point<int>>.from(existingFoods);
    while (result.length < 3 && empties.isNotEmpty) {
      final idx = _rng.nextInt(empties.length);
      result.add(empties[idx]);
      empties.removeAt(idx);
    }
    return result;
  }

  // ── Tick / collision logic ───────────────────────────────────────────────

  void _tick() {
    if (_gameOver) return;

    if (_pendingDir != null && !_dir.isOpposite(_pendingDir!)) {
      _dir = _pendingDir!;
    }
    _pendingDir = null;

    final head = _snake.first;
    final next = math.Point(head.x + _dir.dx, head.y + _dir.dy);

    // Wall collision
    if (next.x < 0 || next.x >= _kBoardN ||
        next.y < 0 || next.y >= _kBoardN) {
      _endGame();
      return;
    }

    final ateIdx = _foods.indexWhere((f) => f == next);
    final ate = ateIdx >= 0;
    final lastIndex = ate ? _snake.length : _snake.length - 1;
    for (int i = 0; i < lastIndex; i++) {
      if (_snake[i] == next) {
        _endGame();
        return;
      }
    }

    final newSnake = <math.Point<int>>[next, ..._snake];
    if (!ate) newSnake.removeLast();

    final eatenPos = ate ? _foods[ateIdx] : null;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    setState(() {
      _prevSnake = _snake;
      _snake = newSnake;
      if (ate) {
        widget.session.incrementScore(_cfg.pointsPerFood);
        _applesEaten += 1;
        AudioService().playScore();
        final remaining = List<math.Point<int>>.from(_foods)
          ..removeAt(ateIdx);
        _foods = _spawnFoods(newSnake, remaining);

        _eatEffects.add(_EatEffect(
          cellPos: eatenPos!,
          points: _cfg.pointsPerFood,
          color: _diff.color,
          startTimeMs: nowMs,
        ));
        _lastEatTimeMs = nowMs;
        _eatEffects.removeWhere((e) => nowMs - e.startTimeMs > 700);
      }
    });

    if (ate) {
      _tickCtrl.duration = Duration(
        milliseconds: _cfg.tickMsForApples(_applesEaten),
      );
    }
  }

  void _endGame() {
    _tickCtrl.stop();
    AudioService().playGameOver();
    setState(() => _gameOver = true);
    widget.session.failGame();
  }

  void _handleSwipeDirection(_Dir d) {
    if (_gameOver) return;
    if (d.isOpposite(_dir)) return;
    _pendingDir = d;

    // Snappy turn — fast-forward in-flight tick if it has >50ms left.
    if (_tickCtrl.isAnimating && _tickCtrl.duration != null) {
      final remainingMs =
          (1.0 - _tickCtrl.value) * _tickCtrl.duration!.inMilliseconds;
      if (remainingMs > 50) {
        _tickCtrl.animateTo(
          1.0,
          duration: const Duration(milliseconds: 40),
          curve: Curves.linear,
        );
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final side = math.min(c.maxWidth - 24, c.maxHeight);
        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) {
                _dragDx = 0;
                _dragDy = 0;
              },
              onPanUpdate: (d) {
                _dragDx += d.delta.dx;
                _dragDy += d.delta.dy;
              },
              onPanEnd: (d) {
                final v = d.velocity.pixelsPerSecond;
                final dx = math.max(v.dx.abs() / 4, _dragDx.abs());
                final dy = math.max(v.dy.abs() / 4, _dragDy.abs());
                if (dx < 24 && dy < 24) return;

                if (dx > dy) {
                  final velSignal = v.dx.abs() / 4;
                  final distSignal = _dragDx.abs();
                  final goRight =
                      (velSignal > distSignal) ? (v.dx > 0) : (_dragDx > 0);
                  _handleSwipeDirection(goRight ? _Dir.right : _Dir.left);
                } else {
                  final velSignal = v.dy.abs() / 4;
                  final distSignal = _dragDy.abs();
                  final goDown =
                      (velSignal > distSignal) ? (v.dy > 0) : (_dragDy > 0);
                  _handleSwipeDirection(goDown ? _Dir.down : _Dir.up);
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: _kBoardBg,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _kSnakeGreen.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedBuilder(
                    animation: _tickCtrl,
                    builder: (_, _) => CustomPaint(
                      size: Size.square(side),
                      painter: _SnakePainter(
                        snake: _snake,
                        prevSnake: _prevSnake,
                        foods: _foods,
                        dir: _dir,
                        t: _tickCtrl.value,
                        eatEffects: _eatEffects,
                        lastEatTimeMs: _lastEatTimeMs,
                        nowMs: DateTime.now().millisecondsSinceEpoch,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Eat-effect data
// ════════════════════════════════════════════════════════════════

class _EatEffect {
  final math.Point<int> cellPos;
  final int points;
  final Color color;
  final int startTimeMs;

  const _EatEffect({
    required this.cellPos,
    required this.points,
    required this.color,
    required this.startTimeMs,
  });
}

// ════════════════════════════════════════════════════════════════
// CUSTOM PAINTER — snake board (snake + food + grid + eat effects)
// ════════════════════════════════════════════════════════════════

class _SnakePainter extends CustomPainter {
  final List<math.Point<int>> snake;
  final List<math.Point<int>> prevSnake;
  final List<math.Point<int>> foods;
  final _Dir dir;
  final double t;
  final List<_EatEffect> eatEffects;
  final int? lastEatTimeMs;
  final int nowMs;

  _SnakePainter({
    required this.snake,
    required this.prevSnake,
    required this.foods,
    required this.dir,
    required this.t,
    required this.eatEffects,
    required this.lastEatTimeMs,
    required this.nowMs,
  });

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  void paint(Canvas canvas, Size size) {
    final cs = size.width / _kBoardN;

    final gridPaint = Paint()
      ..color = _kSnakeGreen.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (int i = 1; i < _kBoardN; i++) {
      canvas.drawLine(
        Offset(i * cs, 0), Offset(i * cs, size.height), gridPaint,
      );
      canvas.drawLine(
        Offset(0, i * cs), Offset(size.width, i * cs), gridPaint,
      );
    }

    _drawFood(canvas, cs);

    if (snake.isNotEmpty) {
      _drawSnake(canvas, cs);
    }

    _drawEatEffects(canvas, cs);
  }

  void _drawSnake(Canvas canvas, double cs) {
    final centers = <Offset>[
      for (int i = 0; i < snake.length; i++)
        () {
          final to = snake[i];
          final from = (i < prevSnake.length) ? prevSnake[i] : to;
          final px = from.x + (to.x - from.x) * t;
          final py = from.y + (to.y - from.y) * t;
          return Offset((px + 0.5) * cs, (py + 0.5) * cs);
        }(),
    ];

    if (centers.length < 2) {
      canvas.drawCircle(centers.first, cs * 0.47,
          Paint()..color = _kSnakeDark);
      canvas.drawCircle(centers.first, cs * 0.32,
          Paint()..color = _kSnakeGreen);
      _drawHead(canvas, centers.first, cs);
      return;
    }

    final segs = <(Offset, Offset, Offset, double)>[];
    final n = centers.length;
    for (int i = 0; i < n - 1; i++) {
      final from = i == 0
          ? centers[0]
          : Offset.lerp(centers[i - 1], centers[i], 0.5)!;
      final to = i == n - 2
          ? centers.last
          : Offset.lerp(centers[i], centers[i + 1], 0.5)!;
      final ctl = centers[i];
      final tFromHead = i / (n - 1);
      segs.add((from, ctl, to, tFromHead));
    }

    final outer = Paint()
      ..color = _kSnakeDark
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final (from, ctl, to, p) in segs) {
      outer.strokeWidth = _lerp(cs * 0.94, cs * 0.55, p);
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(ctl.dx, ctl.dy, to.dx, to.dy);
      canvas.drawPath(path, outer);
    }

    final inner = Paint()
      ..color = _kSnakeGreen
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final (from, ctl, to, p) in segs) {
      inner.strokeWidth = _lerp(cs * 0.66, cs * 0.30, p);
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(ctl.dx, ctl.dy, to.dx, to.dy);
      canvas.drawPath(path, inner);
    }

    _drawHead(canvas, centers.first, cs);
  }

  void _drawHead(Canvas canvas, Offset head, double cs) {
    var headScale = 1.0;
    if (lastEatTimeMs != null) {
      final age = nowMs - lastEatTimeMs!;
      if (age >= 0 && age < 180) {
        final pulseT = age / 180.0;
        headScale = 1.0 + 0.18 * math.sin(pulseT * math.pi);
      }
    }

    canvas.drawCircle(
      head, cs * 0.48 * headScale, Paint()..color = _kSnakeDark,
    );
    canvas.drawCircle(
      Offset(head.dx - cs * 0.10, head.dy - cs * 0.10),
      cs * 0.14 * headScale,
      Paint()..color = _kSnakeGreen.withValues(alpha: 0.45),
    );
    _drawEyesAt(canvas, head, cs);
  }

  void _drawFood(Canvas canvas, double cs) {
    for (final food in foods) {
      final cx = (food.x + 0.5) * cs;
      final cy = (food.y + 0.5) * cs;
      canvas.drawCircle(
        Offset(cx, cy), cs * 0.50,
        Paint()
          ..color = _kFoodColor.withValues(alpha: 0.18)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, cs * 0.30),
      );
      canvas.drawCircle(
        Offset(cx, cy), cs * 0.34, Paint()..color = _kFoodColor,
      );
      canvas.drawCircle(
        Offset(cx - cs * 0.10, cy - cs * 0.10), cs * 0.10,
        Paint()..color = _kFoodGlow.withValues(alpha: 0.85),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + cs * 0.08, cy - cs * 0.32),
          width: cs * 0.20, height: cs * 0.10,
        ),
        Paint()..color = const Color(0xFF22C55E),
      );
    }
  }

  void _drawEatEffects(Canvas canvas, double cs) {
    for (final e in eatEffects) {
      final age = nowMs - e.startTimeMs;
      if (age < 0 || age > 700) continue;

      final cx = (e.cellPos.x + 0.5) * cs;
      final cy = (e.cellPos.y + 0.5) * cs;

      if (age < 220) {
        final flashT = age / 220.0;
        final scale = 1.0 + flashT * 0.55;
        final alpha = 1.0 - flashT;
        canvas.drawCircle(
          Offset(cx, cy), cs * 0.50 * scale,
          Paint()
            ..color = _kFoodColor.withValues(alpha: 0.30 * alpha)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, cs * 0.25),
        );
        canvas.drawCircle(
          Offset(cx, cy), cs * 0.34 * scale,
          Paint()..color = _kFoodColor.withValues(alpha: alpha),
        );
      }

      if (age < 600) {
        final popT = age / 600.0;
        final yOffset = -popT * cs * 1.5;
        final alpha = (1.0 - popT).clamp(0.0, 1.0);
        final scale = 0.85 + (1 - popT) * 0.20;
        final tp = TextPainter(
          text: TextSpan(
            text: '+${e.points}',
            style: TextStyle(
              color: e.color.withValues(alpha: alpha),
              fontSize: cs * 0.62 * scale,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              shadows: [
                Shadow(
                  color: Colors.white.withValues(alpha: alpha * 0.7),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(cx - tp.width / 2, cy + yOffset - tp.height / 2),
        );
      }
    }
  }

  void _drawEyesAt(Canvas canvas, Offset center, double cs) {
    final cx = center.dx;
    final cy = center.dy;
    final off = cs * 0.18;
    final Offset e1, e2;
    switch (dir) {
      case _Dir.right:
        e1 = Offset(cx + cs * 0.12, cy - off);
        e2 = Offset(cx + cs * 0.12, cy + off);
        break;
      case _Dir.left:
        e1 = Offset(cx - cs * 0.12, cy - off);
        e2 = Offset(cx - cs * 0.12, cy + off);
        break;
      case _Dir.up:
        e1 = Offset(cx - off, cy - cs * 0.12);
        e2 = Offset(cx + off, cy - cs * 0.12);
        break;
      case _Dir.down:
        e1 = Offset(cx - off, cy + cs * 0.12);
        e2 = Offset(cx + off, cy + cs * 0.12);
        break;
    }
    final whitePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()..color = const Color(0xFF1B3A2A);
    canvas.drawCircle(e1, cs * 0.10, whitePaint);
    canvas.drawCircle(e2, cs * 0.10, whitePaint);
    canvas.drawCircle(e1, cs * 0.05, pupilPaint);
    canvas.drawCircle(e2, cs * 0.05, pupilPaint);
  }

  @override
  bool shouldRepaint(covariant _SnakePainter old) =>
      old.snake != snake ||
      old.prevSnake != prevSnake ||
      old.foods != foods ||
      old.dir != dir ||
      old.t != t ||
      old.eatEffects != eatEffects ||
      old.lastEatTimeMs != lastEatTimeMs ||
      old.nowMs != nowMs;
}

// ════════════════════════════════════════════════════════════════
// Decorative background — floating snake icons + apple dots
// ════════════════════════════════════════════════════════════════

class SnakeBgPainter extends AnimatedBgPainter {
  const SnakeBgPainter(super.t);

  @override
  void paintAt(Canvas canvas, Size size, double t) {
    final phase = t * 2 * math.pi;
    final items = <(IconData, Color, double, double, double, double)>[
      (Icons.pest_control_rounded, _kSnakeGreen, 0.10, 0.12,  90, 0.0),
      (Icons.circle_rounded,       _kFoodColor,  0.86, 0.18,  44, 0.7),
      (Icons.pest_control_rounded, _kSnakeGreen, 0.18, 0.78,  76, 1.4),
      (Icons.circle_rounded,       _kFoodColor,  0.78, 0.84,  36, 2.1),
      (Icons.pest_control_rounded, _kSnakeGreen, 0.50, 0.50,  64, 4.7),
      (Icons.circle_rounded,       _kFoodColor,  0.06, 0.42,  28, 3.5),
    ];

    for (final (icon, color, xRel, yRel, fontSize, p) in items) {
      final wave = math.sin(phase + p);
      final yBob = wave * 6;
      final rot = math.sin(phase * 0.7 + p) * 0.10;
      final alpha = 0.05 + (math.sin(phase * 1.3 + p) + 1) / 2 * 0.05;

      final tp = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: fontSize,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: color.withValues(alpha: alpha),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final cx = size.width * xRel;
      final cy = size.height * yRel + yBob;
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rot);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }
}

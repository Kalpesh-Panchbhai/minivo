import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/audio_service.dart';
import '../../core/services/score_service.dart';
import '../../core/widgets/how_to_play_sheet.dart';
import '../game_picker_scaffold.dart';
import '../game_registry.dart';
import '../game_wrapper.dart';
import '../shared/animated_background.dart';
import '../shared/animated_difficulty_icon.dart';
import '../shared/game_control_buttons.dart';
import '../shared/game_hud_bar.dart';
import '../shared/game_difficulty_picker.dart';
import '../shared/generic_game_result_screen.dart' as game_result;
import '../shared/rewarded_continue_action.dart';
import 'dino_run_logo.dart' show drawPixelDino;
import 'dino_run_stats.dart';
import 'dino_run_tutorial.dart';

const Color _kBgTop    = Color(0xFFF7F7F7);
const Color _kBgBot    = Color(0xFFECECEC);
const Color _kAccent   = Color(0xFF535353);
const Color _kAccentLt = Color(0xFF757575);

const Color _kEasyColor   = Color(0xFF22C55E);
const Color _kMediumColor = Color(0xFFF59E0B);
const Color _kHardColor   = Color(0xFFEF4444);

const Color _kDayBg      = Color(0xFFF7F7F7);
const Color _kNightBg    = Color(0xFF1A1A2E);
const Color _kDayFg      = Color(0xFF535353);
const Color _kNightFg    = Color(0xFFE0E0E0);
const double _kGroundH    = 50.0;
const double _kDinoW      = 42.0;
const double _kDinoH      = 55.0;
const double _kDinoXRel   = 0.12;
const double _kGravity    = 1800.0;
const double _kJumpForce  = -620.0;

enum _Difficulty { easy, medium, hard }

extension _DifficultyX on _Difficulty {
  String get label => ['EASY', 'MEDIUM', 'HARD'][index];
  Color  get color => [_kEasyColor, _kMediumColor, _kHardColor][index];

  double get startSpeed     => [180.0, 240.0, 320.0][index];
  double get speedRamp      => [0.8, 1.4, 2.2][index];
  double get maxSpeed       => [400.0, 520.0, 620.0][index];
  double get minObstGap     => [280.0, 220.0, 170.0][index];
  String get subKey         => ['easy', 'medium', 'hard'][index];

  String get hint => [
        'Slower speed ramp · wider gaps · great for warming up',
        'Classic T-Rex speed · tighter gaps · stay sharp',
        'Blistering pace · narrow gaps · pure reflexes',
      ][index];

  DifficultyKind get kind => [
        DifficultyKind.easy,
        DifficultyKind.medium,
        DifficultyKind.hard,
      ][index];
}

enum _ObstacleType { cactusSmall, cactusLarge, cactusCluster }

class _Obstacle {
  double x;
  final _ObstacleType type;
  bool scored = false;

  _Obstacle({required this.x, required this.type});

  double get width {
    switch (type) {
      case _ObstacleType.cactusSmall:   return 18;
      case _ObstacleType.cactusLarge:   return 24;
      case _ObstacleType.cactusCluster: return 46;
    }
  }

  Rect hitbox(double groundY) {
    switch (type) {
      case _ObstacleType.cactusSmall:
        return Rect.fromLTWH(x, groundY - 28, 18, 28);
      case _ObstacleType.cactusLarge:
        return Rect.fromLTWH(x, groundY - 40, 24, 40);
      case _ObstacleType.cactusCluster:
        return Rect.fromLTWH(x, groundY - 34, 46, 34);
    }
  }
}

class _Cloud {
  double x;
  final double y;
  final double radius;
  final double speed;
  _Cloud({required this.x, required this.y, required this.radius, required this.speed});
}

class DinoRunScreen extends StatefulWidget {
  const DinoRunScreen({super.key});

  @override
  State<DinoRunScreen> createState() => _DinoRunScreenState();
}

class _DinoRunScreenState extends State<DinoRunScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  _Difficulty? _activeDifficulty;
  _Difficulty _pickerDifficulty = _Difficulty.values[DifficultyKind.defaultIndex];
  bool _isFavorite = false;

  double _dinoY     = 0.0;
  double _dinoVy    = 0.0;

  final List<_Obstacle> _obstacles = [];
  final List<_Cloud> _clouds = [];
  double _sinceLastSpawn = 0.0;
  double _currentSpeed   = 0.0;
  double _groundOffset   = 0.0;
  double _legPhase       = 0.0;
  double _blinkTimer     = 0.0;
  bool   _isBlinking     = false;

  bool _isNight   = false;
  double _nightT  = 0.0;

  int _score      = 0;
  int _bestScore  = 0;
  bool _isNewBest = false;
  bool _gameOver  = false;

  double _canvasW = 0.0;
  double _canvasH = 0.0;

  late final Ticker _ticker;
  DateTime? _lastTime;
  final _repaint = ValueNotifier<int>(0);
  final _rng = math.Random();

  late final AnimationController _flashCtrl;
  double get _deathFlashAlpha => _flashCtrl.value * 0.55;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isFavorite = ScoreService().isFavorite(kDinoRunGameId);
    _ticker = createTicker(_onTick);
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flashCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ticker.dispose();
    _flashCtrl.dispose();
    _repaint.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_activeDifficulty == null || _gameOver) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _stopTicker();
    } else if (state == AppLifecycleState.resumed) {
      if (!_ticker.isActive && !_gameOver) _startTicker();
    }
  }

  void _startTicker() {
    _lastTime = null;
    _ticker.start();
  }

  void _stopTicker() {
    _ticker.stop();
    _lastTime = null;
  }

  void _onTick(Duration elapsed) {
    if (_lastTime == null) {
      _lastTime = DateTime.now();
      return;
    }
    if (!mounted || _gameOver) return;
    if (GameWrapper.of(context).state == GameState.paused) return;

    final now = DateTime.now();
    final dt = now.difference(_lastTime!).inMicroseconds / 1e6;
    _lastTime = now;
    _update(dt.clamp(0.0, 0.05));
  }

  int _bestFor(_Difficulty d) =>
      ScoreService().getHighScore(kDinoRunGameId, subKey: d.subKey);

  void _toggleFavorite() {
    ScoreService().toggleFavorite(kDinoRunGameId);
    setState(() => _isFavorite = !_isFavorite);
  }

  void _showHelp() {
    final info = GameRegistry.getById(kDinoRunGameId);
    if (info == null) return;
    showHowToPlaySheet(
      context,
      title: info.name,
      howToPlay: info.howToPlay,
      accent: _kAccent,
      steps: dinoRunSteps(),
      gameId: kDinoRunGameId,
    );
  }

  void _initClouds() {
    _clouds.clear();
    if (_canvasW == 0 || _canvasH == 0) return;
    final skyH = _canvasH * 0.4;
    for (int i = 0; i < 4; i++) {
      _clouds.add(_Cloud(
        x: _canvasW * (i / 4) + _rng.nextDouble() * (_canvasW / 4),
        y: 20 + _rng.nextDouble() * skyH,
        radius: 20 + _rng.nextDouble() * 16,
        speed: 15 + _rng.nextDouble() * 15,
      ));
    }
  }

  void _startGame(_Difficulty diff) {
    _stopTicker();
    _obstacles.clear();

    final groundY = _canvasH > 0 ? _canvasH - _kGroundH : 0.0;
    setState(() {
      _activeDifficulty = diff;
      _pickerDifficulty = diff;
      _dinoY = groundY;
      _dinoVy = 0.0;
      _score = 0;
      _bestScore = _bestFor(diff);
      _isNewBest = false;
      _gameOver = false;
      _sinceLastSpawn = 0.0;
      _currentSpeed = diff.startSpeed;
      _groundOffset = 0.0;
      _legPhase = 0.0;
      _isNight = false;
      _nightT = 0.0;
    });

    _initClouds();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        GameWrapper.of(context).setDifficultyAndMode(difficulty: diff.label, subKey: diff.subKey);
        GameWrapper.of(context).startGame();
        GameWrapper.of(context).updateScore(0);
        _startTicker();
      }
    });
  }

  void _newGame() => _startGame(_activeDifficulty ?? _pickerDifficulty);

  void _continueGame() {
    if (_activeDifficulty == null) return;
    setState(() {
      _obstacles.clear();
      _dinoY = _canvasH > 0 ? _canvasH - _kGroundH : 0.0;
      _dinoVy = 0.0;
      _gameOver = false;
      _sinceLastSpawn = 0.0;
    });
    GameWrapper.of(context).continueAfterGameOver();
    _startTicker();
  }

  void _backToPicker() {
    _stopTicker();
    setState(() {
      _activeDifficulty = null;
      _gameOver = false;
    });
    GameWrapper.of(context).restartGame();
  }

  void _backOrHome() {
    final wrapper = GameWrapper.of(context);
    wrapper.handleExit(() {
      _stopTicker();
      if (context.canPop()) context.pop(); else context.go('/home');
    });
  }

  void _jump() {
    if (_activeDifficulty == null || _gameOver) return;
    final groundY = _canvasH - _kGroundH;
    if (_dinoY >= groundY - 1) {
      setState(() => _dinoVy = _kJumpForce);
      AudioService().playScore();
    }
  }

  void _update(double dt) {
    final diff = _activeDifficulty;
    if (diff == null || _gameOver || _canvasH == 0) return;

    final groundY = _canvasH - _kGroundH;
    final dinoX = _canvasW * _kDinoXRel;

    _currentSpeed = (_currentSpeed + diff.speedRamp * dt).clamp(0, diff.maxSpeed);
    _groundOffset = (_groundOffset + _currentSpeed * dt) % 40.0;
    _legPhase = (_legPhase + _currentSpeed * dt * 0.15) % (2 * math.pi);

    _blinkTimer += dt;
    if (_isBlinking) {
      if (_blinkTimer > 0.12) {
        _isBlinking = false;
        _blinkTimer = 0.0;
      }
    } else if (_blinkTimer > 2.5 + _rng.nextDouble() * 2.0) {
      _isBlinking = true;
      _blinkTimer = 0.0;
    }

    for (final cloud in _clouds) {
      cloud.x -= cloud.speed * dt;
      if (cloud.x + cloud.radius * 2 < 0) {
        cloud.x = _canvasW + cloud.radius;
      }
    }

    _sinceLastSpawn += _currentSpeed * dt;
    final spawnGap = diff.minObstGap + (500 - _currentSpeed).clamp(0, 300) * 0.4;
    if (_sinceLastSpawn >= spawnGap) {
      _sinceLastSpawn = 0;
      _spawnObstacle(diff);
    }

    for (final obs in _obstacles) {
      obs.x -= _currentSpeed * dt;
      if (!obs.scored && obs.x + obs.width < dinoX) {
        obs.scored = true;
        _score += 1;
        if (_score > _bestScore) {
          _bestScore = _score;
          _isNewBest = true;
          ScoreService().saveScore(kDinoRunGameId, _score, subKey: diff.subKey);
        }
        GameWrapper.of(context).updateScore(_score);
      }
    }
    _obstacles.removeWhere((o) => o.x + o.width < -20);

    if (_dinoY < groundY || _dinoVy < 0) {
      _dinoVy += _kGravity * dt;
      _dinoY += _dinoVy * dt;
      if (_dinoY >= groundY) {
        _dinoY = groundY;
        _dinoVy = 0;
      }
    }

    final dinoRect = Rect.fromLTWH(
      dinoX, _dinoY - _kDinoH, _kDinoW, _kDinoH,
    );
    final shrunk = dinoRect.deflate(3);

    for (final obs in _obstacles) {
      if (shrunk.overlaps(obs.hitbox(groundY))) {
        _endGame();
        return;
      }
    }

    final prevNight = _isNight;
    _isNight = (_score ~/ 100).isOdd;
    if (_isNight != prevNight) {
      _nightT = 0;
    }
    _nightT = (_nightT + dt * 2.0).clamp(0.0, 1.0);

    if (_score > 0 && _score % 100 == 0) {
      AudioService().playScore();
    }

    _repaint.value++;
  }

  void _spawnObstacle(_Difficulty diff) {
    final types = [
      _ObstacleType.cactusSmall,
      _ObstacleType.cactusLarge,
      _ObstacleType.cactusCluster,
    ];
    _obstacles.add(_Obstacle(
      x: _canvasW,
      type: types[_rng.nextInt(types.length)],
    ));
  }

  void _endGame() {
    _stopTicker();
    AudioService().playGameOver();
    _flashCtrl.value = 1.0;
    _flashCtrl.animateTo(0.0, duration: const Duration(milliseconds: 400));
    setState(() => _gameOver = true);

    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      if (mounted) GameWrapper.of(context).endGame();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) GameWrapper.of(context).endGame();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    GameWrapper.of(context);
    if (_activeDifficulty == null) return _buildPicker();
    return _buildGame();
  }

  Widget _buildPicker() {
    return GamePickerScaffold(
      bgColorTop: _kBgTop,
      bgColorBottom: _kBgBot,
      animatedBg: AnimatedBackground(
        factory: (t) => _DinoBgPainter(t),
        period: const Duration(seconds: 10),
      ),
      iconRingColors: const [Color(0xFF535353), Color(0xFF757575), Color(0xFF535353)],
      iconChild: Builder(builder: (ctx) {
        final info = GameRegistry.getById(kDinoRunGameId);
        final logo = info?.buildBrandedLogo(size: 84);
        if (logo != null) {
          return ClipRRect(borderRadius: BorderRadius.circular(42), child: logo);
        }
        return const Icon(Icons.directions_run_rounded, size: 40, color: _kAccent);
      }),
      title: 'Dino Run',
      subtitle: 'Run, jump, duck — survive the desert!',
      onBack: () => context.go('/home'),
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: _showHelp,
      gameId: kDinoRunGameId,
      tallThreshold: 860,
      body: _PickerSection(
        difficulty: _pickerDifficulty,
        onDifficultyChanged: (d) => setState(() => _pickerDifficulty = d),
        onPlay: () => _startGame(_pickerDifficulty),
      ),
    );
  }

  Widget _buildGame() {
    if (_gameOver) return _buildGameOverScreen();

    final diff = _activeDifficulty!;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _jump(),
      child: Stack(
        children: [
          Positioned.fill(child: _buildCanvas()),
          if (_deathFlashAlpha > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.white.withValues(alpha: _deathFlashAlpha),
                ),
              ),
            ),
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _buildGameHud(diff),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameHud(_Difficulty diff) {
    return GameHudBar(
      leading: GameBackButton(onTap: _backOrHome),
      centerContent: _ScoreBoardPill(
        difficulty: diff,
        score: _score,
        best: _bestScore,
      ),
      trailing: GameRestartButton(
        gameName: 'Dino Run',
        accentColor: _kAccent,
        onRestart: _newGame,
        onDialogOpened: _stopTicker,
        onDialogDismissed: () {
          if (!_gameOver) _startTicker();
        },
      ),
    );
  }

  Widget _buildCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        if (_canvasW != w || _canvasH != h) {
          _canvasW = w;
          _canvasH = h;
          final newGround = h - _kGroundH;
          if (_dinoY <= 0.0 || _dinoY > newGround) {
            _dinoY = newGround;
          }
          if (_clouds.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _initClouds();
            });
          }
        }

        return ValueListenableBuilder<int>(
          valueListenable: _repaint,
          builder: (context2, value, child) => CustomPaint(
            size: Size(w, h),
            painter: _DinoRunPainter(
              dinoY: _dinoY,
              canvasW: w,
              canvasH: h,
              obstacles: List.unmodifiable(_obstacles),
              clouds: List.unmodifiable(_clouds),
              score: _score,
              groundOffset: _groundOffset,
              legPhase: _legPhase,
              isBlinking: _isBlinking,
              isDead: _gameOver,
              isNight: _isNight,
              nightT: _nightT,
            ),
          ),
        );
      },
    );
  }

  Widget _buildGameOverScreen() {
    final difficulty = _activeDifficulty!;
    final continueAction = rewardedContinueAction(
      context: context,
      label: 'Watch Ad to Continue',
      color: difficulty.color,
      onRewarded: _continueGame,
    );
    return game_result.GenericGameResultScreen(
      gameId: kDinoRunGameId,
      score: _score,
      headline: 'Game Over',
      badgeContent: '🦖',
      badgeColor: difficulty.color,
      showNewBestBadge: _isNewBest,
      actions: [
        ?continueAction,
        game_result.GameResultAction(
          label: 'Play Again',
          icon: Icons.refresh_rounded,
          onTap: _newGame,
          filled: continueAction == null,
          color: difficulty.color,
          actionId: 'play_again',
        ),
        game_result.GameResultAction(
          label: 'Change Mode',
          icon: Icons.tune_rounded,
          onTap: _backToPicker,
          filled: false,
          actionId: 'change_mode',
        ),
        game_result.GameResultAction(
          label: 'Home',
          icon: Icons.home_rounded,
          onTap: () => context.go('/home'),
          actionId: 'home',
          filled: false,
        ),
      ],
      statsWidget: game_result.GameResultStatsRow(
        stats: [
          game_result.StatItem(
            label: 'SCORE',
            value: _score,
            color: difficulty.color,
          ),
          game_result.StatItem(
            label: 'BEST',
            value: _bestScore,
            color: const Color(0xFF8B7BA7),
          ),
        ],
      ),
    );
  }
}

class _PickerSection extends StatelessWidget {
  final _Difficulty difficulty;
  final ValueChanged<_Difficulty> onDifficultyChanged;
  final VoidCallback onPlay;

  const _PickerSection({
    required this.difficulty,
    required this.onDifficultyChanged,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return GameSinglePickerBody(
      difficulties: _Difficulty.values.map((d) => GameDifficultyData(
        label: d.label,
        color: d.color,
        kind: d.kind,
        hint: d.hint,
        bestScore: ScoreService().getHighScore(kDinoRunGameId, subKey: d.subKey),
        bestLabel: (s) => 'Best $s',
      )).toList(),
      activeIndex: _Difficulty.values.indexOf(difficulty),
      onChanged: (i) => onDifficultyChanged(_Difficulty.values[i]),
      playLabel: 'Play Dino Run',
      playSubLabel: 'Survive the desert',
      onPlay: onPlay,
      accentColor: _kAccent,
    );
  }
}

class _ScoreBoardPill extends StatelessWidget {
  final _Difficulty difficulty;
  final int score;
  final int best;

  const _ScoreBoardPill({
    required this.difficulty,
    required this.score,
    required this.best,
  });

  @override
  Widget build(BuildContext context) {
    final color = difficulty.color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.30),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedDifficultyIcon(
                kind: difficulty.kind,
                size: 14,
                prominent: false,
              ),
              const SizedBox(width: 6),
              Text(
                difficulty.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _kAccent.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _scoreColumn('SCORE', score, color),
              const SizedBox(width: 18),
              Container(
                width: 1,
                height: 28,
                color: _kAccent.withValues(alpha: 0.20),
              ),
              const SizedBox(width: 18),
              _scoreColumn('BEST', best, _kAccentLt),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scoreColumn(String label, int value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.85),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Text(
            '$value',
            key: ValueKey<int>(value),
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _DinoRunPainter extends CustomPainter {
  final double dinoY;
  final double canvasW;
  final double canvasH;
  final List<_Obstacle> obstacles;
  final List<_Cloud> clouds;
  final int score;
  final double groundOffset;
  final double legPhase;
  final bool isBlinking;
  final bool isDead;
  final bool isNight;
  final double nightT;

  const _DinoRunPainter({
    required this.dinoY,
    required this.canvasW,
    required this.canvasH,
    required this.obstacles,
    required this.clouds,
    required this.score,
    required this.groundOffset,
    required this.legPhase,
    required this.isBlinking,
    required this.isDead,
    required this.isNight,
    required this.nightT,
  });

  Color _lerpFg() => Color.lerp(_kDayFg, _kNightFg, isNight ? nightT : 1 - nightT)!;
  Color _lerpBg() => Color.lerp(_kDayBg, _kNightBg, isNight ? nightT : 1 - nightT)!;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bg = _lerpBg();
    final fg = _lerpFg();
    final groundY = h - _kGroundH;

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = bg);

    if (isNight && nightT > 0.3) {
      _drawStars(canvas, w, groundY, fg);
    }

    for (final cloud in clouds) {
      _drawCloud(canvas, cloud.x, cloud.y, cloud.radius, fg);
    }

    _drawGround(canvas, w, h, groundY, fg);

    for (final obs in obstacles) {
      _drawObstacle(canvas, obs, groundY, fg);
    }

    final dinoX = w * _kDinoXRel;
    _drawDino(canvas, dinoX, dinoY, groundY, fg, bg);
  }

  void _drawStars(Canvas canvas, double w, double groundY, Color fg) {
    final starPaint = Paint()..color = fg.withValues(alpha: 0.4);
    final rng = math.Random(42);
    for (int i = 0; i < 20; i++) {
      final sx = rng.nextDouble() * w;
      final sy = rng.nextDouble() * groundY * 0.6;
      canvas.drawCircle(Offset(sx, sy), 1.2, starPaint);
    }
  }

  void _drawCloud(Canvas canvas, double cx, double cy, double r, Color fg) {
    final paint = Paint()..color = fg.withValues(alpha: 0.08);
    canvas.drawCircle(Offset(cx, cy), r, paint);
    canvas.drawCircle(Offset(cx + r * 0.6, cy + r * 0.1), r * 0.7, paint);
    canvas.drawCircle(Offset(cx - r * 0.5, cy + r * 0.1), r * 0.6, paint);
  }

  void _drawGround(Canvas canvas, double w, double h, double groundY, Color fg) {
    canvas.drawLine(
      Offset(0, groundY),
      Offset(w, groundY),
      Paint()
        ..color = fg
        ..strokeWidth = 1.5,
    );

    final dirtPaint = Paint()
      ..color = fg.withValues(alpha: 0.15)
      ..strokeWidth = 1;
    const tileW = 40.0;
    final startX = -(groundOffset % tileW);
    for (double x = startX; x < w; x += tileW) {
      canvas.drawLine(
        Offset(x + 4, groundY + 8),
        Offset(x + 14, groundY + 8),
        dirtPaint,
      );
      canvas.drawCircle(Offset(x + 28, groundY + 12), 2, dirtPaint);
    }
  }

  void _drawObstacle(Canvas canvas, _Obstacle obs, double groundY, Color fg) {
    final paint = Paint()..color = fg;
    switch (obs.type) {
      case _ObstacleType.cactusSmall:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(obs.x, groundY - 28, 18, 28),
            const Radius.circular(3),
          ),
          paint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(obs.x + 14, groundY - 20, 6, 12),
            const Radius.circular(2),
          ),
          paint,
        );
      case _ObstacleType.cactusLarge:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(obs.x, groundY - 40, 10, 40),
            const Radius.circular(3),
          ),
          paint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(obs.x + 10, groundY - 32, 7, 16),
            const Radius.circular(2),
          ),
          paint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(obs.x - 5, groundY - 24, 7, 12),
            const Radius.circular(2),
          ),
          paint,
        );
      case _ObstacleType.cactusCluster:
        for (int i = 0; i < 3; i++) {
          final cx = obs.x + i * 16.0;
          final ch = 26.0 + (i == 1 ? 8.0 : 0.0);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(cx, groundY - ch, 10, ch),
              const Radius.circular(3),
            ),
            paint,
          );
        }
    }
  }

  void _drawDino(Canvas canvas, double cx, double dy, double groundY,
      Color fg, Color bg) {
    drawPixelDino(canvas, cx, dy, 2.5, fg, bg,
        dead: isDead, blink: isBlinking,
        legPhase: legPhase, inAir: dy < groundY - 1);
  }

  @override
  bool shouldRepaint(covariant _DinoRunPainter old) =>
      old.dinoY != dinoY ||
      old.obstacles != obstacles ||
      old.clouds != clouds ||
      old.score != score ||
      old.groundOffset != groundOffset ||
      old.legPhase != legPhase ||
      old.isBlinking != isBlinking ||
      old.isDead != isDead ||
      old.isNight != isNight ||
      old.nightT != nightT;
}

class _DinoBgPainter extends AnimatedBgPainter {
  const _DinoBgPainter(super.t);

  @override
  void paintAt(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;
    final fg = const Color(0xFF535353).withValues(alpha: 0.06);

    for (int i = 0; i < 4; i++) {
      final cx = ((0.15 + i * 0.25 + t * 0.08) % 1.1 - 0.05) * w;
      final cy = 0.08 * h + i * 0.06 * h;
      canvas.drawCircle(Offset(cx, cy), w * 0.06, Paint()..color = fg);
      canvas.drawCircle(Offset(cx + w * 0.04, cy), w * 0.04, Paint()..color = fg);
    }

    final groundY = h * 0.82;
    canvas.drawLine(
      Offset(0, groundY),
      Offset(w, groundY),
      Paint()
        ..color = const Color(0xFF535353).withValues(alpha: 0.08)
        ..strokeWidth = 1,
    );

    final dinoX = ((0.3 + t * 0.1) % 1.0) * w;
    drawPixelDino(
      canvas, dinoX - 8, groundY, 0.8,
      const Color(0xFF535353).withValues(alpha: 0.08),
      const Color(0xFF535353).withValues(alpha: 0.0),
    );

    for (int i = 0; i < 2; i++) {
      final cx = ((0.6 + i * 0.35 + t * 0.05) % 1.1) * w;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx, groundY - 12, 5, 12),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFF535353).withValues(alpha: 0.06),
      );
    }
  }
}

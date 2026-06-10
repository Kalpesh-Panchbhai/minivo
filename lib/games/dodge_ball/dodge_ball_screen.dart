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
import 'dodge_ball_logo.dart';
import 'dodge_ball_stats.dart';
import 'dodge_ball_tutorial.dart';

const Color _kBgDark   = Color(0xFF0F0F23);
const Color _kBgLight  = Color(0xFF1A1A3E);
const Color _kAccent   = Color(0xFF00D4FF);
const Color _kAccentLt = Color(0xFF66E5FF);

const Color _kEasyColor   = Color(0xFF22C55E);
const Color _kMediumColor = Color(0xFFF59E0B);
const Color _kHardColor   = Color(0xFFEF4444);

const double _kRefWidth = 390.0;
const double _kBasePlayerRadius = 14.0;
const double _kMaxPlayerRadius  = 38.0;
const double _kLerpSpeed = 50.0;

const List<Color> _kObsColors = [
  Color(0xFFFF6B6B),
  Color(0xFFFFD93D),
  Color(0xFFFF9FF3),
  Color(0xFF6BCB77),
  Color(0xFFCC8EFF),
  Color(0xFFFF922B),
];

enum _Difficulty { easy, medium, hard }

extension _DifficultyX on _Difficulty {
  String get label => ['EASY', 'MEDIUM', 'HARD'][index];
  Color  get color => [_kEasyColor, _kMediumColor, _kHardColor][index];

  double get startSpeed   => [160.0, 240.0, 340.0][index];
  double get speedRamp    => [8.0, 14.0, 22.0][index];
  double get maxSpeed     => [420.0, 560.0, 700.0][index];
  double get spawnInterval=> [1.2, 0.85, 0.55][index];
  double get spawnRamp    => [0.015, 0.025, 0.04][index];
  double get minSpawn     => [0.45, 0.30, 0.18][index];
  int    get maxActive    => [2, 3, 4][index];
  double get minObsRadius => [12.0, 10.0, 8.0][index];
  double get maxObsRadius => [22.0, 24.0, 28.0][index];
  double get obsGrow      => [0.08, 0.14, 0.22][index];
  double get obsMaxExtra  => [8.0, 12.0, 18.0][index];
  int    get pointsPer    => [5, 10, 20][index];
  double get growRate     => [0.5, 0.9, 1.4][index];
  double get driftStart   => [20.0, 18.0, 15.0][index];
  double get driftMax     => [60.0, 90.0, 130.0][index];
  double get driftRamp    => [1.0, 2.0, 3.5][index];
  double get burstAfter   => [40.0, 25.0, 15.0][index];
  double get spdMulBase   => [1.0, 1.0, 1.0][index];
  double get spdMulMax    => [1.3, 1.5, 1.8][index];
  double get wallNarrowPx => [0.4, 0.7, 1.2][index];
  double get wallMax      => [50.0, 70.0, 90.0][index];
  double get trailLen     => [20.0, 30.0, 45.0][index];
  double get zigzagAmp    => [0.0, 20.0, 35.0][index];
  double get zigzagFreq   => [0.0, 3.0, 4.5][index];
  double get gravPull     => [0.0, 8.0, 20.0][index];
  String get subKey       => ['easy', 'medium', 'hard'][index];

  String get hint => [
    'Gentle pace · fewer obstacles · great for warming up',
    'Faster drops · more obstacles · stay sharp',
    'Blistering speed · packed field · pure reflexes',
  ][index];

  DifficultyKind get kind => [
    DifficultyKind.easy,
    DifficultyKind.medium,
    DifficultyKind.hard,
  ][index];
}

class _Obstacle {
  double x;
  double y;
  final double baseX;
  final double radius;
  final Color color;
  final int shape;
  final double speedMul;
  final double driftAmp;
  final double driftPhase;
  final bool zigzag;
  final double zigzagPhase;
  bool scored;

  _Obstacle({
    required this.x,
    required this.y,
    required this.radius,
    required this.color,
    required this.shape,
    required this.speedMul,
    required this.driftAmp,
    required this.driftPhase,
    required this.zigzag,
    required this.zigzagPhase,
  })  : baseX = x,
        scored = false;
}

class DodgeBallScreen extends StatefulWidget {
  const DodgeBallScreen({super.key});

  @override
  State<DodgeBallScreen> createState() => _DodgeBallScreenState();
}

class _DodgeBallScreenState extends State<DodgeBallScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  _Difficulty? _activeDifficulty;
  _Difficulty _pickerDifficulty = _Difficulty.values[DifficultyKind.defaultIndex];
  bool _isFavorite = false;

  double _playerX = 0.0;
  double _targetPlayerX = 0.0;
  double _playerRadius = _kBasePlayerRadius;
  double _dragStartX = 0.0;
  double _dragPlayerStartX = 0.0;

  final List<_Obstacle> _obstacles = [];
  double _sinceLastSpawn = 0.0;
  double _currentSpeed   = 0.0;
  double _elapsed        = 0.0;
  double _currentSpawnInterval = 1.2;
  double _obsRadiusExtra = 0.0;
  double _currentDrift   = 0.0;
  double _wallInset      = 0.0;

  int  _score     = 0;
  int  _bestScore = 0;
  bool _isNewBest = false;
  bool _gameOver  = false;

  double _canvasW = 0.0;
  double _canvasH = 0.0;
  double _scale = 1.0;
  double _bottomOffset = 30.0;

  late final Ticker _ticker;
  Duration? _lastElapsed;
  final _repaint = ValueNotifier<int>(0);
  final _rng = math.Random();

  late final AnimationController _flashCtrl;

  bool _shielded = false;
  double _shieldTimer = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isFavorite = ScoreService().isFavorite(kDodgeBallGameId);
    _ticker = createTicker(_onTick);
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
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
    _lastElapsed = null;
    _ticker.start();
  }

  void _stopTicker() {
    _ticker.stop();
    _lastElapsed = null;
  }

  void _onTick(Duration elapsed) {
    if (_lastElapsed == null) {
      _lastElapsed = elapsed;
      return;
    }
    if (!mounted || _gameOver) {
      _lastElapsed = elapsed;
      return;
    }
    if (GameWrapper.of(context).state == GameState.paused) {
      _lastElapsed = elapsed;
      return;
    }
    final dt = (elapsed - _lastElapsed!).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    _update(dt.clamp(0.0, 0.05));
  }

  int _bestFor(_Difficulty d) =>
      ScoreService().getHighScore(kDodgeBallGameId, subKey: d.subKey);

  void _toggleFavorite() {
    ScoreService().toggleFavorite(kDodgeBallGameId);
    setState(() => _isFavorite = !_isFavorite);
  }

  void _showHelp() {
    final info = GameRegistry.getById(kDodgeBallGameId);
    if (info == null) return;
    showHowToPlaySheet(
      context,
      title: info.name,
      howToPlay: info.howToPlay,
      accent: _kAccent,
      steps: dodgeBallSteps(),
      gameId: kDodgeBallGameId,
    );
  }

  void _startGame(_Difficulty diff) {
    _stopTicker();
    _obstacles.clear();

    setState(() {
      _activeDifficulty = diff;
      _pickerDifficulty = diff;
      _playerX = _canvasW / 2;
      _targetPlayerX = _canvasW / 2;
      _playerRadius = _kBasePlayerRadius * _scale;
      _score = 0;
      _bestScore = _bestFor(diff);
      _isNewBest = false;
      _gameOver = false;
      _sinceLastSpawn = 0.0;
      _currentSpeed = diff.startSpeed;
      _elapsed = 0.0;
      _currentSpawnInterval = diff.spawnInterval;
      _obsRadiusExtra = 0.0;
      _currentDrift = diff.driftStart;
      _wallInset = 0.0;
      _shielded = false;
      _shieldTimer = 0.0;
    });

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
      _playerX = _canvasW / 2;
      _targetPlayerX = _canvasW / 2;
      _gameOver = false;
      _sinceLastSpawn = 0.0;
      _shielded = true;
      _shieldTimer = 3.0;
      _playerRadius = (_playerRadius * 0.75).clamp(_kBasePlayerRadius * _scale, _kMaxPlayerRadius * _scale);
    });
    GameWrapper.of(context).continueAfterGameOver();
    _startTicker();
  }

  void _backOrHome() {
    final wrapper = GameWrapper.of(context);
    wrapper.handleExit(() {
      _stopTicker();
      if (context.canPop()) context.pop(); else context.go('/home');
    });
  }

  void _update(double dt) {
    final diff = _activeDifficulty;
    if (diff == null || _gameOver || _canvasH == 0) return;

    _elapsed += dt;
    _currentSpeed = (_currentSpeed + diff.speedRamp * dt).clamp(0, diff.maxSpeed);
    final scaledBase = _kBasePlayerRadius * _scale;
    final scaledMax = _kMaxPlayerRadius * _scale;
    _playerRadius = (_playerRadius + diff.growRate * _scale * dt).clamp(scaledBase, scaledMax);
    _currentSpawnInterval = (_currentSpawnInterval - diff.spawnRamp * dt).clamp(diff.minSpawn, diff.spawnInterval);
    _obsRadiusExtra = (_obsRadiusExtra + diff.obsGrow * dt).clamp(0, diff.obsMaxExtra);
    _currentDrift = (_currentDrift + diff.driftRamp * dt).clamp(0, diff.driftMax);
    final wallCap = math.min(diff.wallMax, _canvasW * 0.18);
    _wallInset = (_wallInset + diff.wallNarrowPx * dt).clamp(0, wallCap);

    final lerpT = (1.0 - math.exp(-_kLerpSpeed * dt)).clamp(0.0, 1.0);
    _playerX += (_targetPlayerX - _playerX) * lerpT;
    _playerX = _playerX.clamp(
      _wallInset + _playerRadius, _canvasW - _wallInset - _playerRadius,
    );

    final spdMulProgress = (_elapsed / 120).clamp(0.0, 1.0);
    final spdMulRange = diff.spdMulBase + (diff.spdMulMax - diff.spdMulBase) * spdMulProgress;

    if (diff.gravPull > 0 && _obstacles.isNotEmpty) {
      double nearestDist = double.infinity;
      double pullDx = 0;
      final playerY = _canvasH - _playerRadius - _bottomOffset;
      for (final obs in _obstacles) {
        final gravRange = _canvasH * 0.28;
        final dx = obs.x - _playerX;
        final dy = obs.y - playerY;
        final d = math.sqrt(dx * dx + dy * dy);
        if (d < nearestDist && d < gravRange) {
          nearestDist = d;
          pullDx = dx;
        }
      }
      if (nearestDist < _canvasH * 0.28) {
        final strength = diff.gravPull * (1 - nearestDist / (_canvasH * 0.28)) * dt;
        _playerX += pullDx.sign * strength;
        _playerX = _playerX.clamp(_wallInset + _playerRadius, _canvasW - _wallInset - _playerRadius);
      }
    }

    if (_shielded) {
      _shieldTimer -= dt;
      if (_shieldTimer <= 0) {
        _shielded = false;
        _shieldTimer = 0.0;
      }
    }

    _sinceLastSpawn += dt;
    final maxObs = diff.maxActive + (_elapsed ~/ 15);
    if (_sinceLastSpawn >= _currentSpawnInterval && _obstacles.length < maxObs) {
      _sinceLastSpawn = 0;

      if (_elapsed >= diff.burstAfter && _rng.nextDouble() < 0.25) {
        final count = 2 + _rng.nextInt(2);
        for (int i = 0; i < count; i++) {
          _spawnObstacle(diff, spdMulRange: spdMulRange);
        }
      } else {
        _spawnObstacle(diff, spdMulRange: spdMulRange);
      }
    }

    final playerY = _canvasH - _playerRadius - _bottomOffset;

    for (final obs in _obstacles) {
      obs.y += _currentSpeed * obs.speedMul * dt;

      if (obs.driftAmp > 0) {
        obs.x = (obs.baseX + math.sin(_elapsed * 1.5 + obs.driftPhase) * obs.driftAmp)
            .clamp(_wallInset + obs.radius, _canvasW - _wallInset - obs.radius);
      }
      if (obs.zigzag) {
        obs.x = (obs.x + math.sin(_elapsed * diff.zigzagFreq + obs.zigzagPhase) * diff.zigzagAmp * dt * 4)
            .clamp(_wallInset + obs.radius, _canvasW - _wallInset - obs.radius);
      }

      if (!obs.scored && obs.y - obs.radius > playerY + _playerRadius) {
        obs.scored = true;
        _score += diff.pointsPer;
        if (_score > _bestScore) {
          _bestScore = _score;
          _isNewBest = true;
          ScoreService().saveScore(kDodgeBallGameId, _score, subKey: diff.subKey);
        }
        GameWrapper.of(context).updateScore(_score);
        AudioService().playScore();
      }
    }
    _obstacles.removeWhere((o) => o.y - o.radius > _canvasH + 50);

    if (!_shielded) {
      for (final obs in _obstacles) {
        final dx = obs.x - _playerX;
        final dy = obs.y - playerY;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist < obs.radius + _playerRadius - 4) {
          _endGame();
          return;
        }

        if (diff.trailLen > 0) {
          final trailTop = obs.y - diff.trailLen;
          final trailBot = obs.y;
          if (playerY >= trailTop && playerY <= trailBot) {
            if ((_playerX - obs.x).abs() < obs.radius + _playerRadius - 5) {
              _endGame();
              return;
            }
          }
        }
      }
    }

    _repaint.value++;
  }

  void _spawnObstacle(_Difficulty diff, {double spdMulRange = 1.0}) {
    final maxR = (diff.maxObsRadius + _obsRadiusExtra) * _scale;
    final minR = diff.minObsRadius * _scale;
    final margin = maxR + 10 + _wallInset;
    final available = _canvasW - margin * 2;
    if (available <= 0) return;
    final x = margin + _rng.nextDouble() * available;
    final r = (minR + _rng.nextDouble() * (maxR - minR)).clamp(minR, maxR);

    final mul = 0.85 + _rng.nextDouble() * (spdMulRange - 0.85);
    final drift = _rng.nextDouble() < 0.4 ? _currentDrift * (0.5 + _rng.nextDouble() * 0.5) : 0.0;
    final doZigzag = diff.zigzagAmp > 0 && _rng.nextDouble() < 0.35;

    _obstacles.add(_Obstacle(
      x: x,
      y: -r,
      radius: r,
      color: _kObsColors[_rng.nextInt(_kObsColors.length)],
      shape: _rng.nextInt(3),
      speedMul: mul,
      driftAmp: drift,
      driftPhase: _rng.nextDouble() * math.pi * 2,
      zigzag: doZigzag,
      zigzagPhase: _rng.nextDouble() * math.pi * 2,
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
      bgColorTop: _kBgDark,
      bgColorBottom: _kBgLight,
      animatedBg: AnimatedBackground(
        factory: (t) => DodgeBallBgPainter(t),
        period: const Duration(seconds: 10),
      ),
      iconRingColors: const [Color(0xFF00D4FF), Color(0xFF66E5FF), Color(0xFF00D4FF)],
      iconChild: Builder(builder: (ctx) {
        final info = GameRegistry.getById(kDodgeBallGameId);
        final logo = info?.buildBrandedLogo(size: 84);
        if (logo != null) {
          return ClipRRect(borderRadius: BorderRadius.circular(42), child: logo);
        }
        return const Icon(Icons.sports_baseball_rounded, size: 40, color: _kAccent);
      }),
      title: 'Dodge Ball',
      subtitle: 'Dodge the falling obstacles!',
      titleColor: Colors.white,
      subtitleColor: Colors.white70,
      onBack: () => context.go('/home'),
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: _showHelp,
      gameId: kDodgeBallGameId,
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) {
        _dragStartX = d.localPosition.dx;
        _dragPlayerStartX = _targetPlayerX;
      },
      onPanUpdate: (d) {
        final newX = _dragPlayerStartX + (d.localPosition.dx - _dragStartX);
        _targetPlayerX = newX.clamp(
          _wallInset + _playerRadius, _canvasW - _wallInset - _playerRadius,
        );
      },
      onPanEnd: (_) {},
      child: Stack(
        children: [
          Positioned.fill(child: _buildCanvas()),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _flashCtrl,
                builder: (_, __) => _flashCtrl.value > 0
                    ? ColoredBox(
                        color: Colors.white.withValues(
                          alpha: _flashCtrl.value * 0.55,
                        ),
                      )
                    : const SizedBox.shrink(),
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
        gameName: 'Dodge Ball',
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
          _scale = (w / _kRefWidth).clamp(0.75, 1.6);
          _bottomOffset = 30.0 * _scale;
          if (_playerX == 0) {
            _playerX = w / 2;
            _targetPlayerX = w / 2;
          }
        }

        return RepaintBoundary(
          child: ValueListenableBuilder<int>(
            valueListenable: _repaint,
            builder: (context2, value, child) => CustomPaint(
              size: Size(w, h),
              painter: _DodgeBallPainter(
                playerX: _playerX,
                playerRadius: _playerRadius,
                canvasW: w,
                canvasH: h,
                obstacles: _obstacles,
                shielded: _shielded,
                shieldTimer: _shieldTimer,
                isDead: _gameOver,
                elapsed: _elapsed,
                wallInset: _wallInset,
                trailLen: _activeDifficulty?.trailLen ?? 0,
              ),
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
      gameId: kDodgeBallGameId,
      score: _score,
      headline: 'Game Over',
      badgeContent: '💥',
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
          onTap: _backOrHome,
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
        bestScore: ScoreService().getHighScore(kDodgeBallGameId, subKey: d.subKey),
        bestLabel: (s) => 'Best $s',
      )).toList(),
      activeIndex: _Difficulty.values.indexOf(difficulty),
      onChanged: (i) => onDifficultyChanged(_Difficulty.values[i]),
      playLabel: 'Play Dodge Ball',
      playSubLabel: 'Dodge the obstacles',
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
    final w = MediaQuery.sizeOf(context).width;
    final compact = w < 360;
    final hPad = compact ? 8.0 : 12.0;
    final scorePad = compact ? 12.0 : 18.0;
    final gap = compact ? 12.0 : 18.0;
    final scoreFontSize = compact ? 18.0 : 22.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 5),
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
          padding: EdgeInsets.symmetric(horizontal: scorePad, vertical: 8),
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
              _scoreColumn('SCORE', score, color, scoreFontSize),
              SizedBox(width: gap),
              Container(
                width: 1,
                height: 28,
                color: _kAccent.withValues(alpha: 0.20),
              ),
              SizedBox(width: gap),
              _scoreColumn('BEST', best, _kAccentLt, scoreFontSize),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scoreColumn(String label, int value, Color color, double valueFontSize) {
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
              fontSize: valueFontSize,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _DodgeBallPainter extends CustomPainter {
  final double playerX;
  final double playerRadius;
  final double canvasW;
  final double canvasH;
  final List<_Obstacle> obstacles;
  final bool shielded;
  final double shieldTimer;
  final bool isDead;
  final double elapsed;
  final double wallInset;
  final double trailLen;

  const _DodgeBallPainter({
    required this.playerX,
    required this.playerRadius,
    required this.canvasW,
    required this.canvasH,
    required this.obstacles,
    required this.shielded,
    required this.shieldTimer,
    required this.isDead,
    required this.elapsed,
    required this.wallInset,
    required this.trailLen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = _kBgDark,
    );

    _drawStars(canvas, w, h);

    if (wallInset > 0) {
      _drawWalls(canvas, w, h);
    }

    for (final obs in obstacles) {
      if (trailLen > 0) _drawTrail(canvas, obs);
      _drawObstacle(canvas, obs);
    }

    final scale = (w / _kRefWidth).clamp(0.75, 1.6);
    final playerY = h - playerRadius - 30 * scale;
    _drawPlayer(canvas, playerX, playerY);
  }

  void _drawStars(Canvas canvas, double w, double h) {
    final rng = math.Random(7);
    for (int i = 0; i < 30; i++) {
      final sx = rng.nextDouble() * w;
      final sy = rng.nextDouble() * h * 0.7;
      final pulse = (math.sin(elapsed * 0.8 + i * 1.3) + 1) / 2;
      final alpha = 0.08 + pulse * 0.12;
      canvas.drawCircle(
        Offset(sx, sy),
        1.0 + rng.nextDouble() * 0.8,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }
  }

  void _drawWalls(Canvas canvas, double w, double h) {
    final progress = (wallInset / 90).clamp(0.0, 1.0);
    final baseAlpha = 0.20 + progress * 0.25;

    final leftGrad = LinearGradient(
      begin: Alignment.centerRight,
      end: Alignment.centerLeft,
      colors: [
        const Color(0xFF7B61FF).withValues(alpha: 0.0),
        const Color(0xFF7B61FF).withValues(alpha: baseAlpha * 0.4),
        const Color(0xFF7B61FF).withValues(alpha: baseAlpha),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, wallInset, h),
      Paint()..shader = leftGrad.createShader(Rect.fromLTWH(0, 0, wallInset, h)),
    );

    final rightGrad = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        const Color(0xFF7B61FF).withValues(alpha: 0.0),
        const Color(0xFF7B61FF).withValues(alpha: baseAlpha * 0.4),
        const Color(0xFF7B61FF).withValues(alpha: baseAlpha),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    canvas.drawRect(
      Rect.fromLTWH(w - wallInset, 0, wallInset, h),
      Paint()..shader = rightGrad.createShader(Rect.fromLTWH(w - wallInset, 0, wallInset, h)),
    );

    final pulse = (math.sin(elapsed * 2.5) + 1) / 2;
    final edgeAlpha = 0.35 + progress * 0.30 + pulse * 0.15;
    final edgePaint = Paint()
      ..color = const Color(0xFF9B7BFF).withValues(alpha: edgeAlpha)
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    canvas.drawLine(Offset(wallInset, 0), Offset(wallInset, h), edgePaint);
    canvas.drawLine(Offset(w - wallInset, 0), Offset(w - wallInset, h), edgePaint);

    final dotSpacing = 20.0;
    final dotPaint = Paint()
      ..color = const Color(0xFFB39DFF).withValues(alpha: edgeAlpha * 0.7);
    for (double y = (elapsed * 30) % dotSpacing; y < h; y += dotSpacing) {
      canvas.drawCircle(Offset(wallInset, y), 1.5, dotPaint);
      canvas.drawCircle(Offset(w - wallInset, y), 1.5, dotPaint);
    }
  }

  void _drawTrail(Canvas canvas, _Obstacle obs) {
    final trailPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          obs.color.withValues(alpha: 0.0),
          obs.color.withValues(alpha: 0.12),
        ],
      ).createShader(Rect.fromLTWH(
        obs.x - obs.radius * 0.6,
        obs.y - trailLen,
        obs.radius * 1.2,
        trailLen,
      ));
    canvas.drawRect(
      Rect.fromLTWH(obs.x - obs.radius * 0.6, obs.y - trailLen, obs.radius * 1.2, trailLen),
      trailPaint,
    );
  }

  void _drawObstacle(Canvas canvas, _Obstacle obs) {
    final glowPaint = Paint()
      ..color = obs.color.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(Offset(obs.x, obs.y), obs.radius + 6, glowPaint);

    final rect = Rect.fromCircle(center: Offset(obs.x, obs.y), radius: obs.radius);

    switch (obs.shape) {
      case 0:
        canvas.drawCircle(
          Offset(obs.x, obs.y),
          obs.radius,
          Paint()..color = obs.color,
        );
      case 1:
        final rrect = RRect.fromRectAndRadius(rect, Radius.circular(obs.radius * 0.3));
        canvas.drawRRect(rrect, Paint()..color = obs.color);
      default:
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final a = (i * math.pi / 3) - math.pi / 2;
          final px = obs.x + obs.radius * math.cos(a);
          final py = obs.y + obs.radius * math.sin(a);
          if (i == 0) {
            path.moveTo(px, py);
          } else {
            path.lineTo(px, py);
          }
        }
        path.close();
        canvas.drawPath(path, Paint()..color = obs.color);
    }

    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35);
    canvas.drawCircle(
      Offset(obs.x - obs.radius * 0.25, obs.y - obs.radius * 0.25),
      obs.radius * 0.25,
      highlightPaint,
    );
  }

  void _drawPlayer(Canvas canvas, double x, double y) {
    final outerGlow = Paint()
      ..color = _kAccent.withValues(alpha: 0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(Offset(x, y), playerRadius + 14, outerGlow);

    if (shielded) {
      final pulse = (math.sin(elapsed * 6) + 1) / 2;
      final shieldPaint = Paint()
        ..color = _kAccent.withValues(alpha: 0.08 + pulse * 0.10)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), playerRadius + 10, shieldPaint);

      final shieldStroke = Paint()
        ..color = _kAccent.withValues(alpha: 0.3 + pulse * 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset(x, y), playerRadius + 10, shieldStroke);
    }

    final gradient = RadialGradient(
      center: const Alignment(-0.3, -0.4),
      colors: [
        _kAccentLt,
        _kAccent,
        const Color(0xFF0099CC),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    final playerPaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: Offset(x, y), radius: playerRadius),
      );
    canvas.drawCircle(Offset(x, y), playerRadius, playerPaint);

    canvas.drawCircle(
      Offset(x - playerRadius * 0.22, y - playerRadius * 0.22),
      playerRadius * 0.28,
      Paint()..color = Colors.white.withValues(alpha: 0.40),
    );

    if (isDead) {
      final xPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      final s = playerRadius * 0.3;
      canvas.drawLine(Offset(x - s, y - s), Offset(x + s, y + s), xPaint);
      canvas.drawLine(Offset(x + s, y - s), Offset(x - s, y + s), xPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DodgeBallPainter old) => true;
}

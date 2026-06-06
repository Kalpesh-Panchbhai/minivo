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
import 'tap_tap_dash_stats.dart';
import 'tap_tap_dash_tutorial.dart';

const Color _kBgDark   = Color(0xFF1A1A2E);
const Color _kBgDeep   = Color(0xFF16213E);
const Color _kAccent   = Color(0xFF00D4FF);
const Color _kAccentLt = Color(0xFF66E5FF);

const Color _kEasyColor   = Color(0xFF22C55E);
const Color _kMediumColor = Color(0xFFF59E0B);
const Color _kHardColor   = Color(0xFFEF4444);

const double _kRefWidth = 390.0;

enum _Dir { right, down, left, up }

enum _Difficulty { easy, medium, hard }

extension _DifficultyX on _Difficulty {
  String get label => ['EASY', 'MEDIUM', 'HARD'][index];
  Color  get color => [_kEasyColor, _kMediumColor, _kHardColor][index];

  double get startSpeed     => [3.0, 4.5, 6.0][index];
  double get speedRamp      => [0.05, 0.10, 0.15][index];
  double get maxSpeed       => [7.0, 10.0, 14.0][index];
  int    get minSegLen      => [4, 3, 2][index];
  int    get maxSegLen      => [8, 6, 4][index];
  int    get firstSegLen    => [10, 8, 6][index];
  double get turnWindow     => [2.5, 2.0, 1.6][index];
  String get subKey         => ['easy', 'medium', 'hard'][index];

  String get hint => [
        'Relaxed pace · long segments · learn the rhythm',
        'Steady speed · shorter segments · stay sharp',
        'Rapid-fire turns · tight timing · pure reflexes',
      ][index];

  DifficultyKind get kind => [
        DifficultyKind.easy,
        DifficultyKind.medium,
        DifficultyKind.hard,
      ][index];
}

class _IntPair {
  int col, row;
  _IntPair(this.col, this.row);
}

class _Segment {
  final int col;
  final int row;
  final _Dir dir;
  final int length;

  const _Segment({
    required this.col,
    required this.row,
    required this.dir,
    required this.length,
  });
}

class TapTapDashScreen extends StatefulWidget {
  const TapTapDashScreen({super.key});

  @override
  State<TapTapDashScreen> createState() => _TapTapDashScreenState();
}

class _TrailDot {
  double x, y, life;
  _TrailDot(this.x, this.y, this.life);
}

class _Particle {
  double x, y, vx, vy, life, maxLife, size;
  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.size,
  }) : maxLife = life;
}

class _ScorePopup {
  double x, y, life;
  int value;
  _ScorePopup(this.x, this.y, this.value) : life = 1.0;
}

class _TapTapDashScreenState extends State<TapTapDashScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  _Difficulty? _activeDifficulty;
  _Difficulty _pickerDifficulty = _Difficulty.values[DifficultyKind.defaultIndex];
  bool _isFavorite = false;

  final List<_Segment> _segments = [];
  int _currentSegIndex = 0;
  double _progressInSeg = 0.0;
  double _speed = 0.0;

  double _playerX = 0.0;
  double _playerY = 0.0;

  double _cameraX = 0.0;
  double _cameraY = 0.0;

  int  _score     = 0;
  int  _bestScore = 0;
  bool _isNewBest = false;
  bool _gameOver  = false;
  bool _isFalling = false;
  double _fallVy  = 0.0;
  double _fallVx  = 0.0;

  double _countdown   = 0.0;
  double _slowMoTimer = 0.0;
  double _gameTime    = 0.0;

  bool   _isTurning = false;
  double _turnT     = 0.0;
  double _turnArcLen = 1.0;
  double _turnP0x = 0, _turnP0y = 0;
  double _turnP1x = 0, _turnP1y = 0;
  double _turnP2x = 0, _turnP2y = 0;

  final List<_TrailDot> _trail = [];
  final List<_Particle> _particles = [];
  final List<_ScorePopup> _popups = [];
  double _turnFlash = 0.0;

  double _canvasW = 0.0;
  double _canvasH = 0.0;
  double _scale   = 1.0;
  double _tileSize = 30.0;

  double _elapsed = 0.0;

  late final Ticker _ticker;
  Duration? _lastElapsed;
  final _repaint = ValueNotifier<int>(0);
  final _rng = math.Random();

  late final AnimationController _flashCtrl;

  static const double _kFallThreshold = 0.6;
  static const int _kMaxTrail = 18;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isFavorite = ScoreService().isFavorite(kTapTapDashGameId);
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
      ScoreService().getHighScore(kTapTapDashGameId, subKey: d.subKey);

  void _toggleFavorite() {
    ScoreService().toggleFavorite(kTapTapDashGameId);
    setState(() => _isFavorite = !_isFavorite);
  }

  void _showHelp() {
    final info = GameRegistry.getById(kTapTapDashGameId);
    if (info == null) return;
    showHowToPlaySheet(
      context,
      title: info.name,
      howToPlay: info.howToPlay,
      accent: _kAccent,
      steps: tapTapDashSteps(),
    );
  }

  _Dir _randomPerpendicularDir(_Dir current) {
    switch (current) {
      case _Dir.right:
      case _Dir.left:
        return _rng.nextBool() ? _Dir.down : _Dir.up;
      case _Dir.down:
      case _Dir.up:
        return _rng.nextBool() ? _Dir.right : _Dir.left;
    }
  }

  void _advancePosition(_Dir dir, int len, _IntPair pos) {
    switch (dir) {
      case _Dir.right: pos.col += len;
      case _Dir.left:  pos.col -= len;
      case _Dir.down:  pos.row += len;
      case _Dir.up:    pos.row -= len;
    }
  }

  void _generatePath(_Difficulty diff) {
    _segments.clear();
    final pos = _IntPair(0, 0);
    _Dir dir = _Dir.right;

    for (int i = 0; i < 200; i++) {
      final len = i == 0
          ? diff.firstSegLen
          : diff.minSegLen + _rng.nextInt(diff.maxSegLen - diff.minSegLen + 1);
      _segments.add(_Segment(col: pos.col, row: pos.row, dir: dir, length: len));
      _advancePosition(dir, len, pos);
      dir = _randomPerpendicularDir(dir);
    }
  }

  void _startGame(_Difficulty diff) {
    _stopTicker();

    _generatePath(diff);

    setState(() {
      _activeDifficulty = diff;
      _pickerDifficulty = diff;
      _score = 0;
      _bestScore = _bestFor(diff);
      _isNewBest = false;
      _gameOver = false;
      _isFalling = false;
      _fallVy = 0.0;
      _fallVx = 0.0;
      _isTurning = false;
      _turnT = 0.0;
      _countdown = 3.0;
      _slowMoTimer = 0.0;
      _gameTime = 0.0;
      _currentSegIndex = 0;
      _progressInSeg = 0.0;
      _speed = 0.0;
      _elapsed = 0.0;
      _playerX = 0;
      _playerY = 0;
      _cameraX = 0;
      _cameraY = 0;
      _trail.clear();
      _particles.clear();
      _popups.clear();
      _turnFlash = 0.0;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        GameWrapper.of(context).startGame();
        GameWrapper.of(context).updateScore(0);
        _startTicker();
      }
    });
  }

  void _newGame() => _startGame(_activeDifficulty ?? _pickerDifficulty);

  void _continueGame() {
    if (_activeDifficulty == null) return;

    _generatePath(_activeDifficulty!);

    setState(() {
      _gameOver = false;
      _isFalling = false;
      _fallVy = 0.0;
      _fallVx = 0.0;
      _isTurning = false;
      _turnT = 0.0;
      _countdown = 3.0;
      _slowMoTimer = 0.0;
      _gameTime = 0.0;
      _currentSegIndex = 0;
      _progressInSeg = 0.0;
      _speed = 0.0;
      _playerX = 0;
      _playerY = 0;
      _cameraX = 0;
      _cameraY = 0;
      _trail.clear();
      _particles.clear();
      _popups.clear();
      _turnFlash = 0.0;
    });
    GameWrapper.of(context).continueAfterGameOver();
    _startTicker();
  }

  void _backToPicker() {
    _stopTicker();
    GameWrapper.of(context).restartGame();
    setState(() {
      _activeDifficulty = null;
      _gameOver = false;
      _isNewBest = false;
      _score = 0;
      _segments.clear();
      _trail.clear();
      _particles.clear();
      _popups.clear();
    });
  }

  void _spawnTurnParticles(double x, double y) {
    for (int i = 0; i < 12; i++) {
      final angle = _rng.nextDouble() * 2 * math.pi;
      final speed = 40 + _rng.nextDouble() * 80;
      _particles.add(_Particle(
        x: x,
        y: y,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        life: 0.4 + _rng.nextDouble() * 0.3,
        size: 2.0 + _rng.nextDouble() * 3.0,
      ));
    }
  }

  Offset _segEndPixel(_Segment seg) {
    switch (seg.dir) {
      case _Dir.right: return Offset((seg.col + seg.length) * _tileSize, seg.row * _tileSize);
      case _Dir.left:  return Offset((seg.col - seg.length) * _tileSize, seg.row * _tileSize);
      case _Dir.down:  return Offset(seg.col * _tileSize, (seg.row + seg.length) * _tileSize);
      case _Dir.up:    return Offset(seg.col * _tileSize, (seg.row - seg.length) * _tileSize);
    }
  }

  Offset _oneTileInto(_Segment seg) {
    switch (seg.dir) {
      case _Dir.right: return Offset((seg.col + 1) * _tileSize, seg.row * _tileSize);
      case _Dir.left:  return Offset((seg.col - 1) * _tileSize, seg.row * _tileSize);
      case _Dir.down:  return Offset(seg.col * _tileSize, (seg.row + 1) * _tileSize);
      case _Dir.up:    return Offset(seg.col * _tileSize, (seg.row - 1) * _tileSize);
    }
  }

  void _onTap() {
    if (_activeDifficulty == null || _gameOver || _isFalling || _isTurning || _countdown > 0) return;
    if (_currentSegIndex >= _segments.length - 1) return;

    final seg = _segments[_currentSegIndex];
    final remaining = seg.length - _progressInSeg;

    if (remaining <= _activeDifficulty!.turnWindow) {
      _score += 1;
      if (_score > _bestScore) {
        _bestScore = _score;
        _isNewBest = true;
        ScoreService().saveScore(
          kTapTapDashGameId, _score,
          subKey: _activeDifficulty!.subKey,
        );
      }
      GameWrapper.of(context).updateScore(_score);
      AudioService().playScore();

      final cornerPixel = _segEndPixel(seg);

      _spawnTurnParticles(cornerPixel.dx + _tileSize / 2, cornerPixel.dy + _tileSize / 2);
      _popups.add(_ScorePopup(cornerPixel.dx, cornerPixel.dy - _tileSize, _score));
      _turnFlash = 1.0;

      _turnP0x = _playerX;
      _turnP0y = _playerY;
      _turnP1x = cornerPixel.dx;
      _turnP1y = cornerPixel.dy;

      _currentSegIndex++;
      final nextSeg = _segments[_currentSegIndex];

      final endPt = _oneTileInto(nextSeg);
      _turnP2x = endPt.dx;
      _turnP2y = endPt.dy;

      final d1 = math.sqrt((_turnP1x - _turnP0x) * (_turnP1x - _turnP0x) +
                            (_turnP1y - _turnP0y) * (_turnP1y - _turnP0y));
      final d2 = math.sqrt((_turnP2x - _turnP1x) * (_turnP2x - _turnP1x) +
                            (_turnP2y - _turnP1y) * (_turnP2y - _turnP1y));
      _turnArcLen = ((d1 + d2) / _tileSize).clamp(0.8, 5.0);

      _turnT = 0.0;
      _isTurning = true;
      _progressInSeg = 1.0;
    } else {
      AudioService().playTap();
    }
  }

  void _update(double rawDt) {
    final diff = _activeDifficulty;
    if (diff == null || _canvasW == 0) return;

    _elapsed += rawDt;

    if (_countdown > 0) {
      _countdown -= rawDt;
      if (_countdown < 0) _countdown = 0;
      _repaint.value++;
      return;
    }

    double dt = rawDt;
    if (_slowMoTimer > 0) {
      _slowMoTimer -= rawDt;
      dt *= 0.2;
    }

    _gameTime += dt;

    _turnFlash = (_turnFlash - dt * 4.0).clamp(0.0, 1.0);

    for (int i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += 120 * dt;
      p.life -= dt;
      if (p.life <= 0) _particles.removeAt(i);
    }

    for (int i = _popups.length - 1; i >= 0; i--) {
      final pop = _popups[i];
      pop.life -= dt * 1.5;
      pop.y -= 40 * dt;
      if (pop.life <= 0) _popups.removeAt(i);
    }

    if (_isFalling) {
      _fallVy += 600 * dt;
      _playerX += _fallVx * dt;
      _playerY += _fallVy * dt;

      for (int i = _trail.length - 1; i >= 0; i--) {
        _trail[i].life -= dt * 3.0;
        if (_trail[i].life <= 0) _trail.removeAt(i);
      }

      _repaint.value++;
      if (_playerY > _cameraY + _canvasH) {
        _endGame();
      }
      return;
    }

    final easeIn = (_gameTime / 1.5).clamp(0.0, 1.0);
    final minSpeed = diff.startSpeed * easeIn;
    _speed = (_speed + diff.speedRamp * dt).clamp(minSpeed, diff.maxSpeed);

    if (_isTurning) {
      _turnT += _speed * dt / _turnArcLen;
      if (_turnT >= 1.0) {
        _isTurning = false;
        _playerX = _turnP2x;
        _playerY = _turnP2y;
      } else {
        final t = _turnT;
        final smoothT = t * t * (3.0 - 2.0 * t);
        final mt = 1.0 - smoothT;
        _playerX = mt * mt * _turnP0x + 2 * mt * smoothT * _turnP1x + smoothT * smoothT * _turnP2x;
        _playerY = mt * mt * _turnP0y + 2 * mt * smoothT * _turnP1y + smoothT * smoothT * _turnP2y;
      }
    } else {
      if (_currentSegIndex >= _segments.length) {
        _generateMorePath(diff);
      }

      final seg = _segments[_currentSegIndex];
      _progressInSeg += _speed * dt;

      if (_progressInSeg >= seg.length + _kFallThreshold) {
        _isFalling = true;
        _slowMoTimer = 0.3;
        final momentum = _speed * _tileSize * 0.3;
        switch (seg.dir) {
          case _Dir.right: _fallVx = momentum;  _fallVy = -40.0;
          case _Dir.left:  _fallVx = -momentum; _fallVy = -40.0;
          case _Dir.down:  _fallVx = 0.0;       _fallVy = momentum;
          case _Dir.up:    _fallVx = 0.0;       _fallVy = -momentum - 40.0;
        }
        AudioService().playGameOver();
        _flashCtrl.value = 1.0;
        _flashCtrl.animateTo(0.0, duration: const Duration(milliseconds: 400));
        _repaint.value++;
        return;
      }

      switch (seg.dir) {
        case _Dir.right:
          _playerX = (seg.col + _progressInSeg) * _tileSize;
          _playerY = seg.row * _tileSize;
        case _Dir.left:
          _playerX = (seg.col - _progressInSeg) * _tileSize;
          _playerY = seg.row * _tileSize;
        case _Dir.down:
          _playerX = seg.col * _tileSize;
          _playerY = (seg.row + _progressInSeg) * _tileSize;
        case _Dir.up:
          _playerX = seg.col * _tileSize;
          _playerY = (seg.row - _progressInSeg) * _tileSize;
      }
    }

    _trail.add(_TrailDot(_playerX + _tileSize / 2, _playerY + _tileSize / 2, 1.0));
    while (_trail.length > _kMaxTrail) {
      _trail.removeAt(0);
    }
    for (final dot in _trail) {
      dot.life -= dt * 3.5;
    }
    _trail.removeWhere((d) => d.life <= 0);

    final targetCamX = _playerX - _canvasW * 0.35;
    final targetCamY = _playerY - _canvasH * 0.35;
    final camLerp = (1.0 - math.exp(-3.5 * dt)).clamp(0.0, 1.0);
    _cameraX += (targetCamX - _cameraX) * camLerp;
    _cameraY += (targetCamY - _cameraY) * camLerp;

    _repaint.value++;
  }

  void _generateMorePath(_Difficulty diff) {
    if (_segments.isEmpty) return;
    final last = _segments.last;
    final pos = _IntPair(last.col, last.row);
    _advancePosition(last.dir, last.length, pos);
    _Dir dir = _randomPerpendicularDir(last.dir);

    for (int i = 0; i < 100; i++) {
      final len = diff.minSegLen + _rng.nextInt(diff.maxSegLen - diff.minSegLen + 1);
      _segments.add(_Segment(col: pos.col, row: pos.row, dir: dir, length: len));
      _advancePosition(dir, len, pos);
      dir = _randomPerpendicularDir(dir);
    }
  }

  void _endGame() {
    _stopTicker();
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
      bgColorBottom: _kBgDeep,
      animatedBg: AnimatedBackground(
        factory: (t) => _DashBgPainter(t),
        period: const Duration(seconds: 8),
      ),
      iconRingColors: const [_kAccent, _kAccentLt, _kAccent],
      iconChild: Builder(builder: (ctx) {
        final info = GameRegistry.getById(kTapTapDashGameId);
        final logo = info?.buildBrandedLogo(size: 84);
        if (logo != null) {
          return ClipRRect(borderRadius: BorderRadius.circular(42), child: logo);
        }
        return const Icon(Icons.directions_run_rounded, size: 40, color: _kAccent);
      }),
      title: 'Tap Tap Dash',
      subtitle: 'Tap to turn — don\'t fall off!',
      titleColor: Colors.white,
      subtitleColor: Colors.white70,
      onBack: () => context.go('/home'),
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: _showHelp,
      gameId: kTapTapDashGameId,
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
      onPointerDown: (_) => _onTap(),
      child: Stack(
        children: [
          Positioned.fill(child: _buildCanvas()),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _flashCtrl,
                builder: (_, child) => _flashCtrl.value > 0
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
      leading: GameBackButton(onTap: _backToPicker),
      centerContent: _ScoreBoardPill(
        difficulty: diff,
        score: _score,
        best: _bestScore,
      ),
      trailing: GameRestartButton(
        gameName: 'Tap Tap Dash',
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
          _tileSize = 30.0 * _scale;
        }

        return RepaintBoundary(
          child: ValueListenableBuilder<int>(
            valueListenable: _repaint,
            builder: (context2, value, child) => CustomPaint(
              size: Size(w, h),
              painter: _TapTapDashPainter(
                segments: _segments,
                currentSegIndex: _currentSegIndex,
                progressInSeg: _progressInSeg,
                speed: _speed,
                maxSpeed: _activeDifficulty?.maxSpeed ?? 10.0,
                score: _score,
                countdown: _countdown,
                playerX: _playerX,
                playerY: _playerY,
                cameraX: _cameraX,
                cameraY: _cameraY,
                tileSize: _tileSize,
                canvasW: w,
                canvasH: h,
                elapsed: _elapsed,
                isFalling: _isFalling,
                isDead: _gameOver,
                trail: List.unmodifiable(_trail),
                particles: List.unmodifiable(_particles),
                popups: List.unmodifiable(_popups),
                turnFlash: _turnFlash,
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
      gameId: kTapTapDashGameId,
      score: _score,
      headline: 'Game Over',
      badgeContent: '🏃',
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
            label: 'TURNS',
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
        bestScore: ScoreService().getHighScore(kTapTapDashGameId, subKey: d.subKey),
        bestLabel: (s) => 'Best $s',
      )).toList(),
      activeIndex: _Difficulty.values.indexOf(difficulty),
      onChanged: (i) => onDifficultyChanged(_Difficulty.values[i]),
      playLabel: 'Play Tap Tap Dash',
      playSubLabel: 'Don\'t fall off!',
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
    final scoreFontSize = compact ? 18.0 : 22.0;
    final gap = compact ? 12.0 : 18.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: compact ? 8.0 : 12.0, vertical: 5),
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
          padding: EdgeInsets.symmetric(horizontal: compact ? 12.0 : 18.0, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _scoreColumn('TURNS', score, color, scoreFontSize),
              SizedBox(width: gap),
              Container(width: 1, height: 28, color: Colors.grey.shade200),
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
            color: Colors.grey.shade500,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontSize: valueFontSize,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _TapTapDashPainter extends CustomPainter {
  final List<_Segment> segments;
  final int currentSegIndex;
  final double progressInSeg;
  final double speed;
  final double maxSpeed;
  final int score;
  final double countdown;
  final double playerX;
  final double playerY;
  final double cameraX;
  final double cameraY;
  final double tileSize;
  final double canvasW;
  final double canvasH;
  final double elapsed;
  final bool isFalling;
  final bool isDead;
  final List<_TrailDot> trail;
  final List<_Particle> particles;
  final List<_ScorePopup> popups;
  final double turnFlash;

  const _TapTapDashPainter({
    required this.segments,
    required this.currentSegIndex,
    required this.progressInSeg,
    required this.speed,
    required this.maxSpeed,
    required this.score,
    required this.countdown,
    required this.playerX,
    required this.playerY,
    required this.cameraX,
    required this.cameraY,
    required this.tileSize,
    required this.canvasW,
    required this.canvasH,
    required this.elapsed,
    required this.isFalling,
    required this.isDead,
    required this.trail,
    required this.particles,
    required this.popups,
    required this.turnFlash,
  });

  Color get _pathColor {
    if (score < 10) return _kAccent;
    if (score < 25) return Color.lerp(_kAccent, const Color(0xFF7C3AED), (score - 10) / 15.0)!;
    if (score < 50) return Color.lerp(const Color(0xFF7C3AED), const Color(0xFFF59E0B), (score - 25) / 25.0)!;
    return const Color(0xFFF59E0B);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawGrid(canvas, size);
    _drawStars(canvas, size);
    _drawPath(canvas, size);
    _drawTrail(canvas);
    _drawParticles(canvas);
    _drawPlayer(canvas, size);
    _drawPopups(canvas);
    _drawSpeedLines(canvas, size);
    if (turnFlash > 0) {
      _drawTurnFlash(canvas, size);
    }
    if (countdown > 0) {
      _drawCountdown(canvas, size);
    }
  }

  void _drawBackground(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [_kBgDark, Color(0xFF0F3460), _kBgDeep],
          stops: [0.0, 0.5, 1.0],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect),
    );

    final speedRatio = (speed / maxSpeed).clamp(0.0, 1.0);
    final pulse = (math.sin(elapsed * (1.5 + speedRatio * 2.0)) + 1) / 2;
    final breathAlpha = 0.01 + pulse * 0.03 * speedRatio;
    if (breathAlpha > 0.005) {
      canvas.drawRect(rect, Paint()..color = _pathColor.withValues(alpha: breathAlpha));
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = _kAccent.withValues(alpha: 0.03)
      ..strokeWidth = 0.5;
    final gridSpacing = tileSize * 3;
    final offsetX = -(cameraX * 0.15) % gridSpacing;
    final offsetY = -(cameraY * 0.15) % gridSpacing;

    for (double x = offsetX; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = offsetY; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  void _drawStars(Canvas canvas, Size size) {
    final starPaint = Paint();
    for (int i = 0; i < 50; i++) {
      final parallax = 0.05 + (i % 3) * 0.03;
      final sx = ((i * 97.0 + 13) - cameraX * parallax) % (size.width + 40) - 20;
      final sy = ((i * 53.0 + 7) - cameraY * parallax) % (size.height + 40) - 20;
      final twinkle = (math.sin(elapsed * (0.6 + i * 0.1) + i * 1.3) + 1) / 2;
      final alpha = 0.15 + twinkle * 0.45;
      final radius = 0.6 + (i % 4) * 0.35 + twinkle * 0.3;
      starPaint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(Offset(sx, sy), radius, starPaint);
    }
  }

  Rect _segWorldRect(_Segment seg) {
    switch (seg.dir) {
      case _Dir.right:
        return Rect.fromLTWH(seg.col * tileSize, seg.row * tileSize,
            seg.length * tileSize, tileSize);
      case _Dir.left:
        return Rect.fromLTWH((seg.col - seg.length + 1) * tileSize,
            seg.row * tileSize, seg.length * tileSize, tileSize);
      case _Dir.down:
        return Rect.fromLTWH(seg.col * tileSize, seg.row * tileSize,
            tileSize, seg.length * tileSize);
      case _Dir.up:
        return Rect.fromLTWH(seg.col * tileSize,
            (seg.row - seg.length + 1) * tileSize, tileSize, seg.length * tileSize);
    }
  }

  void _drawPath(Canvas canvas, Size size) {
    final viewLeft = cameraX - tileSize * 2;
    final viewRight = cameraX + canvasW + tileSize * 2;
    final viewTop = cameraY - tileSize * 2;
    final viewBottom = cameraY + canvasH + tileSize * 2;

    final surfPaint = Paint();
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final r = Radius.circular(tileSize * 0.28);

    for (int si = 0; si < segments.length; si++) {
      final seg = segments[si];
      final wRect = _segWorldRect(seg);

      if (wRect.right < viewLeft || wRect.left > viewRight) continue;
      if (wRect.bottom < viewTop || wRect.top > viewBottom) continue;

      final isPast = si < currentSegIndex;
      final isActive = si == currentSegIndex;
      final distAhead = si - currentSegIndex;

      double fillAlpha;
      double edgeAlpha;
      if (isPast) {
        fillAlpha = 0.05;
        edgeAlpha = 0.06;
      } else if (isActive) {
        fillAlpha = 0.16;
        edgeAlpha = 0.22;
      } else {
        fillAlpha = (0.13 - distAhead * 0.012).clamp(0.04, 0.13);
        edgeAlpha = fillAlpha + 0.04;
      }

      final sRect = wRect.shift(Offset(-cameraX, -cameraY)).deflate(1.0);
      final rrect = RRect.fromRectAndRadius(sRect, r);

      final pColor = _pathColor;
      surfPaint.color = pColor.withValues(alpha: fillAlpha);
      canvas.drawRRect(rrect, surfPaint);
      edgePaint.color = pColor.withValues(alpha: edgeAlpha);
      canvas.drawRRect(rrect, edgePaint);

      if (si > 0) {
        final prev = segments[si - 1];
        final prevRect = _segWorldRect(prev);
        final junction = wRect.intersect(prevRect.inflate(tileSize * 0.1));
        if (!junction.isEmpty) {
          final jScreen = junction.shift(Offset(-cameraX, -cameraY));
          final jFill = math.max(fillAlpha, isPast ? 0.05 : 0.10);
          surfPaint.color = pColor.withValues(alpha: jFill);
          canvas.drawRect(jScreen, surfPaint);
        }
      }

      if (isActive && si < segments.length - 1) {
        _drawCornerIndicator(canvas, seg, si);
      }
    }
  }

  void _drawCornerIndicator(Canvas canvas, _Segment seg, int si) {
    final wRect = _segWorldRect(seg);

    double cornerX, cornerY;
    switch (seg.dir) {
      case _Dir.right: cornerX = wRect.right - tileSize / 2; cornerY = wRect.center.dy;
      case _Dir.left:  cornerX = wRect.left + tileSize / 2;  cornerY = wRect.center.dy;
      case _Dir.down:  cornerX = wRect.center.dx; cornerY = wRect.bottom - tileSize / 2;
      case _Dir.up:    cornerX = wRect.center.dx; cornerY = wRect.top + tileSize / 2;
    }

    final sx = cornerX - cameraX;
    final sy = cornerY - cameraY;

    if (sx < -tileSize || sx > canvasW + tileSize) return;
    if (sy < -tileSize || sy > canvasH + tileSize) return;

    final approach = (progressInSeg / seg.length).clamp(0.0, 1.0);
    final pulse = (math.sin(elapsed * 4.0 + si * 0.7) + 1) / 2;
    final glowAlpha = 0.08 + approach * 0.25 + pulse * 0.08;
    final glowRadius = tileSize * (0.4 + approach * 0.25 + pulse * 0.08);

    canvas.drawCircle(
      Offset(sx, sy),
      glowRadius,
      Paint()
        ..color = _pathColor.withValues(alpha: glowAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    final a = tileSize * 0.2;
    final nextDir = si + 1 < segments.length ? segments[si + 1].dir : _Dir.down;
    final arrowPath = Path();
    switch (nextDir) {
      case _Dir.down:
        arrowPath.moveTo(sx - a, sy + a * 0.2);
        arrowPath.lineTo(sx, sy + a * 1.2);
        arrowPath.lineTo(sx + a, sy + a * 0.2);
      case _Dir.up:
        arrowPath.moveTo(sx - a, sy - a * 0.2);
        arrowPath.lineTo(sx, sy - a * 1.2);
        arrowPath.lineTo(sx + a, sy - a * 0.2);
      case _Dir.right:
        arrowPath.moveTo(sx + a * 0.2, sy - a);
        arrowPath.lineTo(sx + a * 1.2, sy);
        arrowPath.lineTo(sx + a * 0.2, sy + a);
      case _Dir.left:
        arrowPath.moveTo(sx - a * 0.2, sy - a);
        arrowPath.lineTo(sx - a * 1.2, sy);
        arrowPath.lineTo(sx - a * 0.2, sy + a);
    }
    canvas.drawPath(
      arrowPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3 + approach * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawTrail(Canvas canvas) {
    if (trail.isEmpty) return;
    final trailPaint = Paint();
    for (int i = 0; i < trail.length; i++) {
      final dot = trail[i];
      final t = (i / trail.length).clamp(0.0, 1.0);
      final alpha = dot.life.clamp(0.0, 1.0) * t * 0.4;
      final radius = tileSize * 0.12 * t + tileSize * 0.04;
      final sx = dot.x - cameraX;
      final sy = dot.y - cameraY;
      if (sx < -20 || sx > canvasW + 20 || sy < -20 || sy > canvasH + 20) continue;
      trailPaint.color = _kAccent.withValues(alpha: alpha);
      canvas.drawCircle(Offset(sx, sy), radius, trailPaint);
    }
  }

  void _drawParticles(Canvas canvas) {
    final pPaint = Paint();
    for (final p in particles) {
      final sx = p.x - cameraX;
      final sy = p.y - cameraY;
      if (sx < -20 || sx > canvasW + 20 || sy < -20 || sy > canvasH + 20) continue;
      final lifeRatio = (p.life / p.maxLife).clamp(0.0, 1.0);
      pPaint.color = Color.lerp(_kAccent, Colors.white, lifeRatio * 0.5)!
          .withValues(alpha: lifeRatio * 0.8);
      canvas.drawCircle(Offset(sx, sy), p.size * lifeRatio, pPaint);
    }
  }

  void _drawPlayer(Canvas canvas, Size size) {
    final sx = playerX - cameraX + tileSize / 2;
    final sy = playerY - cameraY + tileSize / 2;

    if (sx < -50 || sx > canvasW + 50 || sy < -50 || sy > canvasH + 200) return;

    final r = tileSize * 0.32;

    if (!isFalling && !isDead) {
      final glowPulse = (math.sin(elapsed * 3.5) + 1) / 2;
      final speedGlow = (speed / 15.0).clamp(0.0, 1.0);
      final outerR = r * (1.8 + glowPulse * 0.4 + speedGlow * 0.3);
      canvas.drawCircle(
        Offset(sx, sy),
        outerR,
        Paint()
          ..color = _kAccent.withValues(alpha: 0.08 + glowPulse * 0.06 + speedGlow * 0.04)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.5),
      );
      canvas.drawCircle(
        Offset(sx, sy),
        r * (1.3 + glowPulse * 0.15),
        Paint()..color = _kAccent.withValues(alpha: 0.12 + glowPulse * 0.08),
      );
    }

    final gradient = RadialGradient(
      colors: isFalling
          ? [Colors.white.withValues(alpha: 0.7), Colors.red.withValues(alpha: 0.6)]
          : [Colors.white, _kAccent],
      stops: const [0.15, 1.0],
    );
    canvas.drawCircle(
      Offset(sx, sy),
      r,
      Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(center: Offset(sx, sy), radius: r),
        ),
    );

    if (!isFalling) {
      canvas.drawCircle(
        Offset(sx - r * 0.28, sy - r * 0.28),
        r * 0.25,
        Paint()..color = Colors.white.withValues(alpha: 0.7),
      );
      canvas.drawCircle(
        Offset(sx + r * 0.1, sy + r * 0.15),
        r * 0.12,
        Paint()..color = Colors.white.withValues(alpha: 0.25),
      );
    }
  }

  void _drawPopups(Canvas canvas) {
    for (final pop in popups) {
      final sx = pop.x - cameraX + tileSize / 2;
      final sy = pop.y - cameraY;
      if (sx < -40 || sx > canvasW + 40) continue;
      final alpha = pop.life.clamp(0.0, 1.0);
      final scale = 0.8 + (1.0 - pop.life) * 0.4;
      final tp = TextPainter(
        text: TextSpan(
          text: '+1',
          style: TextStyle(
            color: Colors.white.withValues(alpha: alpha),
            fontSize: 16 * scale,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(sx - tp.width / 2, sy));
    }
  }

  void _drawSpeedLines(Canvas canvas, Size size) {
    final speedRatio = (speed / maxSpeed).clamp(0.0, 1.0);
    if (speedRatio < 0.5) return;

    final intensity = ((speedRatio - 0.5) * 2.0).clamp(0.0, 1.0);
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxLen = size.width * 0.7;
    final linePaint = Paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 16; i++) {
      final angle = (i / 16.0) * 2 * math.pi + elapsed * 0.3;
      final startR = maxLen * (0.6 + (math.sin(elapsed * 2.0 + i * 1.7) + 1) * 0.1);
      final endR = startR + maxLen * 0.15 * intensity;
      final alpha = 0.04 + intensity * 0.08;
      linePaint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawLine(
        Offset(cx + math.cos(angle) * startR, cy + math.sin(angle) * startR),
        Offset(cx + math.cos(angle) * endR, cy + math.sin(angle) * endR),
        linePaint,
      );
    }
  }

  void _drawCountdown(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black.withValues(alpha: 0.3),
    );

    final num = countdown.ceil();
    final text = num > 0 ? '$num' : 'GO!';
    final frac = countdown - countdown.floorToDouble();
    final scale = 1.0 + frac * 0.4;
    final alpha = (frac * 2.0).clamp(0.0, 1.0);

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: alpha),
          fontSize: 72 * scale,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2),
    );
  }

  void _drawTurnFlash(Canvas canvas, Size size) {
    final alpha = turnFlash * 0.12;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = _pathColor.withValues(alpha: alpha),
    );
  }

  @override
  bool shouldRepaint(covariant _TapTapDashPainter old) => true;
}

class _DashBgPainter extends AnimatedBgPainter {
  const _DashBgPainter(super.t);

  @override
  void paintAt(Canvas canvas, Size size, double t) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = const LinearGradient(
          colors: [_kBgDark, _kBgDeep],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    final pathPaint = Paint()
      ..color = _kAccent.withValues(alpha: 0.08)
      ..strokeWidth = size.width * 0.06
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final tileS = size.width * 0.08;
    final ox = size.width * 0.15 - t * tileS * 2;
    final oy = size.height * 0.2;

    final path = Path();
    path.moveTo(ox, oy);
    path.lineTo(ox + tileS * 5, oy);
    path.lineTo(ox + tileS * 5, oy + tileS * 3);
    path.lineTo(ox + tileS * 9, oy + tileS * 3);
    path.lineTo(ox + tileS * 9, oy + tileS * 6);
    path.lineTo(ox + tileS * 13, oy + tileS * 6);

    canvas.drawPath(path, pathPaint);
  }
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
import '../shared/game_difficulty_picker.dart';
import '../shared/game_hud_bar.dart';
import '../shared/generic_game_result_screen.dart' as game_result;
import '../shared/rewarded_continue_action.dart';
import 'whack_a_mole_stats.dart';
import 'whack_a_mole_tutorial.dart';

const Color _kBgTop    = Color(0xFF4A7C2E);
const Color _kBgBot    = Color(0xFF2D5A1A);
const Color _kAccent   = Color(0xFF5DB347);
const Color _kAccentLt = Color(0xFF7DCC6A);
const Color _kBrown    = Color(0xFFA07250);
const Color _kBrownDk  = Color(0xFF7A5234);
const Color _kBelly    = Color(0xFFD4B896);
const Color _kGold     = Color(0xFFFFD700);
const Color _kRed      = Color(0xFFE53935);
const Color _kDarkHole = Color(0xFF1C0E04);

const Color _kEasyColor   = Color(0xFF43A047);
const Color _kMediumColor = Color(0xFFF9A825);
const Color _kHardColor   = Color(0xFFE53935);

enum _Difficulty { easy, medium, hard }

extension _DifficultyX on _Difficulty {
  String get label   => ['EASY', 'MEDIUM', 'HARD'][index];
  Color  get color   => [_kEasyColor, _kMediumColor, _kHardColor][index];
  int    get seconds => [45, 35, 25][index];
  int    get points  => [10, 15, 20][index];
  String get subKey  => ['easy', 'medium', 'hard'][index];
  int    get holeCount => [6, 8, 10][index];
  String get hint    => [
        '$holeCount holes • 45 sec • Slow moles.',
        '$holeCount holes • 35 sec • Medium speed.',
        '$holeCount holes • 25 sec • Fast & more bombs!',
      ][index];
  DifficultyKind get kind => [
        DifficultyKind.easy,
        DifficultyKind.medium,
        DifficultyKind.hard,
      ][index];

  int get baseSpawnMs     => [1200, 900, 650][index];
  int get minSpawnMs      => [650, 450, 300][index];
  int get moleVisibleMs   => [1400, 1100, 800][index];
  double get bombChance   => [0.10, 0.18, 0.25][index];
  double get goldenChance => [0.08, 0.10, 0.12][index];
}

enum _MoleType { normal, golden, bomb }

class _MoleState {
  _MoleType type;
  double popUp;
  bool rising;
  bool whacked;
  int visibleMs;
  int elapsedMs;

  _MoleState({required this.type, required this.visibleMs})
      : popUp = 0.0,
        rising = true,
        whacked = false,
        elapsedMs = 0;
}

class _HolePosition {
  final double x;
  final double y;
  final double scale;
  const _HolePosition(this.x, this.y, this.scale);
}

List<_HolePosition> _generateHolePositions(int count, math.Random rng) {
  final positions = <_HolePosition>[];
  final minDist = count <= 6 ? 0.22 : count <= 8 ? 0.19 : 0.16;
  const maxAttempts = 400;

  for (int i = 0; i < count; i++) {
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final x = 0.12 + rng.nextDouble() * 0.76;
      final y = 0.08 + rng.nextDouble() * 0.82;
      bool tooClose = false;
      for (final p in positions) {
        final dx = p.x - x;
        final dy = p.y - y;
        if (math.sqrt(dx * dx + dy * dy) < minDist) {
          tooClose = true;
          break;
        }
      }
      if (!tooClose) {
        final depth = 0.55 + y * 0.65;
        positions.add(_HolePosition(x, y, depth));
        break;
      }
    }
  }
  positions.sort((a, b) => a.y.compareTo(b.y));
  return positions;
}

class _WhackEffect {
  final int holeIdx;
  final bool isBomb;
  double progress;
  _WhackEffect({required this.holeIdx, required this.isBomb}) : progress = 0.0;
}

class WhackAMoleScreen extends StatefulWidget {
  const WhackAMoleScreen({super.key});

  @override
  State<WhackAMoleScreen> createState() => _WhackAMoleScreenState();
}

class _WhackAMoleScreenState extends State<WhackAMoleScreen>
    with TickerProviderStateMixin {
  _Difficulty? _activeDifficulty;
  _Difficulty  _pickerDifficulty = _Difficulty.values[DifficultyKind.defaultIndex];

  bool _isFavorite = false;

  final _rng = math.Random();
  final _audio = AudioService();

  int  _score     = 0;
  int  _bestScore = 0;
  bool _isNewBest = false;
  bool _gameOver  = false;

  int  _timeLeftMs   = 0;

  int  _combo         = 0;
  bool _showCombo     = false;
  Timer? _comboTimer;

  bool _showScorePopup = false;
  int  _lastPoints     = 0;
  int  _popupHoleIdx   = -1;
  Timer? _scorePopupTimer;

  List<_MoleState?> _holes = [];
  List<_HolePosition> _holePositions = [];
  final List<_WhackEffect> _whackEffects = [];

  Timer? _spawnTimer;
  Timer? _tickTimer;

  int _totalElapsedMs = 0;

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(kWhackAMoleGameId);
  }

  @override
  void dispose() {
    _spawnTimer?.cancel();
    _tickTimer?.cancel();
    _comboTimer?.cancel();
    _scorePopupTimer?.cancel();
    super.dispose();
  }

  void _toggleFavorite() {
    ScoreService().toggleFavorite(kWhackAMoleGameId);
    setState(() => _isFavorite = !_isFavorite);
  }

  void _showHelp() {
    final info = GameRegistry.getById(kWhackAMoleGameId);
    if (info == null) return;
    showHowToPlaySheet(
      context,
      title: info.name,
      howToPlay: info.howToPlay,
      accent: _kAccent,
      steps: whackAMoleSteps(),
      gameId: kWhackAMoleGameId,
    );
  }

  int _bestFor(_Difficulty d) =>
      ScoreService().getHighScore(kWhackAMoleGameId, subKey: d.subKey);

  void _startGame(_Difficulty diff) {
    _spawnTimer?.cancel();
    _tickTimer?.cancel();
    _comboTimer?.cancel();
    _scorePopupTimer?.cancel();

    final count = diff.holeCount;
    final positions = _generateHolePositions(count, _rng);

    setState(() {
      _activeDifficulty = diff;
      _pickerDifficulty = diff;
      _score            = 0;
      _bestScore        = _bestFor(diff);
      _isNewBest        = false;
      _gameOver         = false;
      _timeLeftMs       = diff.seconds * 1000;
      _totalElapsedMs   = 0;
      _combo            = 0;
      _showCombo        = false;
      _showScorePopup   = false;
      _holePositions    = positions;
      _holes            = List.filled(count, null);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        GameWrapper.of(context).setDifficultyAndMode(difficulty: diff.label, subKey: diff.subKey);
        GameWrapper.of(context).startGame();
        GameWrapper.of(context).updateScore(0);
      }
    });

    _startTimers(diff);
  }

  void _startTimers(_Difficulty diff) {
    const tickMs = 50;
    final holeCount = diff.holeCount;

    _tickTimer = Timer.periodic(const Duration(milliseconds: tickMs), (_) {
      if (!mounted || _gameOver) return;
      setState(() {
        _timeLeftMs -= tickMs;
        _totalElapsedMs += tickMs;

        for (int i = 0; i < holeCount; i++) {
          final mole = _holes[i];
          if (mole == null) continue;
          mole.elapsedMs += tickMs;

          if (mole.whacked) {
            mole.popUp = (mole.popUp - 0.12).clamp(0.0, 1.0);
            if (mole.popUp <= 0) _holes[i] = null;
          } else if (mole.rising) {
            final remaining = 1.0 - mole.popUp;
            final speed = 0.08 + remaining * 0.06;
            mole.popUp = (mole.popUp + speed).clamp(0.0, 1.0);
            if (mole.popUp >= 1.0) mole.rising = false;
          } else if (mole.elapsedMs >= mole.visibleMs) {
            mole.popUp = (mole.popUp - 0.04).clamp(0.0, 1.0);
            if (mole.popUp <= 0) _holes[i] = null;
          }
        }

        _whackEffects.removeWhere((e) => e.progress >= 1.0);
        for (final e in _whackEffects) {
          e.progress = (e.progress + 0.05).clamp(0.0, 1.0);
        }
      });

      if (_timeLeftMs <= 0) {
        _timeLeftMs = 0;
        _endGame();
      }
    });

    _scheduleNextSpawn(diff);
  }

  void _scheduleNextSpawn(_Difficulty diff) {
    final progress = (_totalElapsedMs / (diff.seconds * 1000)).clamp(0.0, 1.0);
    final spawnDelay = (diff.baseSpawnMs - (diff.baseSpawnMs - diff.minSpawnMs) * progress).round();
    final jitter = _rng.nextInt((spawnDelay * 0.3).round().clamp(50, 400));

    _spawnTimer = Timer(Duration(milliseconds: spawnDelay + jitter), () {
      if (!mounted || _gameOver) return;
      _spawnMole(diff);
      _scheduleNextSpawn(diff);
    });
  }

  void _spawnMole(_Difficulty diff) {
    final count = diff.holeCount;
    final emptyHoles = <int>[];
    for (int i = 0; i < count; i++) {
      if (_holes[i] == null) emptyHoles.add(i);
    }
    if (emptyHoles.isEmpty) return;

    final holeIdx = emptyHoles[_rng.nextInt(emptyHoles.length)];
    final roll = _rng.nextDouble();

    _MoleType type;
    if (roll < diff.bombChance) {
      type = _MoleType.bomb;
    } else if (roll < diff.bombChance + diff.goldenChance) {
      type = _MoleType.golden;
    } else {
      type = _MoleType.normal;
    }

    final visMs = type == _MoleType.golden
        ? (diff.moleVisibleMs * 0.65).round()
        : type == _MoleType.bomb
            ? (diff.moleVisibleMs * 0.85).round()
            : diff.moleVisibleMs;

    setState(() {
      _holes[holeIdx] = _MoleState(type: type, visibleMs: visMs);
    });
  }

  void _onHoleTap(int idx) {
    if (_gameOver || idx >= _holes.length) return;
    final mole = _holes[idx];
    if (mole == null || mole.whacked || mole.popUp < 0.15) return;

    final diff = _activeDifficulty!;

    if (mole.type == _MoleType.bomb) {
      _audio.playGameOver();
      _whackEffects.add(_WhackEffect(holeIdx: idx, isBomb: true));
      setState(() {
        mole.whacked = true;
        _combo = 0;
        _showCombo = false;
        _score = _score - 15;
        _timeLeftMs = (_timeLeftMs - 3000).clamp(0, 999999);
        _showScorePopup = true;
        _lastPoints = -15;
        _popupHoleIdx = idx;
      });
      _scorePopupTimer?.cancel();
      _scorePopupTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _showScorePopup = false);
      });
      GameWrapper.of(context).updateScore(_score);
      if (_timeLeftMs <= 0) {
        _timeLeftMs = 0;
        _endGame();
      }
      return;
    }

    _audio.playScore();
    _whackEffects.add(_WhackEffect(holeIdx: idx, isBomb: false));
    final pts = mole.type == _MoleType.golden ? 25 : diff.points;
    final newScore = _score + pts;
    final newCombo = _combo + 1;

    if (newScore > _bestScore) {
      _bestScore = newScore;
      _isNewBest = true;
      ScoreService().saveScore(kWhackAMoleGameId, newScore, subKey: diff.subKey);
    }

    setState(() {
      mole.whacked = true;
      _score = newScore;
      _combo = newCombo;
      _showCombo = newCombo >= 3;
      _showScorePopup = true;
      _lastPoints = pts;
      _popupHoleIdx = idx;
    });

    _comboTimer?.cancel();
    _comboTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _showCombo = false);
    });
    _scorePopupTimer?.cancel();
    _scorePopupTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showScorePopup = false);
    });

    GameWrapper.of(context).updateScore(_score);
  }

  void _endGame() {
    _spawnTimer?.cancel();
    _tickTimer?.cancel();
    setState(() => _gameOver = true);
    if (_score > 0) {
      ScoreService().saveScore(kWhackAMoleGameId, _score, subKey: _activeDifficulty!.subKey);
    }
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) GameWrapper.of(context).endGame();
    });
  }

  void _continueGame() {
    final diff = _activeDifficulty;
    if (diff == null) return;
    final count = diff.holeCount;
    setState(() {
      _timeLeftMs = 15000;
      _gameOver = false;
      for (int i = 0; i < count; i++) {
        _holes[i] = null;
      }
    });
    GameWrapper.of(context).continueAfterGameOver();
    _startTimers(diff);
  }

  void _newGame() => _startGame(_activeDifficulty ?? _pickerDifficulty);

  void _backOrHome() {
    final wrapper = GameWrapper.of(context);
    wrapper.handleExit(() {
      _spawnTimer?.cancel();
      _tickTimer?.cancel();
      if (context.canPop()) context.pop(); else context.go('/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_activeDifficulty == null) return _buildPicker();
    if (_gameOver) return _buildGameOver();
    return _buildGame();
  }

  Widget _buildPicker() {
    return GamePickerScaffold(
      bgColorTop: _kBgTop,
      bgColorBottom: _kBgBot,
      animatedBg: AnimatedBackground(
        factory: (t) => _WAMBgPainter(t),
        period: const Duration(seconds: 14),
      ),
      iconRingColors: const [_kAccent, _kAccentLt, _kAccent],
      iconChild: ClipOval(
        child: GameRegistry.getById(kWhackAMoleGameId)
                ?.buildBrandedLogo(size: 84) ??
            const SizedBox.shrink(),
      ),
      title: 'Whack-a-Mole',
      subtitle: 'Tap Fast • Score Big',
      onBack: () => context.pop(),
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: _showHelp,
      gameId: kWhackAMoleGameId,
      body: _PickerSection(
        difficulty: _pickerDifficulty,
        onDifficultyChanged: (d) => setState(() => _pickerDifficulty = d),
        onPlay: () => _startGame(_pickerDifficulty),
      ),
    );
  }

  Widget _buildGame() {
    final diff = _activeDifficulty!;
    final timeProgress = _timeLeftMs / (diff.seconds * 1000);
    final grassTime = _totalElapsedMs / 1000.0;
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _GrassPainter(time: grassTime),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 4),
              GameHudBar(
                leading: GameBackButton(onTap: _backOrHome),
                centerContent: _ScorePill(
                  difficulty: diff,
                  score: _score,
                  best: _bestScore,
                  timeLeftMs: _timeLeftMs,
                ),
                trailing: GameRestartButton(
                  gameName: 'Whack-a-Mole',
                  accentColor: _kAccent,
                  onRestart: _newGame,
                  onDialogOpened: () {
                    _tickTimer?.cancel();
                    _spawnTimer?.cancel();
                  },
                  onDialogDismissed: () {
                    if (!_gameOver) _startTimers(diff);
                  },
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _TimerBar(progress: timeProgress, color: diff.color),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _GameField(
                          holes: _holes,
                          holePositions: _holePositions,
                          onTap: _onHoleTap,
                          showScorePopup: _showScorePopup,
                          lastPoints: _lastPoints,
                          popupHoleIdx: _popupHoleIdx,
                          whackEffects: _whackEffects,
                        ),
                      ),
                    ),
                    if (_showCombo)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: _ComboBadge(count: _combo),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGameOver() {
    final diff = _activeDifficulty!;
    final continueAction = rewardedContinueAction(
      context: context,
      label: 'Watch Ad for +15s',
      color: diff.color,
      onRewarded: _continueGame,
    );
    return game_result.GenericGameResultScreen(
      gameId: kWhackAMoleGameId,
      score: _score,
      headline: 'Time\'s Up!',
      badgeContent: '🔨',
      badgeColor: diff.color,
      showNewBestBadge: _isNewBest,
      actions: [
        ?continueAction,
        game_result.GameResultAction(
          label: 'Play Again',
          icon: Icons.refresh_rounded,
          onTap: _newGame,
          filled: continueAction == null,
          color: diff.color,
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
          game_result.StatItem(label: 'SCORE', value: _score, color: diff.color),
          game_result.StatItem(label: 'BEST', value: _bestScore, color: const Color(0xFF8B7BA7)),
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
        bestScore: ScoreService().getHighScore(kWhackAMoleGameId, subKey: d.subKey),
        bestLabel: (s) => 'Best $s pts',
      )).toList(),
      activeIndex: _Difficulty.values.indexOf(difficulty),
      onChanged: (i) => onDifficultyChanged(_Difficulty.values[i]),
      playLabel: 'Play Whack-a-Mole',
      playSubLabel: '${difficulty.holeCount} holes • ${difficulty.seconds}s • ${difficulty.points} pts/mole',
      onPlay: onPlay,
      accentColor: _kAccent,
    );
  }
}

class _ScorePill extends StatelessWidget {
  final _Difficulty difficulty;
  final int score;
  final int best;
  final int timeLeftMs;

  const _ScorePill({
    required this.difficulty,
    required this.score,
    required this.best,
    required this.timeLeftMs,
  });

  @override
  Widget build(BuildContext context) {
    final color = difficulty.color;
    final secs = (timeLeftMs / 1000).ceil();
    final isLow = secs <= 5;
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
              AnimatedDifficultyIcon(kind: difficulty.kind, size: 14, prominent: false),
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
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.40), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _col('SCORE', '$score', score < 0 ? _kRed : color),
              const SizedBox(width: 12),
              Container(width: 1, height: 28, color: _kAccent.withValues(alpha: 0.20)),
              const SizedBox(width: 12),
              _col('BEST', '$best', const Color(0xFF8B7BA7)),
              const SizedBox(width: 12),
              Container(width: 1, height: 28, color: _kAccent.withValues(alpha: 0.20)),
              const SizedBox(width: 12),
              _col('TIME', '${secs}s', isLow ? _kRed : const Color(0xFF2E7D32)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _col(String label, String value, Color color) {
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
            value,
            key: ValueKey<String>(value),
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _TimerBar extends StatelessWidget {
  final double progress;
  final Color color;
  const _TimerBar({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    final barColor = progress < 0.15
        ? _kRed
        : progress < 0.35
            ? const Color(0xFFF59E0B)
            : _kAccent;
    return Container(
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: Colors.black.withValues(alpha: 0.25),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(
              colors: [
                Color.lerp(barColor, Colors.white, 0.30)!,
                barColor,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: barColor.withValues(alpha: 0.40),
                blurRadius: 6,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComboBadge extends StatelessWidget {
  final int count;
  const _ComboBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_kGold, Color(0xFFFFA000)]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _kGold.withValues(alpha: 0.40),
            blurRadius: 8,
          ),
        ],
      ),
      child: Text(
        '🔥 $count COMBO!',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    ).animate().scale(
      begin: const Offset(0.5, 0.5),
      end: const Offset(1.0, 1.0),
      duration: 250.ms,
      curve: Curves.easeOutBack,
    );
  }
}

class _GameField extends StatelessWidget {
  final List<_MoleState?> holes;
  final List<_HolePosition> holePositions;
  final void Function(int) onTap;
  final bool showScorePopup;
  final int lastPoints;
  final int popupHoleIdx;
  final List<_WhackEffect> whackEffects;

  const _GameField({
    required this.holes,
    required this.holePositions,
    required this.onTap,
    required this.showScorePopup,
    required this.lastPoints,
    required this.popupHoleIdx,
    required this.whackEffects,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fieldW = constraints.maxWidth;
        final fieldH = constraints.maxHeight;
        final holeBaseW = fieldW * 0.26;
        final holeBaseH = holeBaseW * 1.15;

        final children = <Widget>[];
        for (int idx = 0; idx < holePositions.length; idx++) {
          if (idx >= holes.length) continue;
          final pos = holePositions[idx];
          final w = holeBaseW * pos.scale;
          final h = holeBaseH * pos.scale;
          final left = pos.x * fieldW - w / 2;
          final top = pos.y * fieldH - h / 2;

          children.add(Positioned(
            left: left,
            top: top,
            width: w,
            height: h,
            child: _HoleWidget(
              mole: holes[idx],
              onTap: () => onTap(idx),
              showPopup: showScorePopup && popupHoleIdx == idx,
              popupPoints: lastPoints,
            ),
          ));

          for (final effect in whackEffects) {
            if (effect.holeIdx != idx) continue;
            final effectSize = w * 1.8;
            final cx = pos.x * fieldW;
            final cy = pos.y * fieldH - h * 0.20;

            children.add(Positioned(
              left: cx - effectSize / 2,
              top: cy - effectSize / 2,
              width: effectSize,
              height: effectSize,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _WhackEffectPainter(
                    progress: effect.progress,
                    isBomb: effect.isBomb,
                  ),
                ),
              ),
            ));
          }
        }

        return Stack(
          clipBehavior: Clip.none,
          children: children,
        );
      },
    );
  }
}

class _HoleWidget extends StatelessWidget {
  final _MoleState? mole;
  final VoidCallback onTap;
  final bool showPopup;
  final int popupPoints;

  const _HoleWidget({
    required this.mole,
    required this.onTap,
    required this.showPopup,
    required this.popupPoints,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onTap(),
      behavior: HitTestBehavior.opaque,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                size: Size(w, h),
                painter: _HolePainter(mole: mole),
              ),
              if (showPopup)
                Positioned(
                  top: h * 0.02,
                  child: _ScorePopup(points: popupPoints),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HolePainter extends CustomPainter {
  final _MoleState? mole;
  const _HolePainter({required this.mole});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final holeY = size.height * 0.70;
    final holeW = size.width * 0.84;
    final holeH = size.height * 0.22;

    final dirtOuter = Rect.fromCenter(center: Offset(cx, holeY + 2), width: holeW + 22, height: holeH + 18);
    canvas.drawOval(dirtOuter, Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFF5D4037).withValues(alpha: 0.45),
        const Color(0xFF4E342E).withValues(alpha: 0.20),
        const Color(0xFF3E2723).withValues(alpha: 0.0),
      ], stops: const [0.25, 0.6, 1.0]).createShader(dirtOuter));

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, holeY + 5), width: holeW + 10, height: holeH + 8),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    final holeRect = Rect.fromCenter(center: Offset(cx, holeY), width: holeW, height: holeH);
    canvas.drawOval(holeRect, Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF080300), _kDarkHole, const Color(0xFF0A0502)],
        stops: const [0.0, 0.5, 1.0],
        center: const Alignment(0, -0.2),
      ).createShader(holeRect));

    final rimRect = Rect.fromCenter(center: Offset(cx, holeY - holeH * 0.06), width: holeW + 6, height: holeH * 0.40);
    canvas.drawOval(rimRect, Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFF8D6E63), const Color(0xFFA1887F), const Color(0xFF6D4C41)],
      ).createShader(rimRect));
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - holeW * 0.15, holeY - holeH * 0.18), width: holeW * 0.35, height: holeH * 0.12),
      Paint()..color = Colors.white.withValues(alpha: 0.08),
    );

    final m = mole;
    if (m == null || m.popUp <= 0) return;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, holeY + holeH * 0.12));

    if (m.type == _MoleType.bomb) {
      _drawBomb(canvas, cx, holeY, m.popUp, m.whacked, size);
    } else {
      _drawMole(canvas, cx, holeY, m.popUp, m.type == _MoleType.golden, m.whacked, size);
    }

    canvas.restore();

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, holeY - holeH * 0.06), width: holeW + 6, height: holeH * 0.18),
      Paint()
        ..color = const Color(0xFF8D6E63).withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawMole(Canvas canvas, double cx, double holeY, double popUp, bool golden, bool whacked, Size size) {
    final mainColor = golden ? _kGold : _kBrown;
    final darkColor = golden ? const Color(0xFFC8A600) : _kBrownDk;
    final lightColor = golden ? const Color(0xFFFFF176) : const Color(0xFFC4A07A);
    final maxH = size.height * 0.52;
    final squash = whacked ? 0.75 : 1.0;
    final stretch = whacked ? 1.15 : 1.0;
    final bodyH = maxH * popUp * squash;
    final bodyW = size.width * 0.50 * stretch;
    final bodyTop = holeY - bodyH;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + 2, holeY + 2), width: bodyW * 0.85, height: 6.0 * popUp),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.30 * popUp)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    final headR = bodyW * 0.48;
    final headCy = bodyTop + headR * 0.55;

    if (popUp > 0.20) {
      final earR = headR * 0.34;
      for (final side in [-1.0, 1.0]) {
        final earX = cx + side * headR * 0.75;
        final earY = headCy - headR * 0.25;
        canvas.drawCircle(Offset(earX, earY + 1.5), earR + 1.5, Paint()..color = Colors.black.withValues(alpha: 0.18));
        canvas.drawCircle(Offset(earX, earY), earR, Paint()
          ..shader = RadialGradient(
            colors: [Color.lerp(darkColor, Colors.white, 0.08)!, darkColor],
            center: Alignment(-0.3 * side, -0.3),
          ).createShader(Rect.fromCircle(center: Offset(earX, earY), radius: earR)));
        canvas.drawCircle(Offset(earX, earY + earR * 0.05), earR * 0.55, Paint()
          ..shader = RadialGradient(
            colors: [const Color(0xFFFFB4B4).withValues(alpha: 0.70), const Color(0xFFFF8A80).withValues(alpha: 0.30)],
          ).createShader(Rect.fromCircle(center: Offset(earX, earY), radius: earR * 0.55)));
      }
    }

    final bodyRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(cx - bodyW / 2, bodyTop + headR * 0.35, bodyW, bodyH - headR * 0.2),
      topLeft: Radius.circular(bodyW * 0.45),
      topRight: Radius.circular(bodyW * 0.45),
    );
    canvas.drawRRect(bodyRect, Paint()
      ..shader = LinearGradient(
        colors: [lightColor, mainColor, darkColor, Color.lerp(darkColor, Colors.black, 0.3)!],
        stops: const [0.0, 0.3, 0.7, 1.0],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(bodyRect.outerRect));

    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - bodyW * 0.20, bodyTop + headR * 0.40, bodyW * 0.15, bodyH * 0.3),
        topLeft: Radius.circular(bodyW * 0.2),
        topRight: Radius.circular(bodyW * 0.2),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.08),
    );

    if (popUp > 0.30) {
      final bellyW = bodyW * 0.55;
      final bellyH = bodyH * 0.32;
      final bellyY = holeY - bellyH * 0.55;
      final bellyRect = Rect.fromCenter(center: Offset(cx, bellyY), width: bellyW, height: bellyH);
      canvas.drawOval(bellyRect, Paint()
        ..shader = RadialGradient(
          colors: [_kBelly.withValues(alpha: 0.55), _kBelly.withValues(alpha: 0.15)],
          center: const Alignment(0, -0.3),
        ).createShader(bellyRect));
    }

    canvas.drawCircle(Offset(cx + 1.5, headCy + 2), headR + 1, Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));

    final headRect = Rect.fromCircle(center: Offset(cx, headCy), radius: headR);
    canvas.drawCircle(Offset(cx, headCy), headR, Paint()
      ..shader = RadialGradient(
        colors: [
          Color.lerp(mainColor, Colors.white, 0.30)!,
          mainColor,
          darkColor,
          Color.lerp(darkColor, Colors.black, 0.25)!,
        ],
        stops: const [0.0, 0.35, 0.75, 1.0],
        center: const Alignment(-0.25, -0.35),
      ).createShader(headRect));

    canvas.drawCircle(
      Offset(cx - headR * 0.30, headCy - headR * 0.35),
      headR * 0.30,
      Paint()..color = Colors.white.withValues(alpha: 0.10),
    );

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, headCy), radius: headR),
      -2.5, 1.2,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );

    if (popUp > 0.45) {
      final eyeY = headCy - headR * 0.10;
      final eyeSpacing = headR * 0.42;
      final eyeR = headR * 0.22;

      for (final side in [-1.0, 1.0]) {
        final ex = cx + side * eyeSpacing;
        canvas.drawCircle(Offset(ex, eyeY + 1), eyeR + 1, Paint()..color = Colors.black.withValues(alpha: 0.15));
        canvas.drawCircle(Offset(ex, eyeY), eyeR, Paint()
          ..shader = RadialGradient(
            colors: [Colors.white, const Color(0xFFF5F5F5), const Color(0xFFE0E0E0)],
            center: const Alignment(-0.2, -0.3),
          ).createShader(Rect.fromCircle(center: Offset(ex, eyeY), radius: eyeR)));

        if (whacked) {
          final sp = Paint()
            ..color = const Color(0xFF1A1A2E)
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(Offset(ex - eyeR * 0.5, eyeY - eyeR * 0.5), Offset(ex + eyeR * 0.5, eyeY + eyeR * 0.5), sp);
          canvas.drawLine(Offset(ex + eyeR * 0.5, eyeY - eyeR * 0.5), Offset(ex - eyeR * 0.5, eyeY + eyeR * 0.5), sp);
        } else {
          final pupilR = eyeR * 0.52;
          canvas.drawCircle(Offset(ex + 1, eyeY + 0.5), pupilR, Paint()
            ..shader = RadialGradient(
              colors: [const Color(0xFF0D0D1A), const Color(0xFF1A1A2E)],
              center: const Alignment(-0.2, -0.2),
            ).createShader(Rect.fromCircle(center: Offset(ex + 1, eyeY), radius: pupilR)));
          canvas.drawCircle(Offset(ex + eyeR * 0.15, eyeY - eyeR * 0.15), eyeR * 0.14, Paint()..color = Colors.white.withValues(alpha: 0.85));
          canvas.drawCircle(Offset(ex - eyeR * 0.10, eyeY + eyeR * 0.12), eyeR * 0.07, Paint()..color = Colors.white.withValues(alpha: 0.45));
        }
      }

      final noseY = headCy + headR * 0.25;
      final noseW = headR * 0.32;
      final noseH = headR * 0.22;
      final noseRect = Rect.fromCenter(center: Offset(cx, noseY), width: noseW, height: noseH);
      canvas.drawOval(Offset(cx + 0.5, noseY + 0.5) & Size(noseW, noseH), Paint()..color = Colors.black.withValues(alpha: 0.15));
      canvas.drawOval(noseRect, Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFFEF9A9A), const Color(0xFFE57373), const Color(0xFFD32F2F)],
          center: const Alignment(-0.25, -0.35),
        ).createShader(noseRect));
      canvas.drawCircle(Offset(cx - noseW * 0.12, noseY - noseH * 0.15), headR * 0.055, Paint()..color = Colors.white.withValues(alpha: 0.55));

      if (!whacked) {
        final whiskerP = Paint()
          ..color = Colors.white.withValues(alpha: 0.50)
          ..strokeWidth = 0.9
          ..strokeCap = StrokeCap.round;
        for (final side in [-1.0, 1.0]) {
          final wx = cx + side * headR * 0.20;
          for (final a in [-0.18, 0.0, 0.18]) {
            final endX = wx + side * headR * 0.60;
            final endY = noseY + a * headR * 1.3;
            canvas.drawLine(Offset(wx, noseY + a * headR * 0.3), Offset(endX, endY), whiskerP);
          }
        }
      }

      for (final side in [-1.0, 1.0]) {
        final cheekX = cx + side * headR * 0.52;
        final cheekY = noseY + headR * 0.10;
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cheekX, cheekY), width: headR * 0.24, height: headR * 0.16),
          Paint()
            ..color = const Color(0xFFFFCDD2).withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      }

      if (whacked) {
        for (int i = 0; i < 5; i++) {
          final angle = i * math.pi * 2 / 5 + popUp * 3;
          final dist = headR * 0.85;
          final sx = cx + math.cos(angle) * dist;
          final sy = headCy - headR * 0.5 + math.sin(angle) * dist * 0.4;
          _drawTinyStar(canvas, sx, sy, 3.5, const Color(0xFFFFEB3B).withValues(alpha: 0.7 * popUp));
        }
      }

      if (golden) {
        canvas.drawCircle(
          Offset(cx, headCy - headR * 0.7),
          headR * 0.35,
          Paint()
            ..color = _kGold.withValues(alpha: 0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
        canvas.drawCircle(
          Offset(cx, headCy - headR * 0.7),
          headR * 0.15,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.15)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
    }
  }

  void _drawTinyStar(Canvas canvas, double x, double y, double r, Color color) {
    final paint = Paint()..color = color;
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final dist = i.isEven ? r : r * 0.4;
      final px = x + math.cos(angle) * dist;
      final py = y + math.sin(angle) * dist;
      if (i == 0) { path.moveTo(px, py); } else { path.lineTo(px, py); }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawBomb(Canvas canvas, double cx, double holeY, double popUp, bool whacked, Size size) {
    final maxH = size.height * 0.46;
    final bodyH = maxH * popUp;
    final bodyW = size.width * 0.42;
    final bodyTop = holeY - bodyH;
    final bombR = bodyW * 0.50;
    final bombCy = bodyTop + bombR * 0.85;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + 2, holeY + 2), width: bombR * 1.5, height: 5.0 * popUp),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.30 * popUp)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    canvas.drawCircle(Offset(cx + 1.5, bombCy + 2), bombR + 1.5, Paint()
      ..color = Colors.black.withValues(alpha: 0.30));

    final bombRect = Rect.fromCircle(center: Offset(cx, bombCy), radius: bombR);
    canvas.drawCircle(Offset(cx, bombCy), bombR, Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF616161), const Color(0xFF333333), const Color(0xFF111111)],
        stops: const [0.0, 0.5, 1.0],
        center: const Alignment(-0.30, -0.35),
      ).createShader(bombRect));

    canvas.drawCircle(
      Offset(cx - bombR * 0.28, bombCy - bombR * 0.28),
      bombR * 0.22,
      Paint()..color = Colors.white.withValues(alpha: 0.15),
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, bombCy), radius: bombR * 0.85),
      -2.8, 0.8,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );

    if (popUp > 0.35) {
      final fuseBase = Offset(cx, bombCy - bombR * 0.88);
      final fuseTop = Offset(cx + bombR * 0.18, bombCy - bombR * 1.30);
      canvas.drawLine(fuseBase, fuseTop, Paint()
        ..color = const Color(0xFF8D6E63)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round);

      if (!whacked) {
        for (int i = 0; i < 4; i++) {
          final sparkR = 2.5 + i * 1.5;
          final sparkY = fuseTop.dy - i * 2.5;
          canvas.drawCircle(
            Offset(fuseTop.dx + (i.isEven ? 1 : -1) * 1.5, sparkY),
            sparkR,
            Paint()
              ..color = Color.lerp(Colors.orange, Colors.yellow, i / 3.0)!.withValues(alpha: 0.75 - i * 0.12)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
          );
        }
      }

      final dangerRect = Rect.fromCircle(center: Offset(cx, bombCy), radius: bombR * 0.16);
      canvas.drawOval(dangerRect, Paint()..color = _kRed);
      canvas.drawLine(
        Offset(cx, bombCy - bombR * 0.08),
        Offset(cx, bombCy + bombR * 0.04),
        Paint()..color = Colors.white..strokeWidth = 1.8..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(Offset(cx, bombCy + bombR * 0.09), 1.2, Paint()..color = Colors.white);
    }

    if (whacked && popUp > 0.15) {
      final crackAlpha = popUp * 0.8;
      final crackP = Paint()
        ..color = _kRed.withValues(alpha: crackAlpha)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < 6; i++) {
        final angle = i * math.pi / 3;
        final inner = bombR * 0.3;
        final outer = bombR * (0.7 + (1.0 - popUp) * 0.5);
        canvas.drawLine(
          Offset(cx + math.cos(angle) * inner, bombCy + math.sin(angle) * inner),
          Offset(cx + math.cos(angle) * outer, bombCy + math.sin(angle) * outer),
          crackP,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HolePainter old) => true;
}

class _ScorePopup extends StatelessWidget {
  final int points;
  const _ScorePopup({required this.points});

  @override
  Widget build(BuildContext context) {
    final isNeg = points < 0;
    final color = isNeg ? _kRed : (points >= 25 ? _kGold : _kAccent);
    final text = isNeg ? '$points' : '+$points';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: isNeg ? 20 : (points >= 25 ? 26 : 22),
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(color: color.withValues(alpha: 0.70), blurRadius: 10),
            Shadow(color: Colors.black.withValues(alpha: 0.40), blurRadius: 2, offset: const Offset(0, 1)),
          ],
        ),
      ),
    )
        .animate()
        .scale(
          begin: const Offset(0.3, 0.3),
          end: const Offset(1.0, 1.0),
          duration: 200.ms,
          curve: Curves.easeOutBack,
        )
        .moveY(begin: 0, end: -32, duration: 600.ms, curve: Curves.easeOut)
        .fadeOut(delay: 400.ms, duration: 200.ms);
  }
}

class _GrassPainter extends CustomPainter {
  final double time;
  const _GrassPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final rect = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFF6DA843),
            Color(0xFF548C32),
            Color(0xFF3D7224),
            Color(0xFF2B5A18),
            Color(0xFF1E4A10),
          ],
          stops: [0.0, 0.2, 0.45, 0.7, 1.0],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect),
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.15),
      Paint()
        ..color = const Color(0xFF8DB86A).withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );

    final rng = math.Random(42);

    for (int band = 0; band < 8; band++) {
      final by = h * (band / 8.0);
      final bh = h * 0.04 * (1.0 + band * 0.08);
      canvas.drawRect(
        Rect.fromLTWH(0, by, w, bh),
        Paint()
          ..color = (band.isEven
              ? const Color(0xFF4CAF50).withValues(alpha: 0.06)
              : const Color(0xFF1B5E20).withValues(alpha: 0.05))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    for (int i = 0; i < 20; i++) {
      final px = rng.nextDouble() * w;
      final py = rng.nextDouble() * h;
      final depthF = py / h;
      final pw = (30.0 + rng.nextDouble() * 50) * (0.5 + depthF * 0.8);
      final ph = pw * 0.4;
      final light = rng.nextBool();
      canvas.drawOval(
        Rect.fromCenter(center: Offset(px, py), width: pw, height: ph),
        Paint()
          ..color = (light ? const Color(0xFF5A9E30) : const Color(0xFF1E4A10))
              .withValues(alpha: 0.12 + depthF * 0.08)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + depthF * 4),
      );
    }

    final bladePaint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const grassColors = [
      Color(0xFF2E7D32), Color(0xFF1B5E20), Color(0xFF33691E),
      Color(0xFF388E3C), Color(0xFF43A047), Color(0xFF4CAF50),
      Color(0xFF66BB6A), Color(0xFF81C784), Color(0xFF558B2F),
      Color(0xFF7CB342), Color(0xFFA5D6A7),
    ];

    for (int i = 0; i < 500; i++) {
      final bx = rng.nextDouble() * w;
      final by = rng.nextDouble() * h;
      final depthF = by / h;
      final bladeH = (6.0 + rng.nextDouble() * 12) * (0.4 + depthF * 0.9);
      final baseLean = (rng.nextDouble() - 0.5) * (6 + depthF * 8);
      final windSpeed = 1.2 + depthF * 1.0;
      final windAmp = 2.0 + depthF * 4.0;
      final windSway = math.sin(time * windSpeed + bx * 0.01 + i * 0.2) * windAmp;
      final lean = baseLean + windSway;
      final thick = (0.6 + rng.nextDouble() * 1.2) * (0.5 + depthF * 0.8);
      final color = grassColors[rng.nextInt(grassColors.length)];
      final alpha = (0.15 + depthF * 0.30 + rng.nextDouble() * 0.15).clamp(0.0, 0.60);
      bladePaint
        ..color = color.withValues(alpha: alpha)
        ..strokeWidth = thick;
      final path = Path()
        ..moveTo(bx, by)
        ..quadraticBezierTo(
          bx + lean * 0.55, by - bladeH * 0.55,
          bx + lean, by - bladeH,
        );
      canvas.drawPath(path, bladePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GrassPainter old) => true;
}

class _WhackEffectPainter extends CustomPainter {
  final double progress;
  final bool isBomb;
  const _WhackEffectPainter({required this.progress, required this.isBomb});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1.0) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = size.width * 0.5;
    final rng = math.Random(isBomb ? 99 : 42);
    final fade = (1.0 - progress).clamp(0.0, 1.0);
    final easeOut = 1.0 - (1.0 - progress) * (1.0 - progress);

    if (progress < 0.25) {
      final flashAlpha = (1.0 - progress / 0.25) * 0.35;
      canvas.drawCircle(
        Offset(cx, cy),
        maxR * 0.4 * (progress / 0.25),
        Paint()
          ..color = (isBomb ? const Color(0xFFFF6D00) : Colors.white).withValues(alpha: flashAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    if (isBomb) {
      final ringR = maxR * 0.8 * easeOut;
      final ringAlpha = fade * 0.5;
      canvas.drawCircle(
        Offset(cx, cy),
        ringR,
        Paint()
          ..color = const Color(0xFFFF6D00).withValues(alpha: ringAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0 * fade,
      );

      canvas.drawCircle(
        Offset(cx, cy),
        maxR * 0.35 * easeOut,
        Paint()
          ..color = const Color(0xFFFFAB00).withValues(alpha: fade * 0.20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );

      for (int i = 0; i < 14; i++) {
        final angle = rng.nextDouble() * math.pi * 2;
        final speed = 0.4 + rng.nextDouble() * 0.6;
        final dist = maxR * easeOut * speed;
        final gravity = progress * progress * maxR * 0.3 * rng.nextDouble();
        final r = (2.5 + rng.nextDouble() * 3.5) * fade;
        final px = cx + math.cos(angle) * dist;
        final py = cy + math.sin(angle) * dist + gravity;
        final t = rng.nextDouble();
        final color = Color.lerp(const Color(0xFFFF6D00), const Color(0xFFD50000), t)!;
        canvas.drawCircle(Offset(px, py), r, Paint()..color = color.withValues(alpha: fade * 0.75));
      }

      for (int i = 0; i < 5; i++) {
        final angle = rng.nextDouble() * math.pi * 2;
        final dist = maxR * 0.2 * easeOut + rng.nextDouble() * maxR * 0.3;
        final puffR = (4 + rng.nextDouble() * 6) * (0.5 + progress * 0.5);
        final px = cx + math.cos(angle) * dist;
        final py = cy + math.sin(angle) * dist - progress * 8;
        canvas.drawCircle(
          Offset(px, py), puffR,
          Paint()
            ..color = const Color(0xFF757575).withValues(alpha: fade * 0.25)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, puffR * 0.8),
        );
      }
    } else {
      final ringR = maxR * 0.6 * easeOut;
      canvas.drawCircle(
        Offset(cx, cy),
        ringR,
        Paint()
          ..color = const Color(0xFF8D6E63).withValues(alpha: fade * 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * fade,
      );

      for (int i = 0; i < 10; i++) {
        final angle = rng.nextDouble() * math.pi * 2;
        final speed = 0.3 + rng.nextDouble() * 0.7;
        final dist = maxR * easeOut * speed;
        final gravity = progress * progress * maxR * 0.4 * rng.nextDouble();
        final r = (1.5 + rng.nextDouble() * 2.5) * fade;
        final px = cx + math.cos(angle) * dist;
        final py = cy + math.sin(angle) * dist + gravity;
        final isDirt = rng.nextBool();
        canvas.drawCircle(
          Offset(px, py), r,
          Paint()..color = (isDirt
            ? const Color(0xFF6D4C41)
            : const Color(0xFFA1887F)
          ).withValues(alpha: fade * 0.7),
        );
      }

      for (int i = 0; i < 4; i++) {
        final angle = i * math.pi / 2 + progress * 4;
        final dist = maxR * 0.35 * easeOut;
        final sx = cx + math.cos(angle) * dist;
        final sy = cy + math.sin(angle) * dist - progress * 12;
        _drawStar(canvas, sx, sy, (4.0 + i) * fade, const Color(0xFFFFEB3B).withValues(alpha: fade * 0.65));
      }

      if (progress < 0.4) {
        final bangAlpha = (1.0 - progress / 0.4) * 0.8;
        final tp = TextPainter(
          text: TextSpan(
            text: 'POW!',
            style: TextStyle(
              color: Colors.white.withValues(alpha: bangAlpha),
              fontSize: 14 + progress * 8,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(color: const Color(0xFF8D6E63).withValues(alpha: bangAlpha), blurRadius: 4),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(cx - tp.width / 2, cy - maxR * 0.6 - progress * 15));
      }
    }
  }

  void _drawStar(Canvas canvas, double x, double y, double r, Color color) {
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final dist = i.isEven ? r : r * 0.38;
      final px = x + math.cos(angle) * dist;
      final py = y + math.sin(angle) * dist;
      if (i == 0) { path.moveTo(px, py); } else { path.lineTo(px, py); }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _WhackEffectPainter old) =>
      old.progress != progress;
}

class _WAMBgPainter extends AnimatedBgPainter {
  const _WAMBgPainter(super.t);

  @override
  void paintAt(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;
    for (int i = 0; i < 6; i++) {
      final phase = (t + i * 0.17) % 1.0;
      final x = w * (0.1 + i * 0.16);
      final y = h * (0.15 + phase * 0.7);
      final r = 8.0 + i * 3.0;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = _kAccent.withValues(alpha: 0.06 + (1 - phase) * 0.04),
      );
    }
  }
}

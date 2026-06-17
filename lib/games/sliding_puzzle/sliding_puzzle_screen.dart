import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/ads_service.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/score_service.dart';
import '../../core/widgets/how_to_play_sheet.dart';
import '../game_registry.dart';
import '../game_wrapper.dart';
import '../game_picker_scaffold.dart';
import '../shared/animated_background.dart';
import '../shared/animated_difficulty_icon.dart';
import '../shared/game_control_buttons.dart';
import '../shared/game_difficulty_picker.dart';
import '../shared/game_hud_bar.dart';
import '../shared/generic_game_result_screen.dart' as game_result;
import 'sliding_puzzle_logo.dart';
import 'sliding_puzzle_tutorial.dart';

const kSlidingPuzzleGameId = 'sliding_puzzle';

const _kBgTop = Color(0xFFF3EEFF);
const _kBgBottom = Color(0xFFE8DEFF);
const _kAccent = Color(0xFF8B5CF6);

const _k3x3Color = Color(0xFF22C55E);
const _k4x4Color = Color(0xFFF59E0B);
const _k5x5Color = Color(0xFFEF4444);

enum _GridSize { s3x3, s4x4, s5x5 }

extension _GridSizeX on _GridSize {
  int get n => [3, 4, 5][index];
  String get label => ['Easy', 'Medium', 'Hard'][index];
  Color get color => [_k3x3Color, _k4x4Color, _k5x5Color][index];
  DifficultyKind get kind => [DifficultyKind.easy, DifficultyKind.medium, DifficultyKind.hard][index];
  String get hint => ['8 tiles — beginner', '15 tiles — classic', '24 tiles — expert'][index];
  String get subKey => ['3x3', '4x4', '5x5'][index];
}

enum _Theme { numbers, animals, nature, space, food, flags }

extension _ThemeX on _Theme {
  String get label => ['Numbers', 'Animals', 'Nature', 'Space', 'Food', 'Flags'][index];
  IconData get icon => [
    Icons.tag_rounded,
    Icons.pets_rounded,
    Icons.park_rounded,
    Icons.rocket_launch_rounded,
    Icons.restaurant_rounded,
    Icons.flag_rounded,
  ][index];

  List<String> get emojis {
    switch (this) {
      case _Theme.numbers:
        return [];
      case _Theme.animals:
        return ['🐶', '🐱', '🐻', '🦊', '🐼', '🐸', '🐵', '🦁', '🐯', '🐨', '🐰', '🐷', '🐮', '🐔', '🐙', '🦋', '🐢', '🐳', '🦉', '🐺', '🦄', '🐝', '🐞', '🦈'];
      case _Theme.nature:
        return ['🌸', '🌻', '🌺', '🍀', '🌵', '🌴', '🍁', '🌊', '⛰️', '🌙', '☀️', '🌈', '❄️', '🔥', '💧', '🌾', '🍂', '🌿', '🪻', '🪸', '🪨', '🌋', '🏝️', '🌠'];
      case _Theme.space:
        return ['🚀', '🌍', '🌙', '⭐', '🪐', '☄️', '🌌', '👽', '🛸', '🌑', '🔭', '🛰️', '💫', '🌟', '✨', '🌎', '🌏', '🌕', '🌖', '🌗', '🌘', '🌒', '🌓', '🌔'];
      case _Theme.food:
        return ['🍕', '🍔', '🌮', '🍣', '🍰', '🍩', '🍎', '🍓', '🥑', '🍿', '🧁', '🍪', '🥐', '🌶️', '🍇', '🍌', '🥝', '🍊', '🫐', '🥥', '🧀', '🥨', '🍟', '🥞'];
      case _Theme.flags:
        return ['🇺🇸', '🇬🇧', '🇫🇷', '🇩🇪', '🇯🇵', '🇮🇳', '🇧🇷', '🇨🇦', '🇦🇺', '🇮🇹', '🇪🇸', '🇲🇽', '🇰🇷', '🇷🇺', '🇨🇳', '🇿🇦', '🇸🇪', '🇳🇴', '🇳🇱', '🇵🇹', '🇦🇷', '🇨🇭', '🇹🇷', '🇵🇱'];
    }
  }
}

class SlidingPuzzleScreen extends StatefulWidget {
  const SlidingPuzzleScreen({super.key});

  @override
  State<SlidingPuzzleScreen> createState() => _SlidingPuzzleScreenState();
}

class _SlidingPuzzleScreenState extends State<SlidingPuzzleScreen> {
  _GridSize? _activeGridSize;
  _GridSize _pickerGridSize = _GridSize.s4x4;
  bool _isFavorite = false;

  _Theme _theme = _Theme.animals;
  List<int> _tiles = [];
  int _emptyIndex = 0;
  int _moves = 0;
  int _bestTime = 0;
  bool _isNewBest = false;
  bool _gameOver = false;
  int _hintsUsed = 0;
  static const _kMaxHints = 3;
  Timer? _idleTimer;
  bool _idleStuck = false;
  static const _kIdleTimeout = Duration(seconds: 15);

  Timer? _ticker;
  final Stopwatch _stopwatch = Stopwatch();
  int _elapsedSeconds = 0;

  List<String> _shuffledEmojis = [];

  static const _tileColors = [
    Color(0xFF8B5CF6),
    Color(0xFFA78BFA),
    Color(0xFF7C3AED),
    Color(0xFF6D28D9),
    Color(0xFF9333EA),
    Color(0xFFC084FC),
    Color(0xFFD946EF),
    Color(0xFF7E22CE),
    Color(0xFFEC4899),
    Color(0xFFF472B6),
    Color(0xFF14B8A6),
    Color(0xFF06B6D4),
    Color(0xFF3B82F6),
    Color(0xFF6366F1),
    Color(0xFFEF4444),
    Color(0xFFF59E0B),
    Color(0xFF22C55E),
    Color(0xFF10B981),
    Color(0xFFE879F9),
    Color(0xFF818CF8),
    Color(0xFF2DD4BF),
    Color(0xFF38BDF8),
    Color(0xFFFB7185),
    Color(0xFFFBBF24),
  ];

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(kSlidingPuzzleGameId);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _idleTimer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _toggleFavorite() {
    ScoreService().toggleFavorite(kSlidingPuzzleGameId);
    setState(() => _isFavorite = !_isFavorite);
  }

  void _showHelp() {
    final info = GameRegistry.getById(kSlidingPuzzleGameId);
    if (info == null) return;
    showHowToPlaySheet(context, title: info.name, howToPlay: info.howToPlay,
      accent: _kAccent, steps: slidingPuzzleSteps(), gameId: kSlidingPuzzleGameId);
  }

  void _startGame(_GridSize gs) {
    final n = gs.n;
    final total = n * n;
    _tiles = List.generate(total - 1, (i) => i + 1)..add(0);
    _emptyIndex = total - 1;
    _moves = 0;
    _bestTime = ScoreService().getHighScore(kSlidingPuzzleGameId, subKey: gs.subKey);
    _isNewBest = false;
    _gameOver = false;
    _hintsUsed = 0;
    _idleStuck = false;
    _elapsedSeconds = 0;
    _stopwatch.reset();

    final themes = _Theme.values.where((t) => t != _Theme.numbers).toList();
    _theme = themes[math.Random().nextInt(themes.length)];
    _shuffledEmojis = _theme.emojis.take(total - 1).toList();

    _shuffle(n);

    setState(() => _activeGridSize = gs);

    if (mounted) {
      GameWrapper.of(context).setDifficultyAndMode(difficulty: gs.label, subKey: gs.subKey);
      GameWrapper.of(context).startGame();
      GameWrapper.of(context).updateScore(0);
    }

    _resetIdleTimer();
    _stopwatch.start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds = _stopwatch.elapsed.inSeconds);
    });
  }

  bool get _isStuck => _idleStuck;

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (_idleStuck) setState(() => _idleStuck = false);
    _idleTimer = Timer(_kIdleTimeout, () {
      if (mounted && _activeGridSize != null && !_gameOver) {
        setState(() => _idleStuck = true);
      }
    });
  }

  void _shuffle(int n) {
    final rng = math.Random();
    do {
      _tiles = List.generate(n * n - 1, (i) => i + 1)..add(0);
      _emptyIndex = n * n - 1;
      for (int i = 0; i < n * n * 200; i++) {
        final neighbors = _getMovableIndices(n);
        if (neighbors.isEmpty) continue;
        final pick = neighbors[rng.nextInt(neighbors.length)];
        _tiles[_emptyIndex] = _tiles[pick];
        _tiles[pick] = 0;
        _emptyIndex = pick;
      }
    } while (_isSolved());
  }

  List<int> _getMovableIndices(int n) {
    final r = _emptyIndex ~/ n;
    final c = _emptyIndex % n;
    final result = <int>[];
    if (r > 0) result.add((r - 1) * n + c);
    if (r < n - 1) result.add((r + 1) * n + c);
    if (c > 0) result.add(r * n + c - 1);
    if (c < n - 1) result.add(r * n + c + 1);
    return result;
  }

  void _onTileTap(int idx) {
    if (_gameOver || _activeGridSize == null) return;
    final n = _activeGridSize!.n;
    final movable = _getMovableIndices(n);
    if (!movable.contains(idx)) return;
    _idleStuck = false;
    _resetIdleTimer();

    setState(() {
      _tiles[_emptyIndex] = _tiles[idx];
      _tiles[idx] = 0;
      _emptyIndex = idx;
      _moves++;
    });
    AudioService().playTap();

    if (_isSolved()) {
      _endGame();
    }
  }

  bool _isSolved() {
    for (int i = 0; i < _tiles.length - 1; i++) {
      if (_tiles[i] != i + 1) return false;
    }
    return true;
  }

  void _endGame() {
    _gameOver = true;
    _ticker?.cancel();
    _stopwatch.stop();
    _isNewBest = _bestTime == 0 || _elapsedSeconds < _bestTime;
    if (_isNewBest) {
      _bestTime = _elapsedSeconds;
      ScoreService().saveScore(kSlidingPuzzleGameId, _elapsedSeconds, subKey: _activeGridSize!.subKey);
    }
    GameWrapper.of(context).updateScore(_elapsedSeconds);
    AudioService().playScore();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) GameWrapper.of(context).endGame(result: 'win');
    });
  }

  void _onHint() {
    if (_gameOver || _activeGridSize == null) return;
    if (_hintsUsed >= _kMaxHints) return;
    if (!AdsService().isRewardedReady) return;
    AudioService().playTap();
    bool earned = false;
    AdsService().showRewarded(
      rewardType: RewardType.hint,
      gameId: kSlidingPuzzleGameId,
      onRewarded: (_) => earned = true,
      onComplete: () {
        if (!earned || !mounted) return;
        _idleStuck = false;
        _hintsUsed++;
        _resetIdleTimer();
        for (int i = 0; i < _tiles.length - 1; i++) {
          if (_tiles[i] != i + 1) {
            final srcIdx = _tiles.indexOf(i + 1);
            setState(() {
              _tiles[srcIdx] = _tiles[i];
              _tiles[i] = i + 1;
              if (_tiles[srcIdx] == 0) _emptyIndex = srcIdx;
              if (_tiles[i] == 0) _emptyIndex = i;
              _moves++;
            });
            AudioService().playTap();
            if (_isSolved()) _endGame();
            return;
          }
        }
      },
    );
  }

  void _newGame() => _startGame(_activeGridSize ?? _pickerGridSize);

  void _backToPicker() {
    _ticker?.cancel();
    _stopwatch.stop();
    setState(() {
      _activeGridSize = null;
      _gameOver = false;
    });
    GameWrapper.of(context).restartGame();
  }

  void _backOrHome() {
    final wrapper = GameWrapper.of(context);
    wrapper.handleExit(() {
      _ticker?.cancel();
      _stopwatch.stop();
      if (context.canPop()) context.pop(); else context.go('/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_activeGridSize == null) return _buildPicker();
    if (_gameOver) return _buildResult();
    return _buildGame();
  }

  Widget _buildPicker() {
    final difficulties = _GridSize.values.map((gs) => GameDifficultyData(
      label: gs.label,
      color: gs.color,
      kind: gs.kind,
      hint: gs.hint,
      bestScore: ScoreService().getHighScore(kSlidingPuzzleGameId, subKey: gs.subKey),
      bestLabel: (s) => s > 0 ? 'Best: ${_formatTime(s)}' : 'No best yet',
    )).toList();

    return GamePickerScaffold(
      bgColorTop: _kBgTop,
      bgColorBottom: _kBgBottom,
      animatedBg: AnimatedBackground(
        factory: (t) => GenericAnimatedBgPainter(t, accent: _kAccent, icon: Icons.grid_view_rounded),
      ),
      iconRingColors: const [_kAccent, Color(0xFFC084FC), Color(0xFF6D28D9)],
      iconChild: buildSlidingPuzzleLogo(60),
      title: 'Sliding Puzzle',
      subtitle: 'Slide tiles to solve the puzzle!',
      onBack: _backOrHome,
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: _showHelp,
      gameId: kSlidingPuzzleGameId,
      body: GameSinglePickerBody(
        difficulties: difficulties,
        activeIndex: _pickerGridSize.index,
        onChanged: (i) => setState(() => _pickerGridSize = _GridSize.values[i]),
        playLabel: 'Play Sliding Puzzle',
        playSubLabel: 'Random emoji theme',
        onPlay: () => _startGame(_pickerGridSize),
        accentColor: _kAccent,
      ),
    );
  }


  Widget _buildGame() {
    final gs = _activeGridSize!;
    final n = gs.n;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFF1A0F2E), const Color(0xFF2D1B4E)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            GameHudBar(
              leading: GameBackButton(onTap: _backOrHome, bgColor: Colors.white.withValues(alpha: 0.10), iconColor: Colors.white),
              centerContent: _buildHud(gs),
              trailing: GameRestartButton(
                gameName: 'Sliding Puzzle',
                accentColor: gs.color,
                onRestart: _newGame,
                bgColor: Colors.white.withValues(alpha: 0.10),
                iconColor: Colors.white,
                onDialogOpened: () { _ticker?.cancel(); _stopwatch.stop(); },
                onDialogDismissed: () {
                  if (!_gameOver) {
                    _stopwatch.start();
                    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
                      if (mounted) setState(() => _elapsedSeconds = _stopwatch.elapsed.inSeconds);
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildGrid(n)),
            if (!_gameOver)
              Opacity(
                opacity: AdsService().isRewardedReady && _hintsUsed < _kMaxHints ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !AdsService().isRewardedReady || _hintsUsed >= _kMaxHints,
                  child: _SlidingPuzzleHintNudge(onTap: _onHint, isStuck: _isStuck),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildHud(_GridSize gs) {
    final color = gs.color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.30), blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedDifficultyIcon(kind: gs.kind, size: 14, prominent: false),
              const SizedBox(width: 6),
              Text(gs.label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: _kAccent.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 6)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _statCol('MOVES', '$_moves', color),
              _pillDivider(),
              _statCol('TIME', _formatTime(_elapsedSeconds), const Color(0xFF6B7280)),
              _pillDivider(),
              _statCol('BEST', _bestTime > 0 ? _formatTime(_bestTime) : '—', const Color(0xFFFEC84B)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statCol(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.85), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900, height: 1)),
        ],
      ),
    );
  }

  Widget _pillDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),
    );
  }

  Widget _buildGrid(int n) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDim = math.min(constraints.maxWidth - 24, constraints.maxHeight - 16);
        final cellSize = maxDim / n;

        return Center(
          child: SizedBox(
            width: cellSize * n,
            height: cellSize * n,
            child: Stack(
              children: List.generate(_tiles.length, (i) {
                final val = _tiles[i];
                if (val == 0) return const SizedBox.shrink();
                final r = i ~/ n;
                final c = i % n;
                return AnimatedPositioned(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutCubic,
                  left: c * cellSize,
                  top: r * cellSize,
                  width: cellSize,
                  height: cellSize,
                  child: GestureDetector(
                    onTap: () => _onTileTap(i),
                    child: _buildTile(val, cellSize, n),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTile(int val, double size, int n) {
    final color = _tileColors[(val - 1) % _tileColors.length];

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color.lerp(color, Colors.white, 0.15)!, color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(size * 0.12),
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  height: (size - 4) * 0.35,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
            ),
          ),
          Center(
            child: Text(
              _shuffledEmojis.isNotEmpty && val - 1 < _shuffledEmojis.length
                  ? _shuffledEmojis[val - 1]
                  : '$val',
              style: TextStyle(fontSize: size * 0.38),
            ),
          ),
          Positioned(
            right: 4,
            bottom: 2,
            child: Text(
              '$val',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: size * 0.15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildResult() {
    final gs = _activeGridSize!;
    return game_result.GenericGameResultScreen(
      headline: 'Solved!',
      subtitle: '$_moves moves · ${_formatTime(_elapsedSeconds)}',
      badgeContent: '🧩',
      badgeColor: gs.color,
      showNewBestBadge: _isNewBest,
      gameId: kSlidingPuzzleGameId,
      score: _elapsedSeconds,
      statsWidget: game_result.GameResultStatsRow(
        stats: [
          game_result.StatItem(label: 'TIME', value: _elapsedSeconds, displayValue: _formatTime(_elapsedSeconds), color: gs.color),
          game_result.StatItem(label: 'MOVES', value: _moves, color: const Color(0xFF6B7280)),
          game_result.StatItem(label: 'BEST', value: _bestTime, displayValue: _bestTime > 0 ? _formatTime(_bestTime) : '—', color: const Color(0xFFFEC84B)),
        ],
      ),
      actions: [
        game_result.GameResultAction(
          label: 'Play Again',
          icon: Icons.refresh_rounded,
          onTap: _newGame,
          filled: true,
          color: gs.color,
          actionId: 'play_again',
        ),
        game_result.GameResultAction(
          label: 'Change Size',
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
    );
  }
}

class _SlidingPuzzleHintNudge extends StatefulWidget {
  final VoidCallback onTap;
  final bool isStuck;
  const _SlidingPuzzleHintNudge({required this.onTap, required this.isStuck});
  @override
  State<_SlidingPuzzleHintNudge> createState() => _SlidingPuzzleHintNudgeState();
}

class _SlidingPuzzleHintNudgeState extends State<_SlidingPuzzleHintNudge> with TickerProviderStateMixin {
  static const _kBg = Color(0xFFFFD43B);
  static const _kFg = Color(0xFF5C4600);

  late final AnimationController _pulseCtrl;
  late final AnimationController _slideCtrl;
  late final Animation<double> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutBack);
    _fadeAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut);
    if (widget.isStuck) {
      _pulseCtrl.repeat(reverse: true);
      _slideCtrl.forward();
    }
  }

  @override
  void didUpdateWidget(_SlidingPuzzleHintNudge old) {
    super.didUpdateWidget(old);
    if (widget.isStuck && !old.isStuck) {
      _pulseCtrl.repeat(reverse: true);
      _slideCtrl.forward();
    } else if (!widget.isStuck && old.isStuck) {
      _pulseCtrl.stop();
      _pulseCtrl.value = 0;
      _slideCtrl.reverse();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, child) {
              final glow = widget.isStuck ? _pulseCtrl.value : 0.0;
              final scale = 1.0 + glow * 0.05;
              return Transform.scale(
                scale: scale,
                child: GestureDetector(
                  onTap: widget.onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _kBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE6BE00), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: _kBg.withValues(alpha: 0.30 + glow * 0.40),
                          blurRadius: 12 + glow * 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lightbulb_rounded, size: 16, color: _kFg),
                        const SizedBox(width: 6),
                        const Text(
                          'HINT',
                          style: TextStyle(
                            color: _kFg,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: _kFg.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow_rounded, size: 12, color: _kFg),
                              SizedBox(width: 2),
                              Text(
                                'AD',
                                style: TextStyle(
                                  color: _kFg,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            bottom: 38,
            child: AnimatedBuilder(
              animation: _slideCtrl,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnim,
                  child: Transform.translate(
                    offset: Offset(0, (1 - _slideAnim.value.clamp(0.0, 1.0)) * 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _kAccent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: _kAccent.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Stuck? Try a hint!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        CustomPaint(
                          size: const Size(14, 7),
                          painter: _SPBubbleTailPainter(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SPBubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _kAccent;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

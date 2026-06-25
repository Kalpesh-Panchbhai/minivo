import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/ads_service.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/level_progress_service.dart';
import '../../core/services/score_service.dart';
import '../../core/widgets/how_to_play_sheet.dart';
import '../game_picker_scaffold.dart';
import '../game_registry.dart';
import '../game_wrapper.dart';
import '../shared/animated_background.dart';
import '../shared/animated_difficulty_icon.dart';
import '../shared/continue_dialog.dart';
import '../shared/game_control_buttons.dart';
import '../shared/game_difficulty_picker.dart';
import '../shared/game_hud_bar.dart';
import '../shared/generic_game_result_screen.dart' as game_result;
import '../shared/level_complete_overlay.dart';
import 'maze_paint_level_gen.dart' as gen;
import 'maze_paint_logo.dart';
import 'maze_paint_tutorial.dart';

const kMazePaintGameId = 'maze_paint';

const _kAccent = Color(0xFFD4708F);
const _kBg = Color(0xFFFFF8F0);
const _kEasyColor = Color(0xFF22C55E);
const _kMediumColor = Color(0xFFF59E0B);
const _kHardColor = Color(0xFFEF4444);

const _kPaintPalette = <Color>[
  Color(0xFF00D4AA),
  Color(0xFFFF6B6B),
  Color(0xFF4ECDC4),
  Color(0xFFFFBE0B),
  Color(0xFF845EC2),
  Color(0xFFFF9671),
  Color(0xFF00C9A7),
  Color(0xFFFFC75F),
  Color(0xFFD65DB1),
  Color(0xFF0089BA),
  Color(0xFFFF6F91),
  Color(0xFF67D5B5),
  Color(0xFFFC5C65),
  Color(0xFF45AAF2),
  Color(0xFFA55EEA),
  Color(0xFF26DE81),
  Color(0xFFFD9644),
  Color(0xFF2BCBBA),
  Color(0xFFEB3B5A),
  Color(0xFF3867D6),
];

Color _paintColorForLevel(int level, int diffIndex) {
  return _kPaintPalette[(level * 7 + diffIndex * 3) % _kPaintPalette.length];
}

enum _Difficulty { easy, medium, hard }

extension _DifficultyX on _Difficulty {
  String get label => ['EASY', 'MEDIUM', 'HARD'][index];
  Color get color => [_kEasyColor, _kMediumColor, _kHardColor][index];
  DifficultyKind get kind => [DifficultyKind.easy, DifficultyKind.medium, DifficultyKind.hard][index];
  String get hint => ['Small boards · clear routes', 'Larger boards · more planning', 'Wide mazes · longer routes'][index];
  String get subKey => ['easy', 'medium', 'hard'][index];
}

class MazePaintScreen extends StatefulWidget {
  const MazePaintScreen({super.key});

  @override
  State<MazePaintScreen> createState() => _MazePaintScreenState();
}

class _MoveSnapshot {
  final int position;
  final Set<int> painted;
  _MoveSnapshot(this.position, this.painted);
}

class _MazePaintScreenState extends State<MazePaintScreen> with SingleTickerProviderStateMixin {
  _Difficulty? _activeDifficulty;
  _Difficulty _pickerDifficulty = _Difficulty.values[DifficultyKind.defaultIndex];
  bool _isFavorite = false;

  int _level = 1;
  int _moves = 0;
  int _hintsUsed = 0;
  bool _gameOver = false;
  bool _won = false;

  int _rows = 5;
  int _cols = 5;
  int _start = 0;
  int _position = 0;
  Set<int> _walls = {};
  Set<int> _painted = {};
  Color _levelColor = _kPaintPalette[0];
  List<gen.MazePaintDir> _solution = [];
  final List<gen.MazePaintDir> _movesMade = [];
  final List<_MoveSnapshot> _history = [];

  bool _animating = false;
  Offset? _swipeStart;
  Timer? _idleTimer;
  bool _idleStuck = false;
  static const _kMaxHints = 3;
  static const _kIdleTimeout = Duration(seconds: 9);
  gen.MazePaintDir? _hintDir;
  late final AnimationController _hintAnim;
  final ValueNotifier<double> _hintNotifier = ValueNotifier(0);
  OverlayEntry? _appreciationOverlay;

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(kMazePaintGameId);
    _hintAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _hintAnim.addListener(() => _hintNotifier.value = _hintAnim.value);
  }

  @override
  void dispose() {
    _appreciationOverlay?.remove();
    _idleTimer?.cancel();
    _hintAnim.dispose();
    super.dispose();
  }

  void _toggleFavorite() {
    ScoreService().toggleFavorite(kMazePaintGameId);
    setState(() => _isFavorite = !_isFavorite);
  }

  void _showHelp() {
    final info = GameRegistry.getById(kMazePaintGameId);
    if (info == null) return;
    showHowToPlaySheet(
      context,
      title: info.name,
      howToPlay: info.howToPlay,
      accent: _kAccent,
      steps: mazePaintSteps(),
      gameId: kMazePaintGameId,
    );
  }

  void _startGame(_Difficulty diff) async {
    final lps = LevelProgressService();
    _level = lps.getCurrentLevel(kMazePaintGameId, diff.subKey);

    final saved = lps.getGameState(kMazePaintGameId, diff.subKey);
    final hasSave = saved != null && saved['level'] == _level;

    bool shouldContinue = false;
    if (hasSave) {
      shouldContinue = await showContinueDialog(
        context,
        gameName: 'Maze Paint',
        accentColor: diff.color,
        level: _level,
      );
      if (!mounted) return;
    }

    _gameOver = false;
    _won = false;
    _moves = 0;
    _hintsUsed = 0;
    _generateLevel(diff);

    if (hasSave && shouldContinue) {
      _position = saved['position'] as int;
      _painted = Set<int>.from(saved['painted'] as List);
      _moves = saved['moves'] as int;
      _hintsUsed = (saved['hintsUsed'] as int?) ?? 0;
      _movesMade
        ..clear()
        ..addAll((saved['movesMade'] as List).map((i) => gen.MazePaintDir.values[i as int]));
    } else {
      if (hasSave) lps.clearGameState(kMazePaintGameId, diff.subKey);
    }

    _resetIdleTimer();
    setState(() => _activeDifficulty = diff);
    GameWrapper.of(context).setDifficultyAndMode(difficulty: diff.label, subKey: diff.subKey);
    GameWrapper.of(context).startGame();
    GameWrapper.of(context).updateScore(_level);
  }

  void _generateLevel(_Difficulty diff) {
    final level = gen.generateMazePaintLevel(_level, diff.index);
    _rows = level.rows;
    _cols = level.cols;
    _start = level.start;
    _position = level.start;
    _walls = level.walls;
    _solution = level.solution;
    _painted = {_start};
    _levelColor = _paintColorForLevel(_level, diff.index);
    _movesMade.clear();
    _history.clear();
    _hintDir = null;
    _hintAnim.stop();
  }

  Future<void> _move(gen.MazePaintDir dir) async {
    if (_gameOver || _won || _animating) return;
    final cells = gen.cellsAlongMove(rows: _rows, cols: _cols, walls: _walls, start: _position, dir: dir);
    if (cells.isEmpty) return;
    _history.add(_MoveSnapshot(_position, Set<int>.from(_painted)));
    _animating = true;
    _hintAnim.stop();
    _hintDir = null;
    _idleStuck = false;
    _moves++;
    _movesMade.add(dir);
    for (final cell in cells) {
      _painted.add(cell);
      _position = cell;
      AudioService().playTap();
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 70));
      if (!mounted || _gameOver) {
        _animating = false;
        return;
      }
    }
    _animating = false;
    _resetIdleTimer();
    _saveState();
    _checkWin();
  }

  void _restartLevel() {
    final diff = _activeDifficulty!;
    setState(() {
      _moves = 0;
      _hintsUsed = 0;
      _gameOver = false;
      _won = false;
      _position = _start;
      _painted = {_start};
      _movesMade.clear();
      _history.clear();
      _hintDir = null;
    });
    _hintAnim.stop();
    LevelProgressService().clearGameState(kMazePaintGameId, diff.subKey);
    _resetIdleTimer();
    GameWrapper.of(context).restartGame();
    GameWrapper.of(context).startGame();
    GameWrapper.of(context).updateScore(_level);
  }

  void _checkWin() {
    if (_painted.length != _rows * _cols - _walls.length) return;
    _won = true;
    final diff = _activeDifficulty!;
    final score = _moves + _hintsUsed * 3;
    final lps = LevelProgressService();
    lps.advanceLevel(kMazePaintGameId, diff.subKey);
    lps.saveLevelBest(kMazePaintGameId, diff.subKey, _level, score);
    lps.clearGameState(kMazePaintGameId, diff.subKey);
    GameWrapper.of(context).updateScore(_level);
    AudioService().playSuccess();
    _showAppreciation();
  }

  void _showAppreciation() {
    _appreciationOverlay?.remove();
    final diff = _activeDifficulty!;
    _appreciationOverlay = OverlayEntry(
      builder: (_) => LevelCompleteOverlay(
        level: _level,
        accentColor: diff.color,
        onComplete: () {
          _appreciationOverlay?.remove();
          _appreciationOverlay = null;
          if (!mounted) return;
          GameWrapper.of(context).completeLevelWithAd(onComplete: () {
            if (mounted) _nextLevel();
          });
        },
      ),
    );
    Overlay.of(context).insert(_appreciationOverlay!);
  }

  void _nextLevel() {
    final diff = _activeDifficulty!;
    _level++;
    _moves = 0;
    _hintsUsed = 0;
    _gameOver = false;
    _won = false;
    _generateLevel(diff);
    _resetIdleTimer();
    setState(() {});
    GameWrapper.of(context).restartGame();
    GameWrapper.of(context).startGame();
    GameWrapper.of(context).updateScore(_level);
  }

  void _onHint() {
    if (_gameOver || _won || _hintsUsed >= _kMaxHints) return;
    if (!AdsService().isRewardedReady) {
      _applyHint();
      return;
    }
    AdsService().showRewarded(
      rewardType: RewardType.hint,
      gameId: kMazePaintGameId,
      onRewarded: (_) {
        if (mounted) _applyHint();
      },
    );
  }

  void _applyHint() {
    final prefix = _solutionPrefixLen();
    if (prefix >= _solution.length) return;
    setState(() {
      _hintsUsed++;
      _idleStuck = false;
      _hintDir = _solution[prefix];
    });
    _hintAnim.forward(from: 0).then((_) {
      if (mounted) _hintAnim.repeat(reverse: true);
    });
    _saveState();
  }

  int _solutionPrefixLen() {
    var len = 0;
    for (int i = 0; i < _movesMade.length && i < _solution.length; i++) {
      if (_movesMade[i] == _solution[i]) {
        len = i + 1;
      } else {
        break;
      }
    }
    return len;
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (_idleStuck && mounted) setState(() => _idleStuck = false);
    _idleTimer = Timer(_kIdleTimeout, () {
      if (mounted && _activeDifficulty != null && !_won && !_gameOver) {
        setState(() => _idleStuck = true);
      }
    });
  }

  void _saveState() {
    final diff = _activeDifficulty;
    if (diff == null || _gameOver || _won) return;
    if (_moves == 0 && _hintsUsed == 0) return;
    LevelProgressService().saveGameState(kMazePaintGameId, diff.subKey, {
      'level': _level,
      'position': _position,
      'painted': _painted.toList(),
      'moves': _moves,
      'hintsUsed': _hintsUsed,
      'movesMade': _movesMade.map((d) => d.index).toList(),
    });
  }

  void _backOrHome() {
    _saveState();
    final wrapper = GameWrapper.of(context);
    wrapper.handleExit(() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_activeDifficulty == null) return _buildPicker();
    if (_gameOver && !_won) return _buildResult();
    return _buildGame();
  }

  Widget _buildPicker() {
    final diffs = _Difficulty.values
        .map((d) => GameDifficultyData(
              label: d.label,
              color: d.color,
              kind: d.kind,
              hint: d.hint,
              bestScore: LevelProgressService().getHighestLevel(kMazePaintGameId, d.subKey),
              bestLabel: (s) => s <= 0 ? '' : 'Completed: Level $s',
            ))
        .toList();
    return GamePickerScaffold(
      bgColorTop: const Color(0xFFFFF8F0),
      bgColorBottom: const Color(0xFFFFF0E6),
      animatedBg: AnimatedBackground(factory: (t) => GenericAnimatedBgPainter(t, accent: _kAccent, icon: Icons.format_paint_rounded)),
      iconRingColors: const [_kAccent, Color(0xFFE0D5CF), Color(0xFF4A3F3A)],
      iconChild: buildMazePaintLogo(60),
      title: 'Maze Paint',
      subtitle: 'Swipe, roll, and paint every tile!',
      onBack: _backOrHome,
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: _showHelp,
      gameId: kMazePaintGameId,
      body: GameSinglePickerBody(
        difficulties: diffs,
        activeIndex: _pickerDifficulty.index,
        onChanged: (i) => setState(() => _pickerDifficulty = _Difficulty.values[i]),
        playLabel: 'Play Maze Paint',
        playSubLabel: 'Level ${LevelProgressService().getCurrentLevel(kMazePaintGameId, _pickerDifficulty.subKey)}',
        onPlay: () => _startGame(_pickerDifficulty),
        accentColor: _kAccent,
      ),
    );
  }

  Widget _buildGame() {
    final diff = _activeDifficulty!;
    return Container(
      color: _kBg,
      child: SafeArea(
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) => _swipeStart = e.position,
          onPointerUp: (e) {
            final start = _swipeStart;
            _swipeStart = null;
            if (_animating || start == null) return;
            final delta = e.position - start;
            if (delta.distance < 30) return;
            if (delta.dx.abs() > delta.dy.abs()) {
              _move(delta.dx > 0 ? gen.MazePaintDir.right : gen.MazePaintDir.left);
            } else {
              _move(delta.dy > 0 ? gen.MazePaintDir.down : gen.MazePaintDir.up);
            }
          },
          child: Column(children: [
            GameHudBar(
              leading: GameBackButton(onTap: _backOrHome, bgColor: _levelColor.withValues(alpha: 0.12), iconColor: _levelColor),
              centerContent: _buildHudPill(diff),
              trailing: GameRestartButton(gameName: 'Maze Paint', accentColor: diff.color, onRestart: _restartLevel, bgColor: _levelColor.withValues(alpha: 0.12), iconColor: _levelColor),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: LayoutBuilder(builder: (_, c) => _buildBoard(c)),
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: !_gameOver && !_won && _hintsUsed < _kMaxHints ? 1.0 : 0.0,
              child: IgnorePointer(ignoring: _gameOver || _won || _hintsUsed >= _kMaxHints || _animating, child: _MazePaintHintNudge(onTap: _onHint, isStuck: _idleStuck)),
            ),
            const SizedBox(height: 12),
          ]),
        ),
      ),
    );
  }

  Widget _buildHudPill(_Difficulty diff) {
    final clr = diff.color;
    final total = _rows * _cols - _walls.length;
    final done = _painted.length;
    return IntrinsicWidth(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(color: clr, borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          boxShadow: [BoxShadow(color: clr.withValues(alpha: 0.30), blurRadius: 8, offset: const Offset(0, 3))]),
        child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedDifficultyIcon(kind: diff.kind, size: 14, prominent: false), const SizedBox(width: 6),
          Text(diff.label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
        ]),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: _kAccent.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 6))]),
        child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          _statCol('LEVEL', '$_level', clr), _pillDivider(),
          _statCol('PAINTED', '$done/$total', const Color(0xFF6B7280)),
        ]),
      ),
    ]));
  }

  Widget _statCol(String label, String value, Color c) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: c.withValues(alpha: 0.70), letterSpacing: 1.0)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: c, height: 1)),
    ]),
  );

  Widget _pillDivider() => Container(width: 1, height: 24, margin: const EdgeInsets.symmetric(horizontal: 6), color: const Color(0xFFE5E7EB));

  Widget _buildBoard(BoxConstraints c) {
    final maxSide = math.max(0.0, math.min(c.maxWidth, c.maxHeight));
    final cell = maxSide / math.max(_cols, _rows);
    final boardW = cell * _cols;
    final boardH = cell * _rows;
    return Center(
      child: SizedBox(
        key: const Key('maze_paint_board'),
        width: boardW,
        height: boardH,
        child: CustomPaint(
          size: Size(boardW, boardH),
          painter: _MazePaintBoardPainter(
            rows: _rows,
            cols: _cols,
            cell: cell,
            start: _start,
            position: _position,
            walls: _walls,
            painted: _painted,
            paintColor: _levelColor,
            hintDir: _hintDir,
            hintNotifier: _hintNotifier,
          ),
        ),
      ),
    );
  }

  Widget _buildResult() {

    final diff = _activeDifficulty!;
    return game_result.GenericGameResultScreen(
      headline: _won ? 'Level $_level Complete!' : 'Try Again',
      subtitle: _won ? 'Painted in $_moves moves' : 'Restart the level and paint every tile',
      badgeContent: _won ? '🎨' : '🧩',
      badgeColor: diff.color,
      showNewBestBadge: false,
      gameId: kMazePaintGameId,
      score: _level,
      statsWidget: game_result.GameResultStatsRow(stats: [
        game_result.StatItem(label: 'LEVEL', value: _level, color: diff.color),
        game_result.StatItem(label: 'MOVES', value: _moves, color: _kAccent),
      ]),
      actions: [
        game_result.GameResultAction(label: _won ? 'Next Level' : 'Retry Level', icon: _won ? Icons.arrow_forward_rounded : Icons.refresh_rounded, onTap: _won ? _nextLevel : _restartLevel, filled: true, color: diff.color, actionId: 'play_again'),
        game_result.GameResultAction(
          label: 'Change Difficulty',
          icon: Icons.tune_rounded,
          onTap: () {
            setState(() {
              _activeDifficulty = null;
              _gameOver = false;
            });
            GameWrapper.of(context).restartGame();
          },
          filled: false,
          actionId: 'change_mode',
        ),
        game_result.GameResultAction(label: 'Home', icon: Icons.home_rounded, onTap: () => context.go('/home'), actionId: 'home', filled: false),
      ],
    );
  }

  @visibleForTesting
  List<gen.MazePaintDir> get solutionForTest => List.unmodifiable(_solution);
  @visibleForTesting
  int get paintedCountForTest => _painted.length;
  @visibleForTesting
  int get paintableCountForTest => _rows * _cols - _walls.length;
  @visibleForTesting
  int get movesForTest => _moves;
  @visibleForTesting
  bool get wonForTest => _won;
  @visibleForTesting
  void configureForTest({int level = 1, int difficulty = 0}) {
    _activeDifficulty = _Difficulty.values[difficulty];
    _level = level;
    _generateLevel(_activeDifficulty!);
  }
  @visibleForTesting
  void moveForTest(gen.MazePaintDir dir) => _move(dir);
}

class _MazePaintBoardPainter extends CustomPainter {
  final int rows;
  final int cols;
  final double cell;
  final int start;
  final int position;
  final Set<int> walls;
  final Set<int> painted;
  final Color paintColor;
  final gen.MazePaintDir? hintDir;
  final ValueNotifier<double>? hintNotifier;

  _MazePaintBoardPainter({
    required this.rows,
    required this.cols,
    required this.cell,
    required this.start,
    required this.position,
    required this.walls,
    required this.painted,
    required this.paintColor,
    required this.hintDir,
    required this.hintNotifier,
  }) : super(repaint: hintNotifier);

  static const _floorColor = Color(0xFF4F5B6E);
  static const _floorLight = Color(0xFF5E6B80);
  static const _floorDark = Color(0xFF3E4A5A);
  static const _startTint = Color(0xFF22D3EE);

  Offset _center(int i) => Offset((i % cols) * cell + cell / 2, (i ~/ cols) * cell + cell / 2);

  bool _isFilled(int r, int c, bool Function(int) test) {
    if (r < 0 || r >= rows || c < 0 || c >= cols) return false;
    final idx = r * cols + c;
    return !walls.contains(idx) && test(idx);
  }

  /// Build a contour path for the region defined by [test], with rounded
  /// convex corners and sharp concave corners.  Works by collecting every
  /// boundary edge between a filled cell and a non-filled neighbor, then
  /// tracing closed loops from those edges and rounding the convex turns.
  Path _buildContour(bool Function(int) test, double inset) {
    // Boundary edges stored as (startVertex, endVertex) in clockwise order.
    // Vertices are grid-corner indices: vertex(r,c) = r*(cols+1)+c, range
    // 0..(rows)*(cols+1)-1+(cols).  r in [0..rows], c in [0..cols].
    final vCols = cols + 1;
    int vid(int r, int c) => r * vCols + c;

    // Collect directed boundary edges (clockwise around filled region).
    final edges = <int, int>{}; // startVertex -> endVertex
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (!_isFilled(r, c, test)) continue;
        // top edge: if cell above is not filled
        if (!_isFilled(r - 1, c, test)) {
          edges[vid(r, c)] = vid(r, c + 1); // left→right
        }
        // right edge
        if (!_isFilled(r, c + 1, test)) {
          edges[vid(r, c + 1)] = vid(r + 1, c + 1); // top→bottom
        }
        // bottom edge
        if (!_isFilled(r + 1, c, test)) {
          edges[vid(r + 1, c + 1)] = vid(r + 1, c); // right→left
        }
        // left edge
        if (!_isFilled(r, c - 1, test)) {
          edges[vid(r + 1, c)] = vid(r, c); // bottom→top
        }
      }
    }

    Offset vtx(int v) {
      final vr = v ~/ vCols, vc = v % vCols;
      return Offset(vc * cell, vr * cell);
    }

    final rad = cell * 0.22;
    final path = Path();
    final visited = <int>{};

    while (visited.length < edges.length) {
      // Find an unvisited start edge.
      int? startV;
      for (final k in edges.keys) {
        if (!visited.contains(k)) { startV = k; break; }
      }
      if (startV == null) break;

      // Trace the loop and collect vertices.
      final loop = <int>[];
      int cur = startV;
      do {
        loop.add(cur);
        visited.add(cur);
        cur = edges[cur]!;
      } while (cur != startV);

      if (loop.length < 3) continue;

      final n = loop.length;

      Offset insetVtx(int v) {
        final vr = v ~/ vCols, vc = v % vCols;
        double x = vc * cell, y = vr * cell;
        final tl = _isFilled(vr - 1, vc - 1, test);
        final tr = _isFilled(vr - 1, vc, test);
        final bl = _isFilled(vr, vc - 1, test);
        final br = _isFilled(vr, vc, test);
        final filledCount = (tl ? 1 : 0) + (tr ? 1 : 0) + (bl ? 1 : 0) + (br ? 1 : 0);
        if (filledCount == 1) {
          if (br) { x += inset; y += inset; }
          else if (bl) { x -= inset; y += inset; }
          else if (tr) { x += inset; y -= inset; }
          else { x -= inset; y -= inset; }
        } else if (filledCount == 3) {
          if (!br) { x -= inset; y -= inset; }
          else if (!bl) { x += inset; y -= inset; }
          else if (!tr) { x -= inset; y += inset; }
          else { x += inset; y += inset; }
        } else {
          if (!tl && !tr) { y += inset; }
          else if (!bl && !br) { y -= inset; }
          else if (!tl && !bl) { x += inset; }
          else if (!tr && !br) { x -= inset; }
        }
        return Offset(x, y);
      }

      // Round ALL corners with quadratic Bézier arcs.
      for (int i = 0; i < n; i++) {
        final prev = insetVtx(loop[(i - 1 + n) % n]);
        final curr = insetVtx(loop[i]);
        final next = insetVtx(loop[(i + 1) % n]);
        final d1 = Offset(curr.dx - prev.dx, curr.dy - prev.dy);
        final d2 = Offset(next.dx - curr.dx, next.dy - curr.dy);
        final len1 = d1.distance, len2 = d2.distance;
        final t1 = (len1 > 0) ? math.min(rad, len1 / 2) / len1 : 0.0;
        final t2 = (len2 > 0) ? math.min(rad, len2 / 2) / len2 : 0.0;
        final arcStart = Offset(curr.dx - d1.dx * t1, curr.dy - d1.dy * t1);
        final arcEnd = Offset(curr.dx + d2.dx * t2, curr.dy + d2.dy * t2);
        if (i == 0) {
          path.moveTo(arcStart.dx, arcStart.dy);
        } else {
          path.lineTo(arcStart.dx, arcStart.dy);
        }
        path.quadraticBezierTo(curr.dx, curr.dy, arcEnd.dx, arcEnd.dy);
      }
      path.close();
    }

    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final inset = cell * 0.08;

    final floorPath = _buildContour((_) => true, inset);
    final bounds = floorPath.getBounds();

    canvas.drawPath(
      floorPath.shift(Offset(0, cell * 0.12)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.12),
    );

    canvas.drawPath(
      floorPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(bounds.left, bounds.top),
          Offset(bounds.left, bounds.bottom),
          [_floorLight, _floorColor, _floorDark],
          [0.0, 0.4, 1.0],
        ),
    );

    canvas.save();
    canvas.clipPath(floorPath);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(bounds.left, bounds.top),
          Offset(bounds.left, bounds.bottom),
          [Colors.white.withValues(alpha: 0.08), Colors.transparent, Colors.black.withValues(alpha: 0.10)],
          [0.0, 0.45, 1.0],
        ),
    );
    canvas.restore();

    if (painted.isNotEmpty) {
      final paintPath = _buildContour(painted.contains, inset);
      final paintBounds = paintPath.getBounds();
      final paintLight = Color.lerp(paintColor, Colors.white, 0.15)!;
      final paintDark = Color.lerp(paintColor, Colors.black, 0.12)!;

      canvas.drawPath(
        paintPath,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(paintBounds.left, paintBounds.top),
            Offset(paintBounds.left, paintBounds.bottom),
            [paintLight, paintColor, paintDark],
            [0.0, 0.4, 1.0],
          ),
      );

      canvas.save();
      canvas.clipPath(paintPath);
      canvas.drawRect(
        paintBounds,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(paintBounds.left, paintBounds.top),
            Offset(paintBounds.left, paintBounds.bottom),
            [Colors.white.withValues(alpha: 0.12), Colors.transparent, Colors.black.withValues(alpha: 0.08)],
            [0.0, 0.45, 1.0],
          ),
      );
      canvas.restore();
    }

    final sr = start ~/ cols, sc = start % cols;
    final startRect = Rect.fromLTWH(sc * cell + inset, sr * cell + inset, cell - 2 * inset, cell - 2 * inset);
    canvas.drawRRect(
      RRect.fromRectAndRadius(startRect, Radius.circular(cell * 0.18)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, cell * 0.05)
        ..color = _startTint.withValues(alpha: 0.85),
    );

    if (hintDir != null) _drawHint(canvas);
    _drawBall(canvas, _center(position));
  }

  void _drawHint(Canvas canvas) {
    final t = hintNotifier?.value ?? 0.0;
    final c = _center(position);
    final pulse = math.sin(t * math.pi * 2) * cell * 0.08;
    final delta = switch (hintDir!) {
      gen.MazePaintDir.up => Offset(0, -cell * 0.40 - pulse),
      gen.MazePaintDir.right => Offset(cell * 0.40 + pulse, 0),
      gen.MazePaintDir.down => Offset(0, cell * 0.40 + pulse),
      gen.MazePaintDir.left => Offset(-cell * 0.40 - pulse, 0),
    };
    final end = c + delta;
    canvas.drawLine(c, end, Paint()..color = const Color(0xFFFFA726)..strokeWidth = math.max(3, cell * 0.09)..strokeCap = StrokeCap.round);
    final arrowSize = cell * 0.14;
    final angle = math.atan2(delta.dy, delta.dx);
    final a1 = end + Offset(math.cos(angle + 2.6) * arrowSize, math.sin(angle + 2.6) * arrowSize);
    final a2 = end + Offset(math.cos(angle - 2.6) * arrowSize, math.sin(angle - 2.6) * arrowSize);
    canvas.drawPath(Path()..moveTo(end.dx, end.dy)..lineTo(a1.dx, a1.dy)..lineTo(a2.dx, a2.dy)..close(), Paint()..color = const Color(0xFFFFA726));
  }

  void _drawBall(Canvas canvas, Offset c) {
    final radius = cell * 0.36;

    canvas.drawOval(
      Rect.fromCenter(center: c.translate(1, radius * 0.4), width: radius * 1.7, height: radius * 0.5),
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
        ..color = Colors.black.withValues(alpha: 0.20),
    );

    canvas.drawCircle(
      c, radius,
      Paint()
        ..shader = ui.Gradient.radial(
          c.translate(-radius * 0.20, -radius * 0.25),
          radius * 2.0,
          const [Color(0xFFFFFFFF), Color(0xFFF0F0F0), Color(0xFFD0D0D0), Color(0xFFAAAAAA)],
          const [0.0, 0.3, 0.65, 1.0],
        ),
    );

    canvas.drawCircle(
      c, radius,
      Paint()
        ..shader = ui.Gradient.radial(
          c.translate(-radius * 0.30, -radius * 0.35),
          radius * 0.75,
          [Colors.white.withValues(alpha: 0.7), Colors.white.withValues(alpha: 0.0)],
        ),
    );

    canvas.drawCircle(c.translate(-radius * 0.22, -radius * 0.22), radius * 0.13, Paint()..color = Colors.white);
    canvas.drawCircle(c.translate(-radius * 0.08, -radius * 0.34), radius * 0.05, Paint()..color = Colors.white.withValues(alpha: 0.7));
  }

  @override
  bool shouldRepaint(_MazePaintBoardPainter old) => true;
}

class _MazePaintHintNudge extends StatelessWidget {
  final VoidCallback onTap;
  final bool isStuck;
  const _MazePaintHintNudge({required this.onTap, required this.isStuck});
  static const _kBg = Color(0xFFFFD43B);
  static const _kFg = Color(0xFF5C4600);

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 4), child: Stack(alignment: Alignment.bottomCenter, clipBehavior: Clip.none, children: [
      GestureDetector(onTap: onTap, child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE6BE00), width: 1.5),
          boxShadow: [BoxShadow(color: _kBg.withValues(alpha: 0.30), blurRadius: 12, offset: const Offset(0, 3))]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lightbulb_rounded, size: 16, color: _kFg), const SizedBox(width: 6),
          const Text('HINT', style: TextStyle(color: _kFg, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.0, height: 1)),
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(color: _kFg.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.play_arrow_rounded, size: 12, color: _kFg), SizedBox(width: 2),
              Text('AD', style: TextStyle(color: _kFg, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8, height: 1)),
            ])),
        ]),
      )),
      if (isStuck) Positioned(bottom: 40, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: const Color(0xFF7C3AED), borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2))]),
          child: const Text('Stuck? Try a hint!', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3))),
        CustomPaint(size: const Size(14, 7), painter: _BubbleTailPainter()),
      ])),
    ]));
  }
}

class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(Path()..moveTo(0, 0)..lineTo(size.width / 2, size.height)..lineTo(size.width, 0)..close(),
      Paint()..color = const Color(0xFF7C3AED));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

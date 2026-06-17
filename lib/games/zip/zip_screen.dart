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
import '../game_registry.dart';
import '../game_wrapper.dart';
import '../game_picker_scaffold.dart';
import '../shared/animated_background.dart';
import '../shared/animated_difficulty_icon.dart';
import '../shared/game_control_buttons.dart';
import '../shared/game_difficulty_picker.dart';
import '../shared/game_hud_bar.dart';
import '../shared/generic_game_result_screen.dart' as game_result;
import '../shared/level_complete_overlay.dart';
import 'zip_logo.dart';
import 'zip_tutorial.dart';

const kZipGameId = 'zip';

const _kAccent = Color(0xFF16A34A);
const _kEasyColor = Color(0xFF22C55E);
const _kMediumColor = Color(0xFFF59E0B);
const _kHardColor = Color(0xFFEF4444);

enum _Difficulty { easy, medium, hard }

extension _DifficultyX on _Difficulty {
  String get label => ['EASY', 'MEDIUM', 'HARD'][index];
  Color get color => [_kEasyColor, _kMediumColor, _kHardColor][index];
  DifficultyKind get kind =>
      [DifficultyKind.easy, DifficultyKind.medium, DifficultyKind.hard][index];
  String get hint =>
      ['Small grids · few walls', 'Medium grids · more walls', 'Large grids · many walls'][index];
  String get subKey => ['easy', 'medium', 'hard'][index];
}

class ZipScreen extends StatefulWidget {
  const ZipScreen({super.key});

  @override
  State<ZipScreen> createState() => _ZipScreenState();
}

class _ZipScreenState extends State<ZipScreen> with SingleTickerProviderStateMixin {
  _Difficulty? _activeDifficulty;
  _Difficulty _pickerDifficulty = _Difficulty.values[DifficultyKind.defaultIndex];
  bool _isFavorite = false;

  int _level = 1;
  int _moves = 0;
  bool _gameOver = false;
  bool _won = false;

  int _gridSize = 5;
  List<int> _solutionPath = [];
  Map<int, int> _checkpoints = {};
  Set<String> _walls = {};
  List<int> _playerPath = [];
  bool _isDragging = false;
  Color _levelAccent = const Color(0xFF22C55E);
  Color _levelLight = const Color(0xFFDCFCE7);
  Color _levelDark = const Color(0xFF166534);
  Color _pathStart = const Color(0xFF22C55E);
  Color _pathEnd = const Color(0xFF16A34A);
  Color _boardBg = const Color(0xFFF0FDF4);
  Color _boardBorder = const Color(0xFFBBF7D0);

  int _hintsUsed = 0;
  static const _kMaxHints = 3;
  Timer? _idleTimer;
  bool _idleStuck = false;
  static const _kIdleTimeout = Duration(seconds: 8);
  int? _hintCell;
  int? _hintFromCell;
  late final AnimationController _hintAnim;
  final ValueNotifier<double> _hintNotifier = ValueNotifier(0);

  OverlayEntry? _appreciationOverlay;

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(kZipGameId);
    _hintAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _hintAnim.addListener(() => _hintNotifier.value = _hintAnim.value);
  }

  @override
  void dispose() {
    _appreciationOverlay?.remove();
    _appreciationOverlay = null;
    _idleTimer?.cancel();
    _hintAnim.dispose();
    super.dispose();
  }

  void _toggleFavorite() {
    ScoreService().toggleFavorite(kZipGameId);
    setState(() => _isFavorite = !_isFavorite);
  }

  void _showHelp() {
    final info = GameRegistry.getById(kZipGameId);
    if (info == null) return;
    showHowToPlaySheet(context,
        title: info.name,
        howToPlay: info.howToPlay,
        accent: _kAccent,
        steps: zipSteps(),
        gameId: kZipGameId);
  }

  int _gridSizeForLevel(int level, _Difficulty diff) {
    switch (diff) {
      case _Difficulty.easy:
        if (level <= 8) return 5;
        if (level <= 20) return 6;
        return 7;
      case _Difficulty.medium:
        if (level <= 6) return 6;
        if (level <= 15) return 7;
        return 8;
      case _Difficulty.hard:
        if (level <= 5) return 7;
        if (level <= 12) return 8;
        return 9;
    }
  }

  int _cpCount(int n, int level, _Difficulty diff) {
    final total = n * n;
    final raw = switch (diff) {
      _Difficulty.easy => 3 + math.min(level ~/ 4, 4),
      _Difficulty.medium => 4 + math.min(level ~/ 3, 6),
      _Difficulty.hard => 5 + math.min(level ~/ 2, 8),
    };
    return raw.clamp(2, total ~/ 3).toInt();
  }

  int _wallCount(int n, int level, _Difficulty diff) {
    final maxW = (2 * n * (n - 1)) ~/ 4;
    final raw = switch (diff) {
      _Difficulty.easy => math.min(level ~/ 3, 4),
      _Difficulty.medium => 2 + math.min(level ~/ 2, 10),
      _Difficulty.hard => 4 + math.min(level, 18),
    };
    return raw.clamp(0, maxW).toInt();
  }

  void _startGame(_Difficulty diff) {
    final lps = LevelProgressService();
    _level = lps.getCurrentLevel(kZipGameId, diff.subKey);
    _gameOver = false;
    _won = false;
    _moves = 0;
    _gridSize = _gridSizeForLevel(_level, diff);
    _hintsUsed = 0;
    _hintCell = null;
    _generateLevel(diff);
    _resetIdleTimer();
    setState(() => _activeDifficulty = diff);
    GameWrapper.of(context)
        .setDifficultyAndMode(difficulty: diff.label, subKey: diff.subKey);
    GameWrapper.of(context).startGame();
    GameWrapper.of(context).updateScore(_level);
  }

  void _generateLevel(_Difficulty diff) {
    final rng = math.Random(_level * 7919 + diff.index * 6271);
    final n = _gridSize;
    final total = n * n;

    List<int>? path;
    for (int attempt = 0; attempt < 100; attempt++) {
      path = _findHamiltonianPath(n, math.Random(rng.nextInt(1 << 30)));
      if (path != null && path.length == total) break;
      path = null;
    }
    path ??= _generateSnakePath(n);
    _solutionPath = path;

    final pathEdges = <String>{};
    for (int i = 0; i < path.length - 1; i++) {
      pathEdges.add(_edgeKey(path[i], path[i + 1]));
    }

    final numWalls = _wallCount(n, _level, diff);
    final candidates = <String>[];
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        final idx = r * n + c;
        if (c < n - 1) {
          final k = _edgeKey(idx, idx + 1);
          if (!pathEdges.contains(k)) candidates.add(k);
        }
        if (r < n - 1) {
          final k = _edgeKey(idx, idx + n);
          if (!pathEdges.contains(k)) candidates.add(k);
        }
      }
    }
    candidates.shuffle(rng);
    _walls = candidates.take(numWalls).toSet();

    final numCp = _cpCount(n, _level, diff);
    _checkpoints = {};
    for (int i = 0; i < numCp; i++) {
      final pathIdx =
          numCp == 1 ? 0 : (i * (total - 1) / (numCp - 1)).round();
      _checkpoints[pathIdx] = i + 1;
    }

    final hue = math.Random().nextDouble() * 360;
    _levelAccent = HSLColor.fromAHSL(1, hue, 0.70, 0.45).toColor();
    _pathStart = HSLColor.fromAHSL(1, hue, 0.72, 0.42).toColor();
    _pathEnd = HSLColor.fromAHSL(1, hue, 0.68, 0.50).toColor();
    _levelLight = HSLColor.fromAHSL(1, hue, 0.55, 0.92).toColor();
    _levelDark = HSLColor.fromAHSL(1, hue, 0.50, 0.25).toColor();
    _boardBg = HSLColor.fromAHSL(1, hue, 0.40, 0.97).toColor();
    _boardBorder = HSLColor.fromAHSL(1, hue, 0.45, 0.85).toColor();
    _playerPath = [];
  }

  String _edgeKey(int a, int b) {
    final lo = math.min(a, b), hi = math.max(a, b);
    return '$lo:$hi';
  }

  bool _hasWall(int a, int b) => _walls.contains(_edgeKey(a, b));

  List<int>? _findHamiltonianPath(int n, math.Random rng) {
    final total = n * n;
    final visited = List.filled(total, false);
    final path = <int>[];
    final start = rng.nextInt(total);
    visited[start] = true;
    path.add(start);
    while (path.length < total) {
      final cur = path.last;
      final nbs = _getNeighbors(cur, n)..shuffle(rng);
      int best = -1, bestDeg = 999;
      for (final nb in nbs) {
        if (visited[nb]) continue;
        final deg = _unvisitedDeg(nb, visited, n);
        if (deg < bestDeg) {
          bestDeg = deg;
          best = nb;
        }
      }
      if (best == -1) return null;
      visited[best] = true;
      path.add(best);
    }
    return path;
  }

  List<int> _getNeighbors(int idx, int n) {
    final r = idx ~/ n, c = idx % n;
    final res = <int>[];
    if (r > 0) res.add((r - 1) * n + c);
    if (r < n - 1) res.add((r + 1) * n + c);
    if (c > 0) res.add(r * n + c - 1);
    if (c < n - 1) res.add(r * n + c + 1);
    return res;
  }

  int _unvisitedDeg(int idx, List<bool> visited, int n) {
    int c = 0;
    for (final nb in _getNeighbors(idx, n)) {
      if (!visited[nb]) c++;
    }
    return c;
  }

  List<int> _generateSnakePath(int n) {
    final p = <int>[];
    for (int r = 0; r < n; r++) {
      if (r.isEven) {
        for (int c = 0; c < n; c++) p.add(r * n + c);
      } else {
        for (int c = n - 1; c >= 0; c--) p.add(r * n + c);
      }
    }
    return p;
  }

  int _cellIdx(int row, int col) => row * _gridSize + col;

  int? _solIdx(int cellIdx) {
    final i = _solutionPath.indexOf(cellIdx);
    return i >= 0 ? i : null;
  }

  bool _adj(int a, int b) {
    final n = _gridSize;
    final r1 = a ~/ n, c1 = a % n, r2 = b ~/ n, c2 = b % n;
    return (r1 == r2 && (c1 - c2).abs() == 1) ||
        (c1 == c2 && (r1 - r2).abs() == 1);
  }

  bool _canAdd(int row, int col) {
    if (_gameOver || _won) return false;
    final ci = _cellIdx(row, col);
    if (_playerPath.contains(ci)) return false;
    if (_playerPath.isEmpty) {
      final si = _solIdx(ci);
      if (si == null) return false;
      if (_checkpoints.containsKey(si) && _checkpoints[si] == 1) return true;
      return !_checkpoints.containsKey(0);
    }
    final last = _playerPath.last;
    if (!_adj(last, ci)) return false;
    if (_hasWall(last, ci)) return false;
    final si = _solIdx(ci);
    if (si != null && _checkpoints.containsKey(si)) {
      if (_checkpoints[si] != _nextCp()) return false;
    }
    return true;
  }

  int _nextCp() {
    int mx = 0;
    for (final ci in _playerPath) {
      final si = _solIdx(ci);
      if (si != null && _checkpoints.containsKey(si)) {
        final cp = _checkpoints[si]!;
        if (cp > mx) mx = cp;
      }
    }
    return mx + 1;
  }

  void _addCell(int row, int col) {
    if (!_canAdd(row, col)) return;
    setState(() {
      _playerPath.add(_cellIdx(row, col));
      _moves++;
    });
    AudioService().playTap();
    _hintCell = null;
    _hintFromCell = null;
    _hintAnim.stop();
    _resetIdleTimer();
    _checkWin();
  }

  void _backtrack(int row, int col) {
    final ci = _cellIdx(row, col);
    final idx = _playerPath.indexOf(ci);
    if (idx < 0 || idx >= _playerPath.length - 1) return;
    setState(() => _playerPath.removeRange(idx + 1, _playerPath.length));
    _hintCell = null;
    _hintFromCell = null;
    _hintAnim.stop();
    _resetIdleTimer();
  }

  void _checkWin() {
    if (_playerPath.length != _gridSize * _gridSize) return;
    final ok = _checkpoints.entries.every(
        (e) => _playerPath.contains(_solutionPath[e.key]));
    if (!ok) return;
    final sorted = _checkpoints.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    int prev = -1;
    for (final cp in sorted) {
      final pi = _playerPath.indexOf(_solutionPath[cp.key]);
      if (pi <= prev) return;
      prev = pi;
    }
    _won = true;
    _endGame(true);
  }

  void _endGame(bool won) {
    _won = won;
    if (won) {
      final diff = _activeDifficulty!;
      final lps = LevelProgressService();
      lps.advanceLevel(kZipGameId, diff.subKey);
      lps.saveLevelBest(kZipGameId, diff.subKey, _level, _moves);
      GameWrapper.of(context).updateScore(_level);
      AudioService().playScore();
      _showAppreciation();
      return;
    }
    _gameOver = true;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) GameWrapper.of(context).endGame(result: 'loss');
    });
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
          GameWrapper.of(context).completeLevelWithAd(
            onComplete: () {
              if (mounted) _nextLevel();
            },
          );
        },
      ),
    );
    Overlay.of(context).insert(_appreciationOverlay!);
  }

  void _nextLevel() {
    final diff = _activeDifficulty!;
    _level++;
    _moves = 0;
    _gameOver = false;
    _won = false;
    _playerPath = [];
    _hintCell = null;
    _hintFromCell = null;
    _hintsUsed = 0;
    _hintAnim.stop();
    _gridSize = _gridSizeForLevel(_level, diff);
    _generateLevel(diff);
    _resetIdleTimer();
    setState(() {});
    GameWrapper.of(context).restartGame();
    GameWrapper.of(context).startGame();
    GameWrapper.of(context).updateScore(_level);
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (_idleStuck) setState(() => _idleStuck = false);
    _idleTimer = Timer(_kIdleTimeout, () {
      if (mounted && _activeDifficulty != null && !_gameOver && !_won) {
        setState(() => _idleStuck = true);
      }
    });
  }

  int _solutionPrefixLen() {
    int len = 0;
    for (int i = 0; i < _playerPath.length && i < _solutionPath.length; i++) {
      if (_playerPath[i] == _solutionPath[i]) {
        len = i + 1;
      } else {
        break;
      }
    }
    return len;
  }

  void _onHint() {
    if (_gameOver || _won) return;
    if (_hintsUsed >= _kMaxHints) return;
    if (!AdsService().isRewardedReady) {
      _applyHint();
      return;
    }
    AdsService().showRewarded(
      rewardType: RewardType.hint,
      gameId: kZipGameId,
      onRewarded: (type) {
        if (!mounted) return;
        _applyHint();
      },
    );
  }

  void _applyHint() {
    _hintsUsed++;
    _idleStuck = false;
    _resetIdleTimer();

    int prefixLen = _solutionPrefixLen();
    if (prefixLen < _playerPath.length) {
      _playerPath.removeRange(prefixLen, _playerPath.length);
    }

    if (prefixLen >= _solutionPath.length) return;
    final nextCell = _solutionPath[prefixLen];
    final from = _playerPath.isNotEmpty ? _playerPath.last : null;
    setState(() {
      _hintCell = nextCell;
      _hintFromCell = from;
    });
    _hintAnim.stop();
    _hintAnim.value = 0;
    _hintAnim.repeat();
  }

  void _restartLevel() {
    setState(() {
      _moves = 0;
      _gameOver = false;
      _won = false;
      _playerPath = [];
      _hintCell = null;
      _hintFromCell = null;
    });
    _hintAnim.stop();
    _resetIdleTimer();
    GameWrapper.of(context).restartGame();
    GameWrapper.of(context).startGame();
    GameWrapper.of(context).updateScore(_level);
  }

  void _backOrHome() {
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
              bestScore:
                  LevelProgressService().getHighestLevel(kZipGameId, d.subKey),
              bestLabel: (s) => s <= 0 ? '' : 'Completed: Level $s',
            ))
        .toList();

    return GamePickerScaffold(
      bgColorTop: const Color(0xFFDCFCE7),
      bgColorBottom: const Color(0xFFBBF7D0),
      animatedBg: AnimatedBackground(
        factory: (t) =>
            GenericAnimatedBgPainter(t, accent: _kAccent, icon: Icons.route_rounded),
      ),
      iconRingColors: const [_kAccent, Color(0xFF22C55E), Color(0xFF166534)],
      iconChild: buildZipLogo(60),
      title: 'Zip',
      subtitle: 'Draw a path through every cell!',
      onBack: _backOrHome,
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: _showHelp,
      gameId: kZipGameId,
      body: GameSinglePickerBody(
        difficulties: diffs,
        activeIndex: _pickerDifficulty.index,
        onChanged: (i) => setState(() => _pickerDifficulty = _Difficulty.values[i]),
        playLabel: 'Play Zip',
        playSubLabel:
            'Level ${LevelProgressService().getCurrentLevel(kZipGameId, _pickerDifficulty.subKey)}',
        onPlay: () => _startGame(_pickerDifficulty),
        accentColor: _kAccent,
      ),
    );
  }

  Widget _buildGame() {
    final diff = _activeDifficulty!;
    return Container(
      color: _boardBg,
      child: SafeArea(
        child: Column(
          children: [
            GameHudBar(
              leading: GameBackButton(
                onTap: _backOrHome,
                bgColor: _levelLight,
                iconColor: _levelDark,
              ),
              centerContent: _buildHud(diff),
              trailing: GameRestartButton(
                gameName: 'Zip',
                accentColor: diff.color,
                onRestart: _restartLevel,
                bgColor: _levelLight,
                iconColor: _levelDark,
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: LayoutBuilder(builder: (_, c) => _buildGrid(c)),
                ),
              ),
            ),
            Opacity(
              opacity: !_gameOver && !_won && _hintsUsed < _kMaxHints ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: _gameOver || _won || _hintsUsed >= _kMaxHints,
                child: _ZipHintNudge(onTap: _onHint, isStuck: _idleStuck),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildHud(_Difficulty diff) {
    final clr = diff.color;
    return IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(
              color: clr,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              boxShadow: [BoxShadow(color: clr.withValues(alpha: 0.30), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedDifficultyIcon(kind: diff.kind, size: 14, prominent: false),
                const SizedBox(width: 6),
                Text(diff.label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: _levelAccent.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 6))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _statCol('LEVEL', '$_level', clr),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCol(String label, String value, Color c) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: c.withValues(alpha: 0.70), letterSpacing: 1.0)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: c, height: 1)),
        ]),
      );

  Widget _buildGrid(BoxConstraints con) {
    final maxSz = math.min(con.maxWidth, con.maxHeight - 16);
    const pad = 6.0;
    final gap = 3.0;
    final cellSz = (maxSz - 2 * pad - (_gridSize - 1) * gap) / _gridSize;
    final gridSz = cellSz * _gridSize + gap * (_gridSize - 1);

    return GestureDetector(
      onPanStart: (d) => _onPan(d.localPosition, cellSz, gap, gridSz, true),
      onPanUpdate: (d) => _onPan(d.localPosition, cellSz, gap, gridSz, false),
      onPanEnd: (_) => _isDragging = false,
      child: Container(
        width: gridSz + 2 * pad,
        height: gridSz + 2 * pad,
        padding: const EdgeInsets.all(pad),
        decoration: BoxDecoration(
          color: _boardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _boardBorder, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: CustomPaint(
          painter: _ZipGridPainter(
            gridSize: _gridSize,
            cellSize: cellSz,
            gap: gap,
            solutionPath: _solutionPath,
            checkpoints: _checkpoints,
            walls: _walls,
            playerPath: _playerPath,
            cellBgColor: _levelLight,
            pathStartColor: _pathStart,
            pathEndColor: _pathEnd,
            hintCell: _hintCell,
            hintFromCell: _hintFromCell,
            hintNotifier: _hintNotifier,
          ),
          size: Size(gridSz, gridSz),
        ),
      ),
    );
  }

  (int, int)? _hit(Offset pos, double cs, double gap, double gs) {
    const pad = 6.0;
    final p = Offset(pos.dx - pad, pos.dy - pad);
    if (p.dx < 0 || p.dy < 0 || p.dx > gs || p.dy > gs) return null;
    final col = (p.dx / (cs + gap)).floor().clamp(0, _gridSize - 1);
    final row = (p.dy / (cs + gap)).floor().clamp(0, _gridSize - 1);
    final cx = col * (cs + gap) + cs / 2;
    final cy = row * (cs + gap) + cs / 2;
    if (math.sqrt(math.pow(p.dx - cx, 2) + math.pow(p.dy - cy, 2)) > cs * 0.8) {
      return null;
    }
    return (row, col);
  }

  void _onPan(Offset pos, double cs, double gap, double gs, bool isStart) {
    if (_gameOver || _won) return;
    if (isStart) _isDragging = true;
    if (!_isDragging) return;
    final h = _hit(pos, cs, gap, gs);
    if (h == null) return;
    final (row, col) = h;
    final ci = _cellIdx(row, col);
    if (_playerPath.isNotEmpty && _playerPath.last == ci) return;
    if (_playerPath.length >= 2 && _playerPath[_playerPath.length - 2] == ci) {
      setState(() => _playerPath.removeLast());
      return;
    }
    if (_playerPath.contains(ci)) {
      if (isStart) _backtrack(row, col);
      return;
    }
    if (_playerPath.isEmpty || _canAdd(row, col)) _addCell(row, col);
  }

  Widget _buildResult() {
    final diff = _activeDifficulty!;
    return game_result.GenericGameResultScreen(
      headline: _won ? 'Level $_level Complete!' : 'Stuck!',
      subtitle: _won ? '$_moves moves' : 'Try again or restart',
      badgeContent: _won ? '⚡' : '😔',
      badgeColor: diff.color,
      showNewBestBadge: false,
      gameId: kZipGameId,
      score: _level,
      statsWidget: game_result.GameResultStatsRow(stats: [
        game_result.StatItem(label: 'LEVEL', value: _level, color: diff.color),
        game_result.StatItem(label: 'MOVES', value: _moves, color: const Color(0xFF6B7280)),
      ]),
      actions: [
        if (_won)
          game_result.GameResultAction(label: 'Next Level', icon: Icons.arrow_forward_rounded, onTap: _nextLevel, filled: true, color: diff.color, actionId: 'play_again')
        else
          game_result.GameResultAction(label: 'Retry Level', icon: Icons.refresh_rounded, onTap: _restartLevel, filled: true, color: diff.color, actionId: 'play_again'),
        game_result.GameResultAction(
          label: 'Change Difficulty',
          icon: Icons.tune_rounded,
          onTap: () {
            setState(() { _activeDifficulty = null; _gameOver = false; });
            GameWrapper.of(context).restartGame();
          },
          filled: false,
          actionId: 'change_mode',
        ),
        game_result.GameResultAction(label: 'Home', icon: Icons.home_rounded, onTap: () => context.go('/home'), actionId: 'home', filled: false),
      ],
    );
  }
}

class _ZipGridPainter extends CustomPainter {
  final int gridSize;
  final double cellSize;
  final double gap;
  final List<int> solutionPath;
  final Map<int, int> checkpoints;
  final Set<String> walls;
  final List<int> playerPath;
  final Color cellBgColor;
  final Color pathStartColor;
  final Color pathEndColor;
  final int? hintCell;
  final int? hintFromCell;
  final ValueNotifier<double>? hintNotifier;

  _ZipGridPainter({
    required this.gridSize,
    required this.cellSize,
    required this.gap,
    required this.solutionPath,
    required this.checkpoints,
    required this.walls,
    required this.playerPath,
    required this.cellBgColor,
    required this.pathStartColor,
    required this.pathEndColor,
    this.hintCell,
    this.hintFromCell,
    this.hintNotifier,
  }) : super(repaint: hintNotifier);

  @override
  void paint(Canvas canvas, Size size) {
    final n = gridSize;
    final total = playerPath.length;
    final posMap = <int, int>{};
    for (int i = 0; i < total; i++) {
      posMap[playerPath[i]] = i;
    }

    final gridRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final outerRR = RRect.fromRectAndRadius(gridRect, Radius.circular(math.min(14, cellSize * 0.25)));
    canvas.save();
    canvas.clipRRect(outerRR);

    canvas.drawRect(gridRect, Paint()..color = const Color(0xFFD1D5DB));

    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        final x = c * (cellSize + gap);
        final y = r * (cellSize + gap);
        final ci = r * n + c;
        final rect = Rect.fromLTWH(x, y, cellSize, cellSize);
        if (posMap.containsKey(ci)) {
          canvas.drawRect(rect, Paint()..color = cellBgColor);
        } else {
          canvas.drawRect(rect, Paint()..color = const Color(0xFFF3F4F6));
        }
      }
    }

    final lineR = cellSize * 0.33;
    if (playerPath.length == 1) {
      final ci = playerPath[0];
      final cx = (ci % n) * (cellSize + gap) + cellSize / 2;
      final cy = (ci ~/ n) * (cellSize + gap) + cellSize / 2;
      canvas.drawCircle(Offset(cx, cy), lineR, Paint()..color = pathStartColor);
    } else if (playerPath.length > 1) {
      final path = Path();
      Offset _c(int ci) => Offset((ci % n) * (cellSize + gap) + cellSize / 2, (ci ~/ n) * (cellSize + gap) + cellSize / 2);
      final first = _c(playerPath.first);
      path.moveTo(first.dx, first.dy);
      for (int i = 1; i < playerPath.length; i++) {
        final p = _c(playerPath[i]);
        path.lineTo(p.dx, p.dy);
      }
      final gridEnd = (n - 1) * (cellSize + gap) + cellSize / 2;
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = lineR * 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..shader = ui.Gradient.linear(
            const Offset(0, 0),
            Offset(gridEnd, gridEnd),
            [pathStartColor, pathEndColor],
          ),
      );
    }

    canvas.restore();

    final wPaint = Paint()..color = const Color(0xFF1F2937)..strokeWidth = math.max(3.0, cellSize * 0.08)..strokeCap = StrokeCap.round;
    for (final wk in walls) {
      final pts = wk.split(':');
      final a = int.parse(pts[0]), b = int.parse(pts[1]);
      final ar = a ~/ n, ac = a % n, br = b ~/ n, bc = b % n;
      if (ar == br) {
        final wx = math.max(ac, bc) * (cellSize + gap) - gap / 2;
        canvas.drawLine(Offset(wx, ar * (cellSize + gap)), Offset(wx, ar * (cellSize + gap) + cellSize), wPaint);
      } else {
        final wy = math.max(ar, br) * (cellSize + gap) - gap / 2;
        canvas.drawLine(Offset(ac * (cellSize + gap), wy), Offset(ac * (cellSize + gap) + cellSize, wy), wPaint);
      }
    }

    if (hintCell != null) {
      final t = hintNotifier?.value ?? 0.0;
      final hr = hintCell! ~/ n, hc = hintCell! % n;
      final hx = hc * (cellSize + gap) + cellSize / 2;
      final hy = hr * (cellSize + gap) + cellSize / 2;

      double fromX = hx, fromY = hy;
      if (hintFromCell != null) {
        final fr = hintFromCell! ~/ n, fc = hintFromCell! % n;
        fromX = fc * (cellSize + gap) + cellSize / 2;
        fromY = fr * (cellSize + gap) + cellSize / 2;
      }

      double dx = hx - fromX, dy = hy - fromY;
      final dLen = math.sqrt(dx * dx + dy * dy);
      if (dLen > 0) { dx /= dLen; dy /= dLen; } else { dy = 1; }

      final ease = Curves.easeInOutSine.transform(t);
      final bounce = ease * cellSize * 0.06;
      final px = -dy, py = dx;

      final start = Offset(fromX + dx * bounce, fromY + dy * bounce);
      final tipOff = cellSize * 0.75 + gap * 0.25;
      final tip = Offset(fromX + dx * (tipOff + bounce), fromY + dy * (tipOff + bounce));

      final sw = cellSize * 0.07;
      final sPaint = Paint()
        ..color = pathStartColor
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(start, tip, sPaint);

      final chevW = cellSize * 0.14;
      final chevD = cellSize * 0.12;
      final chevPaint = Paint()
        ..color = pathStartColor
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final chevPath = Path()
        ..moveTo(tip.dx - dx * chevD + px * chevW, tip.dy - dy * chevD + py * chevW)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(tip.dx - dx * chevD - px * chevW, tip.dy - dy * chevD - py * chevW);
      canvas.drawPath(chevPath, chevPaint);
    }

    for (final entry in checkpoints.entries) {
      if (entry.key >= solutionPath.length) continue;
      final ci = solutionPath[entry.key];
      final r = ci ~/ n, c = ci % n;
      final cx = c * (cellSize + gap) + cellSize / 2;
      final cy = r * (cellSize + gap) + cellSize / 2;
      final cr = cellSize * 0.30;
      canvas.drawCircle(Offset(cx, cy + 1), cr, Paint()..color = Colors.black.withValues(alpha: 0.18));
      canvas.drawCircle(Offset(cx, cy), cr, Paint()..color = const Color(0xFF1F2937));
      final tp = TextPainter(
        text: TextSpan(text: '${entry.value}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: cellSize * 0.28, height: 1)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_ZipGridPainter old) => true;
}

class _ZipHintNudge extends StatelessWidget {
  final VoidCallback onTap;
  final bool isStuck;
  const _ZipHintNudge({required this.onTap, required this.isStuck});

  static const _kBg = Color(0xFFFFD43B);
  static const _kFg = Color(0xFF5C4600);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE6BE00), width: 1.5),
                boxShadow: [BoxShadow(color: _kBg.withValues(alpha: 0.30), blurRadius: 12, offset: const Offset(0, 3))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lightbulb_rounded, size: 16, color: _kFg),
                  const SizedBox(width: 6),
                  const Text('HINT', style: TextStyle(color: _kFg, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.0, height: 1)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: _kFg.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded, size: 12, color: _kFg),
                        SizedBox(width: 2),
                        Text('AD', style: TextStyle(color: _kFg, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8, height: 1)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isStuck)
            Positioned(
              bottom: 40,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF7C3AED).withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: const Text('Stuck? Try a hint!', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                  ),
                  CustomPaint(size: const Size(14, 7), painter: _BubbleTailPainter()),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF7C3AED));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

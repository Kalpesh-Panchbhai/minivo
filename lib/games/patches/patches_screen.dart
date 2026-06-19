import 'dart:async';
import 'dart:math' as math;

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
import '../shared/continue_dialog.dart';
import '../shared/game_hud_bar.dart';
import '../shared/generic_game_result_screen.dart' as game_result;
import '../shared/level_complete_overlay.dart';
import 'patches_logo.dart';
import 'patches_level_gen.dart' as gen;
import 'patches_tutorial.dart';

const kPatchesGameId = 'patches';
const _kAccent = Color(0xFF6366F1);
const _kEasyColor = Color(0xFF22C55E);
const _kMediumColor = Color(0xFFF59E0B);
const _kHardColor = Color(0xFFEF4444);
const _kGridLine = Color(0xFFCBD5E1);
const _kCellBg = Color(0xFFF8FAFC);

const _kPatchColors = [
  Color(0xFFBFDBFE),
  Color(0xFFFDE68A),
  Color(0xFFBBF7D0),
  Color(0xFFFECACA),
  Color(0xFFDDD6FE),
  Color(0xFFFBCFE8),
  Color(0xFFCFFAFE),
  Color(0xFFFED7AA),
  Color(0xFFE9D5FF),
  Color(0xFFA7F3D0),
  Color(0xFFFCA5A5),
  Color(0xFF93C5FD),
  Color(0xFFFCD34D),
  Color(0xFF86EFAC),
  Color(0xFFC4B5FD),
  Color(0xFFF9A8D4),
];

enum _Difficulty { easy, medium, hard }

extension _DifficultyX on _Difficulty {
  String get label => ['EASY', 'MEDIUM', 'HARD'][index];
  Color get color => [_kEasyColor, _kMediumColor, _kHardColor][index];
  DifficultyKind get kind => [DifficultyKind.easy, DifficultyKind.medium, DifficultyKind.hard][index];
  String get hint => ['5×5 boards', '7×7 boards', '9×9 boards'][index];
  String get subKey => ['easy', 'medium', 'hard'][index];
}

const _kClueColors = [
  Color(0xFFEF4444), Color(0xFF22C55E), Color(0xFF3B82F6),
  Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFFF59E0B),
  Color(0xFF14B8A6), Color(0xFFFF6B35), Color(0xFF6366F1),
  Color(0xFF84CC16), Color(0xFFE879F9), Color(0xFF06B6D4),
  Color(0xFFA855F7), Color(0xFFF97316), Color(0xFF10B981),
  Color(0xFFE11D48),
];

class PatchesScreen extends StatefulWidget {
  const PatchesScreen({super.key});
  @override
  State<PatchesScreen> createState() => _PatchesScreenState();
}

class _PatchesScreenState extends State<PatchesScreen> with SingleTickerProviderStateMixin {
  _Difficulty? _activeDifficulty;
  _Difficulty _pickerDifficulty = _Difficulty.values[DifficultyKind.defaultIndex];
  bool _isFavorite = false;
  int _level = 1;
  bool _gameOver = false;
  bool _won = false;
  int _rows = 5;
  int _cols = 5;
  List<int> _clues = [];
  List<int> _solution = [];
  List<int> _playerBoard = [];
  int _nextPatchId = 1;
  Map<int, gen.PatchesShape> _clueShapes = {};
  Map<int, int> _clueColorIdx = {};
  Set<int> _hiddenClueNumbers = {};
  Map<int, int> _patchIdToClueIdx = {};
  int? _dragStart;
  int? _dragEnd;
  int _moves = 0;
  OverlayEntry? _appreciationOverlay;
  int _hintsUsed = 0;
  static const _kMaxHints = 3;
  Timer? _idleTimer;
  bool _idleStuck = false;
  static const _kIdleTimeout = Duration(seconds: 8);
  late final AnimationController _winAnim;

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(kPatchesGameId);
    _winAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  }

  @override
  void dispose() {
    _appreciationOverlay?.remove();
    _appreciationOverlay = null;
    _idleTimer?.cancel();
    _winAnim.dispose();
    super.dispose();
  }

  void _toggleFavorite() {
    ScoreService().toggleFavorite(kPatchesGameId);
    setState(() => _isFavorite = !_isFavorite);
  }

  void _showHelp() {
    final info = GameRegistry.getById(kPatchesGameId);
    if (info == null) return;
    showHowToPlaySheet(context, title: info.name, howToPlay: info.howToPlay,
        accent: _kAccent, steps: patchesTutorialSteps(), gameId: kPatchesGameId);
  }

  void _startGame(_Difficulty diff) async {
    final lps = LevelProgressService();
    _level = lps.getCurrentLevel(kPatchesGameId, diff.subKey);
    final saved = lps.getGameState(kPatchesGameId, diff.subKey);
    final hasSave = saved != null && saved['level'] == _level;
    bool shouldContinue = false;
    if (hasSave) {
      shouldContinue = await showContinueDialog(context, gameName: 'Patches', accentColor: diff.color, level: _level);
      if (!mounted) return;
    }
    _gameOver = false;
    _won = false;
    _hintsUsed = 0;
    _moves = 0;
    _dragStart = null;
    _dragEnd = null;
    _generateLevel(diff);
    if (hasSave && shouldContinue) {
      _playerBoard = List<int>.from(saved['board'] as List);
      _nextPatchId = (saved['nextPatchId'] as int?) ?? 1;
      _hintsUsed = (saved['hintsUsed'] as int?) ?? 0;
      _moves = (saved['moves'] as int?) ?? 0;
      _rebuildPatchColorMap();
    } else {
      if (hasSave) lps.clearGameState(kPatchesGameId, diff.subKey);
    }
    _resetIdleTimer();
    setState(() => _activeDifficulty = diff);
    GameWrapper.of(context).setDifficultyAndMode(difficulty: diff.label, subKey: diff.subKey);
    GameWrapper.of(context).startGame();
    GameWrapper.of(context).updateScore(_level);
  }

  void _generateLevel(_Difficulty diff) {
    final result = gen.generatePatchesLevel(_level, diff.index);
    _rows = result.rows;
    _cols = result.cols;
    _clues = result.clues;
    _solution = result.solution;
    _playerBoard = List<int>.filled(_rows * _cols, 0);
    _nextPatchId = 1;
    _patchIdToClueIdx = {};
    _computeShapes(diff);
  }

  Color _colorForPatch(int pid) {
    final clueCell = _patchIdToClueIdx[pid];
    if (clueCell == null) return _kPatchColors[(pid - 1) % _kPatchColors.length];
    final ci = _clueColorIdx[clueCell] ?? 0;
    return _kClueColors[ci % _kClueColors.length];
  }

  void _rebuildPatchColorMap() {
    _patchIdToClueIdx = {};
    for (int i = 0; i < _playerBoard.length; i++) {
      final pid = _playerBoard[i];
      if (pid > 0 && _clues[i] > 0) _patchIdToClueIdx[pid] = i;
    }
  }

  // Shapes + hidden-number flags come straight from the shared, deterministic
  // gen.derivePatchesPresentation — the exact same function the generator used
  // to PROVE each level has a single solution. So what's rendered here is
  // guaranteed to match what was verified. The colour index is purely cosmetic
  // and stays local.
  void _computeShapes(_Difficulty diff) {
    final puzzle = gen.PatchesLevelResult(
        rows: _rows, cols: _cols, clues: _clues, solution: _solution);
    final pres = gen.derivePatchesPresentation(puzzle, diff.index);
    _clueShapes = Map<int, gen.PatchesShape>.from(pres.shapes);
    _hiddenClueNumbers = Set<int>.from(pres.hidden);
    _clueColorIdx = {};
    final n = _rows * _cols;
    int ci = 0;
    for (int i = 0; i < n; i++) {
      if (_clues[i] <= 0) continue;
      _clueColorIdx[i] = ci;
      ci++;
    }
  }

  Rect? _dragRect() {
    if (_dragStart == null || _dragEnd == null) return null;
    final sr = _dragStart! ~/ _cols, sc = _dragStart! % _cols;
    final er = _dragEnd! ~/ _cols, ec = _dragEnd! % _cols;
    final minR = math.min(sr, er), maxR = math.max(sr, er);
    final minC = math.min(sc, ec), maxC = math.max(sc, ec);
    return Rect.fromLTRB(minC.toDouble(), minR.toDouble(), maxC.toDouble(), maxR.toDouble());
  }

  void _onPanStart(int idx) {
    if (_gameOver || _won) return;
    _resetIdleTimer();
    setState(() {
      _dragStart = idx;
      _dragEnd = idx;
    });
  }

  void _onPanUpdate(int idx) {
    if (_dragStart == null || _gameOver || _won) return;
    if (idx != _dragEnd) {
      setState(() => _dragEnd = idx);
    }
  }

  void _onPanEnd() {
    if (_dragStart == null || _dragEnd == null || _gameOver || _won) return;
    final rect = _dragRect();
    if (rect == null) { setState(() { _dragStart = null; _dragEnd = null; }); return; }
    final minR = rect.top.toInt(), maxR = rect.bottom.toInt();
    final minC = rect.left.toInt(), maxC = rect.right.toInt();

    bool canPlace = true;
    for (int r = minR; r <= maxR && canPlace; r++) {
      for (int c = minC; c <= maxC && canPlace; c++) {
        if (_playerBoard[r * _cols + c] != 0) canPlace = false;
      }
    }

    int clueCount = 0;
    int clueArea = 0;
    for (int r = minR; r <= maxR; r++) {
      for (int c = minC; c <= maxC; c++) {
        if (_clues[r * _cols + c] > 0) {
          clueCount++;
          clueArea = _clues[r * _cols + c];
        }
      }
    }

    final patchArea = (maxR - minR + 1) * (maxC - minC + 1);
    if (clueCount != 1 || clueArea != patchArea) canPlace = false;

    if (canPlace) {
      final id = _nextPatchId++;
      for (int r = minR; r <= maxR; r++) {
        for (int c = minC; c <= maxC; c++) {
          final ci = r * _cols + c;
          _playerBoard[ci] = id;
          if (_clues[ci] > 0) _patchIdToClueIdx[id] = ci;
        }
      }
      _moves++;
      AudioService().playTap();
      _saveState();
      _checkWin();
    }

    setState(() { _dragStart = null; _dragEnd = null; });
  }

  void _onCellTap(int idx) {
    if (_gameOver || _won) return;
    _resetIdleTimer();
    final pid = _playerBoard[idx];
    if (pid > 0) {
      _patchIdToClueIdx.remove(pid);
      setState(() {
        for (int i = 0; i < _playerBoard.length; i++) {
          if (_playerBoard[i] == pid) _playerBoard[i] = 0;
        }
        _moves++;
      });
      AudioService().playTap();
      _saveState();
      return;
    }
    if (_clues[idx] == 1) {
      final id = _nextPatchId++;
      _patchIdToClueIdx[id] = idx;
      setState(() {
        _playerBoard[idx] = id;
        _moves++;
      });
      AudioService().playTap();
      _saveState();
      _checkWin();
    }
  }

  void _checkWin() {
    if (_playerBoard.any((v) => v == 0)) return;
    final n = _rows * _cols;
    final patchCells = <int, List<int>>{};
    for (int i = 0; i < n; i++) {
      patchCells.putIfAbsent(_playerBoard[i], () => []).add(i);
    }
    for (final entry in patchCells.entries) {
      final cells = entry.value;
      int minR = _rows, maxR = 0, minC = _cols, maxC = 0;
      for (final c in cells) {
        final r = c ~/ _cols, cc = c % _cols;
        if (r < minR) minR = r;
        if (r > maxR) maxR = r;
        if (cc < minC) minC = cc;
        if (cc > maxC) maxC = cc;
      }
      if ((maxR - minR + 1) * (maxC - minC + 1) != cells.length) return;
      int clueCount = 0;
      for (final c in cells) {
        if (_clues[c] > 0) clueCount++;
      }
      if (clueCount != 1) return;
      final clueIdx = cells.firstWhere((c) => _clues[c] > 0);
      if (_clues[clueIdx] != cells.length) return;
    }
    _won = true;
    _winAnim.forward(from: 0);
    _endGame(true);
  }

  void _endGame(bool won) {
    _won = won;
    if (won) {
      final diff = _activeDifficulty!;
      LevelProgressService()..advanceLevel(kPatchesGameId, diff.subKey)..clearGameState(kPatchesGameId, diff.subKey);
      GameWrapper.of(context).updateScore(_level);
      AudioService().playScore();
      _showAppreciation();
      return;
    }
    _gameOver = true;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) GameWrapper.of(context).endGame(result: 'loss'); });
  }

  void _showAppreciation() {
    _appreciationOverlay?.remove();
    final diff = _activeDifficulty!;
    _appreciationOverlay = OverlayEntry(
      builder: (_) => LevelCompleteOverlay(level: _level, accentColor: diff.color, onComplete: () {
        _appreciationOverlay?.remove();
        _appreciationOverlay = null;
        if (!mounted) return;
        GameWrapper.of(context).completeLevelWithAd(onComplete: () { if (mounted) _nextLevel(); });
      }),
    );
    Overlay.of(context).insert(_appreciationOverlay!);
  }

  void _nextLevel() {
    final diff = _activeDifficulty!;
    setState(() { _level++; _gameOver = false; _won = false; _hintsUsed = 0; _moves = 0; });
    _generateLevel(diff);
    _resetIdleTimer();
    GameWrapper.of(context).restartGame();
    GameWrapper.of(context).startGame();
    GameWrapper.of(context).updateScore(_level);
  }

  void _restartLevel() {
    setState(() {
      _gameOver = false; _won = false; _hintsUsed = 0; _moves = 0;
      _playerBoard = List<int>.filled(_rows * _cols, 0);
      _nextPatchId = 1;
      _patchIdToClueIdx = {};
    });
    if (_activeDifficulty != null) LevelProgressService().clearGameState(kPatchesGameId, _activeDifficulty!.subKey);
    _resetIdleTimer();
    GameWrapper.of(context).restartGame();
    GameWrapper.of(context).startGame();
    GameWrapper.of(context).updateScore(_level);
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (_idleStuck) setState(() => _idleStuck = false);
    _idleTimer = Timer(_kIdleTimeout, () { if (mounted && _activeDifficulty != null && !_gameOver && !_won) setState(() => _idleStuck = true); });
  }

  void _onHint() {
    if (_gameOver || _won || _hintsUsed >= _kMaxHints) return;
    if (!AdsService().isRewardedReady) { _applyHint(); return; }
    AdsService().showRewarded(rewardType: RewardType.hint, gameId: kPatchesGameId, onRewarded: (_) { if (!mounted) return; _applyHint(); });
  }

  void _applyHint() {
    _hintsUsed++;
    _idleStuck = false;
    _resetIdleTimer();
    final n = _rows * _cols;
    final solPatches = <int, List<int>>{};
    for (int i = 0; i < n; i++) {
      solPatches.putIfAbsent(_solution[i], () => []).add(i);
    }
    for (final entry in solPatches.entries) {
      final cells = entry.value;
      bool alreadyPlaced = false;
      for (final c in cells) {
        if (_playerBoard[c] != 0) { alreadyPlaced = true; break; }
      }
      if (alreadyPlaced) continue;
      final id = _nextPatchId++;
      for (final c in cells) {
        _playerBoard[c] = id;
        if (_clues[c] > 0) _patchIdToClueIdx[id] = c;
      }
      _moves++;
      setState(() {});
      AudioService().playTap();
      _saveState();
      _checkWin();
      return;
    }
  }

  void _saveState() {
    final diff = _activeDifficulty;
    if (diff == null || _gameOver || _won || _moves == 0) return;
    LevelProgressService().saveGameState(kPatchesGameId, diff.subKey, {
      'level': _level, 'board': _playerBoard, 'nextPatchId': _nextPatchId,
      'hintsUsed': _hintsUsed, 'moves': _moves,
    });
  }

  void _backOrHome() {
    _saveState();
    GameWrapper.of(context).handleExit(() { if (context.canPop()) context.pop(); else context.go('/home'); });
  }

  @override
  Widget build(BuildContext context) {
    if (_activeDifficulty == null) return _buildPicker();
    if (_gameOver && !_won) return _buildResult();
    return _buildGame();
  }

  Widget _buildPicker() {
    final diffs = _Difficulty.values.map((d) => GameDifficultyData(
      label: d.label, color: d.color, kind: d.kind, hint: d.hint,
      bestScore: LevelProgressService().getHighestLevel(kPatchesGameId, d.subKey),
      bestLabel: (s) => s <= 0 ? '' : 'Completed: Level $s',
    )).toList();
    return GamePickerScaffold(
      bgColorTop: const Color(0xFFEEF2FF), bgColorBottom: const Color(0xFFE0E7FF),
      animatedBg: AnimatedBackground(factory: (t) => GenericAnimatedBgPainter(t, accent: _kAccent, icon: Icons.grid_view_rounded)),
      iconRingColors: const [_kAccent, Color(0xFF818CF8), Color(0xFF4F46E5)],
      iconChild: buildPatchesLogo(60), title: 'Patches', subtitle: 'Divide the grid into rectangles!',
      onBack: _backOrHome, isFavorite: _isFavorite, onFavoriteToggle: _toggleFavorite, onHowToPlay: _showHelp, gameId: kPatchesGameId,
      body: GameSinglePickerBody(
        difficulties: diffs, activeIndex: _pickerDifficulty.index,
        onChanged: (i) => setState(() => _pickerDifficulty = _Difficulty.values[i]),
        playLabel: 'Play Patches',
        playSubLabel: 'Level ${LevelProgressService().getCurrentLevel(kPatchesGameId, _pickerDifficulty.subKey)}',
        onPlay: () => _startGame(_pickerDifficulty), accentColor: _kAccent,
      ),
    );
  }

  Widget _buildGame() {
    final diff = _activeDifficulty!;
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)])),
      child: SafeArea(child: Column(children: [
        GameHudBar(
          leading: GameBackButton(onTap: _backOrHome, bgColor: _kAccent.withValues(alpha: 0.12), iconColor: _kAccent),
          centerContent: _buildHud(diff),
          trailing: GameRestartButton(gameName: 'Patches', accentColor: diff.color, onRestart: _restartLevel, bgColor: _kAccent.withValues(alpha: 0.12), iconColor: _kAccent),
        ),
        Expanded(child: Center(child: Padding(padding: const EdgeInsets.all(12), child: LayoutBuilder(builder: (_, c) => _buildGrid(c))))),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: !_gameOver && !_won && _hintsUsed < _kMaxHints ? 1.0 : 0.0,
          child: IgnorePointer(ignoring: _gameOver || _won || _hintsUsed >= _kMaxHints, child: _PatchesHintNudge(onTap: _onHint, isStuck: _idleStuck)),
        ),
        const SizedBox(height: 12),
      ])),
    );
  }

  Widget _buildHud(_Difficulty diff) {
    final clr = diff.color;
    final placed = _playerBoard.where((v) => v > 0).length;
    final total = _rows * _cols;
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
          _statCol('FILLED', '$placed/$total', const Color(0xFF6B7280)),
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

  Widget _buildGrid(BoxConstraints con) {
    final maxSz = math.min(con.maxWidth, con.maxHeight - 16);
    const bw = 2.0;
    final cellSz = ((maxSz - 2 * bw) / math.max(_rows, _cols)).floorToDouble();
    final gridW = cellSz * _cols;
    final gridH = cellSz * _rows;
    return GestureDetector(
      onPanStart: (d) {
        final local = d.localPosition;
        final idx = _hitTest(local, cellSz, bw);
        if (idx != null) _onPanStart(idx);
      },
      onPanUpdate: (d) {
        final local = d.localPosition;
        final idx = _hitTest(local, cellSz, bw);
        if (idx != null) _onPanUpdate(idx);
      },
      onPanEnd: (_) => _onPanEnd(),
      child: Container(
        key: const Key('patches_grid'),
        width: gridW + 2 * bw, height: gridH + 2 * bw,
        decoration: BoxDecoration(color: _kCellBg, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF94A3B8), width: bw),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 12, offset: const Offset(0, 4))]),
        child: ClipRRect(borderRadius: BorderRadius.circular(14 - bw), child: Stack(clipBehavior: Clip.none, children: [
          Column(mainAxisSize: MainAxisSize.min, children: List.generate(_rows, (r) =>
            Row(mainAxisSize: MainAxisSize.min, children: List.generate(_cols, (c) => _buildCell(r, c, cellSz))))),
          ..._buildPatchBorders(cellSz),
          if (_dragStart != null && _dragEnd != null) _buildDragOverlay(cellSz),
        ])),
      ),
    );
  }

  int? _hitTest(Offset local, double cellSz, double bw) {
    final col = ((local.dx - bw) / cellSz).floor();
    final row = ((local.dy - bw) / cellSz).floor();
    if (row < 0 || row >= _rows || col < 0 || col >= _cols) return null;
    return row * _cols + col;
  }

  Widget _buildDragOverlay(double cellSz) {
    final rect = _dragRect();
    if (rect == null) return const SizedBox.shrink();
    final minR = rect.top.toInt(), maxR = rect.bottom.toInt();
    final minC = rect.left.toInt(), maxC = rect.right.toInt();
    final w = (maxC - minC + 1) * cellSz;
    final h = (maxR - minR + 1) * cellSz;
    return Positioned(
      left: minC * cellSz, top: minR * cellSz,
      child: IgnorePointer(child: Container(
        width: w, height: h,
        decoration: BoxDecoration(
          color: _kAccent.withValues(alpha: 0.18),
          border: Border.all(color: _kAccent, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
      )),
    );
  }

  List<Widget> _buildPatchBorders(double cellSz) {
    final patches = <int, List<int>>{};
    for (int i = 0; i < _playerBoard.length; i++) {
      final pid = _playerBoard[i];
      if (pid > 0) patches.putIfAbsent(pid, () => []).add(i);
    }
    return patches.entries.map((entry) {
      final pid = entry.key;
      final cells = entry.value;
      int minR = _rows, maxR = 0, minC = _cols, maxC = 0;
      for (final c in cells) {
        final r = c ~/ _cols, cc = c % _cols;
        if (r < minR) minR = r;
        if (r > maxR) maxR = r;
        if (cc < minC) minC = cc;
        if (cc > maxC) maxC = cc;
      }
      final color = _colorForPatch(pid);
      return Positioned(
        left: minC * cellSz, top: minR * cellSz,
        child: IgnorePointer(child: Container(
          width: (maxC - minC + 1) * cellSz,
          height: (maxR - minR + 1) * cellSz,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color, width: 2.5),
          ),
        )),
      );
    }).toList();
  }

  Widget _buildCell(int row, int col, double cellSz) {
    final idx = row * _cols + col;
    final pid = _playerBoard[idx];
    final clue = _clues[idx];
    Color bg = _kCellBg;
    if (pid > 0) {
      bg = _colorForPatch(pid).withValues(alpha: 0.22);
    }

    BorderSide borderForEdge(int dr, int dc) {
      final nr = row + dr, nc = col + dc;
      if (nr < 0 || nr >= _rows || nc < 0 || nc >= _cols) return BorderSide.none;
      return BorderSide(color: _kGridLine, width: 0.5);
    }

    final gridBorder = Border(
      top: row > 0 ? borderForEdge(-1, 0) : BorderSide.none,
      left: col > 0 ? borderForEdge(0, -1) : BorderSide.none,
      right: col < _cols - 1 ? borderForEdge(0, 1) : BorderSide.none,
      bottom: row < _rows - 1 ? borderForEdge(1, 0) : BorderSide.none,
    );

    final clueColor = _kClueColors[(_clueColorIdx[idx] ?? 0) % _kClueColors.length];

    return GestureDetector(
      onTap: () => _onCellTap(idx),
      child: Container(width: cellSz, height: cellSz,
        decoration: BoxDecoration(color: bg, border: gridBorder),
        child: Stack(children: [
          if (clue > 0) Positioned.fill(child: CustomPaint(painter: _ClueShapePainter(
            kind: _clueShapes[idx] ?? gen.PatchesShape.square,
            color: clueColor,
          ))),
          if (clue > 0 && !_hiddenClueNumbers.contains(idx))
            Center(child: FittedBox(fit: BoxFit.scaleDown,
              child: Padding(padding: const EdgeInsets.all(2),
                child: Text('$clue', style: TextStyle(fontSize: cellSz * 0.38, fontWeight: FontWeight.w900,
                  color: const Color(0xFF334155), height: 1))))),
        ]),
      ),
    );
  }

  Widget _buildResult() {
    final diff = _activeDifficulty!;
    return game_result.GenericGameResultScreen(
      headline: _won ? 'Level $_level Complete!' : 'Stuck!',
      subtitle: _won ? 'All patches placed!' : 'Try again or restart',
      badgeContent: _won ? '🧩' : '😔', badgeColor: diff.color, showNewBestBadge: false,
      gameId: kPatchesGameId, score: _level,
      statsWidget: game_result.GameResultStatsRow(stats: [
        game_result.StatItem(label: 'LEVEL', value: _level, color: diff.color),
        game_result.StatItem(label: 'MOVES', value: _moves, color: const Color(0xFF6B7280)),
      ]),
      actions: [
        if (_won) game_result.GameResultAction(label: 'Next Level', icon: Icons.arrow_forward_rounded, onTap: _nextLevel, filled: true, color: diff.color, actionId: 'play_again')
        else game_result.GameResultAction(label: 'Retry Level', icon: Icons.refresh_rounded, onTap: _restartLevel, filled: true, color: diff.color, actionId: 'play_again'),
        game_result.GameResultAction(label: 'Change Difficulty', icon: Icons.tune_rounded,
          onTap: () { setState(() { _activeDifficulty = null; _gameOver = false; }); GameWrapper.of(context).restartGame(); },
          filled: false, actionId: 'change_mode'),
        game_result.GameResultAction(label: 'Home', icon: Icons.home_rounded, onTap: () => context.go('/home'), actionId: 'home', filled: false),
      ],
    );
  }
}

class _ClueShapePainter extends CustomPainter {
  final gen.PatchesShape kind;
  final Color color;
  _ClueShapePainter({required this.kind, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final s = math.min(size.width, size.height);

    late double rw, rh;
    switch (kind) {
      case gen.PatchesShape.square:
        rw = s * 0.62; rh = s * 0.62;
      case gen.PatchesShape.tall:
        rw = s * 0.44; rh = s * 0.74;
      case gen.PatchesShape.wide:
        rw = s * 0.74; rh = s * 0.44;
      case gen.PatchesShape.any:
        rw = s * 0.60; rh = s * 0.60;
    }

    final rect = Rect.fromCenter(center: Offset(cx, cy), width: rw, height: rh);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(s * 0.10));

    canvas.drawRRect(rr, Paint()..color = color.withValues(alpha: 0.16));

    if (kind == gen.PatchesShape.any) {
      canvas.save();
      canvas.clipRRect(rr);
      final hatch = Paint()..color = color.withValues(alpha: 0.13)..strokeWidth = 1.0;
      for (double d = rect.left - rh; d < rect.right + rh; d += 4.0) {
        canvas.drawLine(Offset(d, rect.bottom), Offset(d + rh, rect.top), hatch);
      }
      canvas.restore();
    }

    final dashPaint = Paint()
      ..color = color.withValues(alpha: 0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(rr);
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 3.5, metric.length)), dashPaint);
        d += 6.0;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ClueShapePainter old) =>
      old.kind != kind || old.color != color;
}

class _PatchesHintNudge extends StatelessWidget {
  final VoidCallback onTap;
  final bool isStuck;
  const _PatchesHintNudge({required this.onTap, required this.isStuck});
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

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
import 'tango_logo.dart';
import 'tango_level_gen.dart' as gen;
import 'tango_tutorial.dart';

const kTangoGameId = 'tango';
const _kAccent = Color(0xFFF59E0B);
const _kEasyColor = Color(0xFF22C55E);
const _kMediumColor = Color(0xFFF59E0B);
const _kHardColor = Color(0xFFEF4444);
const _kSunColor = Color(0xFFFFA726);
const _kMoonColor = Color(0xFF7C4DFF);
const _kGridLine = Color(0xFFD4C5A0);
const _kCellBg = Color(0xFFFFF8E7);
const _kPrefilledBg = Color(0xFFF5ECD7);

enum _Difficulty { easy, medium, hard }

extension _DifficultyX on _Difficulty {
  String get label => ['EASY', 'MEDIUM', 'HARD'][index];
  Color get color => [_kEasyColor, _kMediumColor, _kHardColor][index];
  DifficultyKind get kind => [DifficultyKind.easy, DifficultyKind.medium, DifficultyKind.hard][index];
  String get hint => ['4×4 boards', '6×6 boards', '6×6, fewer clues'][index];
  String get subKey => ['easy', 'medium', 'hard'][index];
}

class TangoScreen extends StatefulWidget {
  const TangoScreen({super.key});
  @override
  State<TangoScreen> createState() => _TangoScreenState();
}

class _TangoScreenState extends State<TangoScreen> with SingleTickerProviderStateMixin {
  _Difficulty? _activeDifficulty;
  _Difficulty _pickerDifficulty = _Difficulty.values[DifficultyKind.defaultIndex];
  bool _isFavorite = false;
  int _level = 1;
  bool _gameOver = false;
  bool _won = false;
  int _gridSize = 4;
  List<int> _solution = [];
  Set<int> _prefilled = {};
  Map<int, int> _hClues = {};
  Map<int, int> _vClues = {};
  List<int> _playerBoard = [];
  Set<int> _invalidCells = {};
  Set<int> _invalidHClues = {};
  Set<int> _invalidVClues = {};
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
    _isFavorite = ScoreService().isFavorite(kTangoGameId);
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
    ScoreService().toggleFavorite(kTangoGameId);
    setState(() => _isFavorite = !_isFavorite);
  }

  void _showHelp() {
    final info = GameRegistry.getById(kTangoGameId);
    if (info == null) return;
    showHowToPlaySheet(context, title: info.name, howToPlay: info.howToPlay,
        accent: _kAccent, steps: tangoTutorialSteps(), gameId: kTangoGameId);
  }

  void _startGame(_Difficulty diff) async {
    final lps = LevelProgressService();
    _level = lps.getCurrentLevel(kTangoGameId, diff.subKey);
    final saved = lps.getGameState(kTangoGameId, diff.subKey);
    final hasSave = saved != null && saved['level'] == _level;
    bool shouldContinue = false;
    if (hasSave) {
      shouldContinue = await showContinueDialog(context, gameName: 'Tango', accentColor: diff.color, level: _level);
      if (!mounted) return;
    }
    _gameOver = false;
    _won = false;
    _hintsUsed = 0;
    _moves = 0;
    _generateLevel(diff);
    if (hasSave && shouldContinue) {
      _playerBoard = List<int>.from(saved['board'] as List);
      _hintsUsed = (saved['hintsUsed'] as int?) ?? 0;
      _moves = (saved['moves'] as int?) ?? 0;
      _invalidCells.clear();
      _invalidHClues.clear();
      _invalidVClues.clear();
      _validateBoard();
    } else {
      if (hasSave) lps.clearGameState(kTangoGameId, diff.subKey);
    }
    _resetIdleTimer();
    setState(() => _activeDifficulty = diff);
    GameWrapper.of(context).setDifficultyAndMode(difficulty: diff.label, subKey: diff.subKey);
    GameWrapper.of(context).startGame();
    GameWrapper.of(context).updateScore(_level);
  }

  void _generateLevel(_Difficulty diff) {
    final result = gen.generateTangoLevel(_level, diff.index);
    _gridSize = result.gridSize;
    _solution = result.solution;
    _prefilled = result.prefilled;
    _hClues = result.hClues;
    _vClues = result.vClues;
    _playerBoard = List<int>.filled(_gridSize * _gridSize, -1);
    for (final idx in _prefilled) _playerBoard[idx] = _solution[idx];
    _invalidCells = {};
    _invalidHClues = {};
    _invalidVClues = {};
  }

  void _onCellTap(int idx) {
    if (_gameOver || _won) return;
    if (_prefilled.contains(idx)) return;
    _resetIdleTimer();
    setState(() {
      _playerBoard[idx] = switch (_playerBoard[idx]) { -1 => 0, 0 => 1, _ => -1 };
      _moves++;
      _invalidCells.clear();
      _invalidHClues.clear();
      _invalidVClues.clear();
      _validateBoard();
    });
    AudioService().playTap();
    _saveState();
    _checkWin();
  }

  void _validateBoard() {
    _invalidCells.clear();
    _invalidHClues.clear();
    _invalidVClues.clear();
    final n = _gridSize, half = n ~/ 2;
    for (int r = 0; r < n; r++) {
      int s0 = 0, s1 = 0;
      for (int c = 0; c < n; c++) { final v = _playerBoard[r * n + c]; if (v == 0) s0++; if (v == 1) s1++; }
      if (s0 > half) for (int c = 0; c < n; c++) { if (_playerBoard[r * n + c] == 0) _invalidCells.add(r * n + c); }
      if (s1 > half) for (int c = 0; c < n; c++) { if (_playerBoard[r * n + c] == 1) _invalidCells.add(r * n + c); }
    }
    for (int c = 0; c < n; c++) {
      int s0 = 0, s1 = 0;
      for (int r = 0; r < n; r++) { final v = _playerBoard[r * n + c]; if (v == 0) s0++; if (v == 1) s1++; }
      if (s0 > half) for (int r = 0; r < n; r++) { if (_playerBoard[r * n + c] == 0) _invalidCells.add(r * n + c); }
      if (s1 > half) for (int r = 0; r < n; r++) { if (_playerBoard[r * n + c] == 1) _invalidCells.add(r * n + c); }
    }
    for (int r = 0; r < n; r++) for (int c = 0; c < n - 2; c++) {
      final a = _playerBoard[r * n + c], b = _playerBoard[r * n + c + 1], d = _playerBoard[r * n + c + 2];
      if (a >= 0 && a == b && b == d) _invalidCells.addAll([r * n + c, r * n + c + 1, r * n + c + 2]);
    }
    for (int c = 0; c < n; c++) for (int r = 0; r < n - 2; r++) {
      final a = _playerBoard[r * n + c], b = _playerBoard[(r + 1) * n + c], d = _playerBoard[(r + 2) * n + c];
      if (a >= 0 && a == b && b == d) _invalidCells.addAll([r * n + c, (r + 1) * n + c, (r + 2) * n + c]);
    }
    for (final e in _hClues.entries) {
      final a = _playerBoard[e.key], b = _playerBoard[e.key + 1];
      if (a < 0 || b < 0) continue;
      if ((e.value == 0 && a != b) || (e.value == 1 && a == b)) { _invalidHClues.add(e.key); _invalidCells.addAll([e.key, e.key + 1]); }
    }
    for (final e in _vClues.entries) {
      final a = _playerBoard[e.key], b = _playerBoard[e.key + n];
      if (a < 0 || b < 0) continue;
      if ((e.value == 0 && a != b) || (e.value == 1 && a == b)) { _invalidVClues.add(e.key); _invalidCells.addAll([e.key, e.key + n]); }
    }
  }

  void _checkWin() {
    final n = _gridSize, half = n ~/ 2;
    if (_playerBoard.any((v) => v < 0)) return;
    if (_invalidCells.isNotEmpty) return;
    for (int r = 0; r < n; r++) { int s = 0; for (int c = 0; c < n; c++) if (_playerBoard[r * n + c] == 0) s++; if (s != half) return; }
    for (int c = 0; c < n; c++) { int s = 0; for (int r = 0; r < n; r++) if (_playerBoard[r * n + c] == 0) s++; if (s != half) return; }
    _won = true;
    _winAnim.forward(from: 0);
    _endGame(true);
  }

  void _endGame(bool won) {
    _won = won;
    if (won) {
      final diff = _activeDifficulty!;
      LevelProgressService()..advanceLevel(kTangoGameId, diff.subKey)..clearGameState(kTangoGameId, diff.subKey);
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
      _playerBoard = List<int>.filled(_gridSize * _gridSize, -1);
      for (final idx in _prefilled) _playerBoard[idx] = _solution[idx];
      _invalidCells = {}; _invalidHClues = {}; _invalidVClues = {};
    });
    if (_activeDifficulty != null) LevelProgressService().clearGameState(kTangoGameId, _activeDifficulty!.subKey);
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
    AdsService().showRewarded(rewardType: RewardType.hint, gameId: kTangoGameId, onRewarded: (_) { if (!mounted) return; _applyHint(); });
  }

  void _applyHint() {
    _hintsUsed++;
    _idleStuck = false;
    _resetIdleTimer();
    for (int i = 0; i < _gridSize * _gridSize; i++) {
      if (_prefilled.contains(i) || _playerBoard[i] == _solution[i]) continue;
      setState(() { _playerBoard[i] = _solution[i]; _moves++; _invalidCells.clear(); _invalidHClues.clear(); _invalidVClues.clear(); _validateBoard(); });
      AudioService().playTap();
      _saveState();
      _checkWin();
      return;
    }
  }

  void _saveState() {
    final diff = _activeDifficulty;
    if (diff == null || _gameOver || _won || _moves == 0) return;
    LevelProgressService().saveGameState(kTangoGameId, diff.subKey, {'level': _level, 'board': _playerBoard, 'hintsUsed': _hintsUsed, 'moves': _moves});
  }

  void _backOrHome() {
    _saveState();
    GameWrapper.of(context).handleExit(() { if (context.canPop()) context.pop(); else context.go('/home'); });
  }

  // ── BUILD ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_activeDifficulty == null) return _buildPicker();
    if (_gameOver && !_won) return _buildResult();
    return _buildGame();
  }

  Widget _buildPicker() {
    final diffs = _Difficulty.values.map((d) => GameDifficultyData(
      label: d.label, color: d.color, kind: d.kind, hint: d.hint,
      bestScore: LevelProgressService().getHighestLevel(kTangoGameId, d.subKey),
      bestLabel: (s) => s <= 0 ? '' : 'Completed: Level $s',
    )).toList();
    return GamePickerScaffold(
      bgColorTop: const Color(0xFFFFF8E1), bgColorBottom: const Color(0xFFFFF3E0),
      animatedBg: AnimatedBackground(factory: (t) => GenericAnimatedBgPainter(t, accent: _kAccent, icon: Icons.wb_sunny_rounded)),
      iconRingColors: const [_kAccent, Color(0xFFFFCC02), Color(0xFFE65100)],
      iconChild: buildTangoLogo(60), title: 'Tango', subtitle: 'Fill with suns and moons!',
      onBack: _backOrHome, isFavorite: _isFavorite, onFavoriteToggle: _toggleFavorite, onHowToPlay: _showHelp, gameId: kTangoGameId,
      body: GameSinglePickerBody(
        difficulties: diffs, activeIndex: _pickerDifficulty.index,
        onChanged: (i) => setState(() => _pickerDifficulty = _Difficulty.values[i]),
        playLabel: 'Play Tango',
        playSubLabel: 'Level ${LevelProgressService().getCurrentLevel(kTangoGameId, _pickerDifficulty.subKey)}',
        onPlay: () => _startGame(_pickerDifficulty), accentColor: _kAccent,
      ),
    );
  }

  Widget _buildGame() {
    final diff = _activeDifficulty!;
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFF8E1), Color(0xFFFFF3E0)])),
      child: SafeArea(child: Column(children: [
        GameHudBar(
          leading: GameBackButton(onTap: _backOrHome, bgColor: _kAccent.withValues(alpha: 0.12), iconColor: _kAccent),
          centerContent: _buildHud(diff),
          trailing: GameRestartButton(gameName: 'Tango', accentColor: diff.color, onRestart: _restartLevel, bgColor: _kAccent.withValues(alpha: 0.12), iconColor: _kAccent),
        ),
        Expanded(child: Center(child: Padding(padding: const EdgeInsets.all(12), child: LayoutBuilder(builder: (_, c) => _buildGrid(c))))),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: !_gameOver && !_won && _hintsUsed < _kMaxHints ? 1.0 : 0.0,
          child: IgnorePointer(ignoring: _gameOver || _won || _hintsUsed >= _kMaxHints, child: _TangoHintNudge(onTap: _onHint, isStuck: _idleStuck)),
        ),
        const SizedBox(height: 12),
      ])),
    );
  }

  Widget _buildHud(_Difficulty diff) {
    final clr = diff.color;
    final filled = _playerBoard.where((v) => v >= 0).length;
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
          _statCol('FILLED', '$filled/${_gridSize * _gridSize}', const Color(0xFF6B7280)),
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
    final n = _gridSize;
    final maxSz = math.min(con.maxWidth, con.maxHeight - 16);
    const bw = 2.5;
    final cellSz = ((maxSz - 2 * bw) / n).floorToDouble();
    final gridSz = cellSz * n;
    final clueSz = (cellSz * 0.30).clamp(14.0, 24.0);
    return Container(
      width: gridSz + 2 * bw, height: gridSz + 2 * bw,
      decoration: BoxDecoration(color: _kCellBg, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF8B7355), width: bw),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 12, offset: const Offset(0, 4))]),
      child: ClipRRect(borderRadius: BorderRadius.circular(14 - bw), child: Stack(clipBehavior: Clip.none, children: [
        Column(mainAxisSize: MainAxisSize.min, children: List.generate(n, (r) =>
          Row(mainAxisSize: MainAxisSize.min, children: List.generate(n, (c) => _buildCell(r, c, cellSz))))),
        ..._clueOverlays(cellSz, clueSz),
      ])),
    );
  }

  List<Widget> _clueOverlays(double cellSz, double clueSz) {
    final ws = <Widget>[];
    final n = _gridSize;
    for (final e in _hClues.entries) {
      final r = e.key ~/ n, c = e.key % n;
      ws.add(Positioned(left: (c + 1) * cellSz - clueSz / 2, top: r * cellSz + (cellSz - clueSz) / 2,
        child: _clueW(e.value, clueSz, _invalidHClues.contains(e.key))));
    }
    for (final e in _vClues.entries) {
      final r = e.key ~/ n, c = e.key % n;
      ws.add(Positioned(left: c * cellSz + (cellSz - clueSz) / 2, top: (r + 1) * cellSz - clueSz / 2,
        child: _clueW(e.value, clueSz, _invalidVClues.contains(e.key))));
    }
    return ws;
  }

  Widget _clueW(int type, double sz, bool bad) => Container(
    width: sz, height: sz,
    decoration: BoxDecoration(color: bad ? const Color(0xFFFFCDD2) : Colors.white, shape: BoxShape.circle,
      border: Border.all(color: bad ? Colors.red : const Color(0xFF8B7355), width: 1.2),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 2)]),
    child: Center(child: Text(type == 0 ? '=' : '×',
      style: TextStyle(fontSize: sz * 0.55, fontWeight: FontWeight.w900, color: bad ? Colors.red : const Color(0xFF8B7355), height: 1.1))),
  );

  Widget _buildCell(int row, int col, double cellSz) {
    final n = _gridSize, idx = row * n + col;
    final v = _playerBoard[idx];
    final isPre = _prefilled.contains(idx);
    final bad = _invalidCells.contains(idx);
    final bg = bad ? Colors.red.withValues(alpha: 0.15) : isPre ? _kPrefilledBg : _kCellBg;
    return GestureDetector(
      onTap: () => _onCellTap(idx),
      child: Container(width: cellSz, height: cellSz,
        decoration: BoxDecoration(color: bg, border: Border(
          top: row > 0 ? const BorderSide(color: _kGridLine, width: 0.5) : BorderSide.none,
          left: col > 0 ? const BorderSide(color: _kGridLine, width: 0.5) : BorderSide.none,
          right: col < n - 1 ? const BorderSide(color: _kGridLine, width: 0.5) : BorderSide.none,
          bottom: row < n - 1 ? const BorderSide(color: _kGridLine, width: 0.5) : BorderSide.none,
        )),
        child: Center(child: v == 0
          ? Icon(Icons.wb_sunny_rounded, size: cellSz * 0.55, color: _kSunColor)
          : v == 1
            ? Icon(Icons.nightlight_round, size: cellSz * 0.50, color: _kMoonColor)
            : const SizedBox.shrink()),
      ),
    );
  }

  Widget _buildResult() {
    final diff = _activeDifficulty!;
    return game_result.GenericGameResultScreen(
      headline: _won ? 'Level $_level Complete!' : 'Stuck!',
      subtitle: _won ? 'All cells filled!' : 'Try again or restart',
      badgeContent: _won ? '☀️' : '😔', badgeColor: diff.color, showNewBestBadge: false,
      gameId: kTangoGameId, score: _level,
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

class _TangoHintNudge extends StatelessWidget {
  final VoidCallback onTap;
  final bool isStuck;
  const _TangoHintNudge({required this.onTap, required this.isStuck});
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

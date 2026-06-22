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
import '../shared/continue_dialog.dart';
import '../shared/game_hud_bar.dart';
import '../shared/generic_game_result_screen.dart' as game_result;
import '../shared/level_complete_overlay.dart';
import 'color_connect_logo.dart';
import 'color_connect_level_gen.dart' as gen;
import 'color_connect_tutorial.dart';

const kColorConnectGameId = 'color_connect';

const _kAccent = Color(0xFF6C63FF);
const _kEasyColor = Color(0xFF22C55E);
const _kMediumColor = Color(0xFFF59E0B);
const _kHardColor = Color(0xFFEF4444);

const _kFlowPalette = <Color>[
  Color(0xFFFF6B6B),
  Color(0xFF4ECDC4),
  Color(0xFFFFE66D),
  Color(0xFF6C63FF),
  Color(0xFFFF922B),
  Color(0xFF51CF66),
  Color(0xFFE599F7),
  Color(0xFF339AF0),
  Color(0xFFFFA8A8),
  Color(0xFF38D9A9),
  Color(0xFFFFC078),
  Color(0xFF9775FA),
  Color(0xFFFF8787),
  Color(0xFF63E6BE),
  Color(0xFFFFD43B),
  Color(0xFF748FFC),
  Color(0xFFE64980),
  Color(0xFF20C997),
  Color(0xFFFF6B35),
  Color(0xFF845EF7),
];

const _kFlowLight = <Color>[
  Color(0xFFFFE0E0),
  Color(0xFFD4F5F2),
  Color(0xFFFFF8D4),
  Color(0xFFE0DEFF),
  Color(0xFFFFE4CC),
  Color(0xFFD8F5DC),
  Color(0xFFF5E0FC),
  Color(0xFFD4E8FC),
  Color(0xFFFFE8E8),
  Color(0xFFD4F0E8),
  Color(0xFFFFECD4),
  Color(0xFFE8E0FC),
  Color(0xFFFFE0E0),
  Color(0xFFD8F4EC),
  Color(0xFFFFF5CC),
  Color(0xFFDCE0FF),
  Color(0xFFF8D4E0),
  Color(0xFFD0F0E4),
  Color(0xFFFFDCC8),
  Color(0xFFE4D8FC),
];

const _kFlowDark = <Color>[
  Color(0xFFCC4444),
  Color(0xFF2E9E96),
  Color(0xFFCCB830),
  Color(0xFF4840CC),
  Color(0xFFCC6E10),
  Color(0xFF369E40),
  Color(0xFFB86CC8),
  Color(0xFF1870C0),
  Color(0xFFCC7070),
  Color(0xFF209E80),
  Color(0xFFCC9040),
  Color(0xFF6850C8),
  Color(0xFFCC5050),
  Color(0xFF38B08E),
  Color(0xFFCCAC10),
  Color(0xFF4860CC),
  Color(0xFFB82050),
  Color(0xFF109470),
  Color(0xFFCC4810),
  Color(0xFF5830C0),
];

enum _Difficulty { easy, medium, hard }

extension _DifficultyX on _Difficulty {
  String get label => ['EASY', 'MEDIUM', 'HARD'][index];
  Color get color => [_kEasyColor, _kMediumColor, _kHardColor][index];
  DifficultyKind get kind =>
      [DifficultyKind.easy, DifficultyKind.medium, DifficultyKind.hard][index];
  String get hint =>
      ['5×5 grid · 4-5 flows', '7×7 grid · 7 flows', '9×9 grid · 14 flows'][index];
  String get subKey => ['easy', 'medium', 'hard'][index];
}

class ColorConnectScreen extends StatefulWidget {
  const ColorConnectScreen({super.key});

  @override
  State<ColorConnectScreen> createState() => _ColorConnectScreenState();
}

class _ColorConnectScreenState extends State<ColorConnectScreen>
    with TickerProviderStateMixin {
  _Difficulty? _activeDifficulty;
  _Difficulty _pickerDifficulty = _Difficulty.values[DifficultyKind.defaultIndex];
  bool _isFavorite = false;

  int _level = 1;
  int _moves = 0;
  bool _gameOver = false;
  bool _won = false;

  int _rows = 5;
  int _cols = 5;
  int _numFlows = 5;
  List<int> _endpoints = [];
  List<int> _solution = [];

  List<List<int>> _paths = [];
  int? _activeFlow;
  bool _isDragging = false;

  AnimationController? _pathAnim;
  int _lastChangedFlow = -1;

  int _hintsUsed = 0;
  static const _kMaxHints = 3;
  Timer? _idleTimer;
  bool _idleStuck = false;
  static const _kIdleTimeout = Duration(seconds: 10);

  OverlayEntry? _appreciationOverlay;

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(kColorConnectGameId);
    _pathAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..value = 1.0;
  }

  @override
  void dispose() {
    _pathAnim?.stop();
    _pathAnim?.dispose();
    _appreciationOverlay?.remove();
    _appreciationOverlay = null;
    _idleTimer?.cancel();
    super.dispose();
  }

  void _toggleFavorite() {
    ScoreService().toggleFavorite(kColorConnectGameId);
    setState(() => _isFavorite = !_isFavorite);
  }

  void _showHelp() {
    final info = GameRegistry.getById(kColorConnectGameId);
    if (info == null) return;
    showHowToPlaySheet(context,
        title: info.name,
        howToPlay: info.howToPlay,
        accent: _kAccent,
        steps: colorConnectSteps(),
        gameId: kColorConnectGameId);
  }

  void _startGame(_Difficulty diff) async {
    final lps = LevelProgressService();
    _level = lps.getCurrentLevel(kColorConnectGameId, diff.subKey);

    final saved = lps.getGameState(kColorConnectGameId, diff.subKey);
    final hasSave = saved != null && saved['level'] == _level;

    bool shouldContinue = false;
    if (hasSave) {
      shouldContinue = await showContinueDialog(
        context,
        gameName: 'Color Connect',
        accentColor: diff.color,
        level: _level,
      );
      if (!mounted) return;
    }

    _gameOver = false;
    _won = false;
    _moves = 0;
    _hintsUsed = 0;
    _activeFlow = null;
    _generateLevel(diff);

    if (hasSave && shouldContinue) {
      final savedPaths = saved['paths'] as List?;
      if (savedPaths != null) {
        _paths = savedPaths.map((p) => List<int>.from(p as List)).toList();
      }
      _moves = saved['moves'] as int;
      _hintsUsed = (saved['hintsUsed'] as int?) ?? 0;
    } else {
      if (hasSave) lps.clearGameState(kColorConnectGameId, diff.subKey);
    }

    _resetIdleTimer();
    setState(() => _activeDifficulty = diff);
    GameWrapper.of(context)
        .setDifficultyAndMode(difficulty: diff.label, subKey: diff.subKey);
    GameWrapper.of(context).startGame();
    GameWrapper.of(context).updateScore(_level);
  }

  void _generateLevel(_Difficulty diff) {
    final result = gen.generateColorConnectLevel(_level, diff.index);
    _rows = result.rows;
    _cols = result.cols;
    _numFlows = result.numFlows;
    _endpoints = result.endpoints;
    _solution = result.solution;
    _paths = List.generate(_numFlows, (_) => <int>[]);
    _lastChangedFlow = -1;
  }

  void _animatePathChange(int flowIdx) {
    _lastChangedFlow = flowIdx;
    _pathAnim?.forward(from: 0.0);
  }

  int _cellIdx(int row, int col) => row * _cols + col;

  int? _flowAt(int cellIdx) {
    for (int f = 0; f < _numFlows; f++) {
      if (_paths[f].contains(cellIdx)) return f;
    }
    return null;
  }

  int? _endpointFlowAt(int cellIdx) {
    for (int f = 0; f < _numFlows; f++) {
      if (_endpoints[f * 2] == cellIdx || _endpoints[f * 2 + 1] == cellIdx) return f;
    }
    return null;
  }

  bool _isEndpoint(int cellIdx) {
    for (int f = 0; f < _numFlows; f++) {
      if (_endpoints[f * 2] == cellIdx || _endpoints[f * 2 + 1] == cellIdx) return true;
    }
    return false;
  }

  bool _adj(int a, int b) {
    final r1 = a ~/ _cols, c1 = a % _cols, r2 = b ~/ _cols, c2 = b % _cols;
    return (r1 == r2 && (c1 - c2).abs() == 1) ||
        (c1 == c2 && (r1 - r2).abs() == 1);
  }

  void _onPanStart(int cellIdx) {
    if (_gameOver || _won) return;
    final epFlow = _endpointFlowAt(cellIdx);
    if (epFlow != null) {
      _activeFlow = epFlow;
      final otherEp = _endpoints[epFlow * 2 + 1];
      if (_paths[epFlow].isNotEmpty && _paths[epFlow].last == otherEp) {
        _paths[epFlow] = [otherEp];
      } else {
        _paths[epFlow] = [cellIdx];
      }
      _isDragging = true;
      _animatePathChange(epFlow);
      setState(() {});
      AudioService().playTap();
      return;
    }
    final existingFlow = _flowAt(cellIdx);
    if (existingFlow != null) {
      _activeFlow = existingFlow;
      final idx = _paths[existingFlow].indexOf(cellIdx);
      if (idx >= 0) {
        _paths[existingFlow] = _paths[existingFlow].sublist(0, idx + 1);
      }
      _isDragging = true;
      setState(() {});
      return;
    }
  }

  void _onPanUpdate(int cellIdx) {
    if (!_isDragging || _activeFlow == null || _gameOver || _won) return;
    final f = _activeFlow!;
    final path = _paths[f];
    if (path.isEmpty) return;
    if (path.last == cellIdx) return;

    if (path.length >= 2 && path[path.length - 2] == cellIdx) {
      setState(() => path.removeLast());
      _animatePathChange(f);
      return;
    }

    if (!_adj(path.last, cellIdx)) return;

    if (_isEndpoint(cellIdx)) {
      final epf = _endpointFlowAt(cellIdx)!;
      if (epf != f) return;
      final ep0 = _endpoints[f * 2];
      final ep1 = _endpoints[f * 2 + 1];
      if (cellIdx != ep0 && cellIdx != ep1) return;
      if (path.first == cellIdx) return;
      setState(() {
        path.add(cellIdx);
        _moves++;
      });
      _animatePathChange(f);
      AudioService().playScore();
      _resetIdleTimer();
      _saveState();
      _checkWin();
      return;
    }

    for (int of = 0; of < _numFlows; of++) {
      if (of == f) continue;
      if (_paths[of].contains(cellIdx)) return;
    }

    if (path.contains(cellIdx)) return;

    setState(() {
      path.add(cellIdx);
      _moves++;
    });
    _animatePathChange(f);
    AudioService().playTap();
    _resetIdleTimer();
    _saveState();
  }

  void _onPanEnd() {
    _isDragging = false;
    _activeFlow = null;
  }

  void _checkWin() {
    final n = _rows * _cols;
    final filled = <bool>[...List.filled(n, false)];
    for (int f = 0; f < _numFlows; f++) {
      final ep0 = _endpoints[f * 2];
      final ep1 = _endpoints[f * 2 + 1];
      if (_paths[f].isEmpty) return;
      if (!(_paths[f].first == ep0 && _paths[f].last == ep1) &&
          !(_paths[f].first == ep1 && _paths[f].last == ep0)) {
        return;
      }
      for (final c in _paths[f]) {
        if (filled[c]) return;
        filled[c] = true;
      }
    }
    if (filled.any((f) => !f)) return;
    _won = true;
    _endGame(true);
  }

  void _endGame(bool won) {
    _won = won;
    if (won) {
      final diff = _activeDifficulty!;
      final lps = LevelProgressService();
      lps.advanceLevel(kColorConnectGameId, diff.subKey);
      lps.saveLevelBest(kColorConnectGameId, diff.subKey, _level, _moves);
      lps.clearGameState(kColorConnectGameId, diff.subKey);
      GameWrapper.of(context).updateScore(_level);
      AudioService().playSuccess();
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
    _activeFlow = null;
    _hintsUsed = 0;
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

  void _onHint() {
    if (_gameOver || _won) return;
    if (_hintsUsed >= _kMaxHints) return;
    if (!AdsService().isRewardedReady) {
      _applyHint();
      return;
    }
    AdsService().showRewarded(
      rewardType: RewardType.hint,
      gameId: kColorConnectGameId,
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

    int? incompleteFlow;
    for (int f = 0; f < _numFlows; f++) {
      final ep0 = _endpoints[f * 2];
      final ep1 = _endpoints[f * 2 + 1];
      if (_paths[f].isEmpty ||
          !((_paths[f].first == ep0 && _paths[f].last == ep1) ||
            (_paths[f].first == ep1 && _paths[f].last == ep0))) {
        incompleteFlow = f;
        break;
      }
    }
    if (incompleteFlow == null) return;

    final f = incompleteFlow;
    final ep0 = _endpoints[f * 2];

    final solPath = <int>[];
    for (int i = 0; i < _rows * _cols; i++) {
      if (_solution[i] == f) solPath.add(i);
    }

    final ordered = <int>[ep0];
    final visited = <int>{ep0};
    while (ordered.length < solPath.length) {
      final last = ordered.last;
      bool found = false;
      for (final c in solPath) {
        if (!visited.contains(c) && _adj(last, c)) {
          ordered.add(c);
          visited.add(c);
          found = true;
          break;
        }
      }
      if (!found) break;
    }

    setState(() {
      for (int of = 0; of < _numFlows; of++) {
        if (of != f) continue;
        _paths[of] = List.from(ordered);
      }
    });
    AudioService().playScore();
    _saveState();
    _checkWin();
  }

  void _restartLevel() {
    setState(() {
      _moves = 0;
      _gameOver = false;
      _won = false;
      _hintsUsed = 0;
      _activeFlow = null;
      _paths = List.generate(_numFlows, (_) => <int>[]);
    });
    if (_activeDifficulty != null) {
      LevelProgressService().clearGameState(kColorConnectGameId, _activeDifficulty!.subKey);
    }
    _resetIdleTimer();
    GameWrapper.of(context).restartGame();
    GameWrapper.of(context).startGame();
    GameWrapper.of(context).updateScore(_level);
  }

  void _saveState() {
    final diff = _activeDifficulty;
    if (diff == null || _gameOver || _won) return;
    bool hasActivity = false;
    for (final p in _paths) {
      if (p.isNotEmpty) {
        hasActivity = true;
        break;
      }
    }
    if (!hasActivity) return;
    LevelProgressService().saveGameState(kColorConnectGameId, diff.subKey, {
      'level': _level,
      'paths': _paths.map((p) => p.toList()).toList(),
      'moves': _moves,
      'hintsUsed': _hintsUsed,
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

  int _completedFlows() {
    int count = 0;
    for (int f = 0; f < _numFlows; f++) {
      final ep0 = _endpoints[f * 2];
      final ep1 = _endpoints[f * 2 + 1];
      if (_paths[f].isNotEmpty &&
          ((_paths[f].first == ep0 && _paths[f].last == ep1) ||
           (_paths[f].first == ep1 && _paths[f].last == ep0))) {
        count++;
      }
    }
    return count;
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
              bestScore: LevelProgressService()
                  .getHighestLevel(kColorConnectGameId, d.subKey),
              bestLabel: (s) => s <= 0 ? '' : 'Completed: Level $s',
            ))
        .toList();

    return GamePickerScaffold(
      bgColorTop: const Color(0xFFE8E5FF),
      bgColorBottom: const Color(0xFFD0CDFF),
      animatedBg: AnimatedBackground(
        factory: (t) => GenericAnimatedBgPainter(t,
            accent: _kAccent, icon: Icons.linear_scale_rounded),
      ),
      iconRingColors: const [_kAccent, Color(0xFF9775FA), Color(0xFF4A42DB)],
      iconChild: buildColorConnectLogo(60),
      title: 'Color Connect',
      subtitle: 'Link the dots, fill the grid!',
      onBack: _backOrHome,
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: _showHelp,
      gameId: kColorConnectGameId,
      body: GameSinglePickerBody(
        difficulties: diffs,
        activeIndex: _pickerDifficulty.index,
        onChanged: (i) =>
            setState(() => _pickerDifficulty = _Difficulty.values[i]),
        playLabel: 'Play Color Connect',
        playSubLabel:
            'Level ${LevelProgressService().getCurrentLevel(kColorConnectGameId, _pickerDifficulty.subKey)}',
        onPlay: () => _startGame(_pickerDifficulty),
        accentColor: _kAccent,
      ),
    );
  }

  Widget _buildGame() {
    final diff = _activeDifficulty!;
    return Container(
      color: const Color(0xFFF8F9FE),
      child: SafeArea(
        child: Column(
          children: [
            GameHudBar(
              leading: GameBackButton(
                onTap: _backOrHome,
                bgColor: const Color(0xFFE8E5FF),
                iconColor: const Color(0xFF4A42DB),
              ),
              centerContent: _buildHud(diff),
              trailing: GameRestartButton(
                gameName: 'Color Connect',
                accentColor: diff.color,
                onRestart: _restartLevel,
                bgColor: const Color(0xFFE8E5FF),
                iconColor: const Color(0xFF4A42DB),
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
            _buildFlowProgress(),
            const SizedBox(height: 4),
            Visibility(
              visible: !_gameOver && !_won && _hintsUsed < _kMaxHints,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: _CCHintNudge(onTap: _onHint, isStuck: _idleStuck),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildHud(_Difficulty diff) {
    final clr = diff.color;
    final shadowClr = Color.lerp(clr, Colors.black, 0.40)!;
    const hudShadow = Color(0xFFCBC8EE);
    return IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(
              color: clr,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
              boxShadow: [
                BoxShadow(
                    color: shadowClr,
                    blurRadius: 8,
                    offset: const Offset(0, 3))
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedDifficultyIcon(
                    kind: diff.kind, size: 14, prominent: false),
                const SizedBox(width: 6),
                Text(diff.label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                    color: hudShadow,
                    blurRadius: 12,
                    offset: Offset(0, 6))
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _statCol('LEVEL', '$_level', clr),
                Container(
                    width: 1,
                    height: 24,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: Colors.grey.shade200),
                _statCol('FLOWS', '${_completedFlows()}/$_numFlows', clr),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCol(String label, String value, Color c) {
    final muted = Color.lerp(c, const Color(0xFFF8F9FE), 0.45)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: muted,
                letterSpacing: 1.0)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: c,
                height: 1)),
      ]),
    );
  }

  Widget _buildFlowProgress() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: List.generate(_numFlows, (f) {
          final ep0 = _endpoints[f * 2];
          final ep1 = _endpoints[f * 2 + 1];
          final complete = _paths[f].isNotEmpty &&
              ((_paths[f].first == ep0 && _paths[f].last == ep1) ||
               (_paths[f].first == ep1 && _paths[f].last == ep0));
          final fi = f % _kFlowPalette.length;
          final color = _kFlowPalette[fi];
          final light = _kFlowLight[fi];
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            width: complete ? 20 : 18,
            height: complete ? 20 : 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: complete ? color : light,
              border: Border.all(
                color: complete ? color : Color.lerp(color, light, 0.40)!,
                width: 1.5,
              ),
            ),
            child: complete
                ? const Icon(Icons.check_rounded, size: 11, color: Colors.white)
                : null,
          );
        }),
      ),
    );
  }

  Widget _buildGrid(BoxConstraints con) {
    final maxSz = math.min(con.maxWidth, con.maxHeight - 16);
    const pad = 6.0;
    final gap = _rows <= 5 ? 3.0 : (_rows <= 7 ? 2.5 : 2.0);
    final cellSz = (maxSz - 2 * pad - (_cols - 1) * gap) / _cols;
    final gridW = cellSz * _cols + gap * (_cols - 1);
    final gridH = cellSz * _rows + gap * (_rows - 1);

    return GestureDetector(
      onPanStart: (d) => _handlePan(d.localPosition, cellSz, gap, gridW, gridH, pad, true),
      onPanUpdate: (d) => _handlePan(d.localPosition, cellSz, gap, gridW, gridH, pad, false),
      onPanEnd: (_) => _onPanEnd(),
      child: Container(
        key: const Key('cc_grid'),
        width: gridW + 2 * pad,
        height: gridH + 2 * pad,
        padding: const EdgeInsets.all(pad),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F1F8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD0CDFF), width: 1.5),
          boxShadow: const [
            BoxShadow(
                color: Color(0xFFDBD9EC),
                blurRadius: 12,
                offset: Offset(0, 4))
          ],
        ),
        child: AnimatedBuilder(
          animation: _pathAnim!,
          builder: (_, _) => CustomPaint(
            painter: _CCGridPainter(
              rows: _rows,
              cols: _cols,
              cellSize: cellSz,
              gap: gap,
              numFlows: _numFlows,
              endpoints: _endpoints,
              paths: _paths,
              flowColors: _kFlowPalette,
              flowLightColors: _kFlowLight,
              flowDarkColors: _kFlowDark,
              won: _won,
              animProgress: _pathAnim!.value,
              animFlow: _lastChangedFlow,
            ),
            size: Size(gridW, gridH),
          ),
        ),
      ),
    );
  }

  (int, int)? _hit(Offset pos, double cs, double gap, double gw, double gh, double pad) {
    final p = Offset(pos.dx - pad, pos.dy - pad);
    if (p.dx < 0 || p.dy < 0 || p.dx > gw || p.dy > gh) return null;
    final col = (p.dx / (cs + gap)).floor().clamp(0, _cols - 1);
    final row = (p.dy / (cs + gap)).floor().clamp(0, _rows - 1);
    final cx = col * (cs + gap) + cs / 2;
    final cy = row * (cs + gap) + cs / 2;
    if (math.sqrt(math.pow(p.dx - cx, 2) + math.pow(p.dy - cy, 2)) > cs * 0.85) {
      return null;
    }
    return (row, col);
  }

  void _handlePan(Offset pos, double cs, double gap, double gw, double gh, double pad, bool isStart) {
    if (_gameOver || _won) return;
    final h = _hit(pos, cs, gap, gw, gh, pad);
    if (h == null) return;
    final (row, col) = h;
    final ci = _cellIdx(row, col);
    if (isStart) {
      _onPanStart(ci);
    } else {
      _onPanUpdate(ci);
    }
  }

  Widget _buildResult() {
    final diff = _activeDifficulty!;
    return game_result.GenericGameResultScreen(
      headline: _won ? 'Level $_level Complete!' : 'Stuck!',
      subtitle: _won ? '$_moves moves' : 'Try again or restart',
      badgeContent: _won ? '⚡' : '😔',
      badgeColor: diff.color,
      showNewBestBadge: false,
      gameId: kColorConnectGameId,
      score: _level,
      statsWidget: game_result.GameResultStatsRow(stats: [
        game_result.StatItem(
            label: 'LEVEL', value: _level, color: diff.color),
        game_result.StatItem(
            label: 'MOVES', value: _moves, color: const Color(0xFF6B7280)),
      ]),
      actions: [
        if (_won)
          game_result.GameResultAction(
              label: 'Next Level',
              icon: Icons.arrow_forward_rounded,
              onTap: _nextLevel,
              filled: true,
              color: diff.color,
              actionId: 'play_again')
        else
          game_result.GameResultAction(
              label: 'Retry Level',
              icon: Icons.refresh_rounded,
              onTap: _restartLevel,
              filled: true,
              color: diff.color,
              actionId: 'play_again'),
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
        game_result.GameResultAction(
            label: 'Home',
            icon: Icons.home_rounded,
            onTap: () => context.go('/home'),
            actionId: 'home',
            filled: false),
      ],
    );
  }
}

class _CCGridPainter extends CustomPainter {
  final int rows;
  final int cols;
  final double cellSize;
  final double gap;
  final int numFlows;
  final List<int> endpoints;
  final List<List<int>> paths;
  final List<Color> flowColors;
  final List<Color> flowLightColors;
  final List<Color> flowDarkColors;
  final bool won;
  final double animProgress;
  final int animFlow;

  _CCGridPainter({
    required this.rows,
    required this.cols,
    required this.cellSize,
    required this.gap,
    required this.numFlows,
    required this.endpoints,
    required this.paths,
    required this.flowColors,
    required this.flowLightColors,
    required this.flowDarkColors,
    required this.won,
    required this.animProgress,
    required this.animFlow,
  });

  Offset _center(int ci) => Offset(
        (ci % cols) * (cellSize + gap) + cellSize / 2,
        (ci ~/ cols) * (cellSize + gap) + cellSize / 2,
      );

  @override
  void paint(Canvas canvas, Size size) {
    final cellOwner = List<int>.filled(rows * cols, -1);
    for (int f = 0; f < numFlows; f++) {
      for (final ci in paths[f]) {
        if (ci >= 0 && ci < cellOwner.length) cellOwner[ci] = f;
      }
    }

    final rad = Radius.circular(cellSize * 0.18);
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final x = c * (cellSize + gap);
        final y = r * (cellSize + gap);
        final ci = r * cols + c;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, cellSize, cellSize),
          rad,
        );
        final owner = cellOwner[ci];
        if (owner >= 0) {
          final fi = owner % flowLightColors.length;
          canvas.drawRRect(rect, Paint()..color = flowLightColors[fi]);
        } else {
          canvas.drawRRect(rect, Paint()..color = const Color(0xFFE8E8F0));
        }
      }
    }

    final lineW = cellSize * 0.40;
    for (int f = 0; f < numFlows; f++) {
      final fi = f % flowColors.length;
      final color = flowColors[fi];
      final dark = flowDarkColors[fi];
      final path = paths[f];
      if (path.length >= 2) {
        final p = Path();
        final first = _center(path[0]);
        p.moveTo(first.dx, first.dy);

        final isAnimating = f == animFlow && animProgress < 1.0;
        final segCount = isAnimating ? path.length - 1 : path.length;

        for (int i = 1; i < segCount; i++) {
          final pt = _center(path[i]);
          p.lineTo(pt.dx, pt.dy);
        }

        if (isAnimating && path.length >= 2) {
          final prev = _center(path[path.length - 2]);
          final curr = _center(path[path.length - 1]);
          final t = Curves.easeOutCubic.transform(animProgress);
          p.lineTo(
            prev.dx + (curr.dx - prev.dx) * t,
            prev.dy + (curr.dy - prev.dy) * t,
          );
        }

        final gridEnd = Offset(
          (cols - 1) * (cellSize + gap) + cellSize / 2,
          (rows - 1) * (cellSize + gap) + cellSize / 2,
        );
        canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = lineW
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..shader = ui.Gradient.linear(
              Offset.zero,
              gridEnd,
              [color, dark],
            ),
        );
      } else if (path.length == 1) {
        final pt = _center(path[0]);
        canvas.drawCircle(
            pt, cellSize * 0.18, Paint()..color = flowLightColors[fi]);
      }
    }

    final dotR = cellSize * 0.28;
    final highlightR = dotR * 0.42;
    for (int f = 0; f < numFlows; f++) {
      final fi = f % flowColors.length;
      final color = flowColors[fi];
      final ep0 = endpoints[f * 2];
      final ep1 = endpoints[f * 2 + 1];
      for (final ep in [ep0, ep1]) {
        final pt = _center(ep);
        canvas.drawCircle(
            pt.translate(0, 1.0), dotR + 1, Paint()..color = const Color(0xFFCCCCD4));
        canvas.drawCircle(pt, dotR, Paint()..color = color);
        canvas.drawCircle(
            Offset(pt.dx - dotR * 0.18, pt.dy - dotR * 0.18),
            highlightR,
            Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(_CCGridPainter old) =>
      animProgress != old.animProgress ||
      animFlow != old.animFlow ||
      won != old.won ||
      paths != old.paths;
}

class _CCHintNudge extends StatelessWidget {
  final VoidCallback onTap;
  final bool isStuck;
  const _CCHintNudge({required this.onTap, required this.isStuck});

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
                boxShadow: const [
                  BoxShadow(
                      color: Color(0xFFE8C84C),
                      blurRadius: 12,
                      offset: Offset(0, 3))
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lightbulb_rounded, size: 16, color: _kFg),
                  const SizedBox(width: 6),
                  const Text('HINT',
                      style: TextStyle(
                          color: _kFg,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          height: 1)),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                        color: const Color(0xFFE8C978),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded, size: 12, color: _kFg),
                        SizedBox(width: 2),
                        Text('AD',
                            style: TextStyle(
                                color: _kFg,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                                height: 1)),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0xFF9E7ECC),
                            blurRadius: 8,
                            offset: Offset(0, 2)),
                      ],
                    ),
                    child: const Text('Stuck? Try a hint!',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3)),
                  ),
                  CustomPaint(
                      size: const Size(14, 7),
                      painter: _BubbleTailPainter()),
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

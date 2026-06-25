import 'dart:async';
import 'dart:math' as math;

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
import '../shared/game_control_buttons.dart';
import '../shared/game_difficulty_picker.dart';
import '../shared/game_hud_bar.dart';
import '../shared/generic_game_result_screen.dart' as game_result;
import '../shared/continue_dialog.dart';
import '../shared/level_complete_overlay.dart';
import 'block_escape_level_gen.dart';
import 'block_escape_logo.dart';
import 'block_escape_tutorial.dart';

const kBlockEscapeGameId = 'block_escape';

const _kAccent = Color(0xFFE74C3C);
const _kBg = Color(0xFFC4956A);
const _kBoardBg = Color(0xFF5C3D2E);
const _kBoardBorder = Color(0xFFA67C5B);
const _kBlockColor = Color(0xFFE8A838);
const _kBlockHighlight = Color(0xFFEEC060);
const _kTargetColor = Color(0xFFE74C3C);
const _kTargetHighlight = Color(0xFFF07070);
const _kEasyColor = Color(0xFF22C55E);
const _kMediumColor = Color(0xFFF59E0B);
const _kHardColor = Color(0xFFEF4444);

enum _Difficulty { easy, medium, hard }

extension _DifficultyX on _Difficulty {
  String get label => ['EASY', 'MEDIUM', 'HARD'][index];
  Color get color => [_kEasyColor, _kMediumColor, _kHardColor][index];
  DifficultyKind get kind => [DifficultyKind.easy, DifficultyKind.medium, DifficultyKind.hard][index];
  String get hint => ['Few blocks · short solutions', 'More blocks · plan ahead', 'Packed board · tricky exits'][index];
  String get subKey => ['easy', 'medium', 'hard'][index];
}

class BlockEscapeScreen extends StatefulWidget {
  const BlockEscapeScreen({super.key});

  @override
  State<BlockEscapeScreen> createState() => _BlockEscapeScreenState();
}

class _BlockEscapeScreenState extends State<BlockEscapeScreen> with TickerProviderStateMixin {
  _Difficulty? _activeDifficulty;
  _Difficulty _pickerDifficulty = _Difficulty.values[DifficultyKind.defaultIndex];
  bool _isFavorite = false;

  int _level = 1;
  int _moves = 0;
  int _hintsUsed = 0;
  bool _gameOver = false;
  bool _won = false;

  late List<Block> _blocks;
  int _rows = 6;
  int _cols = 6;
  int _exitRow = 2;
  List<(int blockId, int delta)> _solution = [];

  int? _selectedBlockId;
  Offset? _dragStart;
  final ValueNotifier<double> _dragNotifier = ValueNotifier<double>(0);
  int _dragMinCells = 0;
  int _dragMaxCells = 0;
  bool _isSliding = false;
  int _slidingBlockId = -1;
  double _slideFrom = 0;
  double _slideTo = 0;
  int _slideMoveDelta = 0;
  late final AnimationController _slideAnim;

  Timer? _idleTimer;
  bool _idleStuck = false;
  static const _kMaxHints = 3;
  static const _kIdleTimeout = Duration(seconds: 12);
  int? _hintBlockId;
  int? _hintDelta;
  late final AnimationController _hintAnim;
  OverlayEntry? _appreciationOverlay;

  @override
  void initState() {
    super.initState();
    _blocks = [];
    _isFavorite = ScoreService().isFavorite(kBlockEscapeGameId);
    _hintAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _slideAnim = AnimationController(vsync: this)
      ..addListener(_onSlideFrame)
      ..addStatusListener(_onSlideStatus);
  }

  @override
  void dispose() {
    _appreciationOverlay?.remove();
    _idleTimer?.cancel();
    _hintAnim.dispose();
    _slideAnim.dispose();
    _dragNotifier.dispose();
    super.dispose();
  }

  void _toggleFavorite() {
    ScoreService().toggleFavorite(kBlockEscapeGameId);
    setState(() => _isFavorite = !_isFavorite);
  }

  void _showHelp() {
    final info = GameRegistry.getById(kBlockEscapeGameId);
    if (info == null) return;
    showHowToPlaySheet(
      context,
      title: info.name,
      howToPlay: info.howToPlay,
      accent: _kAccent,
      steps: blockEscapeSteps(),
      gameId: kBlockEscapeGameId,
    );
  }

  void _startGame(_Difficulty diff) async {
    final lps = LevelProgressService();
    _level = lps.getCurrentLevel(kBlockEscapeGameId, diff.subKey);

    final saved = lps.getGameState(kBlockEscapeGameId, diff.subKey);
    final hasSave = saved != null && saved['level'] == _level;

    bool shouldContinue = false;
    if (hasSave) {
      shouldContinue = await showContinueDialog(
        context,
        gameName: 'Block Escape',
        accentColor: diff.color,
        level: _level,
      );
      if (!mounted) return;
    }

    _gameOver = false;
    _won = false;
    _moves = 0;
    _hintsUsed = 0;
    _hintBlockId = null;
    _hintDelta = null;
    _generateLevel(diff);

    if (hasSave && shouldContinue) {
      _moves = saved['moves'] as int;
      _hintsUsed = (saved['hintsUsed'] as int?) ?? 0;
      final blocksData = saved['blocks'] as List;
      _blocks = blocksData.map((b) => Block(
        id: b['id'] as int,
        row: b['row'] as int,
        col: b['col'] as int,
        length: b['length'] as int,
        dir: BlockDir.values[b['dir'] as int],
        isTarget: b['isTarget'] as bool,
      )).toList();
    } else {
      if (hasSave) lps.clearGameState(kBlockEscapeGameId, diff.subKey);
    }

    _resetIdleTimer();
    setState(() => _activeDifficulty = diff);
    GameWrapper.of(context).setDifficultyAndMode(difficulty: diff.label, subKey: diff.subKey);
    GameWrapper.of(context).startGame();
    GameWrapper.of(context).updateScore(_level);
  }

  void _generateLevel(_Difficulty diff) {
    final level = generateBlockEscapeLevel(_level, diff.index);
    _rows = level.rows;
    _cols = level.cols;
    _exitRow = level.exitRow;
    _blocks = level.blocks;
    _solution = level.solution;
    _selectedBlockId = null;
  }

  void _restartLevel() {
    final diff = _activeDifficulty!;
    setState(() {
      _moves = 0;
      _hintsUsed = 0;
      _gameOver = false;
      _won = false;
      _hintBlockId = null;
      _hintDelta = null;
      _selectedBlockId = null;
    });
    _hintAnim.stop();
    _generateLevel(diff);
    LevelProgressService().clearGameState(kBlockEscapeGameId, diff.subKey);
    _resetIdleTimer();
    GameWrapper.of(context).restartGame();
    GameWrapper.of(context).startGame();
    GameWrapper.of(context).updateScore(_level);
  }

  int _maxDelta(int blockId, int direction) {
    int delta = 0;
    final limit = math.max(_rows, _cols);
    while (delta.abs() < limit && _canMoveBlock(blockId, delta + direction)) {
      delta += direction;
    }
    return delta;
  }

  bool _canMoveBlock(int blockId, int delta) {
    final block = _blocks.firstWhere((b) => b.id == blockId);
    final moved = block.moved(delta);
    for (final (r, c) in moved.cells) {
      if (block.isTarget && block.dir == BlockDir.horizontal && c >= _cols) {
        continue;
      }
      if (r < 0 || r >= _rows || c < 0 || c >= _cols) return false;
    }
    for (final other in _blocks) {
      if (other.id == blockId) continue;
      for (final (r, c) in moved.cells) {
        if (r < 0 || r >= _rows || c < 0 || c >= _cols) continue;
        for (final (or, oc) in other.cells) {
          if (r == or && c == oc) return false;
        }
      }
    }
    return true;
  }

  void _applyMove(int blockId, int delta) {
    if (delta == 0) return;
    final idx = _blocks.indexWhere((b) => b.id == blockId);
    if (idx < 0) return;
    _blocks[idx] = _blocks[idx].moved(delta);
    _moves++;
    _hintBlockId = null;
    _hintDelta = null;
    _hintAnim.stop();
    AudioService().playTap();
    _resetIdleTimer();
    _saveState();
    _checkWin();
    setState(() {});
  }

  void _startSlide(int blockId, double fromPx, double toPx, int moveDelta, double cell) {
    _slidingBlockId = blockId;
    _slideFrom = fromPx;
    _slideTo = toPx;
    _slideMoveDelta = moveDelta;
    _isSliding = true;
    final dist = (toPx - fromPx).abs();
    final ms = (dist / cell * 80 + 60).clamp(80.0, 350.0).toInt();
    _slideAnim.duration = Duration(milliseconds: ms);
    _slideAnim.forward(from: 0);
  }

  void _onSlideFrame() {
    final t = Curves.easeOutCubic.transform(_slideAnim.value);
    _dragNotifier.value = _slideFrom + (_slideTo - _slideFrom) * t;
  }

  void _onSlideStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _isSliding = false;
    final blockId = _slidingBlockId;
    final delta = _slideMoveDelta;
    _selectedBlockId = null;
    _slidingBlockId = -1;
    _dragNotifier.value = 0;
    if (delta != 0) {
      _applyMove(blockId, delta);
    } else {
      setState(() {});
    }
  }

  void _checkWin() {
    final target = _blocks.firstWhere((b) => b.isTarget);
    if (target.col + target.length >= _cols) {
      _won = true;
      final diff = _activeDifficulty!;
      final score = _moves + _hintsUsed * 3;
      final lps = LevelProgressService();
      lps.advanceLevel(kBlockEscapeGameId, diff.subKey);
      lps.saveLevelBest(kBlockEscapeGameId, diff.subKey, _level, score);
      lps.clearGameState(kBlockEscapeGameId, diff.subKey);
      GameWrapper.of(context).updateScore(_level);
      AudioService().playSuccess();
      _showAppreciation();
    }
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
    _hintBlockId = null;
    _hintDelta = null;
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
      gameId: kBlockEscapeGameId,
      onRewarded: (_) {
        if (mounted) _applyHint();
      },
    );
  }

  void _applyHint() {
    if (_solution.isEmpty) return;
    // Fast int-grid solver (block_escape_level_gen), node-capped so it can
    // never freeze the UI thread on a dense Hard board.
    final move = blockEscapeHintMove(_blocks, _rows, _cols);
    if (move == null) return;
    setState(() {
      _hintsUsed++;
      _idleStuck = false;
      _hintBlockId = move.$1;
      _hintDelta = move.$2;
    });
    _hintAnim.forward(from: 0).then((_) {
      if (mounted) _hintAnim.repeat(reverse: true);
    });
    _saveState();
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
    LevelProgressService().saveGameState(kBlockEscapeGameId, diff.subKey, {
      'level': _level,
      'moves': _moves,
      'hintsUsed': _hintsUsed,
      'blocks': _blocks.map((b) => {
        'id': b.id,
        'row': b.row,
        'col': b.col,
        'length': b.length,
        'dir': b.dir.index,
        'isTarget': b.isTarget,
      }).toList(),
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
              bestScore: LevelProgressService().getHighestLevel(kBlockEscapeGameId, d.subKey),
              bestLabel: (s) => s <= 0 ? '' : 'Completed: Level $s',
            ))
        .toList();
    return GamePickerScaffold(
      bgColorTop: const Color(0xFFFFF8F0),
      bgColorBottom: const Color(0xFFFFF0E6),
      animatedBg: AnimatedBackground(factory: (t) => GenericAnimatedBgPainter(t, accent: _kAccent, icon: Icons.lock_open_rounded)),
      iconRingColors: const [_kAccent, Color(0xFFE0C5A5), Color(0xFF5C3D2E)],
      iconChild: buildBlockEscapeLogo(60),
      title: 'Block Escape',
      subtitle: 'Slide blocks and free the red piece!',
      onBack: _backOrHome,
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: _showHelp,
      gameId: kBlockEscapeGameId,
      body: GameSinglePickerBody(
        difficulties: diffs,
        activeIndex: _pickerDifficulty.index,
        onChanged: (i) => setState(() => _pickerDifficulty = _Difficulty.values[i]),
        playLabel: 'Play Block Escape',
        playSubLabel: 'Level ${LevelProgressService().getCurrentLevel(kBlockEscapeGameId, _pickerDifficulty.subKey)}',
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
        child: Column(children: [
          GameHudBar(
            leading: GameBackButton(onTap: _backOrHome),
            centerContent: _buildHudPill(diff),
            trailing: GameRestartButton(gameName: 'Block Escape', accentColor: diff.color, onRestart: _restartLevel),
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
            child: IgnorePointer(ignoring: _gameOver || _won || _hintsUsed >= _kMaxHints, child: _BlockEscapeHintNudge(onTap: _onHint, isStuck: _idleStuck)),
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  Widget _buildHudPill(_Difficulty diff) {
    final clr = diff.color;
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
          _statCol('MOVES', '$_moves', const Color(0xFF6B7280)),
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
    final exitGateWidth = 24.0;
    final maxBoardW = c.maxWidth - exitGateWidth;
    final maxBoardH = c.maxHeight;
    final cellW = maxBoardW / _cols;
    final cellH = maxBoardH / _rows;
    final cell = math.min(cellW, cellH);
    final boardW = cell * _cols;
    final boardH = cell * _rows;
    final borderRadius = cell * 0.25;
    final gap = cell * 0.06;

    return Center(
      child: SizedBox(
        key: const Key('block_escape_board'),
        width: boardW + exitGateWidth,
        height: boardH,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: boardW,
              height: boardH,
              decoration: BoxDecoration(
                color: _kBoardBg,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(color: _kBoardBorder, width: 3),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))],
              ),
            ),
            Positioned(
              left: boardW - 3,
              top: _exitRow * cell,
              child: CustomPaint(
                size: Size(exitGateWidth + 6, cell),
                painter: _ExitGatePainter(cell: cell),
              ),
            ),
            ..._blocks.map((block) {
              final isHinted = _hintBlockId == block.id;
              return _buildBlockWidget(block, cell, gap, boardW, isHinted);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockWidget(Block block, double cell, double gap, double boardW, bool isHinted) {
    final isTarget = block.isTarget;
    final baseColor = isTarget ? _kTargetColor : _kBlockColor;
    final highlightColor = isTarget ? _kTargetHighlight : _kBlockHighlight;

    double w, h;
    if (block.dir == BlockDir.horizontal) {
      w = cell * block.length - gap * 2;
      h = cell - gap * 2;
    } else {
      w = cell - gap * 2;
      h = cell * block.length - gap * 2;
    }

    // Base grid position. The live drag offset is applied via Transform on the
    // selected block only (see below) so a drag never repositions the rest.
    final double left = block.col * cell + gap;
    final double top = block.row * cell + gap;

    final Widget body = Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [highlightColor, baseColor],
        ),
        borderRadius: BorderRadius.circular(cell * 0.18),
        border: Border.all(color: baseColor.withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.30), blurRadius: 4, offset: const Offset(0, 3)),
        ],
      ),
      child: isTarget
          ? Center(child: Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.9), size: math.min(w, h) * 0.5))
          : null,
    );

    // Only the hinted piece animates; every other block is static, so a pulsing
    // hint no longer rebuilds/repaints the whole board each frame.
    final Widget blockContent = isHinted
        ? AnimatedBuilder(
            animation: _hintAnim,
            child: body,
            builder: (context, child) {
              final hintOffset = math.sin(_hintAnim.value * math.pi * 2) * cell * 0.08;
              final direction = _hintDelta != null ? (_hintDelta! > 0 ? 1.0 : -1.0) : 0.0;
              final hintDx = block.dir == BlockDir.horizontal ? hintOffset * direction : 0.0;
              final hintDy = block.dir == BlockDir.vertical ? hintOffset * direction : 0.0;
              return Transform.translate(offset: Offset(hintDx, hintDy), child: child);
            },
          )
        : body;

    final Widget gesture = GestureDetector(
      onPanStart: _won || _gameOver || _isSliding ? null : (d) {
        _dragStart = d.globalPosition;
        _dragNotifier.value = 0;
        _dragMinCells = _maxDelta(block.id, -1);
        _dragMaxCells = _maxDelta(block.id, 1);
        _selectedBlockId = block.id;
      },
      onPanUpdate: _won || _gameOver || _isSliding ? null : (d) {
        if (_isSliding || _selectedBlockId != block.id) return;
        final dx = d.globalPosition.dx - (_dragStart?.dx ?? 0);
        final dy = d.globalPosition.dy - (_dragStart?.dy ?? 0);
        final rawDelta = block.dir == BlockDir.horizontal ? dx : dy;
        final clampedCells = (rawDelta / cell).clamp(
            _dragMinCells.toDouble(), _dragMaxCells.toDouble());
        _dragNotifier.value = clampedCells * cell;
      },
      onPanEnd: _won || _gameOver ? null : (d) {
        if (_isSliding || _selectedBlockId != block.id) return;
        final currentDrag = _dragNotifier.value;
        final snappedCells = (currentDrag / cell).round().clamp(
            _dragMinCells, _dragMaxCells);
        if (snappedCells == 0) {
          _startSlide(block.id, currentDrag, 0, 0, cell);
        } else {
          _startSlide(block.id, currentDrag, snappedCells * cell, snappedCells, cell);
        }
      },
      child: blockContent,
    );

    // Every block carries the same ValueListenableBuilder so the tree shape is
    // identical whether or not it's being dragged — flipping selection never
    // restructures the subtree under an active pointer. At rest (drag == 0) and
    // for non-selected blocks the builder returns the cached child untouched, so
    // only the piece under the finger actually translates while dragging.
    return Positioned(
      left: left,
      top: top,
      child: ValueListenableBuilder<double>(
        valueListenable: _dragNotifier,
        child: gesture,
        builder: (context, drag, child) {
          final isActive = _selectedBlockId == block.id || _slidingBlockId == block.id;
          final d = isActive ? drag : 0.0;
          final dx = block.dir == BlockDir.horizontal ? d : 0.0;
          final dy = block.dir == BlockDir.vertical ? d : 0.0;
          return Transform.translate(offset: Offset(dx, dy), child: child);
        },
      ),
    );
  }

  Widget _buildResult() {
    final diff = _activeDifficulty!;
    return game_result.GenericGameResultScreen(
      headline: _won ? 'Level $_level Complete!' : 'Try Again',
      subtitle: _won ? 'Escaped in $_moves moves' : 'Slide the blocks and free the red piece',
      badgeContent: _won ? '🚗' : '🧩',
      badgeColor: diff.color,
      showNewBestBadge: false,
      gameId: kBlockEscapeGameId,
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
}

class _BlockEscapeHintNudge extends StatelessWidget {
  final VoidCallback onTap;
  final bool isStuck;
  const _BlockEscapeHintNudge({required this.onTap, required this.isStuck});
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

class _ExitGatePainter extends CustomPainter {
  final double cell;
  _ExitGatePainter({required this.cell});

  static const _gateRed = Color(0xFFC0392B);
  static const _gateDarkRed = Color(0xFF922B21);
  static const _gateHighlight = Color(0xFFE74C3C);
  static const _barColor = Color(0xFF7B241C);
  static const _gold = Color(0xFFD4A017);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final pad = cell * 0.06;
    final gateTop = pad;
    final gateBot = h - pad;
    final gateH = gateBot - gateTop;
    final barW = cell * 0.04;

    canvas.drawRect(Rect.fromLTWH(0, 0, 6, h), Paint()..color = _kBoardBg);

    final gateRect = Rect.fromLTWH(3, gateTop, w - 3, gateH);
    canvas.drawRect(
      gateRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [_gateHighlight, _gateRed, _gateDarkRed],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(gateRect),
    );

    canvas.drawRect(
      gateRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.black.withValues(alpha: 0.15),
            Colors.transparent,
            Colors.white.withValues(alpha: 0.10),
          ],
        ).createShader(gateRect),
    );

    final railPaint = Paint()..color = _barColor;
    final railH = cell * 0.07;
    canvas.drawRRect(
      RRect.fromLTRBR(3, gateTop, w, gateTop + railH, const Radius.circular(1)),
      railPaint,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(3, gateBot - railH, w, gateBot, const Radius.circular(1)),
      railPaint,
    );

    final innerTop = gateTop + railH;
    final innerBot = gateBot - railH;
    final innerH = innerBot - innerTop;
    final barPaint = Paint()
      ..color = _barColor
      ..strokeWidth = barW
      ..strokeCap = StrokeCap.round;
    final barCount = 3;
    for (int i = 0; i < barCount; i++) {
      final x = 3 + (w - 3) * (i + 1) / (barCount + 1);
      canvas.drawLine(Offset(x, innerTop), Offset(x, innerBot), barPaint);
      canvas.drawLine(
        Offset(x + 0.5, innerTop),
        Offset(x + 0.5, innerBot),
        Paint()..color = Colors.white.withValues(alpha: 0.12)..strokeWidth = 0.5,
      );
    }

    final xPaint = Paint()
      ..color = _barColor
      ..strokeWidth = barW * 0.8
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i <= barCount; i++) {
      final lx = 3 + (w - 3) * i / (barCount + 1);
      final rx = 3 + (w - 3) * (i + 1) / (barCount + 1);
      final midY = innerTop + innerH * 0.5;
      canvas.drawLine(Offset(lx, innerTop), Offset(rx, midY), xPaint);
      canvas.drawLine(Offset(lx, midY), Offset(rx, innerBot), xPaint);
      canvas.drawLine(Offset(lx, midY), Offset(rx, innerTop), xPaint);
      canvas.drawLine(Offset(lx, innerBot), Offset(rx, midY), xPaint);
    }

    final hingePaint = Paint()..color = _gold;
    final hingeW = cell * 0.06;
    final hingeH = cell * 0.10;
    for (final y in [gateTop + gateH * 0.2, gateTop + gateH * 0.8]) {
      final hingeRect = RRect.fromLTRBR(
        1, y - hingeH / 2, 1 + hingeW, y + hingeH / 2, Radius.circular(hingeW * 0.3),
      );
      canvas.drawRRect(hingeRect, hingePaint);
      canvas.drawRRect(
        hingeRect,
        Paint()..color = Colors.white.withValues(alpha: 0.25)..style = PaintingStyle.stroke..strokeWidth = 0.5,
      );
    }

    final framePaint = Paint()
      ..color = _kBoardBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(Rect.fromLTWH(3, gateTop, w - 3, gateH), framePaint);

    final arrowX = w - cell * 0.12;
    final arrowY = h / 2;
    final arrowS = cell * 0.18;
    final arrowPath = Path()
      ..moveTo(arrowX - arrowS, arrowY - arrowS)
      ..lineTo(arrowX, arrowY)
      ..lineTo(arrowX - arrowS, arrowY + arrowS);
    canvas.drawPath(
      arrowPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.80)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.045
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ExitGatePainter old) => old.cell != cell;
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

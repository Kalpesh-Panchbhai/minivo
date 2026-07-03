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
import 'arrow_puzzle_logo.dart';
import 'arrow_puzzle_level_gen.dart' as gen;
import 'arrow_puzzle_tutorial.dart';

const kArrowPuzzleGameId = 'arrow_puzzle';

const _kAccent = Color(0xFF7C3AED);
const _kEasyColor = Color(0xFF22C55E);
const _kMediumColor = Color(0xFFF59E0B);
const _kHardColor = Color(0xFFEF4444);

const _kBgTop = Color(0xFFF8FAFC);
const _kBgBot = Color(0xFFEDE9FE);

const _kDirColors = [
  Color(0xFF3B82F6),
  Color(0xFFF97316),
  Color(0xFF0D9488),
  Color(0xFF7C3AED),
];

enum _Difficulty { easy, medium, hard }

extension _DifficultyX on _Difficulty {
  String get label => ['EASY', 'MEDIUM', 'HARD'][index];
  Color get color => [_kEasyColor, _kMediumColor, _kHardColor][index];
  DifficultyKind get kind => [DifficultyKind.easy, DifficultyKind.medium, DifficultyKind.hard][index];
  String get hint => ['Relaxed', 'Tricky', 'Intense'][index];
  String get subKey => ['easy', 'medium', 'hard'][index];
}

enum _ArrowDir { up, down, left, right }

extension _ArrowDirX on _ArrowDir {
  Offset get vec => [const Offset(0, -1), const Offset(0, 1), const Offset(-1, 0), const Offset(1, 0)][index];
  Color get color => _kDirColors[index];
}

class _Arrow {
  final int id;
  final List<Offset> segments;
  final _ArrowDir headDir;
  bool freed = false;
  double flyProgress = 0;
  _Arrow({required this.id, required this.segments, required this.headDir});

  Offset get head => segments.last;
  Offset get tail => segments.first;

  Rect get bounds {
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final s in segments) {
      if (s.dx < minX) minX = s.dx;
      if (s.dy < minY) minY = s.dy;
      if (s.dx > maxX) maxX = s.dx;
      if (s.dy > maxY) maxY = s.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  Set<int> get occupiedCells {
    final set = <int>{};
    for (final s in segments) {
      set.add(s.dx.round() * 10000 + s.dy.round());
    }
    return set;
  }

  bool isBlockedBy(_Arrow other) {
    if (other.freed) return false;
    final dir = headDir.vec;
    final h = head;
    final otherCells = other.occupiedCells;
    for (int step = 1; step <= 20; step++) {
      final checkPt = Offset(h.dx + dir.dx * step, h.dy + dir.dy * step);
      final key = checkPt.dx.round() * 10000 + checkPt.dy.round();
      if (otherCells.contains(key)) return true;
    }
    return false;
  }

  int distToBlocker(List<_Arrow> allArrows) {
    final dir = headDir.vec;
    final h = head;
    int minDist = 20;
    for (final other in allArrows) {
      if (other.id == id || other.freed) continue;
      final otherCells = other.occupiedCells;
      for (int step = 1; step <= 20; step++) {
        final checkPt = Offset(h.dx + dir.dx * step, h.dy + dir.dy * step);
        final key = checkPt.dx.round() * 10000 + checkPt.dy.round();
        if (otherCells.contains(key)) {
          if (step < minDist) minDist = step;
          break;
        }
      }
    }
    return minDist;
  }

  bool canBeFree(List<_Arrow> allArrows) {
    if (freed) return false;
    for (final other in allArrows) {
      if (other.id == id || other.freed) continue;
      if (isBlockedBy(other)) return false;
    }
    return true;
  }
}

class ArrowPuzzleScreen extends StatefulWidget {
  const ArrowPuzzleScreen({super.key});

  @override
  State<ArrowPuzzleScreen> createState() => _ArrowPuzzleScreenState();
}

class _ArrowPuzzleScreenState extends State<ArrowPuzzleScreen> with TickerProviderStateMixin {
  _Difficulty? _activeDifficulty;
  _Difficulty _pickerDifficulty = _Difficulty.values[DifficultyKind.defaultIndex];
  bool _isFavorite = false;

  int _level = 1;
  int _taps = 0;
  bool _gameOver = false;
  bool _won = false;

  List<_Arrow> _arrows = [];
  int _gridCols = 8;
  int _gridRows = 10;
  int _totalArrows = 0;
  int _freedCount = 0;

  AnimationController? _flyAnim;
  int? _flyingArrowId;
  final ValueNotifier<double> _flyNotifier = ValueNotifier(0);

  AnimationController? _blockedAnim;
  int? _blockedArrowId;
  double _blockedDistCells = 0;
  final ValueNotifier<double> _blockedNotifier = ValueNotifier(0);

  int? _hintArrowId;
  AnimationController? _hintAnim;
  final ValueNotifier<double> _hintNotifier = ValueNotifier(0);
  int _consecutiveBlocks = 0;
  static const _kStuckThreshold = 3;
  int _hintsUsed = 0;
  static const _kMaxHints = 3;
  Timer? _idleTimer;
  bool _idleStuck = false;
  static const _kIdleTimeout = Duration(seconds: 30);

  OverlayEntry? _appreciationOverlay;

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(kArrowPuzzleGameId);
  }

  @override
  void dispose() {
    _appreciationOverlay?.remove();
    _appreciationOverlay = null;
    _idleTimer?.cancel();
    _flyAnim?.dispose();
    _blockedAnim?.dispose();
    _hintAnim?.dispose();
    _flyNotifier.dispose();
    _blockedNotifier.dispose();
    _hintNotifier.dispose();
    super.dispose();
  }

  void _toggleFavorite() {
    ScoreService().toggleFavorite(kArrowPuzzleGameId);
    setState(() => _isFavorite = !_isFavorite);
  }

  void _showHelp() {
    final info = GameRegistry.getById(kArrowPuzzleGameId);
    if (info == null) return;
    showHowToPlaySheet(context, title: info.name, howToPlay: info.howToPlay,
      accent: _kAccent, steps: arrowPuzzleSteps(), gameId: kArrowPuzzleGameId);
  }

  void _startGame(_Difficulty diff) async {
    final lps = LevelProgressService();
    _level = lps.getCurrentLevel(kArrowPuzzleGameId, diff.subKey);

    final saved = lps.getGameState(kArrowPuzzleGameId, diff.subKey);
    final hasSave = saved != null && saved['level'] == _level;

    bool shouldContinue = false;
    if (hasSave) {
      shouldContinue = await showContinueDialog(
        context,
        gameName: 'Arrow Puzzle',
        accentColor: diff.color,
        level: _level,
      );
      if (!mounted) return;
    }

    _gameOver = false;
    _won = false;
    _taps = 0;
    _freedCount = 0;
    _consecutiveBlocks = 0;
    _idleStuck = false;
    _hintsUsed = 0;
    _generateLevel(diff);

    if (hasSave && shouldContinue) {
      _taps = saved['taps'] as int;
      _freedCount = saved['freedCount'] as int;
      _hintsUsed = (saved['hintsUsed'] as int?) ?? 0;
      final freedIds = Set<int>.from((saved['freedArrowIds'] as List).cast<int>());
      for (final a in _arrows) {
        if (freedIds.contains(a.id)) {
          a.freed = true;
        }
      }
    } else {
      if (hasSave) lps.clearGameState(kArrowPuzzleGameId, diff.subKey);
    }

    _resetIdleTimer();
    setState(() => _activeDifficulty = diff);
    GameWrapper.of(context).setDifficultyAndMode(difficulty: diff.label, subKey: diff.subKey);
    GameWrapper.of(context).startGame();
    GameWrapper.of(context).updateScore(_level);
  }

  Set<int> _boardCells = {};

  void _generateLevel(_Difficulty diff) {
    final result = gen.generateArrowLevel(_level, diff.index);
    _gridCols = result.gridCols;
    _gridRows = result.gridRows;
    _boardCells = result.boardCells;
    _arrows = result.arrows.map((a) => _Arrow(
      id: a.id,
      segments: a.segments.map((p) => Offset(p.dx, p.dy)).toList(),
      headDir: _ArrowDir.values[a.headDir.index],
    )).toList();
    _totalArrows = _arrows.length;
  }

  void _onArrowTap(int arrowId) {
    if (_gameOver || _won || _flyingArrowId != null || _blockedArrowId != null) return;
    final arrow = _arrows.firstWhere((a) => a.id == arrowId);
    if (arrow.freed) return;

    _taps++;

    if (!arrow.canBeFree(_arrows)) {
      _consecutiveBlocks++;
      _resetIdleTimer();
      _blockedArrowId = arrowId;
      _blockedDistCells = (arrow.distToBlocker(_arrows) - 0.5).clamp(0.5, 20.0);
      _blockedNotifier.value = 0;
      _blockedAnim?.dispose();
      final dur = Duration(milliseconds: (120 + _blockedDistCells * 40).round().clamp(180, 500));
      _blockedAnim = AnimationController(vsync: this, duration: dur)
        ..addListener(() => _blockedNotifier.value = _blockedAnim!.value)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) {
            _blockedAnim!.reverse();
          } else if (s == AnimationStatus.dismissed && _blockedArrowId != null) {
            _blockedArrowId = null;
            _blockedAnim?.dispose();
            _blockedAnim = null;
            _blockedNotifier.value = 0;
          }
        });
      _blockedAnim!.forward();
      AudioService().playTap();
      setState(() {});
      return;
    }

    _consecutiveBlocks = 0;
    _idleStuck = false;
    _resetIdleTimer();
    _flyingArrowId = arrowId;
    _flyNotifier.value = 0;
    _flyAnim?.dispose();
    _flyAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..addListener(() => _flyNotifier.value = _flyAnim!.value)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          _onFlyComplete(arrowId);
        }
      });
    _flyAnim!.forward();
    AudioService().playScore();
    setState(() {});
  }

  void _onFlyComplete(int arrowId) {
    if (!mounted) return;
    final arrow = _arrows.firstWhere((a) => a.id == arrowId);
    arrow.freed = true;
    arrow.flyProgress = 0;
    _flyingArrowId = null;
    _freedCount++;

    if (_freedCount >= _totalArrows) {
      _won = true;
      _endGame(true);
    } else {
      _saveState();
    }
    setState(() {});
  }

  void _endGame(bool won) {
    _won = won;
    if (won) {
      final diff = _activeDifficulty!;
      final lps = LevelProgressService();
      lps.advanceLevel(kArrowPuzzleGameId, diff.subKey);
      lps.saveLevelBest(kArrowPuzzleGameId, diff.subKey, _level, _taps + _hintsUsed * 3);
      lps.clearGameState(kArrowPuzzleGameId, diff.subKey);
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

  bool get _isStuck => _consecutiveBlocks >= _kStuckThreshold || _idleStuck;

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
    if (_gameOver || _won || _flyingArrowId != null || _blockedArrowId != null) return;
    if (_hintsUsed >= _kMaxHints) return;
    if (!AdsService().isRewardedReady) return;
    final freeArrow = _arrows.cast<_Arrow?>().firstWhere(
      (a) => a != null && !a.freed && a.canBeFree(_arrows),
      orElse: () => null,
    );
    if (freeArrow == null) return;

    AudioService().playTap();
    bool earned = false;
    AdsService().showRewarded(
      rewardType: RewardType.hint,
      gameId: kArrowPuzzleGameId,
      onRewarded: (_) => earned = true,
      onComplete: () {
        if (!earned || !mounted) return;
        _consecutiveBlocks = 0;
        _idleStuck = false;
        _hintsUsed++;
        _resetIdleTimer();
        _saveState();
        _showHint(freeArrow.id);
      },
    );
  }

  void _showHint(int arrowId) {
    _hintAnim?.dispose();
    _hintArrowId = arrowId;
    _hintNotifier.value = 0;
    _hintAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..addListener(() => _hintNotifier.value = _hintAnim!.value)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _hintAnim!.reverse();
        if (s == AnimationStatus.dismissed) {
          if (_hintAnim!.status == AnimationStatus.dismissed) {
            _hintAnim!.forward();
          }
        }
      });
    _hintAnim!.forward();
    setState(() {});
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      _hintAnim?.dispose();
      _hintAnim = null;
      _hintArrowId = null;
      _hintNotifier.value = 0;
      if (mounted) setState(() {});
    });
  }

  void _nextLevel() {
    final diff = _activeDifficulty!;
    _hintAnim?.dispose();
    _hintAnim = null;
    _hintArrowId = null;
    _hintNotifier.value = 0;
    setState(() {
      _level++;
      _taps = 0;
      _gameOver = false;
      _won = false;
      _freedCount = 0;
      _consecutiveBlocks = 0;
      _hintsUsed = 0;
      _idleStuck = false;
      _flyingArrowId = null;
      _blockedArrowId = null;
    });
    _blockedAnim?.dispose();
    _blockedAnim = null;
    _generateLevel(diff);
    _resetIdleTimer();
    GameWrapper.of(context).restartGame();
    GameWrapper.of(context).startGame();
    GameWrapper.of(context).updateScore(_level);
  }

  void _restartLevel() {
    _hintAnim?.dispose();
    _hintAnim = null;
    _hintArrowId = null;
    _hintNotifier.value = 0;
    setState(() {
      _taps = 0;
      _gameOver = false;
      _won = false;
      _freedCount = 0;
      _consecutiveBlocks = 0;
      _idleStuck = false;
      _flyingArrowId = null;
      _blockedArrowId = null;
      _hintsUsed = 0;
      for (final a in _arrows) {
        a.freed = false;
        a.flyProgress = 0;
      }
    });
    if (_activeDifficulty != null) {
      LevelProgressService().clearGameState(kArrowPuzzleGameId, _activeDifficulty!.subKey);
    }
    _resetIdleTimer();
    GameWrapper.of(context).restartGame();
    GameWrapper.of(context).startGame();
    GameWrapper.of(context).updateScore(_level);
  }

  void _saveState() {
    final diff = _activeDifficulty;
    if (diff == null || _gameOver || _won) return;
    if (_taps == 0 && _hintsUsed == 0) return;
    final freedIds = _arrows.where((a) => a.freed).map((a) => a.id).toList();
    LevelProgressService().saveGameState(kArrowPuzzleGameId, diff.subKey, {
      'level': _level,
      'taps': _taps,
      'freedCount': _freedCount,
      'hintsUsed': _hintsUsed,
      'freedArrowIds': freedIds,
    });
  }

  void _backToPicker() {
    _saveState();
    _flyAnim?.dispose();
    _flyAnim = null;
    _flyingArrowId = null;
    _blockedAnim?.dispose();
    _blockedAnim = null;
    _blockedArrowId = null;
    _hintAnim?.dispose();
    _hintAnim = null;
    _hintArrowId = null;
    _hintNotifier.value = 0;
    setState(() {
      _activeDifficulty = null;
      _gameOver = false;
    });
    GameWrapper.of(context).restartGame();
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
    if (_gameOver) return _buildResult();
    return _buildGame();
  }

  Widget _buildPicker() {
    final difficulties = _Difficulty.values.map((d) => GameDifficultyData(
      label: d.label,
      color: d.color,
      kind: d.kind,
      hint: d.hint,
      bestScore: LevelProgressService().getHighestLevel(kArrowPuzzleGameId, d.subKey),
      bestLabel: (s) {
        if (s <= 0) return '';
        return 'Completed: Level $s';
      },
    )).toList();

    return GamePickerScaffold(
      bgColorTop: const Color(0xFFEDE9FE),
      bgColorBottom: const Color(0xFFDDD6FE),
      animatedBg: AnimatedBackground(
        factory: (t) => GenericAnimatedBgPainter(t, accent: _kAccent, icon: Icons.arrow_forward_rounded),
      ),
      iconRingColors: const [_kAccent, Color(0xFF8B5CF6), Color(0xFF6D28D9)],
      iconChild: buildArrowPuzzleLogo(60),
      title: 'Arrow Puzzle',
      subtitle: 'Untangle & free all arrows!',
      onBack: _backOrHome,
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: _showHelp,
      gameId: kArrowPuzzleGameId,
      body: GameSinglePickerBody(
        difficulties: difficulties,
        activeIndex: _pickerDifficulty.index,
        onChanged: (i) => setState(() => _pickerDifficulty = _Difficulty.values[i]),
        playLabel: 'Play Arrow Puzzle',
        playSubLabel: 'Level ${LevelProgressService().getCurrentLevel(kArrowPuzzleGameId, _pickerDifficulty.subKey)}',
        onPlay: () => _startGame(_pickerDifficulty),
        accentColor: _kAccent,
      ),
    );
  }

  Widget _buildGame() {
    final diff = _activeDifficulty!;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kBgTop, _kBgBot],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            GameHudBar(
              leading: GameBackButton(onTap: _backOrHome, bgColor: _kAccent.withValues(alpha: 0.10), iconColor: _kAccent),
              centerContent: _buildHud(diff),
              trailing: GameRestartButton(
                gameName: 'Arrow Puzzle',
                accentColor: diff.color,
                onRestart: _restartLevel,
                bgColor: _kAccent.withValues(alpha: 0.10),
                iconColor: _kAccent,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$_freedCount / $_totalArrows freed',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kAccent.withValues(alpha: 0.60),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      int minC = _gridCols, maxC = 0, minR = _gridRows, maxR = 0;
                      for (final k in _boardCells) {
                        final c = k ~/ 10000;
                        final r = k % 10000;
                        if (c < minC) minC = c;
                        if (c > maxC) maxC = c;
                        if (r < minR) minR = r;
                        if (r > maxR) maxR = r;
                      }
                      final spanC = maxC - minC + 1;
                      final spanR = maxR - minR + 1;
                      final maxW = constraints.maxWidth;
                      final maxH = constraints.maxHeight;
                      final cell = math.min(maxW / spanC, maxH / spanR).clamp(18.0, 20.0);
                      final boardW = cell * spanC;
                      final boardH = cell * spanR;
                      return SizedBox(
                        width: boardW,
                        height: boardH,
                        child: _buildBoard(cell, minC, minR, spanC, spanR),
                      );
                    },
                  ),
                ),
              ),
            ),
            if (!_gameOver && !_won)
              Opacity(
                opacity: AdsService().isRewardedReady && _hintArrowId == null && _hintsUsed < _kMaxHints ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !AdsService().isRewardedReady || _hintArrowId != null || _hintsUsed >= _kMaxHints,
                  child: _HintNudge(onTap: _onHint, isStuck: _isStuck),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildBoard(double cell, int offC, int offR, int spanC, int spanR) {
    return GestureDetector(
      onTapDown: (details) => _handleTapOnBoard(details.localPosition, cell, offC, offR),
      child: RepaintBoundary(
        child: ValueListenableBuilder<double>(
          valueListenable: _flyNotifier,
          builder: (_, flyVal, _) => ValueListenableBuilder<double>(
            valueListenable: _blockedNotifier,
            builder: (_, blockedVal, _) => ValueListenableBuilder<double>(
              valueListenable: _hintNotifier,
              builder: (_, hintVal, _) => CustomPaint(
                size: Size(spanC * cell, spanR * cell),
                painter: _BoardPainter(
                  arrows: _arrows,
                  cell: cell,
                  boardCells: _boardCells,
                  offC: offC,
                  offR: offR,
                  spanC: spanC,
                  spanR: spanR,
                  flyingId: _flyingArrowId,
                  flyProgress: flyVal,
                  blockedId: _blockedArrowId,
                  blockedProgress: blockedVal,
                  blockedDistCells: _blockedDistCells,
                  hintId: _hintArrowId,
                  hintProgress: hintVal,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleTapOnBoard(Offset localPos, double cell, int offC, int offR) {
    final col = (localPos.dx / cell).floor() + offC;
    final row = (localPos.dy / cell).floor() + offR;

    for (final arrow in _arrows.reversed) {
      if (arrow.freed) continue;
      for (final seg in arrow.segments) {
        if (seg.dx.round() == col && seg.dy.round() == row) {
          _onArrowTap(arrow.id);
          return;
        }
      }
    }
  }

  Widget _buildHud(_Difficulty diff) {
    final color = diff.color;
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
              AnimatedDifficultyIcon(kind: diff.kind, size: 14, prominent: false),
              const SizedBox(width: 6),
              Text(diff.label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
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
              _statCol('LEVEL', '$_level', color),
              _pillDivider(),
              _statCol('TAPS', '$_taps', const Color(0xFF6B7280)),
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
          Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: color.withValues(alpha: 0.70), letterSpacing: 1.0)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color, height: 1)),
        ],
      ),
    );
  }

  Widget _pillDivider() {
    return Container(width: 1, height: 22, color: const Color(0xFFE5E7EB));
  }

  Widget _buildResult() {
    final diff = _activeDifficulty!;
    return game_result.GenericGameResultScreen(
      headline: _won ? 'Level $_level Complete!' : 'Stuck!',
      subtitle: _won ? '$_taps taps' : 'Try again or restart',
      badgeContent: _won ? '➡️' : '😔',
      badgeColor: diff.color,
      showNewBestBadge: false,
      gameId: kArrowPuzzleGameId,
      score: _level,
      statsWidget: game_result.GameResultStatsRow(
        stats: [
          game_result.StatItem(label: 'LEVEL', value: _level, color: diff.color),
          game_result.StatItem(label: 'TAPS', value: _taps, color: const Color(0xFF6B7280)),
        ],
      ),
      actions: [
        if (_won)
          game_result.GameResultAction(
            label: 'Next Level',
            icon: Icons.arrow_forward_rounded,
            onTap: _nextLevel,
            filled: true,
            color: diff.color,
            actionId: 'play_again',
          )
        else
          game_result.GameResultAction(
            label: 'Retry Level',
            icon: Icons.refresh_rounded,
            onTap: _restartLevel,
            filled: true,
            color: diff.color,
            actionId: 'play_again',
          ),
        game_result.GameResultAction(
          label: 'Change Difficulty',
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

class _BoardPainter extends CustomPainter {
  final List<_Arrow> arrows;
  final double cell;
  final Set<int> boardCells;
  final int offC;
  final int offR;
  final int spanC;
  final int spanR;
  final int? flyingId;
  final double flyProgress;
  final int? blockedId;
  final double blockedProgress;
  final double blockedDistCells;
  final int? hintId;
  final double hintProgress;

  _BoardPainter({
    required this.arrows,
    required this.cell,
    required this.boardCells,
    required this.offC,
    required this.offR,
    required this.spanC,
    required this.spanR,
    this.flyingId,
    this.flyProgress = 0,
    this.blockedId,
    this.blockedProgress = 0,
    this.blockedDistCells = 1,
    this.hintId,
    this.hintProgress = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final arrow in arrows) {
      if (arrow.freed && arrow.id != flyingId) continue;
      _drawArrow(canvas, arrow);
    }
  }

  void _drawArrow(Canvas canvas, _Arrow arrow) {
    final isFlying = arrow.id == flyingId;
    final isBlocked = arrow.id == blockedId;

    var pts = <Offset>[];
    for (final s in arrow.segments) {
      pts.add(_cellCenter(s));
    }

    final arrowLen = _pathLength(pts);

    if (isBlocked && blockedProgress > 0) {
      final nudgeDist = Curves.easeOut.transform(blockedProgress) * cell * blockedDistCells;
      final dir = arrow.headDir.vec;
      final lastPt = pts.last;
      final extended = [...pts];
      for (int e = 1; e <= 3; e++) {
        extended.add(Offset(lastPt.dx + dir.dx * cell * e, lastPt.dy + dir.dy * cell * e));
      }
      final trimmed = _trimTail(extended, nudgeDist);
      if (trimmed.length >= 2) {
        pts = _keepLen(trimmed, arrowLen);
      }
    }

    if (isFlying && flyProgress > 0) {
      final t = Curves.easeInCubic.transform(flyProgress);
      final dir = arrow.headDir.vec;
      final lastPt = pts.last;
      final extended = [...pts];
      for (int e = 1; e <= 14; e++) {
        extended.add(Offset(lastPt.dx + dir.dx * cell * e, lastPt.dy + dir.dy * cell * e));
      }
      final maxSlide = _pathLength(extended) - arrowLen;
      final slideDist = t * maxSlide.clamp(0, double.infinity);
      final trimmed = _trimTail(extended, slideDist);
      if (trimmed.length >= 2) {
        pts = _keepLen(trimmed, arrowLen);
      }
      if (pts.length < 2) return;
    }

    if (pts.length < 2) return;

    final isHint = arrow.id == hintId && hintProgress > 0;

    if (isHint) {
      final glowT = Curves.easeInOut.transform(hintProgress);
      final glowPath = ui.Path();
      glowPath.moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length; i++) {
        glowPath.lineTo(pts[i].dx, pts[i].dy);
      }
      final glowAlpha = (0.25 + glowT * 0.35).clamp(0.0, 1.0);
      canvas.drawPath(glowPath, Paint()
        ..color = const Color(0xFF22C55E).withValues(alpha: glowAlpha)
        ..strokeWidth = cell * 0.28
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    }

    final strokeW = cell * 0.16;
    final color = isHint ? const Color(0xFF22C55E) : arrow.headDir.color;

    final bodyPath = ui.Path();
    bodyPath.moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      bodyPath.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(bodyPath, Paint()
      ..color = color
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke);

    final head = pts.last;
    final prev = pts[pts.length - 2];
    final dx = head.dx - prev.dx;
    final dy = head.dy - prev.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 0.01) return;
    final ndx = dx / len;
    final ndy = dy / len;

    final headLen = cell * 0.38;
    final headW = cell * 0.24;
    final tipX = head.dx + ndx * cell * 0.25;
    final tipY = head.dy + ndy * cell * 0.25;
    final perpX = -ndy;
    final perpY = ndx;
    final baseX = tipX - ndx * headLen;
    final baseY = tipY - ndy * headLen;

    final lx = baseX + perpX * headW;
    final ly = baseY + perpY * headW;
    final rx = baseX - perpX * headW;
    final ry = baseY - perpY * headW;

    final arrowHead = ui.Path()
      ..moveTo(tipX, tipY)
      ..quadraticBezierTo(
        tipX + perpX * headW * 0.3 - ndx * headLen * 0.1,
        tipY + perpY * headW * 0.3 - ndy * headLen * 0.1,
        lx, ly,
      )
      ..quadraticBezierTo(
        baseX + ndx * headLen * 0.12,
        baseY + ndy * headLen * 0.12,
        rx, ry,
      )
      ..quadraticBezierTo(
        tipX - perpX * headW * 0.3 - ndx * headLen * 0.1,
        tipY - perpY * headW * 0.3 - ndy * headLen * 0.1,
        tipX, tipY,
      )
      ..close();

    canvas.drawPath(arrowHead, Paint()
      ..color = color
      ..style = PaintingStyle.fill);
  }

  double _pathLength(List<Offset> pts) {
    double len = 0;
    for (int i = 1; i < pts.length; i++) {
      len += (pts[i] - pts[i - 1]).distance;
    }
    return len;
  }

  List<Offset> _trimTail(List<Offset> pts, double trimLen) {
    if (trimLen <= 0) return List.from(pts);
    final result = <Offset>[];
    double consumed = 0;
    for (int i = 1; i < pts.length; i++) {
      final segLen = (pts[i] - pts[i - 1]).distance;
      final segEnd = consumed + segLen;
      if (result.isEmpty) {
        if (segEnd > trimLen) {
          final frac = (trimLen - consumed) / segLen;
          result.add(Offset(
            pts[i - 1].dx + (pts[i].dx - pts[i - 1].dx) * frac,
            pts[i - 1].dy + (pts[i].dy - pts[i - 1].dy) * frac,
          ));
          result.add(pts[i]);
        }
      } else {
        result.add(pts[i]);
      }
      consumed = segEnd;
    }
    return result;
  }

  List<Offset> _keepLen(List<Offset> pts, double keepLen) {
    if (pts.length < 2) return pts;
    final result = <Offset>[pts.first];
    double consumed = 0;
    for (int i = 1; i < pts.length; i++) {
      final segLen = (pts[i] - pts[i - 1]).distance;
      final segEnd = consumed + segLen;
      if (segEnd >= keepLen) {
        final remaining = keepLen - consumed;
        if (segLen > 0) {
          final frac = remaining / segLen;
          result.add(Offset(
            pts[i - 1].dx + (pts[i].dx - pts[i - 1].dx) * frac,
            pts[i - 1].dy + (pts[i].dy - pts[i - 1].dy) * frac,
          ));
        }
        break;
      }
      result.add(pts[i]);
      consumed = segEnd;
    }
    return result;
  }

  Offset _cellCenter(Offset gridPos) {
    return Offset((gridPos.dx - offC) * cell + cell / 2, (gridPos.dy - offR) * cell + cell / 2);
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}

class _HintNudge extends StatefulWidget {
  final VoidCallback onTap;
  final bool isStuck;
  const _HintNudge({required this.onTap, required this.isStuck});

  @override
  State<_HintNudge> createState() => _HintNudgeState();
}

class _HintNudgeState extends State<_HintNudge> with TickerProviderStateMixin {
  static const _kBg = Color(0xFFFFD43B);
  static const _kFg = Color(0xFF5C4600);

  late final AnimationController _pulseCtrl;
  late final AnimationController _slideCtrl;
  late final Animation<double> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutBack);
    _fadeAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut);
    if (widget.isStuck) {
      _pulseCtrl.repeat(reverse: true);
      _slideCtrl.forward();
    }
  }

  @override
  void didUpdateWidget(_HintNudge old) {
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
                            color: const Color(0xFF7C3AED),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
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
                          painter: _BubbleTailPainter(),
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

class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF7C3AED);
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

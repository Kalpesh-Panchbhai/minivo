import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/ads_service.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/score_service.dart';
import '../../core/widgets/how_to_play_sheet.dart';
import '../game_picker_scaffold.dart';
import '../game_wrapper.dart';
import '../shared/animated_background.dart';
import '../shared/animated_difficulty_icon.dart';
import '../shared/game_control_buttons.dart';
import '../shared/game_difficulty_picker.dart';
import '../shared/game_hud_bar.dart';
import '../shared/generic_game_result_screen.dart' as game_result;
import 'sudoku_engine.dart';
import 'sudoku_logo.dart';
import 'sudoku_stats.dart';
import 'sudoku_tutorial.dart';

// ── Palette ─────────────────────────────────────────────────────────────────
const Color _kBgTop    = Color(0xFFEEF2FF); // indigo-50
const Color _kBgBot    = Color(0xFFE0E7FF); // indigo-100
const Color _kAccent   = Color(0xFF6366F1); // indigo-500
const Color _kAccentLt = Color(0xFF818CF8); // indigo-400

// ── Mode & Difficulty ────────────────────────────────────────────────────────

enum _Mode { picker, playing, done }

enum _Difficulty { easy, medium, hard }

extension _DifficultyX on _Difficulty {
  String get label => ['EASY', 'MEDIUM', 'HARD'][index];
  int    get clues  => [46, 36, 28][index];
  Color  get color  => [
    const Color(0xFF22C55E),
    const Color(0xFFF59E0B),
    const Color(0xFFEF4444),
  ][index];
  DifficultyKind get kind => [
    DifficultyKind.easy,
    DifficultyKind.medium,
    DifficultyKind.hard,
  ][index];
  String get hint => [
    'More starting numbers • great for beginners.',
    'A balanced challenge • think ahead.',
    'Fewer starting numbers • pure logic required.',
  ][index];
  String get subKey => ['easy', 'medium', 'hard'][index];
}

// ── Helpers ──────────────────────────────────────────────────────────────────

String _formatTime(int seconds) {
  final m = seconds ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

// ════════════════════════════════════════════════════════════════
// Root screen
// ════════════════════════════════════════════════════════════════

class SudokuScreen extends StatefulWidget {
  const SudokuScreen({super.key});

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen> {
  _Mode _mode = _Mode.picker;
  _Difficulty _pickerDiff = _Difficulty.values[DifficultyKind.defaultIndex];
  _Difficulty? _activeDiff;
  bool _isFavorite = false;

  // Board state
  List<List<int>> _puzzle    = [];
  List<List<int>> _solution  = [];
  List<List<bool>> _given    = [];
  int? _selRow, _selCol;
  int _errorCount  = 0;

  // Animation triggers
  int _animRow = -1;
  int _animCol = -1;
  bool _animCorrect = false;

  // Completion tracking
  Set<int> _completedRows   = {};
  Set<int> _completedCols   = {};
  Set<int> _completedBoxes  = {};
  Set<int> _flashingRows    = {};
  Set<int> _flashingCols    = {};
  Set<int> _flashingBoxes   = {};

  // Generation
  bool _isGenerating = false;

  // Timing
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;
  int _elapsedSeconds = 0;

  // Hint support (1 per game)
  bool _hintUsed = false;

  // Result
  bool _isNewBestScore = false;

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(kSudokuGameId);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _toggleFavorite() {
    ScoreService().toggleFavorite(kSudokuGameId);
    setState(() => _isFavorite = !_isFavorite);
  }

  void _showHelp() {
    showHowToPlaySheet(
      context,
      title: 'Sudoku',
      accent: _kAccent,
      steps: sudokuSteps(),
      gameId: kSudokuGameId,
    );
  }

  // ── Game logic ────────────────────────────────────────────────

  void _startGame(_Difficulty diff) {
    _ticker?.cancel();
    _stopwatch.stop();
    setState(() {
      _isGenerating = true;
      _activeDiff = diff;
    });

    ScoreService().incrementGamePlayCount(kSudokuGameId);

    compute(generateSudokuPuzzle, diff.clues).then((result) {
      if (!mounted) return;
      final given = List.generate(
        9,
        (r) => List.generate(9, (c) => result.puzzle[r][c] != 0),
      );
      final puzzle = result.puzzle.map((row) => List<int>.from(row)).toList();

      _ticker?.cancel();
      _stopwatch
        ..reset()
        ..start();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsedSeconds = _stopwatch.elapsed.inSeconds);
      });

      setState(() {
        _puzzle         = puzzle;
        _solution       = result.solution;
        _given          = given;
        _selRow         = null;
        _selCol         = null;
        _errorCount     = 0;
        _elapsedSeconds = 0;
        _isNewBestScore = false;
        _isGenerating   = false;
        _hintUsed       = false;
        _mode           = _Mode.playing;
        _animRow        = -1;
        _animCol        = -1;
        _animCorrect    = false;
        _completedRows   = {};
        _completedCols   = {};
        _completedBoxes  = {};
        _flashingRows    = {};
        _flashingCols    = {};
        _flashingBoxes   = {};
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          GameWrapper.of(context).setDifficultyAndMode(difficulty: diff.label);
          GameWrapper.of(context).startGame();
          GameWrapper.of(context).updateScore(0);
        }
      });
    });
  }

  void _onCellTap(int row, int col) {
    setState(() {
      _selRow = row;
      _selCol = col;
    });
  }


  void _recomputeCompletion(int r, int c) {
    final bool rowDone = List.generate(9, (col) => _puzzle[r][col] == _solution[r][col]).every((b) => b);
    final bool colDone = List.generate(9, (row) => _puzzle[row][c] == _solution[row][c]).every((b) => b);
    final br = (r ~/ 3) * 3, bc = (c ~/ 3) * 3;
    final bool boxDone = [for (int dr = 0; dr < 3; dr++) for (int dc = 0; dc < 3; dc++) _puzzle[br + dr][bc + dc] == _solution[br + dr][bc + dc]].every((b) => b);
    final boxIdx = (r ~/ 3) * 3 + (c ~/ 3);

    final newFlashRows  = <int>{};
    final newFlashCols  = <int>{};
    final newFlashBoxes = <int>{};
    if (rowDone && !_completedRows.contains(r))        { newFlashRows.add(r);       _completedRows.add(r); }
    if (colDone && !_completedCols.contains(c))        { newFlashCols.add(c);       _completedCols.add(c); }
    if (boxDone && !_completedBoxes.contains(boxIdx))  { newFlashBoxes.add(boxIdx); _completedBoxes.add(boxIdx); }


    if (newFlashRows.isNotEmpty || newFlashCols.isNotEmpty || newFlashBoxes.isNotEmpty) {
      setState(() {
        _flashingRows  = newFlashRows;
        _flashingCols  = newFlashCols;
        _flashingBoxes = newFlashBoxes;
      });
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) setState(() { _flashingRows = {}; _flashingCols = {}; _flashingBoxes = {}; });
      });
    }
  }

  void _onNumberInput(int num) {
    final r = _selRow;
    final c = _selCol;
    if (r == null || c == null) return;
    if (_given[r][c]) return;
    // Block overwriting a correctly-placed given cell (givens are already blocked above)
    // but allow overwriting any user-entered cell, correct or not — direct replacement UX
    if (_given[r][c]) return; // already checked above, belt-and-suspenders

    final isCorrect = num == _solution[r][c];
    // If the cell already has the same value, do nothing
    if (_puzzle[r][c] == num) return;
    setState(() {
      _puzzle[r][c] = num;
      if (!isCorrect) {
        _errorCount++;
      }
      _animRow    = r;
      _animCol    = c;
      _animCorrect = isCorrect;
    });

    if (isCorrect) {
      _recomputeCompletion(r, c);
    } else {
      HapticFeedback.mediumImpact();
    }

    // Clear anim trigger after animation duration
    Future.delayed(const Duration(milliseconds: 420), () {
      if (mounted) setState(() { _animRow = -1; _animCol = -1; });
    });

    // Check completion
    bool complete = true;
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (_puzzle[row][col] != _solution[row][col]) {
          complete = false;
          break;
        }
      }
      if (!complete) break;
    }
    if (complete) _onGameComplete();
  }

  void _onErase() {
    final r = _selRow;
    final c = _selCol;
    if (r == null || c == null) return;
    if (_given[r][c]) return;
    setState(() => _puzzle[r][c] = 0);
  }

  void _onHint() {
    if (_hintUsed) return;
    if (!AdsService().isRewardedReady) return;

    AudioService().playTap();
    bool earned = false;
    AdsService().showRewarded(
      rewardType: RewardType.hint,
      gameId: kSudokuGameId,
      onRewarded: (_) => earned = true,
      onComplete: () {
        if (!earned || !mounted) return;
        int r, c;
        if (_selRow != null && _selCol != null && !_given[_selRow!][_selCol!] && _puzzle[_selRow!][_selCol!] != _solution[_selRow!][_selCol!]) {
          r = _selRow!;
          c = _selCol!;
        } else {
          final empties = <(int, int)>[];
          for (int row = 0; row < 9; row++) {
            for (int col = 0; col < 9; col++) {
              if (!_given[row][col] && _puzzle[row][col] != _solution[row][col]) {
                empties.add((row, col));
              }
            }
          }
          if (empties.isEmpty) return;
          final pick = empties[Random().nextInt(empties.length)];
          r = pick.$1;
          c = pick.$2;
        }
        setState(() {
          _puzzle[r][c] = _solution[r][c];
          _given[r][c] = true;
          _hintUsed = true;
          _selRow = r;
          _selCol = c;
          _animRow = r;
          _animCol = c;
          _animCorrect = true;
        });
        _recomputeCompletion(r, c);
        Future.delayed(const Duration(milliseconds: 420), () {
          if (mounted) setState(() { _animRow = -1; _animCol = -1; });
        });
        bool complete = true;
        for (int row = 0; row < 9; row++) {
          for (int col = 0; col < 9; col++) {
            if (_puzzle[row][col] != _solution[row][col]) {
              complete = false;
              break;
            }
          }
          if (!complete) break;
        }
        if (complete) _onGameComplete();
      },
    );
  }

  Future<void> _onGameComplete() async {
    _ticker?.cancel();
    _stopwatch.stop();
    final secs = _stopwatch.elapsed.inSeconds;
    setState(() => _elapsedSeconds = secs);

    final score = kSudokuMaxScore - secs;
    final isNew = await ScoreService()
        .saveScore(kSudokuGameId, score, subKey: _activeDiff!.subKey);

    if (!mounted) return;
    setState(() {
      _isNewBestScore = isNew;
      _mode = _Mode.done;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) GameWrapper.of(context).endGame();
    });
  }

  void _newGame() => _startGame(_activeDiff ?? _pickerDiff);

  void _backToPicker() {
    _ticker?.cancel();
    _stopwatch.stop();
    GameWrapper.of(context).restartGame();
    setState(() {
      _mode           = _Mode.picker;
      _activeDiff     = null;
      _isGenerating   = false;
      _puzzle         = [];
      _solution       = [];
      _given          = [];
      _selRow         = null;
      _selCol         = null;
      _errorCount     = 0;
      _elapsedSeconds = 0;
      _animRow        = -1;
      _animCol        = -1;
      _animCorrect    = false;
      _completedRows   = {};
      _completedCols   = {};
      _completedBoxes  = {};
      _flashingRows    = {};
      _flashingCols    = {};
      _flashingBoxes   = {};
    });
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return switch (_mode) {
      _Mode.picker  => _buildPicker(),
      _Mode.playing => _buildGame(),
      _Mode.done    => _buildResult(),
    };
  }

  // ════════════════════════════════════════════════════════════════
  // PICKER
  // ════════════════════════════════════════════════════════════════

  Widget _buildPicker() {
    return GamePickerScaffold(
      bgColorTop: _kBgTop,
      bgColorBottom: _kBgBot,
      animatedBg: AnimatedBackground(
        factory: (t) => _SudokuBgPainter(t),
        period: const Duration(seconds: 14),
      ),
      iconRingColors: const [_kAccent, _kAccentLt, _kAccent],
      iconChild: ClipOval(child: buildSudokuLogo(90)),
      title: 'Sudoku',
      subtitle: 'Fill the grid • Logic & Deduction',
      onBack: () => context.pop(),
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: _showHelp,
      gameId: kSudokuGameId,
      body: _PickerSection(
        difficulty: _pickerDiff,
        onDifficultyChanged: (d) => setState(() => _pickerDiff = d),
        onPlay: () => _startGame(_pickerDiff),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // GAME
  // ════════════════════════════════════════════════════════════════

  Widget _buildGame() {
    final diff = _activeDiff!;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.lerp(_kBgTop, diff.color, 0.06)!,
            Color.lerp(_kBgBot, diff.color, 0.04)!,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: _isGenerating
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  GameHudBar(
                    leading: GameBackButton(onTap: _backToPicker),
                    centerContent: _ScorePill(
                      difficulty: diff,
                      elapsedSeconds: _elapsedSeconds,
                      mistakeCount: _errorCount,
                      bestSeconds: () {
                        final s = bestSudokuScore(diff.subKey);
                        return s > 0 ? kSudokuMaxScore - s : null;
                      }(),
                    ),
                    trailing: GameRestartButton(
                      gameName: 'Sudoku',
                      accentColor: diff.color,
                      onRestart: () => _startGame(diff),
                      onDialogOpened: () {
                        _ticker?.cancel();
                        _stopwatch.stop();
                      },
                      onDialogDismissed: () {
                        if (_mode == _Mode.playing) {
                          _stopwatch.start();
                          _ticker = Timer.periodic(
                            const Duration(seconds: 1),
                            (_) { if (mounted) setState(() => _elapsedSeconds = _stopwatch.elapsed.inSeconds); },
                          );
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: _SudokuGrid(
                      puzzle: _puzzle,
                      given: _given,
                      solution: _solution,
                      selRow: _selRow,
                      selCol: _selCol,
                      showErrors: true,
                      accentColor: diff.color,
                      onTap: _onCellTap,
                      animRow: _animRow,
                      animCol: _animCol,
                      animCorrect: _animCorrect,
                      completedRows: _completedRows,
                      completedCols: _completedCols,
                      completedBoxes: _completedBoxes,
                      flashingRows: _flashingRows,
                      flashingCols: _flashingCols,
                      flashingBoxes: _flashingBoxes,
                    ),
                  ),
                  _NumberKeypad(
                    onNumber: _onNumberInput,
                    onErase: _onErase,
                    onHint: _onHint,
                    hintUsed: _hintUsed,
                    accentColor: diff.color,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // RESULT
  // ════════════════════════════════════════════════════════════════

  Widget _buildResult() {
    final diff = _activeDiff!;
    final bestStored = bestSudokuScore(diff.subKey);
    final bestSecs   = bestStored > 0 ? kSudokuMaxScore - bestStored : null;

    return game_result.GenericGameResultScreen(
      gameId: kSudokuGameId,
      score: _elapsedSeconds,
      headline: _isNewBestScore ? 'New Best! 🎉' : 'Solved! ✅',
      subtitle: '${diff.label} • ${_formatTime(_elapsedSeconds)}',
      badgeContent: '🧩',
      badgeColor: diff.color,
      showNewBestBadge: _isNewBestScore,
      statsWidget: _SudokuResultStats(
        elapsedSeconds: _elapsedSeconds,
        errorCount: _errorCount,
        bestSeconds: bestSecs,
        accentColor: diff.color,
      ),
      actions: [
        game_result.GameResultAction(
          label: 'Play Again',
          icon: Icons.refresh_rounded,
          onTap: _newGame,
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

// ════════════════════════════════════════════════════════════════
// PICKER SECTION
// ════════════════════════════════════════════════════════════════

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
        bestScore: bestSudokuScore(d.subKey),
        bestLabel: (s) {
          if (s <= 0) return 'No record yet';
          final secs = kSudokuMaxScore - s;
          return 'Best ${_formatTime(secs)}';
        },
      )).toList(),
      activeIndex: _Difficulty.values.indexOf(difficulty),
      onChanged: (i) => onDifficultyChanged(_Difficulty.values[i]),
      playLabel: 'Play Sudoku',
      playSubLabel: difficulty.index == 0
          ? 'Relaxed • lots of hints'
          : difficulty.index == 1
              ? 'Balanced • think ahead'
              : 'Expert • pure deduction',
      onPlay: onPlay,
      accentColor: _kAccent,
    );
  }
}

// ════════════════════════════════════════════════════════════════
// HUD BAR
// ════════════════════════════════════════════════════════════════

// ── Score pill (same structure as Snake's _ScoreBoardPill) ─────────────────
class _ScorePill extends StatelessWidget {
  final _Difficulty difficulty;
  final int elapsedSeconds;
  final int mistakeCount;
  final int? bestSeconds; // null = no record yet

  const _ScorePill({
    required this.difficulty,
    required this.elapsedSeconds,
    required this.mistakeCount,
    required this.bestSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final color = difficulty.color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Difficulty tab
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
        // Stats pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _statCol('TIME', _formatTime(elapsedSeconds), color),
              _divider(),
              _statCol('MISTAKES', '$mistakeCount', const Color(0xFFEF4444)),
              _divider(),
              _statCol(
                'BEST',
                bestSeconds != null ? _formatTime(bestSeconds!) : '--:--',
                const Color(0xFF8B7BA7),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _divider() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Container(width: 1, height: 28, color: const Color(0xFFE0E7FF)),
  );

  Widget _statCol(String label, String value, Color color) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: TextStyle(
          color: color.withValues(alpha: 0.85),
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
      const SizedBox(height: 2),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Text(
          value,
          key: ValueKey(value),
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    ],
  );
}

// ── Error-highlight toggle button ────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════
// SUDOKU GRID
// ════════════════════════════════════════════════════════════════

class _SudokuGrid extends StatefulWidget {
  final List<List<int>> puzzle;
  final List<List<bool>> given;
  final List<List<int>> solution;
  final int? selRow;
  final int? selCol;
  final bool showErrors;
  final Color accentColor;
  final void Function(int row, int col) onTap;
  final int animRow;
  final int animCol;
  final bool animCorrect;
  final Set<int> completedRows;
  final Set<int> completedCols;
  final Set<int> completedBoxes;
  final Set<int> flashingRows;
  final Set<int> flashingCols;
  final Set<int> flashingBoxes;

  const _SudokuGrid({
    required this.puzzle,
    required this.given,
    required this.solution,
    required this.selRow,
    required this.selCol,
    required this.showErrors,
    required this.accentColor,
    required this.onTap,
    required this.animRow,
    required this.animCol,
    required this.animCorrect,
    required this.completedRows,
    required this.completedCols,
    required this.completedBoxes,
    required this.flashingRows,
    required this.flashingCols,
    required this.flashingBoxes,
  });

  @override
  State<_SudokuGrid> createState() => _SudokuGridState();
}

class _SudokuGridState extends State<_SudokuGrid> with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final AnimationController _shakeCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.18), weight: 0.4),
      TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.0), weight: 0.6),
    ]).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_SudokuGrid old) {
    super.didUpdateWidget(old);
    if (widget.animRow != old.animRow || widget.animCol != old.animCol) {
      if (widget.animRow >= 0) {
        if (widget.animCorrect) {
          _entryCtrl.forward(from: 0);
        } else {
          _shakeCtrl.forward(from: 0);
        }
      }
    }
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  bool _isSameBox(int r, int c, int sr, int sc) =>
      (r ~/ 3) == (sr ~/ 3) && (c ~/ 3) == (sc ~/ 3);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Leave 28px horizontal breathing room so shadow is visible
        final available = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final gridSize = available - 28;
        final cellSize = gridSize / 9;

        return Center(
          child: Container(
            width: gridSize,
            height: gridSize,
            decoration: BoxDecoration(
              // Three-layer shadow: key drop + colored glow + wide ambient
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.09),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: widget.accentColor.withValues(alpha: 0.22),
                  blurRadius: 36,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: widget.accentColor.withValues(alpha: 0.10),
                  blurRadius: 60,
                  spreadRadius: 4,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            // Clip cells AND border ring together — corners are always clean
            child: Stack(
              children: [
                Container(
                  color: Colors.white,
                  child: Column(
                      children: List.generate(9, (row) {
                        return Row(
                          children: List.generate(9, (col) {
                            return _buildCell(row, col, cellSize);
                          }),
                        );
                      }),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: widget.accentColor.withValues(alpha: 0.20),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ),
        );
      },
    );
  }

  Widget _buildCell(int row, int col, double cellSize) {
    final sr = widget.selRow;
    final sc = widget.selCol;
    final isSelected = sr == row && sc == col;
    final isHighlighted = sr != null && sc != null &&
        (sr == row || sc == col || _isSameBox(row, col, sr, sc));
    final cellVal = widget.puzzle.isNotEmpty ? widget.puzzle[row][col] : 0;
    final solVal  = widget.solution.isNotEmpty ? widget.solution[row][col] : 0;
    final isGiven = widget.given.isNotEmpty ? widget.given[row][col] : false;
    final isError = widget.showErrors && cellVal != 0 && cellVal != solVal;
    final isSameNum = sr != null && sc != null &&
        widget.puzzle.isNotEmpty && widget.puzzle[sr][sc] != 0 &&
        cellVal == widget.puzzle[sr][sc] &&
        !(sr == row && sc == col);

    final boxIdx = (row ~/ 3) * 3 + (col ~/ 3);
    final isFlashing = widget.flashingRows.contains(row) ||
        widget.flashingCols.contains(col) ||
        widget.flashingBoxes.contains(boxIdx);
    final isCompletedGroup = widget.completedRows.contains(row) ||
        widget.completedCols.contains(col) ||
        widget.completedBoxes.contains(boxIdx);

    // Background color
    Color bgColor = Colors.white;
    if (isSelected) {
      bgColor = widget.accentColor.withValues(alpha: 0.14);
    } else if (isError) {
      bgColor = const Color(0xFFFFE4E4);
    } else if (isSameNum) {
      bgColor = widget.accentColor.withValues(alpha: 0.11);
    } else if (isHighlighted) {
      bgColor = widget.accentColor.withValues(alpha: 0.055);
    }

    // Apply completion tints
    if (isFlashing) {
      bgColor = Color.alphaBlend(const Color(0xFF22C55E).withValues(alpha: 0.18), bgColor);
    } else if (isCompletedGroup) {
      bgColor = Color.alphaBlend(const Color(0xFF22C55E).withValues(alpha: 0.05), bgColor);
    }

    // Text color
    Color textColor;
    if (isError) {
      textColor = const Color(0xFFDC2626);
    } else if (isGiven) {
      textColor = const Color(0xFF1E1B4B); // deep indigo-950
    } else {
      textColor = widget.accentColor;
    }

    // Border: box separators are rich indigo, thin lines are soft slate
    final isThickLeft   = col % 3 == 0;
    final isThickTop    = row % 3 == 0;
    final isThickRight  = col == 8;
    final isThickBottom = row == 8;

    const boxBorderColor  = Color(0xFF4338CA); // indigo-700 — box dividers
    const cellBorderColor = Color(0xFFCBD5E1); // slate-300 — thin cell lines

    final leftWidth   = isThickLeft   ? 1.8 : 0.5;
    final topWidth    = isThickTop    ? 1.8 : 0.5;
    final rightWidth  = isThickRight  ? 1.8 : 0.5;
    final bottomWidth = isThickBottom ? 1.8 : 0.5;

    final leftColor   = isThickLeft   ? boxBorderColor  : cellBorderColor;
    final topColor    = isThickTop    ? boxBorderColor  : cellBorderColor;
    final rightColor  = isThickRight  ? boxBorderColor  : cellBorderColor;
    final bottomColor = isThickBottom ? boxBorderColor  : cellBorderColor;

    final isAnimCell = widget.animRow == row && widget.animCol == col;

    Widget cellContainer = Stack(
      children: [
        Container(
          width: cellSize,
          height: cellSize,
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              left:   BorderSide(color: leftColor,   width: leftWidth),
              top:    BorderSide(color: topColor,    width: topWidth),
              right:  BorderSide(color: rightColor,  width: rightWidth),
              bottom: BorderSide(color: bottomColor, width: bottomWidth),
            ),
          ),
          child: Center(
            child: cellVal != 0
                ? Text(
                    '$cellVal',
                    style: TextStyle(
                      fontSize: cellSize * 0.50,
                      fontWeight: isGiven ? FontWeight.w900 : FontWeight.w600,
                      color: textColor,
                      height: 1,
                    ),
                  )
                : null,
          ),
        ),
        // Selected cell: top-edge accent bar
        if (isSelected)
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 2.5,
              decoration: BoxDecoration(
                color: widget.accentColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(1)),
              ),
            ),
          ),
      ],
    );

    if (isAnimCell && widget.animCorrect) {
      cellContainer = AnimatedBuilder(
        animation: _entryCtrl,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnim.value, child: child);
        },
        child: cellContainer,
      );
    } else if (isAnimCell && !widget.animCorrect && widget.animRow >= 0) {
      cellContainer = AnimatedBuilder(
        animation: _shakeCtrl,
        builder: (context, child) {
          final dx = sin(_shakeCtrl.value * 3 * pi) * 5.0;
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: cellContainer,
      );
    }

    return GestureDetector(
      onTap: () => widget.onTap(row, col),
      child: cellContainer,
    );
  }
}

// ════════════════════════════════════════════════════════════════
// NUMBER KEYPAD
// ════════════════════════════════════════════════════════════════

class _NumberKeypad extends StatelessWidget {
  final void Function(int) onNumber;
  final VoidCallback onErase;
  final VoidCallback onHint;
  final bool hintUsed;
  final Color accentColor;
  const _NumberKeypad({
    required this.onNumber,
    required this.onErase,
    required this.onHint,
    required this.hintUsed,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final hintAvailable = !hintUsed && AdsService().isRewardedReady;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ...List.generate(9, (i) {
                final digit = i + 1;
                return Expanded(
                  child: _KeypadButton(
                    label: '$digit',
                    accentColor: accentColor,
                    onTap: () => onNumber(digit),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _KeypadButton(
                label: '⌫',
                accentColor: accentColor,
                isErase: true,
                fixedWidth: 52,
                onTap: onErase,
              ),
              const SizedBox(width: 10),
              _KeypadButton(
                label: '💡',
                accentColor: const Color(0xFFFFD43B),
                isHint: true,
                fixedWidth: 52,
                onTap: hintAvailable ? onHint : null,
                disabled: !hintAvailable,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeypadButton extends StatefulWidget {
  final String label;
  final Color accentColor;
  final bool isErase;
  final bool isHint;
  final bool disabled;
  final double? fixedWidth;
  final VoidCallback? onTap;

  const _KeypadButton({
    required this.label,
    required this.accentColor,
    this.isErase = false,
    this.isHint = false,
    this.disabled = false,
    this.fixedWidth,
    required this.onTap,
  });

  @override
  State<_KeypadButton> createState() => _KeypadButtonState();
}

class _KeypadButtonState extends State<_KeypadButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.disabled || widget.onTap == null;
    final double opacity = isDisabled ? 0.35 : 1.0;

    Color bg;
    Color border;
    Color textColor;

    if (widget.isHint) {
      bg = const Color(0xFFFFF9DB);
      border = const Color(0xFFFFD43B).withValues(alpha: 0.50);
      textColor = const Color(0xFFF59F00);
    } else if (widget.isErase) {
      bg = Colors.white;
      border = const Color(0xFFEF4444).withValues(alpha: 0.30);
      textColor = const Color(0xFFEF4444);
    } else {
      bg = widget.accentColor.withValues(alpha: 0.10);
      border = widget.accentColor.withValues(alpha: 0.22);
      textColor = widget.accentColor;
    }

    Widget child;
    if (widget.isErase) {
      child = Icon(Icons.backspace_rounded, size: 18, color: textColor);
    } else if (widget.isHint) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lightbulb_rounded, size: 16, color: textColor),
          const SizedBox(width: 3),
          Icon(Icons.play_circle_filled_rounded, size: 12, color: textColor.withValues(alpha: 0.7)),
        ],
      );
    } else {
      child = Text(
        widget.label,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor, height: 1),
      );
    }

    final inner = AnimatedScale(
      scale: _pressed ? 0.88 : 1.0,
      duration: const Duration(milliseconds: 70),
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: widget.fixedWidth,
          height: 52,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: textColor.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(child: child),
        ),
      ),
    );

    return GestureDetector(
      onTapDown: !isDisabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: !isDisabled ? (_) { setState(() => _pressed = false); widget.onTap!(); } : null,
      onTapCancel: !isDisabled ? () => setState(() => _pressed = false) : null,
      child: widget.fixedWidth != null ? inner : Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: inner,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// RESULT STATS
// ════════════════════════════════════════════════════════════════

class _SudokuResultStats extends StatelessWidget {
  final int elapsedSeconds;
  final int errorCount;
  final int? bestSeconds;
  final Color accentColor;

  const _SudokuResultStats({
    required this.elapsedSeconds,
    required this.errorCount,
    required this.bestSeconds,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8475C2).withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _statCol('TIME', _formatTime(elapsedSeconds), accentColor),
          _divider(),
          _statCol('ERRORS', '$errorCount', Colors.redAccent),
          _divider(),
          _statCol(
            'BEST',
            bestSeconds != null ? _formatTime(bestSeconds!) : '--',
            const Color(0xFF8B7BA7),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Container(width: 1, height: 48, color: Colors.black.withValues(alpha: 0.1)),
  );

  Widget _statCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ],
    );
  }
}

// ── Background painter ────────────────────────────────────────────────────────

class _SudokuBgPainter extends AnimatedBgPainter {
  const _SudokuBgPainter(super.t);

  // Floating digit tiles: (digit, xRel, yRel, phaseOffset)
  static const List<(String, double, double, double)> _tiles = [
    ('5', 0.08, 0.09, 0.0),
    ('3', 0.82, 0.07, 0.7),
    ('9', 0.18, 0.80, 1.4),
    ('7', 0.76, 0.78, 2.1),
    ('1', 0.88, 0.44, 2.8),
    ('6', 0.04, 0.52, 3.5),
    ('4', 0.58, 0.92, 4.2),
    ('8', 0.42, 0.04, 4.9),
    ('2', 0.65, 0.30, 5.6),
  ];

  @override
  void paintAt(Canvas canvas, Size size, double t) {
    final phase = t * 2 * pi;
    const tileSize = 48.0;
    final cellPaint = Paint()..color = _kAccent;
    final borderPaint = Paint()
      ..color = _kAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (final (digit, xRel, yRel, p) in _tiles) {
      final wave = sin(phase + p);
      final yBob = wave * 7.0;
      final rot = sin(phase * 0.6 + p) * 0.12;
      final alphaBg = 0.08 + (sin(phase * 1.2 + p) + 1) / 2 * 0.07;
      final alphaTxt = alphaBg * 2.2;

      final cx = size.width * xRel;
      final cy = size.height * yRel + yBob;

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rot);

      final rect = Rect.fromCenter(center: Offset.zero, width: tileSize, height: tileSize);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));

      // Cell fill
      canvas.drawRRect(rrect, cellPaint..color = _kAccent.withValues(alpha: alphaBg));
      // Cell border
      canvas.drawRRect(rrect, borderPaint..color = _kAccent.withValues(alpha: alphaBg + 0.08));

      // Inner 3×3 grid lines (mini Sudoku cell feel)
      final linePaint = Paint()
        ..color = _kAccent.withValues(alpha: alphaBg * 0.9)
        ..strokeWidth = 0.6;
      final third = tileSize / 3;
      for (int i = 1; i <= 2; i++) {
        final offset = -tileSize / 2 + i * third;
        canvas.drawLine(Offset(offset, -tileSize / 2), Offset(offset, tileSize / 2), linePaint);
        canvas.drawLine(Offset(-tileSize / 2, offset), Offset(tileSize / 2, offset), linePaint);
      }

      // Digit
      final tp = TextPainter(
        text: TextSpan(
          text: digit,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _kAccent.withValues(alpha: alphaTxt.clamp(0.0, 1.0)),
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));

      canvas.restore();
    }
  }
}

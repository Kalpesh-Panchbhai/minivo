import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../framework/game_definition.dart';
import '../framework/game_scaffold.dart';
import '../framework/game_session.dart';
import '../shared/animated_background.dart';
import 'sudoku_definition.dart';
import 'sudoku_engine.dart';
import 'sudoku_stats.dart';

// ── Palette ─────────────────────────────────────────────────────────────────
const Color _kAccent = Color(0xFF6366F1); // indigo-500

// ════════════════════════════════════════════════════════════════
// Root screen — thin wrapper around GameScaffold
// ════════════════════════════════════════════════════════════════

class SudokuScreen extends StatelessWidget {
  const SudokuScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      GameScaffold(definition: sudokuGame);
}

// ════════════════════════════════════════════════════════════════
// Board — playing-state widget driven by GameSession
// ════════════════════════════════════════════════════════════════

class SudokuBoard extends StatefulWidget {
  final GameSession session;
  const SudokuBoard({required this.session, super.key});

  @override
  State<SudokuBoard> createState() => _SudokuBoardState();
}

class _SudokuBoardState extends State<SudokuBoard> {
  // Board state
  List<List<int>> _puzzle = [];
  List<List<int>> _solution = [];
  List<List<bool>> _given = [];
  int? _selRow, _selCol;
  bool _isGenerating = true;
  bool _completed = false;

  // Animation triggers
  int _animRow = -1;
  int _animCol = -1;
  bool _animCorrect = false;

  // Completion tracking
  Set<int> _completedRows = {};
  Set<int> _completedCols = {};
  Set<int> _completedBoxes = {};
  Set<int> _flashingRows = {};
  Set<int> _flashingCols = {};
  Set<int> _flashingBoxes = {};

  StreamSubscription<void>? _restartSub;

  DifficultyDef get _diff => widget.session.difficulty;

  @override
  void initState() {
    super.initState();
    _generate();
    _restartSub = widget.session.restartSignal.listen((_) {
      if (mounted) _generate();
    });
  }

  @override
  void dispose() {
    _restartSub?.cancel();
    super.dispose();
  }

  void _generate() {
    final clues = switch (_diff.key) {
      'easy' => 46,
      'medium' => 36,
      'hard' => 28,
      _ => 36,
    };
    setState(() => _isGenerating = true);

    compute(generateSudokuPuzzle, clues).then((result) {
      if (!mounted) return;
      final given = List.generate(
        9,
        (r) => List.generate(9, (c) => result.puzzle[r][c] != 0),
      );
      final puzzle = result.puzzle.map((row) => List<int>.from(row)).toList();
      setState(() {
        _puzzle = puzzle;
        _solution = result.solution;
        _given = given;
        _selRow = null;
        _selCol = null;
        _isGenerating = false;
        _completed = false;
        _animRow = -1;
        _animCol = -1;
        _animCorrect = false;
        _completedRows = {};
        _completedCols = {};
        _completedBoxes = {};
        _flashingRows = {};
        _flashingCols = {};
        _flashingBoxes = {};
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
    final bool rowDone = List.generate(
        9, (col) => _puzzle[r][col] == _solution[r][col]).every((b) => b);
    final bool colDone = List.generate(
        9, (row) => _puzzle[row][c] == _solution[row][c]).every((b) => b);
    final br = (r ~/ 3) * 3, bc = (c ~/ 3) * 3;
    final bool boxDone = [
      for (int dr = 0; dr < 3; dr++)
        for (int dc = 0; dc < 3; dc++)
          _puzzle[br + dr][bc + dc] == _solution[br + dr][bc + dc]
    ].every((b) => b);
    final boxIdx = (r ~/ 3) * 3 + (c ~/ 3);

    final newFlashRows = <int>{};
    final newFlashCols = <int>{};
    final newFlashBoxes = <int>{};
    if (rowDone && !_completedRows.contains(r)) {
      newFlashRows.add(r);
      _completedRows.add(r);
    }
    if (colDone && !_completedCols.contains(c)) {
      newFlashCols.add(c);
      _completedCols.add(c);
    }
    if (boxDone && !_completedBoxes.contains(boxIdx)) {
      newFlashBoxes.add(boxIdx);
      _completedBoxes.add(boxIdx);
    }

    if (newFlashRows.isNotEmpty ||
        newFlashCols.isNotEmpty ||
        newFlashBoxes.isNotEmpty) {
      setState(() {
        _flashingRows = newFlashRows;
        _flashingCols = newFlashCols;
        _flashingBoxes = newFlashBoxes;
      });
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) {
          setState(() {
            _flashingRows = {};
            _flashingCols = {};
            _flashingBoxes = {};
          });
        }
      });
    }
  }

  void _onNumberInput(int num) {
    if (_completed) return;
    final r = _selRow;
    final c = _selCol;
    if (r == null || c == null) return;
    if (_given[r][c]) return;

    final isCorrect = num == _solution[r][c];
    if (_puzzle[r][c] == num) return;
    setState(() {
      _puzzle[r][c] = num;
      _animRow = r;
      _animCol = c;
      _animCorrect = isCorrect;
    });
    if (!isCorrect) {
      widget.session.incrementMistakes();
      HapticFeedback.mediumImpact();
    } else {
      _recomputeCompletion(r, c);
    }

    Future.delayed(const Duration(milliseconds: 420), () {
      if (mounted) {
        setState(() {
          _animRow = -1;
          _animCol = -1;
        });
      }
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

  void _onGameComplete() {
    if (_completed) return;
    _completed = true;
    final secs = widget.session.elapsedTime.inSeconds;
    final score = kSudokuMaxScore - secs;
    widget.session.updateScore(score);
    widget.session.completeGame();
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isGenerating) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Expanded(
          child: _SudokuGrid(
            puzzle: _puzzle,
            given: _given,
            solution: _solution,
            selRow: _selRow,
            selCol: _selCol,
            showErrors: true,
            accentColor: _diff.color,
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
          accentColor: _diff.color,
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

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

class _SudokuGridState extends State<_SudokuGrid>
    with TickerProviderStateMixin {
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
    final isHighlighted = sr != null &&
        sc != null &&
        (sr == row || sc == col || _isSameBox(row, col, sr, sc));
    final cellVal = widget.puzzle.isNotEmpty ? widget.puzzle[row][col] : 0;
    final solVal =
        widget.solution.isNotEmpty ? widget.solution[row][col] : 0;
    final isGiven = widget.given.isNotEmpty ? widget.given[row][col] : false;
    final isError = widget.showErrors && cellVal != 0 && cellVal != solVal;
    final isSameNum = sr != null &&
        sc != null &&
        widget.puzzle.isNotEmpty &&
        widget.puzzle[sr][sc] != 0 &&
        cellVal == widget.puzzle[sr][sc] &&
        !(sr == row && sc == col);

    final boxIdx = (row ~/ 3) * 3 + (col ~/ 3);
    final isFlashing = widget.flashingRows.contains(row) ||
        widget.flashingCols.contains(col) ||
        widget.flashingBoxes.contains(boxIdx);
    final isCompletedGroup = widget.completedRows.contains(row) ||
        widget.completedCols.contains(col) ||
        widget.completedBoxes.contains(boxIdx);

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

    if (isFlashing) {
      bgColor = Color.alphaBlend(
          const Color(0xFF22C55E).withValues(alpha: 0.18), bgColor);
    } else if (isCompletedGroup) {
      bgColor = Color.alphaBlend(
          const Color(0xFF22C55E).withValues(alpha: 0.05), bgColor);
    }

    Color textColor;
    if (isError) {
      textColor = const Color(0xFFDC2626);
    } else if (isGiven) {
      textColor = const Color(0xFF1E1B4B);
    } else {
      textColor = widget.accentColor;
    }

    final isThickLeft = col % 3 == 0;
    final isThickTop = row % 3 == 0;
    final isThickRight = col == 8;
    final isThickBottom = row == 8;

    const boxBorderColor = Color(0xFF4338CA);
    const cellBorderColor = Color(0xFFCBD5E1);

    final leftWidth = isThickLeft ? 1.8 : 0.5;
    final topWidth = isThickTop ? 1.8 : 0.5;
    final rightWidth = isThickRight ? 1.8 : 0.5;
    final bottomWidth = isThickBottom ? 1.8 : 0.5;

    final leftColor = isThickLeft ? boxBorderColor : cellBorderColor;
    final topColor = isThickTop ? boxBorderColor : cellBorderColor;
    final rightColor = isThickRight ? boxBorderColor : cellBorderColor;
    final bottomColor = isThickBottom ? boxBorderColor : cellBorderColor;

    final isAnimCell = widget.animRow == row && widget.animCol == col;

    Widget cellContainer = Stack(
      children: [
        Container(
          width: cellSize,
          height: cellSize,
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              left: BorderSide(color: leftColor, width: leftWidth),
              top: BorderSide(color: topColor, width: topWidth),
              right: BorderSide(color: rightColor, width: rightWidth),
              bottom: BorderSide(color: bottomColor, width: bottomWidth),
            ),
          ),
          child: Center(
            child: cellVal != 0
                ? Text(
                    '$cellVal',
                    style: TextStyle(
                      fontSize: cellSize * 0.50,
                      fontWeight:
                          isGiven ? FontWeight.w900 : FontWeight.w600,
                      color: textColor,
                      height: 1,
                    ),
                  )
                : null,
          ),
        ),
        if (isSelected)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 2.5,
              decoration: BoxDecoration(
                color: widget.accentColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(1)),
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
  final Color accentColor;
  const _NumberKeypad({
    required this.onNumber,
    required this.onErase,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
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
          const SizedBox(width: 6),
          _KeypadButton(
            label: '⌫',
            accentColor: accentColor,
            isErase: true,
            fixedWidth: 44,
            onTap: onErase,
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
  final double? fixedWidth;
  final VoidCallback? onTap;

  const _KeypadButton({
    required this.label,
    required this.accentColor,
    this.isErase = false,
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
    final bg = widget.isErase
        ? Colors.white
        : widget.accentColor.withValues(alpha: 0.10);
    final border = widget.isErase
        ? const Color(0xFFEF4444).withValues(alpha: 0.30)
        : widget.accentColor.withValues(alpha: 0.22);
    final textColor = widget.isErase
        ? const Color(0xFFEF4444)
        : widget.accentColor;

    final inner = AnimatedScale(
      scale: _pressed ? 0.88 : 1.0,
      duration: const Duration(milliseconds: 70),
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
        child: Center(
          child: widget.isErase
              ? Icon(Icons.backspace_rounded, size: 18, color: textColor)
              : Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    height: 1,
                  ),
                ),
        ),
      ),
    );

    return GestureDetector(
      onTapDown:
          widget.onTap != null ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.onTap != null
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      onTapCancel:
          widget.onTap != null ? () => setState(() => _pressed = false) : null,
      child: widget.fixedWidth != null
          ? inner
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: inner,
            ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Background painter
// ════════════════════════════════════════════════════════════════

class SudokuBgPainter extends AnimatedBgPainter {
  const SudokuBgPainter(super.t);

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

      final rect = Rect.fromCenter(
          center: Offset.zero, width: tileSize, height: tileSize);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));

      canvas.drawRRect(
          rrect, cellPaint..color = _kAccent.withValues(alpha: alphaBg));
      canvas.drawRRect(rrect,
          borderPaint..color = _kAccent.withValues(alpha: alphaBg + 0.08));

      final linePaint = Paint()
        ..color = _kAccent.withValues(alpha: alphaBg * 0.9)
        ..strokeWidth = 0.6;
      final third = tileSize / 3;
      for (int i = 1; i <= 2; i++) {
        final offset = -tileSize / 2 + i * third;
        canvas.drawLine(Offset(offset, -tileSize / 2),
            Offset(offset, tileSize / 2), linePaint);
        canvas.drawLine(Offset(-tileSize / 2, offset),
            Offset(tileSize / 2, offset), linePaint);
      }

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

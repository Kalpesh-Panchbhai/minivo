import 'dart:math';
import 'package:flutter/material.dart';
import '../game_wrapper.dart';

class NumberMergeScreen extends StatefulWidget {
  const NumberMergeScreen({super.key});

  @override
  State<NumberMergeScreen> createState() => _NumberMergeScreenState();
}

class _NumberMergeScreenState extends State<NumberMergeScreen> {
  static const int gridSize = 4;
  late List<List<int>> _grid;
  final _rand = Random();
  int _score = 0;

  @override
  void initState() {
    super.initState();
    _initGrid();
  }

  void _initGrid() {
    _grid = List.generate(gridSize, (_) => List.filled(gridSize, 0));
    _score = 0;
    _addRandomTile();
    _addRandomTile();
  }

  void _addRandomTile() {
    final empties = <Point<int>>[];
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (_grid[r][c] == 0) empties.add(Point(r, c));
      }
    }
    if (empties.isEmpty) return;
    final spot = empties[_rand.nextInt(empties.length)];
    _grid[spot.x][spot.y] = _rand.nextDouble() < 0.9 ? 2 : 4;
  }

  List<int> _merge(List<int> row) {
    final nonZero = row.where((e) => e != 0).toList();
    final merged = <int>[];
    int i = 0;
    while (i < nonZero.length) {
      if (i + 1 < nonZero.length && nonZero[i] == nonZero[i + 1]) {
        final val = nonZero[i] * 2;
        merged.add(val);
        _score += val;
        i += 2;
      } else {
        merged.add(nonZero[i]);
        i++;
      }
    }
    while (merged.length < gridSize) merged.add(0);
    return merged;
  }

  void _move(Direction dir) {
    final wrapper = GameWrapper.of(context);
    if (wrapper.state != GameState.playing) return;

    final prev = _grid.map((r) => List<int>.from(r)).toList();
    bool changed = false;

    switch (dir) {
      case Direction.left:
        for (int r = 0; r < gridSize; r++) {
          _grid[r] = _merge(_grid[r]);
        }
        break;
      case Direction.right:
        for (int r = 0; r < gridSize; r++) {
          _grid[r] = _merge(_grid[r].reversed.toList()).reversed.toList();
        }
        break;
      case Direction.up:
        for (int c = 0; c < gridSize; c++) {
          final col = List.generate(gridSize, (r) => _grid[r][c]);
          final merged = _merge(col);
          for (int r = 0; r < gridSize; r++) _grid[r][c] = merged[r];
        }
        break;
      case Direction.down:
        for (int c = 0; c < gridSize; c++) {
          final col = List.generate(gridSize, (r) => _grid[r][c]).reversed.toList();
          final merged = _merge(col).reversed.toList();
          for (int r = 0; r < gridSize; r++) _grid[r][c] = merged[r];
        }
        break;
    }

    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (_grid[r][c] != prev[r][c]) changed = true;
      }
    }

    if (changed) {
      _addRandomTile();
      wrapper.updateScore(_score);

      if (_isGameOver()) {
        wrapper.endGame();
      }
    }

    setState(() {});
  }

  bool _isGameOver() {
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (_grid[r][c] == 0) return false;
        if (c + 1 < gridSize && _grid[r][c] == _grid[r][c + 1]) return false;
        if (r + 1 < gridSize && _grid[r][c] == _grid[r + 1][c]) return false;
      }
    }
    return true;
  }

  Color _tileColor(int val) {
    switch (val) {
      case 2: return const Color(0xFFEDE4DA);
      case 4: return const Color(0xFFECDFC6);
      case 8: return const Color(0xFFF2B179);
      case 16: return const Color(0xFFF59563);
      case 32: return const Color(0xFFF67C60);
      case 64: return const Color(0xFFF65E3B);
      case 128: return const Color(0xFFEDCF73);
      case 256: return const Color(0xFFEDCC62);
      case 512: return const Color(0xFFEDC850);
      case 1024: return const Color(0xFFEDC53F);
      case 2048: return const Color(0xFFEDC22E);
      default: return const Color(0xFF3C3A33);
    }
  }

  Color _textColor(int val) {
    return val <= 4 ? const Color(0xFF776E65) : Colors.white;
  }

  double _fontSize(int val) {
    if (val < 100) return 28;
    if (val < 1000) return 22;
    return 18;
  }

  @override
  Widget build(BuildContext context) {
    final wrapper = GameWrapper.of(context);

    // Reset when wrapper restarts
    if (wrapper.state == GameState.ready && _score > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _initGrid());
      });
    }

    return GestureDetector(
      onHorizontalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 0) {
          _move(Direction.right);
        } else {
          _move(Direction.left);
        }
      },
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 0) {
          _move(Direction.down);
        } else {
          _move(Direction.up);
        }
      },
      child: Container(
        color: const Color(0xFFFAF8F0),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFBBADA0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: gridSize,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: gridSize * gridSize,
                  itemBuilder: (context, index) {
                    final r = index ~/ gridSize;
                    final c = index % gridSize;
                    final val = _grid[r][c];
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: val == 0
                            ? const Color(0xFFCDC1B4)
                            : _tileColor(val),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: val > 0
                            ? Text(
                                '$val',
                                style: TextStyle(
                                  fontSize: _fontSize(val),
                                  fontWeight: FontWeight.w800,
                                  color: _textColor(val),
                                ),
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum Direction { up, down, left, right }

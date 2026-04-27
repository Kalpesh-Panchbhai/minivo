import 'dart:math';
import 'package:flutter/material.dart';
import '../game_wrapper.dart';

class BlockFitScreen extends StatefulWidget {
  const BlockFitScreen({super.key});

  @override
  State<BlockFitScreen> createState() => _BlockFitScreenState();
}

class _BlockFitScreenState extends State<BlockFitScreen> {
  static const int boardSize = 8;
  late List<List<bool>> _board;
  late List<_BlockShape> _available;
  int _score = 0;
  final _rand = Random();

  static const List<List<List<int>>> _shapes = [
    // Single
    [[1]],
    // Horizontal 2
    [[1, 1]],
    // Horizontal 3
    [[1, 1, 1]],
    // Vertical 2
    [[1], [1]],
    // Vertical 3
    [[1], [1], [1]],
    // L shape
    [[1, 0], [1, 0], [1, 1]],
    // Square 2x2
    [[1, 1], [1, 1]],
    // T shape
    [[1, 1, 1], [0, 1, 0]],
    // Z shape
    [[1, 1, 0], [0, 1, 1]],
    // Corner
    [[1, 1], [1, 0]],
  ];

  @override
  void initState() {
    super.initState();
    _initBoard();
  }

  void _initBoard() {
    _board = List.generate(boardSize, (_) => List.filled(boardSize, false));
    _score = 0;
    _generateShapes();
  }

  void _generateShapes() {
    _available = List.generate(3, (_) {
      final shape = _shapes[_rand.nextInt(_shapes.length)];
      final color = _blockColors[_rand.nextInt(_blockColors.length)];
      return _BlockShape(shape: shape, color: color);
    });
  }

  static const _blockColors = [
    Color(0xFF6C63FF),
    Color(0xFFFF6B6B),
    Color(0xFF4ECDC4),
    Color(0xFFFF922B),
    Color(0xFF51CF66),
    Color(0xFFFFD43B),
  ];

  bool _canPlace(List<List<int>> shape, int startR, int startC) {
    for (int r = 0; r < shape.length; r++) {
      for (int c = 0; c < shape[r].length; c++) {
        if (shape[r][c] == 1) {
          final br = startR + r;
          final bc = startC + c;
          if (br < 0 || br >= boardSize || bc < 0 || bc >= boardSize) return false;
          if (_board[br][bc]) return false;
        }
      }
    }
    return true;
  }

  void _placeShape(List<List<int>> shape, int startR, int startC, Color color) {
    for (int r = 0; r < shape.length; r++) {
      for (int c = 0; c < shape[r].length; c++) {
        if (shape[r][c] == 1) {
          _board[startR + r][startC + c] = true;
        }
      }
    }
    _clearLines();
  }

  void _clearLines() {
    final wrapper = GameWrapper.of(context);
    int cleared = 0;

    // Check rows
    for (int r = 0; r < boardSize; r++) {
      if (_board[r].every((cell) => cell)) {
        _board[r] = List.filled(boardSize, false);
        cleared++;
      }
    }

    // Check columns
    for (int c = 0; c < boardSize; c++) {
      bool full = true;
      for (int r = 0; r < boardSize; r++) {
        if (!_board[r][c]) { full = false; break; }
      }
      if (full) {
        for (int r = 0; r < boardSize; r++) _board[r][c] = false;
        cleared++;
      }
    }

    if (cleared > 0) {
      _score += cleared * 10 * cleared; // combo bonus
      wrapper.updateScore(_score);
    }
  }

  bool _canPlaceAny() {
    for (final block in _available) {
      for (int r = 0; r < boardSize; r++) {
        for (int c = 0; c < boardSize; c++) {
          if (_canPlace(block.shape, r, c)) return true;
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final wrapper = GameWrapper.of(context);

    if (wrapper.state == GameState.ready && _score > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _initBoard());
      });
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final cellSize = (screenWidth - 48) / boardSize;

    return Container(
      color: const Color(0xFFF5F3EE),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 80),
            // Board
            Center(
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E4DD),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SizedBox(
                  width: cellSize * boardSize + 4,
                  height: cellSize * boardSize + 4,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: boardSize,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                    ),
                    itemCount: boardSize * boardSize,
                    itemBuilder: (context, index) {
                      final r = index ~/ boardSize;
                      final c = index % boardSize;
                      return DragTarget<_DragData>(
                        onWillAcceptWithDetails: (details) {
                          final data = details.data;
                          return _canPlace(data.shape.shape, r, c);
                        },
                        onAcceptWithDetails: (details) {
                          final data = details.data;
                          setState(() {
                            _placeShape(data.shape.shape, r, c, data.shape.color);
                            _available.removeAt(data.index);
                            if (_available.isEmpty) _generateShapes();
                            if (!_canPlaceAny()) {
                              wrapper.endGame();
                            }
                          });
                        },
                        builder: (context, candidateData, rejectedData) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: _board[r][c]
                                  ? const Color(0xFF6C63FF).withValues(alpha: 0.7)
                                  : candidateData.isNotEmpty
                                      ? const Color(0xFF6C63FF).withValues(alpha: 0.2)
                                      : const Color(0xFFF8F6F1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),

            const Spacer(),

            // Available blocks
            Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_available.length, (i) {
                  final block = _available[i];
                  return Draggable<_DragData>(
                    data: _DragData(shape: block, index: i),
                    feedback: _buildMiniBlock(block, cellSize * 0.6, 0.8),
                    childWhenDragging: Opacity(
                      opacity: 0.3,
                      child: _buildMiniBlock(block, cellSize * 0.5, 1),
                    ),
                    child: _buildMiniBlock(block, cellSize * 0.5, 1),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBlock(_BlockShape block, double cellSize, double opacity) {
    final rows = block.shape.length;
    final cols = block.shape.isEmpty ? 0 : block.shape[0].length;
    return Opacity(
      opacity: opacity,
      child: SizedBox(
        width: cols * cellSize + (cols - 1) * 2,
        height: rows * cellSize + (rows - 1) * 2,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: rows * cols,
          itemBuilder: (context, index) {
            final r = index ~/ cols;
            final c = index % cols;
            return Container(
              decoration: BoxDecoration(
                color: block.shape[r][c] == 1
                    ? block.color
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BlockShape {
  final List<List<int>> shape;
  final Color color;
  const _BlockShape({required this.shape, required this.color});
}

class _DragData {
  final _BlockShape shape;
  final int index;
  const _DragData({required this.shape, required this.index});
}

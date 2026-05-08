import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/services/audio_service.dart';
import '../framework/game_definition.dart';
import '../framework/game_scaffold.dart';
import '../framework/game_session.dart';
import '../shared/animated_background.dart';
import 'number_merge_definition.dart';

// ── 2048 board palette ─────────────────────────────────────────────────────
const Color _kBoardBg = Color(0xFFBBADA0);
const Color _kEmptyCell = Color(0xFFCDC1B4);

// ── Tile color palette (original 2048) ─────────────────────────────────────
const Map<int, _TileStyle> _kTileStyles = {
  2: _TileStyle(Color(0xFFEEE4DA), Color(0xFF776E65)),
  4: _TileStyle(Color(0xFFEDE0C8), Color(0xFF776E65)),
  8: _TileStyle(Color(0xFFF2B179), Color(0xFFF9F6F2)),
  16: _TileStyle(Color(0xFFF59563), Color(0xFFF9F6F2)),
  32: _TileStyle(Color(0xFFF67C5F), Color(0xFFF9F6F2)),
  64: _TileStyle(Color(0xFFF65E3B), Color(0xFFF9F6F2)),
  128: _TileStyle(Color(0xFFEDCF72), Color(0xFFF9F6F2)),
  256: _TileStyle(Color(0xFFEDCC61), Color(0xFFF9F6F2)),
  512: _TileStyle(Color(0xFFEDC850), Color(0xFFF9F6F2)),
  1024: _TileStyle(Color(0xFFEDC53F), Color(0xFFF9F6F2)),
  2048: _TileStyle(Color(0xFFEDC22E), Color(0xFFF9F6F2)),
};

_TileStyle _styleFor(int v) =>
    _kTileStyles[v] ?? const _TileStyle(Color(0xFF3C3A32), Color(0xFFF9F6F2));

class _TileStyle {
  final Color bg;
  final Color fg;
  const _TileStyle(this.bg, this.fg);
}

double _tileFont(int v) {
  if (v < 100) return 30;
  if (v < 1000) return 24;
  if (v < 10000) return 18;
  return 14;
}

// ── Per-difficulty config ──────────────────────────────────────────────────
class _NMConfig {
  final int target;
  final double twoProb;
  const _NMConfig({required this.target, required this.twoProb});
}

const Map<String, _NMConfig> _kConfigs = {
  'easy': _NMConfig(target: 1024, twoProb: 0.90),
  'medium': _NMConfig(target: 2048, twoProb: 0.80),
  'hard': _NMConfig(target: 4096, twoProb: 0.65),
};

_NMConfig _configFor(DifficultyDef d) =>
    _kConfigs[d.key] ?? _kConfigs['medium']!;

// ── Tile identity tracking ─────────────────────────────────────────────────
class _Tile {
  final int id;
  int value;
  int row;
  int col;
  bool justSpawned;
  bool mergedOut = false;

  _Tile({
    required this.id,
    required this.value,
    required this.row,
    required this.col,
    this.justSpawned = false,
  });
}

const int _kN = 4;

// ════════════════════════════════════════════════════════════════
// Root screen — thin wrapper around GameScaffold
// ════════════════════════════════════════════════════════════════

class NumberMergeScreen extends StatelessWidget {
  const NumberMergeScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      GameScaffold(definition: numberMergeGame);
}

// ════════════════════════════════════════════════════════════════
// Board — playing-state widget driven by GameSession
// ════════════════════════════════════════════════════════════════

class NumberMergeBoard extends StatefulWidget {
  final GameSession session;
  const NumberMergeBoard({required this.session, super.key});

  @override
  State<NumberMergeBoard> createState() => _NumberMergeBoardState();
}

class _NumberMergeBoardState extends State<NumberMergeBoard> {
  final _rng = math.Random();
  List<_Tile> _tiles = [];
  int _nextId = 0;
  bool _won = false;
  bool _gameOver = false;

  // Swipe gesture state
  double _dragDx = 0;
  double _dragDy = 0;

  DifficultyDef get _diff => widget.session.difficulty;
  _NMConfig get _cfg => _configFor(_diff);

  @override
  void initState() {
    super.initState();
    final tiles = <_Tile>[];
    tiles.addAll(_spawnNewTile(tiles));
    tiles.addAll(_spawnNewTile(tiles));
    _tiles = tiles;
  }

  // ── Tile spawning ────────────────────────────────────────────────────────

  List<_Tile> _spawnNewTile(List<_Tile> existing, {double? twoProb}) {
    final occupied = <String>{};
    for (final t in existing) {
      if (!t.mergedOut) occupied.add('${t.row},${t.col}');
    }
    final empties = <(int, int)>[];
    for (int r = 0; r < _kN; r++) {
      for (int c = 0; c < _kN; c++) {
        if (!occupied.contains('$r,$c')) empties.add((r, c));
      }
    }
    if (empties.isEmpty) return [];
    final (r, c) = empties[_rng.nextInt(empties.length)];
    final prob = twoProb ?? 0.9;
    final value = _rng.nextDouble() < prob ? 2 : 4;
    return [
      _Tile(id: _nextId++, value: value, row: r, col: c, justSpawned: true)
    ];
  }

  // ── Slide logic ──────────────────────────────────────────────────────────

  (List<_Tile>, int, bool) _slideLeft(List<_Tile> tiles) {
    final result = <_Tile>[];
    int score = 0;
    bool moved = false;

    for (int row = 0; row < _kN; row++) {
      final rowTiles = tiles.where((t) => t.row == row && !t.mergedOut).toList()
        ..sort((a, b) => a.col.compareTo(b.col));

      int targetCol = 0;
      int i = 0;
      while (i < rowTiles.length) {
        final tile = rowTiles[i];
        if (i + 1 < rowTiles.length && tile.value == rowTiles[i + 1].value) {
          if (tile.col != targetCol || tile.row != row) moved = true;
          tile
            ..value = tile.value * 2
            ..col = targetCol
            ..row = row;
          result.add(tile);

          final loser = rowTiles[i + 1];
          if (loser.col != targetCol || loser.row != row) moved = true;
          loser
            ..col = targetCol
            ..row = row
            ..mergedOut = true;
          result.add(loser);

          score += tile.value;
          i += 2;
        } else {
          if (tile.col != targetCol || tile.row != row) moved = true;
          tile
            ..col = targetCol
            ..row = row;
          result.add(tile);
          i++;
        }
        targetCol++;
      }
    }
    return (result, score, moved);
  }

  (List<_Tile>, int, bool) _slideRight(List<_Tile> tiles) {
    final result = <_Tile>[];
    int score = 0;
    bool moved = false;

    for (int row = 0; row < _kN; row++) {
      final rowTiles = tiles.where((t) => t.row == row && !t.mergedOut).toList()
        ..sort((a, b) => b.col.compareTo(a.col));

      int targetCol = _kN - 1;
      int i = 0;
      while (i < rowTiles.length) {
        final tile = rowTiles[i];
        if (i + 1 < rowTiles.length && tile.value == rowTiles[i + 1].value) {
          if (tile.col != targetCol || tile.row != row) moved = true;
          tile
            ..value = tile.value * 2
            ..col = targetCol
            ..row = row;
          result.add(tile);

          final loser = rowTiles[i + 1];
          if (loser.col != targetCol || loser.row != row) moved = true;
          loser
            ..col = targetCol
            ..row = row
            ..mergedOut = true;
          result.add(loser);

          score += tile.value;
          i += 2;
        } else {
          if (tile.col != targetCol || tile.row != row) moved = true;
          tile
            ..col = targetCol
            ..row = row;
          result.add(tile);
          i++;
        }
        targetCol--;
      }
    }
    return (result, score, moved);
  }

  (List<_Tile>, int, bool) _slideUp(List<_Tile> tiles) {
    final result = <_Tile>[];
    int score = 0;
    bool moved = false;

    for (int col = 0; col < _kN; col++) {
      final colTiles = tiles.where((t) => t.col == col && !t.mergedOut).toList()
        ..sort((a, b) => a.row.compareTo(b.row));

      int targetRow = 0;
      int i = 0;
      while (i < colTiles.length) {
        final tile = colTiles[i];
        if (i + 1 < colTiles.length && tile.value == colTiles[i + 1].value) {
          if (tile.row != targetRow || tile.col != col) moved = true;
          tile
            ..value = tile.value * 2
            ..row = targetRow
            ..col = col;
          result.add(tile);

          final loser = colTiles[i + 1];
          if (loser.row != targetRow || loser.col != col) moved = true;
          loser
            ..row = targetRow
            ..col = col
            ..mergedOut = true;
          result.add(loser);

          score += tile.value;
          i += 2;
        } else {
          if (tile.row != targetRow || tile.col != col) moved = true;
          tile
            ..row = targetRow
            ..col = col;
          result.add(tile);
          i++;
        }
        targetRow++;
      }
    }
    return (result, score, moved);
  }

  (List<_Tile>, int, bool) _slideDown(List<_Tile> tiles) {
    final result = <_Tile>[];
    int score = 0;
    bool moved = false;

    for (int col = 0; col < _kN; col++) {
      final colTiles = tiles.where((t) => t.col == col && !t.mergedOut).toList()
        ..sort((a, b) => b.row.compareTo(a.row));

      int targetRow = _kN - 1;
      int i = 0;
      while (i < colTiles.length) {
        final tile = colTiles[i];
        if (i + 1 < colTiles.length && tile.value == colTiles[i + 1].value) {
          if (tile.row != targetRow || tile.col != col) moved = true;
          tile
            ..value = tile.value * 2
            ..row = targetRow
            ..col = col;
          result.add(tile);

          final loser = colTiles[i + 1];
          if (loser.row != targetRow || loser.col != col) moved = true;
          loser
            ..row = targetRow
            ..col = col
            ..mergedOut = true;
          result.add(loser);

          score += tile.value;
          i += 2;
        } else {
          if (tile.row != targetRow || tile.col != col) moved = true;
          tile
            ..row = targetRow
            ..col = col;
          result.add(tile);
          i++;
        }
        targetRow--;
      }
    }
    return (result, score, moved);
  }

  bool _isGameOver(List<_Tile> tiles) {
    final occupied = <String>{};
    for (final t in tiles) {
      if (!t.mergedOut) occupied.add('${t.row},${t.col}');
    }
    if (occupied.length < _kN * _kN) return false;

    for (final t in tiles) {
      if (t.mergedOut) continue;
      for (final other in tiles) {
        if (other.mergedOut || other.id == t.id) continue;
        if (other.value == t.value) {
          if ((other.row == t.row && (other.col - t.col).abs() == 1) ||
              (other.col == t.col && (other.row - t.row).abs() == 1)) {
            return false;
          }
        }
      }
    }
    return true;
  }

  void _handleSwipeDirection(String dir) {
    if (_gameOver) return;

    final (slid, gained, moved) = switch (dir) {
      'left' => _slideLeft(List.from(_tiles)),
      'right' => _slideRight(List.from(_tiles)),
      'up' => _slideUp(List.from(_tiles)),
      _ => _slideDown(List.from(_tiles)),
    };

    if (!moved) return;

    final spawned = _spawnNewTile(slid, twoProb: _cfg.twoProb);
    final allTiles = [...slid, ...spawned];

    if (gained > 0) {
      widget.session.incrementScore(gained);
      AudioService().playScore();
    }

    setState(() {
      _tiles = allTiles;
    });

    if (!_won && allTiles.any((t) => !t.mergedOut && t.value >= _cfg.target)) {
      _won = true;
      widget.session.completeGame();
      return;
    }

    Future.delayed(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      setState(() {
        _tiles.removeWhere((t) => t.mergedOut);
        for (final t in _tiles) {
          t.justSpawned = false;
        }
      });
      if (_isGameOver(_tiles)) {
        setState(() => _gameOver = true);
        widget.session.failGame();
      }
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LayoutBuilder(
        builder: (context, c) {
          final side = math.min(c.maxWidth - 24, c.maxHeight);
          return SizedBox(
            width: side,
            height: side,
            child: _Board(
              side: side,
              tiles: _tiles,
              onSwipe: _handleSwipeDirection,
              onPanStart: () {
                _dragDx = 0;
                _dragDy = 0;
              },
              onPanUpdate: (dx, dy) {
                _dragDx += dx;
                _dragDy += dy;
              },
              dragDxGetter: () => _dragDx,
              dragDyGetter: () => _dragDy,
            ),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Board widget
// ════════════════════════════════════════════════════════════════

class _Board extends StatelessWidget {
  final double side;
  final List<_Tile> tiles;
  final ValueChanged<String> onSwipe;
  final VoidCallback onPanStart;
  final void Function(double dx, double dy) onPanUpdate;
  final double Function() dragDxGetter;
  final double Function() dragDyGetter;

  const _Board({
    required this.side,
    required this.tiles,
    required this.onSwipe,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.dragDxGetter,
    required this.dragDyGetter,
  });

  @override
  Widget build(BuildContext context) {
    const padding = 8.0;
    const gap = 8.0;
    const n = _kN;
    final cellSize = (side - 2 * padding - (n - 1) * gap) / n;

    double tileLeft(int col) => padding + col * (cellSize + gap);
    double tileTop(int row) => padding + row * (cellSize + gap);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => onPanStart(),
      onPanUpdate: (d) => onPanUpdate(d.delta.dx, d.delta.dy),
      onPanEnd: (d) {
        final v = d.velocity.pixelsPerSecond;
        final accDx = dragDxGetter();
        final accDy = dragDyGetter();
        final dx = math.max(v.dx.abs() / 4, accDx.abs());
        final dy = math.max(v.dy.abs() / 4, accDy.abs());
        if (dx < 24 && dy < 24) return;

        final velX = v.dx;
        final velY = v.dy;

        if (dx > dy) {
          final velSignal = v.dx.abs() / 4;
          final distSignal = accDx.abs();
          final goRight = (velSignal > distSignal) ? (velX > 0) : (accDx > 0);
          onSwipe(goRight ? 'right' : 'left');
        } else {
          final velSignal = v.dy.abs() / 4;
          final distSignal = accDy.abs();
          final goDown = (velSignal > distSignal) ? (velY > 0) : (accDy > 0);
          onSwipe(goDown ? 'down' : 'up');
        }
      },
      child: Container(
        width: side,
        height: side,
        decoration: BoxDecoration(
          color: _kBoardBg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            for (int r = 0; r < n; r++)
              for (int c = 0; c < n; c++)
                Positioned(
                  left: tileLeft(c),
                  top: tileTop(r),
                  width: cellSize,
                  height: cellSize,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _kEmptyCell,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
            for (final tile in tiles)
              AnimatedPositioned(
                key: ValueKey(tile.id),
                duration: const Duration(milliseconds: 130),
                curve: Curves.easeOutCubic,
                left: tileLeft(tile.col),
                top: tileTop(tile.row),
                width: cellSize,
                height: cellSize,
                child: _TileView(tile: tile, cellSize: cellSize),
              ),
          ],
        ),
      ),
    );
  }
}

class _TileView extends StatelessWidget {
  final _Tile tile;
  final double cellSize;
  const _TileView({required this.tile, required this.cellSize});

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(tile.value);
    Widget body = Container(
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(6),
        boxShadow: tile.value >= 8
            ? [
                BoxShadow(
                  color: style.bg.withValues(alpha: 0.30),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        '${tile.value}',
        style: TextStyle(
          color: style.fg,
          fontSize: _tileFont(tile.value),
          fontWeight: FontWeight.w900,
          height: 1,
          letterSpacing: -0.5,
        ),
      ),
    );

    if (tile.justSpawned) {
      body = body.animate().scale(
            begin: const Offset(0, 0),
            end: const Offset(1, 1),
            duration: 180.ms,
            curve: Curves.easeOutBack,
          );
    }
    if (tile.mergedOut) {
      body = Opacity(opacity: 0, child: body);
    }
    return body;
  }
}

// ════════════════════════════════════════════════════════════════
// Animated background — scattered ghost tiles
// ════════════════════════════════════════════════════════════════

class MergeBgPainter extends AnimatedBgPainter {
  const MergeBgPainter(super.t);

  @override
  void paintAt(Canvas canvas, Size size, double t) {
    final phase = t * 2 * math.pi;
    final items = <(String, Color, double, double, double)>[
      ('2', Color(0xFFEEE4DA), 0.08, 0.09, 0.0),
      ('4', Color(0xFFEDE0C8), 0.82, 0.07, 0.7),
      ('8', Color(0xFFF2B179), 0.18, 0.84, 1.4),
      ('16', Color(0xFFF59563), 0.75, 0.82, 2.1),
      ('64', Color(0xFFF65E3B), 0.88, 0.45, 2.8),
      ('2', Color(0xFFEEE4DA), 0.04, 0.55, 3.5),
      ('4', Color(0xFFEDE0C8), 0.60, 0.93, 4.2),
      ('8', Color(0xFFF2B179), 0.40, 0.05, 4.9),
    ];

    for (final (label, color, xRel, yRel, p) in items) {
      const tileSize = 52.0;
      final wave = math.sin(phase + p);
      final yBob = wave * 6.0;
      final rot = math.sin(phase * 0.7 + p) * 0.10;
      final alphaPulse = 0.22 + math.sin(phase * 1.3 + p) * 0.06;

      final cx = size.width * xRel;
      final cy = size.height * yRel + yBob;

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rot);

      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: tileSize,
        height: tileSize,
      );
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
      canvas.drawRRect(
        rrect,
        Paint()..color = color.withValues(alpha: alphaPulse.clamp(0.0, 1.0)),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: label.length > 1 ? 14 : 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF776E65).withValues(alpha: 0.30),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }
}

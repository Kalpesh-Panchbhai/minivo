import 'package:flutter/material.dart';
import 'mosaic_game_tile.dart';
import '../services/game_score_ranker.dart';

class MosaicGrid extends StatelessWidget {
  final List<RankedGame> games;
  final void Function(String gameId) onGameTap;

  const MosaicGrid({
    super.key,
    required this.games,
    required this.onGameTap,
  });

  static const int _columns = 6;
  static const double _spacing = 3;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalW = constraints.maxWidth;
        final cellW = (totalW - (_columns - 1) * _spacing) / _columns;
        final cellH = cellW;
        final placements = _computePlacements();
        final totalRows = placements.isEmpty
            ? 0
            : placements.map((p) => p.row + p.rowSpan).reduce((a, b) => a > b ? a : b);
        final totalHeight = totalRows * cellH + (totalRows > 0 ? (totalRows - 1) * _spacing : 0);

        return SizedBox(
          height: totalHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: placements.map((p) {
              final w = cellW * p.colSpan + (p.colSpan - 1) * _spacing;
              final h = cellH * p.rowSpan + (p.rowSpan - 1) * _spacing;
              final x = p.col * (cellW + _spacing);
              final y = p.row * (cellH + _spacing);
              return Positioned(
                left: x,
                top: y,
                width: w,
                height: h,
                child: MosaicGameTile(
                  game: p.game.game,
                  tileSize: p.game.tileSize,
                  onTap: () => onGameTap(p.game.game.id),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  List<_TilePlacement> _computePlacements() {
    final grid = <List<bool>>[];
    final result = <_TilePlacement>[];

    void ensureRows(int needed) {
      while (grid.length < needed) {
        grid.add(List.filled(_columns, false));
      }
    }

    for (final game in games) {
      final cs = game.tileSize.colSpan;
      final rs = game.tileSize.rowSpan;

      bool placed = false;
      for (int r = 0; !placed; r++) {
        ensureRows(r + rs);
        for (int c = 0; c <= _columns - cs; c++) {
          if (_canPlace(grid, r, c, rs, cs)) {
            _markUsed(grid, r, c, rs, cs);
            result.add(_TilePlacement(
              game: game,
              row: r,
              col: c,
              rowSpan: rs,
              colSpan: cs,
            ));
            placed = true;
            break;
          }
        }
        if (r > 100) break;
      }
    }
    return result;
  }

  bool _canPlace(List<List<bool>> grid, int r, int c, int rs, int cs) {
    if (r + rs > grid.length) return false;
    for (int dr = 0; dr < rs; dr++) {
      for (int dc = 0; dc < cs; dc++) {
        if (grid[r + dr][c + dc]) return false;
      }
    }
    return true;
  }

  void _markUsed(List<List<bool>> grid, int r, int c, int rs, int cs) {
    for (int dr = 0; dr < rs; dr++) {
      for (int dc = 0; dc < cs; dc++) {
        grid[r + dr][c + dc] = true;
      }
    }
  }
}

class _TilePlacement {
  final RankedGame game;
  final int row;
  final int col;
  final int rowSpan;
  final int colSpan;

  const _TilePlacement({
    required this.game,
    required this.row,
    required this.col,
    required this.rowSpan,
    required this.colSpan,
  });
}

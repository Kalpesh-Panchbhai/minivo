import 'package:flutter/material.dart';
import 'mosaic_game_tile.dart';
import '../services/game_score_ranker.dart';

class MosaicGrid extends StatelessWidget {
  final List<RankedGame> games;
  final void Function(String gameId) onGameTap;
  final int columns;
  final double spacing;
  final double cellHeight;

  const MosaicGrid({
    super.key,
    required this.games,
    required this.onGameTap,
    this.columns = 3,
    this.spacing = 8,
    this.cellHeight = 100,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalW = constraints.maxWidth;
        final cellW = (totalW - (columns - 1) * spacing) / columns;
        final placements = _computePlacements();
        final totalRows = placements.isEmpty
            ? 0
            : placements.map((p) => p.row + p.rowSpan).reduce((a, b) => a > b ? a : b);
        final totalHeight = totalRows * cellHeight + (totalRows > 0 ? (totalRows - 1) * spacing : 0);

        return SizedBox(
          height: totalHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: placements.map((p) {
              final w = cellW * p.colSpan + (p.colSpan - 1) * spacing;
              final h = cellHeight * p.rowSpan + (p.rowSpan - 1) * spacing;
              final x = p.col * (cellW + spacing);
              final y = p.row * (cellHeight + spacing);
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
        grid.add(List.filled(columns, false));
      }
    }

    for (final game in games) {
      final cs = _colSpan(game.tileSize);
      final rs = _rowSpan(game.tileSize);

      bool placed = false;
      for (int r = 0; !placed; r++) {
        ensureRows(r + rs);
        for (int c = 0; c <= columns - cs; c++) {
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

  int _colSpan(TileSize size) {
    switch (size) {
      case TileSize.large:
        return 2;
      case TileSize.wide:
        return 2;
      case TileSize.small:
        return 1;
    }
  }

  int _rowSpan(TileSize size) {
    switch (size) {
      case TileSize.large:
        return 2;
      case TileSize.wide:
        return 1;
      case TileSize.small:
        return 1;
    }
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

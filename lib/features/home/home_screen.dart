import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/game_info.dart';
import '../../core/services/score_service.dart';
import '../../core/widgets/category_chip.dart';
import '../../core/widgets/mosaic_game_tile.dart';
import '../../games/game_registry.dart';
import '../../routing/app_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  // Refresh when the user returns from a pushed route (e.g. game detail or
  // play screen) so any newly-toggled favourites or recent plays show up.
  @override
  void didPopNext() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final recentIds = ScoreService().getRecentlyPlayed();
    final favoriteIds = ScoreService().getFavorites();
    final trendingIds = GameRegistry.trending
        .take(6)
        .map((g) => g.id)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.videogame_asset_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppStrings.appName,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildIconButton(
                      Icons.search_rounded,
                      () => context.push('/search'),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),
            ),

            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: GameCategory.values.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (context, index) {
                        final cat = GameCategory.values[index];
                        return CategoryChip(
                          category: cat,
                          onTap: () => context.push('/category/${cat.name}'),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            if (recentIds.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _buildRecentlyPlayedRow(recentIds),
                ),
              ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  AppStrings.trending,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildMasonryGrid(
                  recentIds: recentIds,
                  favoriteIds: favoriteIds,
                  trendingIds: trendingIds,
                  onGameTap: (id) => context.push('/game/$id'),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentlyPlayedRow(List<String> recentIds) {
    final games = recentIds
        .take(5)
        .map((id) => GameRegistry.getById(id))
        .where((g) => g != null)
        .cast<GameInfo>()
        .toList();
    if (games.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.recentlyPlayed,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 60,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: games.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final game = games[index];
              return GestureDetector(
                onTap: () => context.push('/game/${game.id}'),
                child: Container(
                  width: 60,
                  decoration: BoxDecoration(
                    color: game.bgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: game.color.withValues(alpha: 0.2),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: game.hasBrandedLogo
                      ? game.buildBrandedLogo(size: 60)
                      : Center(
                          child: game.buildIcon(size: 28),
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMasonryGrid({
    required List<String> recentIds,
    required List<String> favoriteIds,
    required List<String> trendingIds,
    required void Function(String) onGameTap,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isWide = screenWidth > 600;
        final columns = isWide ? 6 : 3;
        final spacing = 3.0;
        final cellSize = (screenWidth - (columns - 1) * spacing) / columns;

        final tiles = <_GridTile>[];
        final allGameIds = GameRegistry.allGames.map((g) => g.id).toList();

        for (final gameId in allGameIds) {
          final game = GameRegistry.getById(gameId);
          if (game == null) continue;

          final isRecent = recentIds.contains(gameId);
          final isTrending = trendingIds.contains(gameId);
          final isFavorite = favoriteIds.contains(gameId);

          final isBig = isRecent && isTrending;
          final colSpan = isBig ? 2 : 1;
          final rowSpan = isBig ? 2 : 1;

          tiles.add(_GridTile(
            game: game,
            isFavorite: isFavorite,
            colSpan: colSpan,
            rowSpan: rowSpan,
            onTap: () => onGameTap(gameId),
          ));
        }

        return _MasonryGridLayout(
          tiles: tiles,
          columns: columns,
          cellSize: cellSize,
          spacing: spacing,
        );
      },
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 20),
      ),
    );
  }
}

class _GridTile {
  final GameInfo game;
  final bool isFavorite;
  final int colSpan;
  final int rowSpan;
  final VoidCallback onTap;

  _GridTile({
    required this.game,
    required this.isFavorite,
    required this.colSpan,
    required this.rowSpan,
    required this.onTap,
  });
}

class _MasonryGridLayout extends StatelessWidget {
  final List<_GridTile> tiles;
  final int columns;
  final double cellSize;
  final double spacing;

  const _MasonryGridLayout({
    required this.tiles,
    required this.columns,
    required this.cellSize,
    required this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    final placements = _computePlacements();
    final totalRows = placements.isEmpty
        ? 0
        : placements.map((p) => p.row + p.rowSpan).reduce((a, b) => a > b ? a : b);
    final totalHeight = totalRows * cellSize + (totalRows > 0 ? (totalRows - 1) * spacing : 0);

    return SizedBox(
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: placements.map((p) {
          final w = cellSize * p.colSpan + (p.colSpan - 1) * spacing;
          final h = cellSize * p.rowSpan + (p.rowSpan - 1) * spacing;
          final x = p.col * (cellSize + spacing);
          final y = p.row * (cellSize + spacing);

          return Positioned(
            left: x,
            top: y,
            width: w,
            height: h,
            child: _FavoritableGameTile(
              tile: p.tile,
              onTap: p.tile.onTap,
            ),
          );
        }).toList(),
      ),
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

    for (final tile in tiles) {
      bool placed = false;
      for (int r = 0; !placed && r < 100; r++) {
        ensureRows(r + tile.rowSpan);
        for (int c = 0; c <= columns - tile.colSpan; c++) {
          if (_canPlace(grid, r, c, tile.rowSpan, tile.colSpan)) {
            _markUsed(grid, r, c, tile.rowSpan, tile.colSpan);
            result.add(_TilePlacement(
              tile: tile,
              row: r,
              col: c,
            ));
            placed = true;
            break;
          }
        }
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
  final _GridTile tile;
  final int row;
  final int col;

  _TilePlacement({
    required this.tile,
    required this.row,
    required this.col,
  });

  int get rowSpan => tile.rowSpan;
  int get colSpan => tile.colSpan;
}

class _FavoritableGameTile extends StatelessWidget {
  final _GridTile tile;
  final VoidCallback onTap;

  const _FavoritableGameTile({
    required this.tile,
    required this.onTap,
  });

  TileSize get _tileSize {
    return tile.colSpan == 2 ? TileSize.medium : TileSize.small;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          MosaicGameTile(
            game: tile.game,
            tileSize: _tileSize,
            onTap: onTap,
          ),
          if (tile.isFavorite)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFFE85D75),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.background,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  size: 10,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

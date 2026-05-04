import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/game_info.dart';
import '../../core/services/score_service.dart';
import '../../core/widgets/category_chip.dart';
import '../../core/widgets/mosaic_game_tile.dart';
import '../../games/game_registry.dart';
import '../../routing/app_router.dart';

const _bgColor = Color(0xFFF4F4F8);
const _headingColor = Color(0xFF1A1A2E);
const _accentColor = Color(0xFF6C63FF);

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
    final trendingGames = GameRegistry.trending.toList();
    final trendingIds = trendingGames.take(6).map((g) => g.id).toList();

    return Scaffold(
      backgroundColor: _bgColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: GameCategory.values.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = GameCategory.values[index];
                    return CategoryChip(
                      category: cat,
                      onTap: () => context.push('/category/${cat.name}'),
                    )
                        .animate(delay: (index * 40).ms)
                        .fadeIn(duration: 250.ms)
                        .slideX(begin: 0.2);
                  },
                ),
              ),
            ),
          ),

          if (recentIds.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: _buildRecentlyPlayedRow(recentIds),
              ),
            ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: _SectionHeader(
                title: AppStrings.trending,
                accentColor: _accentColor,
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
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF4ECDC4)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x556C63FF),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.videogame_asset_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'MINIVO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      'Play • Explore • Win',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/search'),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.20),
                    ),
                  ),
                  child: const Icon(
                    Icons.search_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildRecentlyPlayedRow(List<String> recentIds) {
    final games = recentIds
        .take(8)
        .map((id) => GameRegistry.getById(id))
        .where((g) => g != null)
        .cast<GameInfo>()
        .toList();
    if (games.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: AppStrings.recentlyPlayed,
          accentColor: const Color(0xFF4ECDC4),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: games.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final game = games[index];
              return GestureDetector(
                onTap: () => context.push('/game/${game.id}'),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: game.bgColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: game.color.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: game.hasBrandedLogo
                      ? game.buildBrandedLogo(size: 72)
                      : Center(child: game.buildIcon(size: 32)),
                )
                    .animate(delay: (index * 60).ms)
                    .fadeIn(duration: 300.ms)
                    .slideX(begin: 0.3),
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
        final spacing = 12.0;
        final cellSize = (screenWidth - (columns - 1) * spacing) / columns;

        final allGameIds = GameRegistry.allGames.map((g) => g.id).toList();

        // Pick at most 2 "big" slots: prefer branded+trending games, spread them
        // out so they don't cluster on the same side (poki-style).
        final bigCandidateIds = allGameIds
            .where((id) {
              final g = GameRegistry.getById(id);
              return g != null && g.hasBrandedLogo && trendingIds.contains(id);
            })
            .take(2)
            .toSet();

        // Separate into big and small tiles, maintaining order.
        final bigTiles = <_GridTile>[];
        final smallTiles = <_GridTile>[];

        for (final gameId in allGameIds) {
          final game = GameRegistry.getById(gameId);
          if (game == null) continue;
          final isFavorite = favoriteIds.contains(gameId);
          final isBig = bigCandidateIds.contains(gameId);

          final tile = _GridTile(
            game: game,
            isFavorite: isFavorite,
            colSpan: isBig ? 2 : 1,
            rowSpan: isBig ? 2 : 1,
            onTap: () => onGameTap(gameId),
          );

          if (isBig) {
            bigTiles.add(tile);
          } else {
            smallTiles.add(tile);
          }
        }

        // Interleave big tiles at positions 0 and ~4 so they appear on
        // alternating sides of the grid (left then right), like poki.com.
        // Pattern for 3-col: big@0 fills cols 0-1; 1 small fills col 2 rows 0-1;
        // then 3 smalls fill row 2; then big@4 lands naturally at col 1.
        final tiles = <_GridTile>[];
        final smallIter = smallTiles.iterator;

        void addSmalls(int count) {
          for (int i = 0; i < count; i++) {
            if (smallIter.moveNext()) tiles.add(smallIter.current);
          }
        }

        if (bigTiles.isNotEmpty) {
          tiles.add(bigTiles[0]);
          // For 3-col grid: big1 occupies cols 0-1, rows 0-1.
          // Fill col 2 rows 0-1 with 2 smalls, then row 2 col 0 with 1 small.
          // That leaves cols 1-2 of row 2 free for big2 (right-side placement).
          addSmalls(columns - 1); // fills the free strip beside big1

          if (bigTiles.length > 1) {
            // 1 small at col 0 of the new row pushes big2 to cols 1-2 (right side)
            addSmalls(1);
            tiles.add(bigTiles[1]);
            // fill strip after big2
            addSmalls(columns - 2);
          }
        }

        // Append remaining small tiles
        while (smallIter.moveNext()) {
          tiles.add(smallIter.current);
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
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color accentColor;

  const _SectionHeader({required this.title, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _headingColor,
          ),
        ),
      ],
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
        children: [
          for (int i = 0; i < placements.length; i++)
            () {
              final p = placements[i];
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
                )
                    .animate(delay: (i * 35).ms)
                    .fadeIn(duration: 320.ms)
                    .slideY(begin: 0.15),
              );
            }(),
        ],
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

class _FavoritableGameTile extends StatefulWidget {
  final _GridTile tile;
  final VoidCallback onTap;

  const _FavoritableGameTile({
    required this.tile,
    required this.onTap,
  });

  @override
  State<_FavoritableGameTile> createState() => _FavoritableGameTileState();
}

class _FavoritableGameTileState extends State<_FavoritableGameTile> {
  bool _pressed = false;

  TileSize get _tileSize {
    return widget.tile.colSpan == 2 ? TileSize.medium : TileSize.small;
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.tile.game;
    final radius = widget.tile.colSpan == 2 ? 20.0 : 16.0;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                boxShadow: [
                  BoxShadow(
                    color: game.color.withValues(alpha: 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: MosaicGameTile(
                  game: game,
                  tileSize: _tileSize,
                  onTap: widget.onTap,
                ),
              ),
            ),
            if (widget.tile.isFavorite)
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
                      color: _bgColor,
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
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
      ),
    );
  }
}

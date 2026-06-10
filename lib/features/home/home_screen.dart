import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../bootstrap.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/force_update_service.dart';
import '../force_update/force_update_screen.dart';
import '../../core/models/game_info.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/score_service.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/category_chip.dart';
import '../../core/widgets/mosaic_game_tile.dart';
import '../../games/game_registry.dart';
import '../../games/shared/animated_background.dart';
import '../../routing/app_router.dart';

const _headingColor = Color(0xFF1A1A2E);
const _accentColor = Color(0xFF6C63FF);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  bool _updateChecked = false;
  Timer? _forceUpdateTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
    if (!_updateChecked) {
      _updateChecked = true;
      _checkForceUpdate();
    }
  }

  Future<void> _checkForceUpdate() async {
    final completer = Completer<void>();
    _forceUpdateTimer = Timer(const Duration(seconds: 5), () {
      if (!completer.isCompleted) completer.complete();
    });
    firebaseReady.future.then((_) {
      if (!completer.isCompleted) completer.complete();
    });
    try {
      await completer.future;
      _forceUpdateTimer?.cancel();
      _forceUpdateTimer = null;
      if (!mounted) return;
      await ForceUpdateService().init();
    } catch (_) {
      _forceUpdateTimer?.cancel();
      _forceUpdateTimer = null;
    }
    if (!mounted) return;
    if (ForceUpdateService().needsForceUpdate) {
      showForceUpdateDialog(context);
    }
  }

  @override
  void dispose() {
    _forceUpdateTimer?.cancel();
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
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBackground(
              factory: (t) => _HomeBgPainter(t),
              period: const Duration(seconds: 18),
            ),
          ),
          CustomScrollView(
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
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final cat = GameCategory.values[index];
                        return CategoryChip(
                          category: cat,
                          onTap: () {
                            AnalyticsService().homeSectionTapped(
                              section: 'category',
                            );
                            context.push('/category/${cat.name}');
                          },
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

              if (favoriteIds.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: _buildFavoritesRow(favoriteIds),
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
                    onGameTap: (id) {
                      AnalyticsService().homeSectionTapped(
                        section: 'trending',
                        gameId: id,
                      );
                      context.push('/game/$id');
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF0D1B3E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Row(
            children: [
              // Game controller icon
              SizedBox(
                width: 48,
                height: 48,
                child: CustomPaint(
                  painter: _AppLogoPainter(),
                ),
              ),
              const SizedBox(width: 12),
              // Brand text — Flexible so it can shrink on narrow phones
              // (320px) and respect large-font users without overflowing.
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'MINIVO',
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: context.fontSize(24, max: 26),
                        fontWeight: FontWeight.w900,
                        letterSpacing: context.isCompactWidth ? 1.8 : 2.5,
                      ),
                    ),
                    Text(
                      'Play • Explore • Win',
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.50),
                        fontSize: context.fontSize(11, max: 13),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Leaderboard button
              GestureDetector(
                onTap: () {
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => const SizedBox(
                      height: 160,
                      child: Center(
                        child: Text(
                          'Coming soon',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Color(0xFFFFCC00),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Settings button
              GestureDetector(
                onTap: () => context.push('/settings'),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.settings_rounded,
                    color: Colors.white.withValues(alpha: 0.80),
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
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final game = games[index];
              return GestureDetector(
                onTap: () {
                  AnalyticsService().homeSectionTapped(
                    section: 'recent',
                    gameId: game.id,
                  );
                  context.push('/game/${game.id}');
                },
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

  Widget _buildFavoritesRow(List<String> favoriteIds) {
    final games = favoriteIds
        .map((id) => GameRegistry.getById(id))
        .where((g) => g != null)
        .cast<GameInfo>()
        .toList();
    if (games.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SectionHeader(
              title: AppStrings.favorites,
              accentColor: const Color(0xFFE85D75),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE85D75).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${games.length}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE85D75),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: games.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final game = games[index];
              return _FavoriteCard(
                game: game,
                onTap: () {
                  AnalyticsService().homeSectionTapped(
                    section: 'favorites',
                    gameId: game.id,
                  );
                  context.push('/game/${game.id}');
                },
              )
                  .animate(delay: (index * 60).ms)
                  .fadeIn(duration: 300.ms)
                  .slideX(begin: 0.25);
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

class _FavoriteCard extends StatelessWidget {
  final GameInfo game;
  final VoidCallback onTap;
  const _FavoriteCard({required this.game, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: game.color.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: game.bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: game.hasBrandedLogo
                  ? game.buildBrandedLogo(size: 56)
                  : Center(child: game.buildIcon(size: 28)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    game.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF1A1A2E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    game.category.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: game.color.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                size: 18,
                color: game.color,
              ),
            ),
          ],
        ),
      ),
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
                top: -5,
                right: -5,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFF6B8A), Color(0xFFE85D75)],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE85D75).withValues(alpha: 0.40),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    size: 11,
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

// ── Animated home screen background ────────────────────────────────────────

class _HomeBgPainter extends AnimatedBgPainter {
  const _HomeBgPainter(super.t);

  @override
  void paintAt(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;
    final phase = t * 2 * math.pi;

    // Base gradient — deep navy to soft indigo/lavender
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFF0EEFF), // soft lavender
          Color(0xFFEBF5FF), // cool blue-white
          Color(0xFFF5F0FF), // pale violet
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // Floating game-themed elements
    // Each entry: (xRel, yRel, radius, phase_offset, color, shape)
    // shape: 0=circle, 1=X-mark, 2=O-ring, 3=snake-segment, 4=star, 5=card
    final elements = [
      // Large ambient blobs (circles, very low alpha)
      (0.15, 0.08, 70.0, 0.0, const Color(0xFF6C4EF3), 0),
      (0.85, 0.15, 55.0, 1.2, const Color(0xFF4ECDC4), 0),
      (0.10, 0.55, 60.0, 2.4, const Color(0xFFFF6B35), 0),
      (0.88, 0.60, 50.0, 3.6, const Color(0xFF339AF0), 0),
      (0.50, 0.90, 65.0, 4.8, const Color(0xFF20C997), 0),
      (0.30, 0.35, 45.0, 0.6, const Color(0xFFBE4BDB), 0),
      (0.75, 0.80, 48.0, 1.8, const Color(0xFFFF6B6B), 0),
      // X marks (tic-tac-toe)
      (0.80, 0.05, 18.0, 0.3, const Color(0xFFE85D75), 1),
      (0.05, 0.80, 14.0, 2.1, const Color(0xFFE85D75), 1),
      (0.55, 0.18, 12.0, 3.9, const Color(0xFFE85D75), 1),
      // O rings (tic-tac-toe)
      (0.90, 0.35, 16.0, 1.5, const Color(0xFF5BC0DE), 2),
      (0.20, 0.92, 13.0, 3.3, const Color(0xFF5BC0DE), 2),
      // Snake segments
      (0.65, 0.42, 10.0, 0.9, const Color(0xFF20C997), 3),
      (0.35, 0.68, 9.0, 2.7, const Color(0xFF20C997), 3),
      (0.72, 0.72, 11.0, 4.5, const Color(0xFF20C997), 3),
      // Stars
      (0.45, 0.04, 11.0, 1.1, const Color(0xFFFFD43B), 4),
      (0.92, 0.88, 10.0, 2.9, const Color(0xFFFFD43B), 4),
      (0.12, 0.20, 9.0, 4.7, const Color(0xFFFFD43B), 4),
      // Cards (memory match)
      (0.25, 0.12, 14.0, 0.4, const Color(0xFF339AF0), 5),
      (0.78, 0.48, 12.0, 2.2, const Color(0xFF339AF0), 5),
      (0.48, 0.78, 13.0, 4.0, const Color(0xFF339AF0), 5),
    ];

    for (final (xRel, yRel, r, phOff, color, shape) in elements) {
      final bob = math.sin(phase + phOff) * (r * 0.15);
      final cx = w * xRel;
      final cy = h * yRel + bob;
      final pulse = 0.9 + math.sin(phase * 0.7 + phOff) * 0.1;
      final effectiveR = r * pulse;

      canvas.save();
      canvas.translate(cx, cy);

      switch (shape) {
        case 0: // ambient circle blob
          final alpha = 0.07 + (math.sin(phase * 0.5 + phOff) + 1) / 2 * 0.06;
          canvas.drawCircle(
            Offset.zero,
            effectiveR,
            Paint()
              ..color = color.withValues(alpha: alpha)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
          );

        case 1: // X mark
          final alpha = 0.15 + (math.sin(phase * 0.8 + phOff) + 1) / 2 * 0.10;
          final rot = math.sin(phase * 0.4 + phOff) * 0.15;
          canvas.rotate(rot);
          final paint = Paint()
            ..color = color.withValues(alpha: alpha)
            ..strokeWidth = effectiveR * 0.35
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke;
          final pad = effectiveR * 0.5;
          canvas.drawLine(Offset(-pad, -pad), Offset(pad, pad), paint);
          canvas.drawLine(Offset(pad, -pad), Offset(-pad, pad), paint);

        case 2: // O ring
          final alpha = 0.14 + (math.sin(phase * 0.9 + phOff) + 1) / 2 * 0.09;
          canvas.drawCircle(
            Offset.zero,
            effectiveR * 0.55,
            Paint()
              ..color = color.withValues(alpha: alpha)
              ..strokeWidth = effectiveR * 0.28
              ..style = PaintingStyle.stroke,
          );

        case 3: // snake segment (rounded rect)
          final alpha = 0.16 + (math.sin(phase * 0.6 + phOff) + 1) / 2 * 0.10;
          final rot = math.sin(phase * 0.5 + phOff) * 0.2;
          canvas.rotate(rot);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset.zero,
                  width: effectiveR * 1.8,
                  height: effectiveR * 1.8),
              Radius.circular(effectiveR * 0.4),
            ),
            Paint()..color = color.withValues(alpha: alpha),
          );

        case 4: // star (5-pointed using path)
          final alpha = 0.18 + (math.sin(phase * 1.1 + phOff) + 1) / 2 * 0.12;
          final rot = phase * 0.3 + phOff;
          canvas.rotate(rot);
          final path = _starPath(effectiveR);
          canvas.drawPath(path, Paint()..color = color.withValues(alpha: alpha));

        case 5: // memory card (rounded rect portrait)
          final alpha = 0.13 + (math.sin(phase * 0.7 + phOff) + 1) / 2 * 0.09;
          final rot = math.sin(phase * 0.35 + phOff) * 0.18;
          canvas.rotate(rot);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset.zero,
                  width: effectiveR * 1.4,
                  height: effectiveR * 1.9),
              Radius.circular(effectiveR * 0.25),
            ),
            Paint()..color = color.withValues(alpha: alpha),
          );
      }

      canvas.restore();
    }
  }

  Path _starPath(double r) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final outerAngle = (i * 2 * math.pi / 5) - math.pi / 2;
      final innerAngle = outerAngle + math.pi / 5;
      final outer = Offset(math.cos(outerAngle) * r, math.sin(outerAngle) * r);
      final inner = Offset(
          math.cos(innerAngle) * r * 0.42, math.sin(innerAngle) * r * 0.42);
      if (i == 0) {
        path.moveTo(outer.dx, outer.dy);
      } else {
        path.lineTo(outer.dx, outer.dy);
      }
      path.lineTo(inner.dx, inner.dy);
    }
    path.close();
    return path;
  }

}

class _AppLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cx = s / 2;
    final cy = s / 2;

    final bgRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, s, s),
      Radius.circular(s * 0.27),
    );
    canvas.drawRRect(
      bgRRect.shift(const Offset(0, 2)),
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );
    canvas.drawRRect(
      bgRRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF7B73FF), Color(0xFF5248E0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(0, 0, s, s)),
    );

    final bodyW = s * 0.54;
    final bodyH = s * 0.24;
    final bodyRect =
        Rect.fromCenter(center: Offset(cx, cy), width: bodyW, height: bodyH);

    final gripW = bodyW * 0.20;
    final gripH = bodyH * 1.05;
    for (final side in [-1.0, 1.0]) {
      final gripCx = cx + side * bodyW * 0.40;
      final gripCy = cy + bodyH * 0.20;
      final gripRect = Rect.fromCenter(
        center: Offset(gripCx, gripCy),
        width: gripW,
        height: gripH,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(gripRect, Radius.circular(gripW * 0.45)),
        Paint()..color = Colors.white,
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(bodyH * 0.38)),
      Paint()..color = Colors.white,
    );

    final dpadX = cx - bodyW * 0.18;
    final dpadY = cy;
    final dpadArm = bodyH * 0.14;
    final dpadPaint = Paint()..color = const Color(0xFFCBCBDB);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(dpadX, dpadY),
            width: dpadArm,
            height: dpadArm * 2.6),
        Radius.circular(dpadArm * 0.25),
      ),
      dpadPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(dpadX, dpadY),
            width: dpadArm * 2.6,
            height: dpadArm),
        Radius.circular(dpadArm * 0.25),
      ),
      dpadPaint,
    );

    final btnX = cx + bodyW * 0.18;
    final btnY = cy;
    final btnR = bodyH * 0.09;
    final gap = btnR * 2.4;
    const colors = [
      Color(0xFFFF6B6B),
      Color(0xFF51CF66),
      Color(0xFFFFD43B),
      Color(0xFF339AF0),
    ];
    final offsets = [
      Offset(0, -gap),
      Offset(gap, 0),
      Offset(0, gap),
      Offset(-gap, 0),
    ];
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset(btnX, btnY) + offsets[i],
        btnR,
        Paint()..color = colors[i],
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AppLogoPainter old) => false;
}

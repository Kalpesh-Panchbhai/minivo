import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/game_info.dart';
import '../../core/services/game_score_ranker.dart';
import '../../core/services/score_service.dart';
import '../../core/widgets/category_chip.dart';
import '../../core/widgets/mosaic_grid.dart';
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
    final rankedGames = GameScoreRanker.rankAllGames();
    final recentIds = ScoreService().getRecentlyPlayed();
    final favoriteIds = ScoreService().getFavorites();

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

            if (favoriteIds.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _buildFavoritesRow(favoriteIds),
                ),
              ),

            if (recentIds.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _buildQuickPlayRow(recentIds),
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
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: MosaicGrid(
                  games: rankedGames,
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

  // Favourites rail — heart-marked games surface first so users can jump
  // straight back into their go-to picks. Mirrors the Recently Played row
  // visually but with a heart-tinted ring around each tile.
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
            const Icon(
              Icons.favorite_rounded,
              size: 18,
              color: Color(0xFFE85D75),
            ),
            const SizedBox(width: 6),
            Text(
              AppStrings.favorites,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: games.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final game = games[index];
              return GestureDetector(
                onTap: () => context.push('/game/${game.id}'),
                child: SizedBox(
                  width: 60,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: game.bgColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFE85D75)
                                .withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: game.hasBrandedLogo
                            ? game.buildBrandedLogo(size: 60)
                            : Center(child: game.buildIcon(size: 28)),
                      ),
                      // Tiny heart badge in the top-right corner.
                      Positioned(
                        top: -3,
                        right: -3,
                        child: Container(
                          width: 18,
                          height: 18,
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
                            size: 8,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickPlayRow(List<String> recentIds) {
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

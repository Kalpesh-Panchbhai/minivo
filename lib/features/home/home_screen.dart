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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final rankedGames = GameScoreRanker.rankAllGames();
    final recentIds = ScoreService().getRecentlyPlayed();

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
                    height: 36,
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
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: MosaicGrid(
                  games: rankedGames,
                  columns: 3,
                  spacing: 6,
                  cellHeight: 110,
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
                  child: Center(
                    child: Icon(game.icon, color: game.color, size: 28),
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

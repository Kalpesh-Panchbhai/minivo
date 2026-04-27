import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/score_service.dart';
import '../../core/widgets/game_card.dart';
import '../../games/game_registry.dart';

class GameDetailScreen extends StatefulWidget {
  final String gameId;

  const GameDetailScreen({super.key, required this.gameId});

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> {
  late bool _isFav;

  @override
  void initState() {
    super.initState();
    _isFav = ScoreService().isFavorite(widget.gameId);
  }

  void _toggleFav() {
    ScoreService().toggleFavorite(widget.gameId);
    setState(() => _isFav = !_isFav);
  }

  @override
  Widget build(BuildContext context) {
    final game = GameRegistry.getById(widget.gameId);
    if (game == null) {
      return const Scaffold(body: Center(child: Text('Game not found')));
    }
    final highScore = ScoreService().getHighScore(widget.gameId);
    final similar = GameRegistry.getByCategory(game.category)
        .where((g) => g.id != game.id)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              children: [
                Container(
                  height: 260,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        game.color,
                        game.color.withValues(alpha: 0.6),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      game.icon,
                      size: 100,
                      color: Colors.white.withValues(alpha: 0.3),
                    )
                        .animate()
                        .scale(
                          begin: const Offset(0.6, 0.6),
                          end: const Offset(1, 1),
                          duration: 600.ms,
                          curve: Curves.easeOutBack,
                        )
                        .fadeIn(duration: 400.ms),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _circleButton(
                          Icons.arrow_back_rounded,
                          () => context.pop(),
                        ),
                        _circleButton(
                          _isFav
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          _toggleFav,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -30),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name and stats
                      Text(
                        game.name,
                        style: Theme.of(context)
                            .textTheme
                            .displayMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          _statChip(
                            Icons.star_rounded,
                            game.rating.toStringAsFixed(1),
                            AppColors.starFilled,
                          ),
                          _statChip(
                            Icons.play_arrow_rounded,
                            '${game.playCountFormatted} plays',
                            AppColors.textHint,
                          ),
                          _statChip(
                            Icons.category_rounded,
                            game.category.label,
                            game.color,
                          ),
                        ],
                      ),
                      if (highScore > 0) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.emoji_events_rounded,
                                size: 18,
                                color: AppColors.starFilled,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Your best: $highScore',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Play button
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (GameRegistry.hasGame(game.id)) {
                              context.push('/play/${game.id}');
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      const Text('Coming soon!'),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.play_arrow_rounded, size: 26),
                          label: const Text(AppStrings.playNow),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: game.color,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 200.ms, duration: 400.ms)
                          .slideY(begin: 0.15, delay: 200.ms, duration: 400.ms),

                      // Description
                      const SizedBox(height: 28),
                      Text(
                        'About',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        game.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.6,
                            ),
                      ),

                      // How to play
                      const SizedBox(height: 24),
                      Text(
                        AppStrings.howToPlay,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        game.howToPlay,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.6,
                            ),
                      ),

                      // Similar games
                      if (similar.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        Text(
                          AppStrings.similarGames,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 100,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: similar.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final g = similar[index];
                              return GameCard(
                                game: g,
                                compact: true,
                                onTap: () => context.push('/game/${g.id}'),
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _statChip(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

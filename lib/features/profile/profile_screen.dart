import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/score_service.dart';
import '../../core/widgets/game_card.dart';
import '../../games/game_registry.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = ScoreService();
    final name = svc.getDisplayName();
    final played = svc.getTotalGamesPlayed();
    final coins = svc.getTotalCoins();
    final favIds = svc.getFavorites();
    final favGames = favIds
        .map((id) => GameRegistry.getById(id))
        .where((g) => g != null)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    Text(
                      AppStrings.profile,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => context.push('/settings'),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.settings_rounded,
                          color: AppColors.textPrimary,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Avatar
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primaryLight,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 44,
                    color: Colors.white,
                  ),
                ).animate().scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1, 1),
                      duration: 500.ms,
                      curve: Curves.easeOutBack,
                    ),
                const SizedBox(height: 14),
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Game Enthusiast',
                  style: Theme.of(context).textTheme.bodySmall,
                ),

                // Stats cards
                const SizedBox(height: 28),
                Row(
                  children: [
                    _statCard(context, '$played', AppStrings.gamesPlayed,
                        Icons.videogame_asset_rounded, AppColors.primary),
                    const SizedBox(width: 10),
                    _statCard(context, '$coins', 'Coins',
                        Icons.monetization_on_rounded, AppColors.starFilled),
                    const SizedBox(width: 10),
                    _statCard(context, '${favIds.length}', AppStrings.favorites,
                        Icons.favorite_rounded, AppColors.accent),
                  ],
                )
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 400.ms)
                    .slideY(begin: 0.1, delay: 200.ms, duration: 400.ms),

                // Achievements
                const SizedBox(height: 28),
                _sectionRow(context, AppStrings.achievements, () {
                  context.push('/achievements');
                }),
                const SizedBox(height: 12),
                SizedBox(
                  height: 80,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _badge(context, Icons.sports_esports_rounded,
                          'First Steps', played >= 1),
                      _badge(context, Icons.local_fire_department_rounded,
                          '10 Games', played >= 10),
                      _badge(context, Icons.emoji_events_rounded, 'Top Scorer',
                          false),
                      _badge(
                          context, Icons.star_rounded, 'Star Pro', false),
                    ],
                  ),
                ),

                // Favorites
                if (favGames.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _sectionRow(context, AppStrings.favorites, null),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: favGames.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final game = favGames[index]!;
                        return GameCard(
                          game: game,
                          compact: true,
                          onTap: () => context.push('/game/${game.id}'),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCard(BuildContext context, String value, String label,
      IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _sectionRow(
      BuildContext context, String title, VoidCallback? onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (onTap != null)
          GestureDetector(
            onTap: onTap,
            child: Text(
              'See all',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
      ],
    );
  }

  Widget _badge(
      BuildContext context, IconData icon, String label, bool unlocked) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: unlocked
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 24,
              color: unlocked ? AppColors.primary : AppColors.textHint,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: unlocked ? AppColors.textPrimary : AppColors.textHint,
                ),
          ),
        ],
      ),
    );
  }
}

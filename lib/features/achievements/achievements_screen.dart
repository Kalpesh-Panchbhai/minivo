import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/score_service.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final played = ScoreService().getTotalGamesPlayed();
    final coins = ScoreService().getTotalCoins();
    final favs = ScoreService().getFavorites().length;

    final achievements = [
      _Achievement('First Steps', 'Play your first game',
          Icons.sports_esports_rounded, played >= 1),
      _Achievement('Getting Hooked', 'Play 10 games',
          Icons.local_fire_department_rounded, played >= 10),
      _Achievement('Addict', 'Play 50 games',
          Icons.whatshot_rounded, played >= 50),
      _Achievement('Century', 'Play 100 games',
          Icons.military_tech_rounded, played >= 100),
      _Achievement('Coin Starter', 'Earn 100 coins',
          Icons.monetization_on_rounded, coins >= 100),
      _Achievement('Coin Hoarder', 'Earn 1000 coins',
          Icons.savings_rounded, coins >= 1000),
      _Achievement('Fan', 'Add 3 favorites',
          Icons.favorite_rounded, favs >= 3),
      _Achievement('Collector', 'Add 10 favorites',
          Icons.collections_rounded, favs >= 10),
      _Achievement('Sharpshooter', 'Score 100+ in any game',
          Icons.gps_fixed_rounded, false),
      _Achievement('Top 10', 'Reach top 10 on a leaderboard',
          Icons.emoji_events_rounded, false),
      _Achievement('All-Rounder', 'Play every game at least once',
          Icons.public_rounded, false),
      _Achievement('Social Butterfly', 'Share a score 5 times',
          Icons.share_rounded, false),
    ];

    final unlocked = achievements.where((a) => a.unlocked).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Achievements',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$unlocked / ${achievements.length}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const BouncingScrollPhysics(),
                itemCount: achievements.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final a = achievements[index];
                  return _buildTile(context, a, index);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(BuildContext context, _Achievement a, int index) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: a.unlocked
            ? AppColors.primary.withValues(alpha: 0.06)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: a.unlocked
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.15))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: a.unlocked
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              a.icon,
              size: 24,
              color: a.unlocked ? AppColors.primary : AppColors.textHint,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: a.unlocked
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  a.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (a.unlocked)
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.primary,
              size: 24,
            )
          else
            Icon(
              Icons.lock_outline_rounded,
              color: AppColors.textHint,
              size: 22,
            ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: (index * 40).ms)
        .slideX(begin: 0.05, duration: 300.ms, delay: (index * 40).ms);
  }
}

class _Achievement {
  final String title;
  final String description;
  final IconData icon;
  final bool unlocked;
  const _Achievement(this.title, this.description, this.icon, this.unlocked);
}

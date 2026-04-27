import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/game_info.dart';
import '../../core/widgets/game_card.dart';
import '../../games/game_registry.dart';

class CategoryScreen extends StatelessWidget {
  final String categoryName;

  const CategoryScreen({super.key, required this.categoryName});

  @override
  Widget build(BuildContext context) {
    final category = GameCategory.values.firstWhere(
      (c) => c.name == categoryName,
      orElse: () => GameCategory.action,
    );
    final games = GameRegistry.getByCategory(category);

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
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: category.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      category.icon,
                      color: category.color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      category.label,
                      style: Theme.of(context).textTheme.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${games.length} games',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: games.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            category.icon,
                            size: 64,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No games yet',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Coming soon!',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(20),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: games.length,
                      itemBuilder: (context, index) {
                        final game = games[index];
                        return GameCardAnimated(
                          game: game,
                          index: index,
                          onTap: () => context.push('/game/${game.id}'),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

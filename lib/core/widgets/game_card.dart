import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_colors.dart';
import '../models/game_info.dart';

class GameCard extends StatelessWidget {
  final GameInfo game;
  final VoidCallback onTap;
  final double? width;
  final bool compact;

  const GameCard({
    super.key,
    required this.game,
    required this.onTap,
    this.width,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact(context);
    return _buildFull(context);
  }

  Widget _buildFull(BuildContext context) {
    final hasBranded = game.hasBrandedLogo;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: game.color.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: hasBranded
            ? LayoutBuilder(
                builder: (context, c) => game.buildBrandedLogo(
                      size: c.maxWidth > c.maxHeight ? c.maxWidth : c.maxHeight,
                    ) ??
                    const SizedBox.shrink(),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: game.bgColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Center(
                        child: game.buildIcon(size: 48),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          game.name,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.play_arrow_rounded,
                              size: 14,
                              color: AppColors.textHint,
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                game.playCountFormatted,
                                style: Theme.of(context).textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width ?? 80,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: game.bgColor,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: game.color.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: game.hasBrandedLogo
                  ? game.buildBrandedLogo(size: 64)
                  : Center(
                      child: game.buildIcon(size: 30),
                    ),
            ),
            const SizedBox(height: 8),
            if (!game.hasBrandedLogo)
              Text(
                game.name,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}

class GameCardAnimated extends StatelessWidget {
  final GameInfo game;
  final VoidCallback onTap;
  final int index;
  final double? width;
  final bool compact;

  const GameCardAnimated({
    super.key,
    required this.game,
    required this.onTap,
    this.index = 0,
    this.width,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GameCard(
      game: game,
      onTap: onTap,
      width: width,
      compact: compact,
    )
        .animate()
        .fadeIn(
          duration: 400.ms,
          delay: (index * 60).ms,
        )
        .slideY(
          begin: 0.1,
          end: 0,
          duration: 400.ms,
          delay: (index * 60).ms,
          curve: Curves.easeOutCubic,
        );
  }
}

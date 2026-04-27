import 'package:flutter/material.dart';
import '../models/game_info.dart';

enum TileSize { small, wide, large }

class MosaicGameTile extends StatelessWidget {
  final GameInfo game;
  final TileSize tileSize;
  final VoidCallback? onTap;

  const MosaicGameTile({
    super.key,
    required this.game,
    this.tileSize = TileSize.small,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: game.bgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: game.color.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Icon(
                game.icon,
                size: _iconSize,
                color: game.color.withValues(alpha: 0.2),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.all(tileSize == TileSize.small ? 8 : 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      game.color.withValues(alpha: 0.85),
                    ],
                    stops: const [0.0, 0.7],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: tileSize == TileSize.small ? 16 : 24),
                    Text(
                      game.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: _titleFontSize,
                        height: 1.2,
                      ),
                      maxLines: tileSize == TileSize.small ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (tileSize != TileSize.small) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 12,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            game.rating.toStringAsFixed(1),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            game.category.icon,
                            size: 12,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              game.category.label,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: game.color.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: tileSize == TileSize.small ? 14 : 18,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double get _iconSize {
    switch (tileSize) {
      case TileSize.large:
        return 80;
      case TileSize.wide:
        return 56;
      case TileSize.small:
        return 40;
    }
  }

  double get _titleFontSize {
    switch (tileSize) {
      case TileSize.large:
        return 16;
      case TileSize.wide:
        return 14;
      case TileSize.small:
        return 12;
    }
  }
}

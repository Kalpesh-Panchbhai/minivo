import 'package:flutter/material.dart';
import '../models/game_info.dart';

enum TileSize {
  small(1, 1),
  wide(2, 1),
  tall(1, 2),
  medium(2, 2),
  large(3, 3);

  const TileSize(this.colSpan, this.rowSpan);
  final int colSpan;
  final int rowSpan;
}

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

  bool get _isSmall => tileSize == TileSize.small;
  bool get _isBig => tileSize == TileSize.large || tileSize == TileSize.medium;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              game.bgColor,
              game.color.withValues(alpha: 0.25),
            ],
          ),
          borderRadius: BorderRadius.circular(_isSmall ? 10 : 14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              right: _isBig ? -10 : -12,
              bottom: _isBig ? -10 : -12,
              child: Icon(
                game.icon,
                size: _bgIconSize,
                color: game.color.withValues(alpha: 0.07),
              ),
            ),
            Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: _isSmall ? 14 : 24),
                child: Container(
                  padding: EdgeInsets.all(_isSmall ? 8 : 16),
                  decoration: BoxDecoration(
                    color: game.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    game.icon,
                    size: _centerIconSize,
                    color: game.color,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  _isSmall ? 5 : 10,
                  _isSmall ? 6 : 8,
                  _isSmall ? 5 : 10,
                  _isSmall ? 5 : 8,
                ),
                decoration: BoxDecoration(
                  color: game.color.withValues(alpha: 0.9),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      game.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: _titleFontSize,
                        height: 1.1,
                      ),
                      maxLines: _isSmall ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_isBig) ...[
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          game.category.label,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double get _bgIconSize {
    switch (tileSize) {
      case TileSize.large:
        return 140;
      case TileSize.medium:
        return 100;
      case TileSize.tall:
        return 72;
      case TileSize.wide:
        return 72;
      case TileSize.small:
        return 56;
    }
  }

  double get _centerIconSize {
    switch (tileSize) {
      case TileSize.large:
        return 64;
      case TileSize.medium:
        return 44;
      case TileSize.tall:
        return 36;
      case TileSize.wide:
        return 32;
      case TileSize.small:
        return 24;
    }
  }

  double get _titleFontSize {
    switch (tileSize) {
      case TileSize.large:
        return 18;
      case TileSize.medium:
        return 14;
      case TileSize.tall:
        return 12;
      case TileSize.wide:
        return 12;
      case TileSize.small:
        return 9;
    }
  }
}

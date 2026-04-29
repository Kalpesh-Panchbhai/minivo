import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum GameCategory {
  action('Action', Icons.flash_on_rounded, AppColors.categoryAction),
  puzzle('Puzzle', Icons.extension_rounded, AppColors.categoryPuzzle),
  board('Board', Icons.grid_on_rounded, AppColors.categoryBoard),
  card('Cards', Icons.style_rounded, AppColors.categoryCard),
  sports('Sports', Icons.sports_soccer_rounded, AppColors.categorySports),
  arcade('Arcade', Icons.videogame_asset_rounded, AppColors.categoryArcade);

  const GameCategory(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

/// Function signature for a widget-based brand logo. Receives the side length
/// (square) and must return a widget that fills [size]×[size]. Use a
/// top-level / static function so it can be passed to a `const GameInfo(...)`.
typedef GameLogoBuilder = Widget Function(double size);

class GameInfo {
  final String id;
  final String name;
  final String description;
  final String howToPlay;
  final GameCategory category;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final int playCount;
  final bool isFeatured;

  /// PNG/JPG asset path used as the full-tile brand logo. Mutually exclusive
  /// with [customLogo] in practice (asset is checked second).
  final String? iconAsset;

  /// Widget-based brand logo. Preferred for games whose logo is best
  /// rendered procedurally (e.g. 2048's mini-board). Wins over [iconAsset].
  final GameLogoBuilder? customLogo;

  const GameInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.howToPlay,
    required this.category,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.playCount = 0,
    this.isFeatured = false,
    this.iconAsset,
    this.customLogo,
  });

  /// True when the game has a "branded" filled-tile logo (asset or widget).
  /// Use this instead of `iconAsset != null` so widget-based logos are picked
  /// up automatically by every tile/card surface.
  bool get hasBrandedLogo => customLogo != null || iconAsset != null;

  /// Returns a [size]×[size] widget that fills the tile, using either the
  /// custom widget logo or the image asset. Returns `null` when neither is
  /// configured — caller should fall back to its own centered-icon layout.
  Widget? buildBrandedLogo({required double size}) {
    if (customLogo != null) {
      return SizedBox(width: size, height: size, child: customLogo!(size));
    }
    if (iconAsset != null) {
      return Image.asset(
        iconAsset!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Icon(icon, size: size * 0.5, color: color),
      );
    }
    return null;
  }

  /// Inline icon for compact contexts (lists, leaderboards, picker mascot).
  /// Falls back through customLogo → iconAsset → Material `icon`.
  Widget buildIcon({double size = 48}) {
    if (customLogo != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.2),
        child: SizedBox(width: size, height: size, child: customLogo!(size)),
      );
    }
    if (iconAsset != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.2),
        child: Image.asset(
          iconAsset!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Icon(icon, size: size, color: color),
        ),
      );
    }
    return Icon(icon, size: size, color: color);
  }

  String get playCountFormatted {
    if (playCount >= 1000000) {
      return '${(playCount / 1000000).toStringAsFixed(1)}M';
    } else if (playCount >= 1000) {
      return '${(playCount / 1000).toStringAsFixed(1)}K';
    }
    return playCount.toString();
  }
}

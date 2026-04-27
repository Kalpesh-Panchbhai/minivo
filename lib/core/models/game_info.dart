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
  });

  String get playCountFormatted {
    if (playCount >= 1000000) {
      return '${(playCount / 1000000).toStringAsFixed(1)}M';
    } else if (playCount >= 1000) {
      return '${(playCount / 1000).toStringAsFixed(1)}K';
    }
    return playCount.toString();
  }
}

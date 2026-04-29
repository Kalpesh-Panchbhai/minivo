import 'package:flutter/material.dart';
import '../core/models/game_info.dart';
import 'flappy_tap/flappy_tap_screen.dart';
import 'number_merge/number_merge_screen.dart';
import 'block_fit/block_fit_screen.dart';
import 'tic_tac_toe/tic_tac_toe_screen.dart';

typedef GameWidgetBuilder = Widget Function();

class GameRegistry {
  GameRegistry._();

  static final Map<String, GameWidgetBuilder> _builders = {
    'flappy_tap': () => const FlappyTapScreen(),
    'number_merge': () => const NumberMergeScreen(),
    'block_fit': () => const BlockFitScreen(),
    'tic_tac_toe': () => const TicTacToeScreen(),
  };

  static Widget buildGame(String gameId) {
    final builder = _builders[gameId];
    if (builder == null) {
      return const Center(child: Text('Game not found'));
    }
    return builder();
  }

  static bool hasGame(String gameId) => _builders.containsKey(gameId);

  static const Set<String> _customOverlayGames = {'tic_tac_toe'};

  static bool usesCustomOverlays(String gameId) =>
      _customOverlayGames.contains(gameId);

  static final List<GameInfo> allGames = [
    const GameInfo(
      id: 'flappy_tap',
      name: 'Flappy Tap',
      description: 'Tap to fly through the gaps. How far can you go? Simple yet addictive!',
      howToPlay: 'Tap the screen to make the bird flap and fly upward. Avoid the pipes and try to fly as far as possible.',
      category: GameCategory.action,
      icon: Icons.air_rounded,
      color: Color(0xFF4ECDC4),
      bgColor: Color(0xFFE8FAF8),

      playCount: 12500,
      isFeatured: true,
    ),
    const GameInfo(
      id: 'number_merge',
      name: '2048 Merge',
      description: 'Slide tiles and merge numbers. Can you reach 2048?',
      howToPlay: 'Swipe in any direction to move all tiles. When two tiles with the same number touch, they merge into one. Try to reach 2048!',
      category: GameCategory.puzzle,
      icon: Icons.calculate_rounded,
      color: Color(0xFFFF6B6B),
      bgColor: Color(0xFFFFF0F0),

      playCount: 18200,
      isFeatured: true,
    ),
    const GameInfo(
      id: 'block_fit',
      name: 'Block Fit',
      description: 'Drag blocks to fill rows and columns. Clear them for points!',
      howToPlay: 'Drag the block shapes onto the grid. Complete a full row or column to clear it and score points. Game ends when no blocks fit.',
      category: GameCategory.puzzle,
      icon: Icons.apps_rounded,
      color: Color(0xFF6C63FF),
      bgColor: Color(0xFFF0EFFF),
      playCount: 9800,
      isFeatured: true,
    ),
    const GameInfo(
      id: 'color_switch',
      name: 'Color Tap',
      description: 'Tap through matching colored gates. Test your reflexes!',
      howToPlay: 'Tap to move the ball upward. Pass through gates that match your ball color. The color changes as you collect switches.',
      category: GameCategory.arcade,
      icon: Icons.circle_rounded,
      color: Color(0xFFFF922B),
      bgColor: Color(0xFFFFF4EC),
      playCount: 7600,
    ),
    const GameInfo(
      id: 'stack_tower',
      name: 'Stack Tower',
      description: 'Tap to stack blocks perfectly. How high can you build?',
      howToPlay: 'Tap the screen to drop the moving block. Stack it perfectly on top of the previous block. Misaligned parts get cut off.',
      category: GameCategory.arcade,
      icon: Icons.layers_rounded,
      color: Color(0xFF51CF66),
      bgColor: Color(0xFFECFBF0),
      playCount: 6200,
    ),
    const GameInfo(
      id: 'memory_match',
      name: 'Memory Match',
      description: 'Flip cards and find matching pairs. Train your memory!',
      howToPlay: 'Tap cards to flip them over. Find all matching pairs by remembering card positions. Fewer flips = higher score.',
      category: GameCategory.puzzle,
      icon: Icons.flip_rounded,
      color: Color(0xFF339AF0),
      bgColor: Color(0xFFEBF5FF),
      playCount: 5400,
    ),
    const GameInfo(
      id: 'snake_classic',
      name: 'Snake Classic',
      description: 'Guide the snake to eat food and grow longer!',
      howToPlay: 'Swipe to change direction. Eat food to grow longer. Don\'t hit the walls or your own tail!',
      category: GameCategory.action,
      icon: Icons.pest_control_rounded,
      color: Color(0xFF20C997),
      bgColor: Color(0xFFE6FCF5),
      playCount: 11000,
    ),
    const GameInfo(
      id: 'tic_tac_toe',
      name: 'Tic Tac Toe',
      description: 'Classic X and O. Play against the computer!',
      howToPlay:
          'Choose your difficulty (Easy, Medium, Hard) or play with a friend on the same device.\n'
          'Players take turns — X always goes first in any given round.\n'
          'Tap an empty cell on the 3x3 grid to place your mark there.\n'
          'Get three of your marks in a row, column, or diagonal to win the round.\n'
          'Win two rounds in a row to start a Streak — keep it going for bragging rights!\n'
          'After each round the starter alternates, so you both get a fair go.',
      category: GameCategory.board,
      icon: Icons.close_rounded,
      color: Color(0xFFBE4BDB),
      bgColor: Color(0xFFF8F0FC),
      playCount: 8900,
      iconAsset: 'assets/games/tic_tac_toe/icon.png',
    ),
  ];

  static List<GameInfo> getByCategory(GameCategory category) {
    return allGames.where((g) => g.category == category).toList();
  }

  static List<GameInfo> get featured {
    return allGames.where((g) => g.isFeatured).toList();
  }

  static List<GameInfo> get trending {
    final sorted = List<GameInfo>.from(allGames);
    sorted.sort((a, b) => b.playCount.compareTo(a.playCount));
    return sorted;
  }

  static GameInfo? getById(String id) {
    try {
      return allGames.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<GameInfo> search(String query) {
    final q = query.toLowerCase();
    return allGames.where((g) {
      return g.name.toLowerCase().contains(q) ||
          g.category.label.toLowerCase().contains(q) ||
          g.description.toLowerCase().contains(q);
    }).toList();
  }
}

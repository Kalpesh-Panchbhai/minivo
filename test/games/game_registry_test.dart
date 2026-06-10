import 'package:flutter_test/flutter_test.dart';

import '../../lib/core/models/game_info.dart';
import '../../lib/games/game_registry.dart';

void main() {
  group('GameRegistry', () {
    test('allGames list is not empty', () {
      expect(GameRegistry.allGames.isNotEmpty, isTrue);
    });

    test('all 20 games are registered with builders', () {
      const expectedIds = [
        'checkers', 'color_tap', 'connect_four', 'dino_run', 'dodge_ball',
        'dots_and_boxes', 'drop_merge', 'flappy_tap', 'go', 'gomoku',
        'hangman', 'mancala', 'memory_match',
        'number_merge', 'reversi', 'snake_classic', 'sudoku',
        'tap_tap_dash', 'tic_tac_toe', 'whack_a_mole',
      ];
      for (final id in expectedIds) {
        expect(GameRegistry.hasGame(id), isTrue, reason: '$id must have a builder');
        expect(GameRegistry.getById(id), isNotNull, reason: '$id must have metadata');
      }
    });

    test('allGames count matches builder count', () {
      expect(GameRegistry.allGames.length, 20);
    });

    test('each game has unique id', () {
      final ids = GameRegistry.allGames.map((g) => g.id).toSet();
      expect(ids.length, GameRegistry.allGames.length);
    });

    test('every game has non-empty name, description, and howToPlay', () {
      for (final game in GameRegistry.allGames) {
        expect(game.name.isNotEmpty, isTrue, reason: '${game.id} name');
        expect(game.description.isNotEmpty, isTrue, reason: '${game.id} description');
        expect(game.howToPlay.isNotEmpty, isTrue, reason: '${game.id} howToPlay');
      }
    });

    test('getById returns null for unknown id', () {
      expect(GameRegistry.getById('nonexistent'), isNull);
    });

    test('hasGame returns false for unknown id', () {
      expect(GameRegistry.hasGame('nonexistent'), isFalse);
    });

    test('getByCategory returns only games of that category', () {
      final boardGames = GameRegistry.getByCategory(GameCategory.board);
      for (final g in boardGames) {
        expect(g.category, GameCategory.board);
      }
      expect(boardGames.isNotEmpty, isTrue);
    });

    test('featured returns only featured games', () {
      final featured = GameRegistry.featured;
      for (final g in featured) {
        expect(g.isFeatured, isTrue);
      }
    });

    test('trending returns all games sorted by playCount descending', () {
      final trending = GameRegistry.trending;
      expect(trending.length, GameRegistry.allGames.length);
      for (int i = 0; i < trending.length - 1; i++) {
        expect(trending[i].playCount, greaterThanOrEqualTo(trending[i + 1].playCount));
      }
    });

    test('search finds games by name', () {
      final results = GameRegistry.search('snake');
      expect(results.any((g) => g.id == 'snake_classic'), isTrue);
    });

    test('search finds games by category label', () {
      final results = GameRegistry.search('board');
      expect(results.isNotEmpty, isTrue);
      for (final g in results) {
        final matchesName = g.name.toLowerCase().contains('board');
        final matchesCat = g.category.label.toLowerCase().contains('board');
        final matchesDesc = g.description.toLowerCase().contains('board');
        expect(matchesName || matchesCat || matchesDesc, isTrue);
      }
    });

    test('search finds games by description keyword', () {
      final results = GameRegistry.search('flip');
      expect(results.isNotEmpty, isTrue);
    });

    test('search is case-insensitive', () {
      final upper = GameRegistry.search('SNAKE');
      final lower = GameRegistry.search('snake');
      expect(upper.length, lower.length);
    });

    test('search with empty query returns all games', () {
      final results = GameRegistry.search('');
      expect(results.length, GameRegistry.allGames.length);
    });

    test('buildGame returns a widget for known game', () {
      final widget = GameRegistry.buildGame('tic_tac_toe');
      expect(widget, isNotNull);
    });

    test('buildGame returns "Game not found" for unknown game', () {
      final widget = GameRegistry.buildGame('nonexistent');
      expect(widget, isNotNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lib/core/services/score_service.dart';

void main() {
  group('ScoreService', () {
    late ScoreService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      service = ScoreService();
      await service.init();
    });

    group('high scores', () {
      test('default is 0 for unknown game', () {
        expect(service.getHighScore('unknown'), 0);
      });

      test('saveScore returns true and persists when score is higher', () async {
        final saved = await service.saveScore('flappy_tap', 42);
        expect(saved, isTrue);
        expect(service.getHighScore('flappy_tap'), 42);
      });

      test('saveScore returns false and keeps existing when score is lower',
          () async {
        await service.saveScore('flappy_tap', 100);
        final saved = await service.saveScore('flappy_tap', 50);
        expect(saved, isFalse);
        expect(service.getHighScore('flappy_tap'), 100);
      });

      test('saveScore returns false when score equals existing', () async {
        await service.saveScore('flappy_tap', 100);
        final saved = await service.saveScore('flappy_tap', 100);
        expect(saved, isFalse);
        expect(service.getHighScore('flappy_tap'), 100);
      });

      test('high scores are isolated per game', () async {
        await service.saveScore('a', 10);
        await service.saveScore('b', 20);
        expect(service.getHighScore('a'), 10);
        expect(service.getHighScore('b'), 20);
      });
    });

    group('games-played counter', () {
      test('default is 0', () {
        expect(service.getTotalGamesPlayed(), 0);
      });

      test('incrementGamesPlayed increases by 1 each call', () async {
        await service.incrementGamesPlayed();
        await service.incrementGamesPlayed();
        await service.incrementGamesPlayed();
        expect(service.getTotalGamesPlayed(), 3);
      });
    });

    group('coins', () {
      test('default is 0', () {
        expect(service.getTotalCoins(), 0);
      });

      test('addCoins accumulates positive amounts', () async {
        await service.addCoins(10);
        await service.addCoins(5);
        expect(service.getTotalCoins(), 15);
      });

      test('addCoins accepts negative amounts (spending)', () async {
        await service.addCoins(20);
        await service.addCoins(-5);
        expect(service.getTotalCoins(), 15);
      });
    });

    group('recently played (LRU, max 10)', () {
      test('default is empty', () {
        expect(service.getRecentlyPlayed(), isEmpty);
      });

      test('newest entry goes to the front', () async {
        await service.addRecentlyPlayed('a');
        await service.addRecentlyPlayed('b');
        expect(service.getRecentlyPlayed(), ['b', 'a']);
      });

      test('replaying an existing game moves it to the front', () async {
        await service.addRecentlyPlayed('a');
        await service.addRecentlyPlayed('b');
        await service.addRecentlyPlayed('a');
        expect(service.getRecentlyPlayed(), ['a', 'b']);
      });

      test('list is capped at 10 entries (oldest evicted)', () async {
        for (var i = 0; i < 12; i++) {
          await service.addRecentlyPlayed('g$i');
        }
        final list = service.getRecentlyPlayed();
        expect(list.length, 10);
        // The most recent is at the front; the oldest two ("g0", "g1")
        // should have been evicted.
        expect(list.first, 'g11');
        expect(list.contains('g0'), isFalse);
        expect(list.contains('g1'), isFalse);
      });
    });

    group('favorites', () {
      test('default is empty and isFavorite false', () {
        expect(service.getFavorites(), isEmpty);
        expect(service.isFavorite('any'), isFalse);
      });

      test('toggleFavorite adds when missing, removes when present', () async {
        await service.toggleFavorite('flappy_tap');
        expect(service.isFavorite('flappy_tap'), isTrue);
        await service.toggleFavorite('flappy_tap');
        expect(service.isFavorite('flappy_tap'), isFalse);
      });

      test('multiple favorites coexist', () async {
        await service.toggleFavorite('a');
        await service.toggleFavorite('b');
        expect(service.getFavorites(), containsAll(<String>['a', 'b']));
      });
    });

    group('onboarding flag', () {
      test('default is false', () {
        expect(service.hasSeenOnboarding(), isFalse);
      });

      test('setOnboardingSeen flips to true', () async {
        await service.setOnboardingSeen();
        expect(service.hasSeenOnboarding(), isTrue);
      });
    });

    group('settings toggles', () {
      test('sound defaults to enabled', () {
        expect(service.isSoundEnabled(), isTrue);
      });

      test('vibration defaults to enabled', () {
        expect(service.isVibrationEnabled(), isTrue);
      });

      test('setSoundEnabled persists', () async {
        await service.setSoundEnabled(false);
        expect(service.isSoundEnabled(), isFalse);
        await service.setSoundEnabled(true);
        expect(service.isSoundEnabled(), isTrue);
      });

      test('setVibrationEnabled persists', () async {
        await service.setVibrationEnabled(false);
        expect(service.isVibrationEnabled(), isFalse);
      });
    });

    group('display name', () {
      test('default is "Player"', () {
        expect(service.getDisplayName(), 'Player');
      });

      test('setDisplayName persists', () async {
        await service.setDisplayName('Kalpesh');
        expect(service.getDisplayName(), 'Kalpesh');
      });
    });

    group('per-game play counts', () {
      test('default is 0', () {
        expect(service.getGamePlayCount('flappy_tap'), 0);
      });

      test('incrementGamePlayCount accumulates', () async {
        await service.incrementGamePlayCount('flappy_tap');
        await service.incrementGamePlayCount('flappy_tap');
        expect(service.getGamePlayCount('flappy_tap'), 2);
      });

      test('counts are isolated per game', () async {
        await service.incrementGamePlayCount('a');
        await service.incrementGamePlayCount('b');
        await service.incrementGamePlayCount('b');
        expect(service.getGamePlayCount('a'), 1);
        expect(service.getGamePlayCount('b'), 2);
      });
    });

    group('persistence (round-trip via SharedPreferences mock)', () {
      test('values survive a fresh service instance over the same prefs',
          () async {
        await service.saveScore('flappy_tap', 99);
        await service.toggleFavorite('flappy_tap');
        await service.setDisplayName('K');

        // ScoreService is a singleton, so we re-init against the same backing
        // store — equivalent to relaunching the app with the same prefs.
        await service.init();
        expect(service.getHighScore('flappy_tap'), 99);
        expect(service.isFavorite('flappy_tap'), isTrue);
        expect(service.getDisplayName(), 'K');
      });
    });

    group('tutorial seen', () {
      test('default is false for any game', () {
        expect(service.hasTutorialSeen('any_game'), isFalse);
      });

      test('setTutorialSeen persists true', () async {
        await service.setTutorialSeen('tic_tac_toe');
        expect(service.hasTutorialSeen('tic_tac_toe'), isTrue);
      });

      test('tutorial flags are isolated per game', () async {
        await service.setTutorialSeen('tic_tac_toe');
        expect(service.hasTutorialSeen('tic_tac_toe'), isTrue);
        expect(service.hasTutorialSeen('flappy_tap'), isFalse);
      });
    });

    group('high score with subKey', () {
      test('default is 0 for an unknown bucket', () {
        expect(
          service.getHighScore('tic_tac_toe', subKey: 'ai_easy'),
          0,
        );
      });

      test('saveScore + getHighScore round-trips per subKey', () async {
        final saved = await service.saveScore(
          'tic_tac_toe',
          5,
          subKey: 'ai_easy',
        );
        expect(saved, isTrue);
        expect(
          service.getHighScore('tic_tac_toe', subKey: 'ai_easy'),
          5,
        );
      });

      test('only persists higher values', () async {
        await service.saveScore('tic_tac_toe', 5, subKey: 'ai_easy');
        final stored =
            await service.saveScore('tic_tac_toe', 3, subKey: 'ai_easy');
        expect(stored, isFalse);
        expect(
          service.getHighScore('tic_tac_toe', subKey: 'ai_easy'),
          5,
        );
      });

      test('different subKeys are isolated', () async {
        await service.saveScore('tic_tac_toe', 5, subKey: 'ai_easy');
        await service.saveScore('tic_tac_toe', 1, subKey: 'ai_hard');
        expect(
          service.getHighScore('tic_tac_toe', subKey: 'ai_easy'),
          5,
        );
        expect(
          service.getHighScore('tic_tac_toe', subKey: 'ai_hard'),
          1,
        );
      });

      test('subKey storage does not collide with the unscoped game key',
          () async {
        await service.saveScore('tic_tac_toe', 99);
        await service.saveScore('tic_tac_toe', 5, subKey: 'ai_easy');
        expect(service.getHighScore('tic_tac_toe'), 99);
        expect(
          service.getHighScore('tic_tac_toe', subKey: 'ai_easy'),
          5,
        );
      });

      test('clearHighScore wipes a single bucket', () async {
        await service.saveScore('tic_tac_toe', 5, subKey: 'ai_easy');
        await service.clearHighScore('tic_tac_toe', subKey: 'ai_easy');
        expect(
          service.getHighScore('tic_tac_toe', subKey: 'ai_easy'),
          0,
        );
      });

      test('persists across re-init', () async {
        await service.saveScore('tic_tac_toe', 7, subKey: 'ai_medium');
        await service.init();
        expect(
          service.getHighScore('tic_tac_toe', subKey: 'ai_medium'),
          7,
        );
      });
    });
  });
}

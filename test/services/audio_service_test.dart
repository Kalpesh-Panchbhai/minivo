import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lib/core/services/audio_service.dart';
import '../../lib/core/services/score_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioService', () {
    late AudioService audio;
    late ScoreService score;
    final hapticCalls = <String>[];

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      score = ScoreService();
      await score.init();
      audio = AudioService();
      hapticCalls.clear();

      // Capture every HapticFeedback platform call so we can assert which
      // method was invoked without actually firing native haptics.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          hapticCalls.add(call.arguments as String? ?? 'default');
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('isSoundEnabled mirrors ScoreService flag', () async {
      expect(audio.isSoundEnabled, isTrue);
      await score.setSoundEnabled(false);
      expect(audio.isSoundEnabled, isFalse);
    });

    test('playTap uses light haptic when sound is enabled', () async {
      await audio.playTap();
      expect(hapticCalls, contains('HapticFeedbackType.lightImpact'));
    });

    test('playScore uses medium haptic when sound is enabled', () async {
      await audio.playScore();
      expect(hapticCalls, contains('HapticFeedbackType.mediumImpact'));
    });

    test('playGameOver uses heavy haptic when sound is enabled', () async {
      await audio.playGameOver();
      expect(hapticCalls, contains('HapticFeedbackType.heavyImpact'));
    });

    test('playSuccess uses medium haptic when sound is enabled', () async {
      await audio.playSuccess();
      expect(hapticCalls, contains('HapticFeedbackType.mediumImpact'));
    });

    test('no haptic is fired when sound is disabled', () async {
      await score.setSoundEnabled(false);
      await audio.playTap();
      await audio.playScore();
      await audio.playGameOver();
      await audio.playSuccess();
      expect(hapticCalls, isEmpty);
    });
  });
}

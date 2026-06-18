import 'package:flutter/services.dart';
import 'score_service.dart';

/// Haptic feedback layer for the games. The app has NO audio/music — this
/// service provides only tactile (vibration) feedback via [HapticFeedback].
/// Gated by the user's feedback preference ([ScoreService.isSoundEnabled],
/// default on). Named `AudioService` for historical reasons; it is purely
/// haptic.
class AudioService {
  static final AudioService _instance = AudioService._();
  factory AudioService() => _instance;
  AudioService._();

  bool get isSoundEnabled => ScoreService().isSoundEnabled();

  /// Light tap — for taps/selections/moves.
  Future<void> playTap() async {
    if (!isSoundEnabled) return;
    await HapticFeedback.lightImpact();
  }

  /// Medium tap — for scoring / a successful match.
  Future<void> playScore() async {
    if (!isSoundEnabled) return;
    await HapticFeedback.mediumImpact();
  }

  /// Heavy tap — for game over / loss.
  Future<void> playGameOver() async {
    if (!isSoundEnabled) return;
    await HapticFeedback.heavyImpact();
  }

  /// Medium tap — for a win / level complete.
  Future<void> playSuccess() async {
    if (!isSoundEnabled) return;
    await HapticFeedback.mediumImpact();
  }
}

import 'package:flutter/services.dart';
import 'score_service.dart';

class AudioService {
  static final AudioService _instance = AudioService._();
  factory AudioService() => _instance;
  AudioService._();

  bool get isSoundEnabled => ScoreService().isSoundEnabled();

  Future<void> playTap() async {
    if (!isSoundEnabled) return;
    await HapticFeedback.lightImpact();
  }

  Future<void> playScore() async {
    if (!isSoundEnabled) return;
    await HapticFeedback.mediumImpact();
  }

  Future<void> playGameOver() async {
    if (!isSoundEnabled) return;
    await HapticFeedback.heavyImpact();
  }

  Future<void> playSuccess() async {
    if (!isSoundEnabled) return;
    await HapticFeedback.mediumImpact();
  }
}

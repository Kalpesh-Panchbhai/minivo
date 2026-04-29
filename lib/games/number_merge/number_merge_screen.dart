import 'package:flutter/material.dart';

import '../game_wrapper.dart';
import 'number_merge_game.dart';
import 'number_merge_stats.dart';

/// Entry point for the 2048 game. Uses `customOverlays: true` because the
/// board renders its own HUD, score chips, win/game-over banners, and new-game
/// button — the default GameWrapper overlays would collide.
class NumberMergeScreen extends StatelessWidget {
  const NumberMergeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GameWrapper(
      gameId: kNumberMergeGameId,
      customOverlays: true,
      child: const NumberMergeGame(),
    );
  }
}

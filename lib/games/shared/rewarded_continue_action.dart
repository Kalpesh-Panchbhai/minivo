import 'package:flutter/material.dart';

import '../../core/services/ads_service.dart';
import '../game_wrapper.dart';
import 'generic_game_result_screen.dart';

/// Builds the "Watch ad to continue" [GameResultAction] for any game's
/// game-over result screen.
///
/// Returns `null` when the player has already used their one continue this
/// session, or when there's no rewarded ad ready — callers should drop
/// the button entirely in that case rather than show a disabled tile (the
/// player should never see "watch ad" and have nothing happen).
///
/// [onRewarded] is called when **both** the user earned the reward AND the
/// ad has fully dismissed — i.e. the AdMob activity has gone away and the
/// Flutter activity is back on top. This timing matters: AdMob fires its
/// "earned reward" callback partway through the video, but if we run the
/// continue logic at that point, any per-round timers in the game start
/// running while the user is still watching the ad.
GameResultAction? rewardedContinueAction({
  required BuildContext context,
  required String label,
  required Color color,
  required VoidCallback onRewarded,
}) {
  if (GameWrapper.of(context).hasContinued) return null;
  if (!AdsService().isRewardedReady) return null;
  return GameResultAction(
    label: label,
    icon: Icons.play_circle_fill_rounded,
    filled: true,
    color: color,
    actionId: 'rewarded_continue',
    onTap: () {
      bool rewardEarned = false;
      AdsService().showRewarded(
        rewardType: RewardType.continueGame,
        onRewarded: (_) {
          rewardEarned = true;
        },
        onComplete: () {
          if (rewardEarned) onRewarded();
        },
      );
    },
  );
}

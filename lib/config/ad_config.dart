/// AdMob unit IDs for the current flavor.
///
/// Test IDs (Google's official test units) ride with `main_dev.dart`.
/// Real IDs ride with `main_prod.dart`.
///
/// **Never** call `AdConfig.prod()` from a debug or non-prod build — that
/// would serve live ads against your real ad units in test traffic, which
/// AdMob policy treats as fraudulent and can suspend the account.
class AdConfig {
  final String interstitialId;
  final String rewardedId;

  const AdConfig({required this.interstitialId, required this.rewardedId});

  /// Google's official test ad unit IDs. Safe to ship in dev builds.
  factory AdConfig.test() => const AdConfig(
        interstitialId: 'ca-app-pub-3940256099942544/1033173712',
        rewardedId: 'ca-app-pub-3940256099942544/5224354917',
      );

  /// Real AdMob unit IDs for production releases.
  factory AdConfig.prod() => const AdConfig(
        interstitialId: 'ca-app-pub-6010707433076438/3369137664',
        rewardedId: 'ca-app-pub-6010707433076438/8837086769',
      );
}

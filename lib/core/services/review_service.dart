import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'analytics_service.dart';
import 'score_service.dart';

class ReviewService {
  ReviewService._();
  static final ReviewService _instance = ReviewService._();
  factory ReviewService() => _instance;

  static const _kLastPrompted = 'review_last_prompted';
  static const _kPromptCount = 'review_prompt_count';

  static const _minGamesPlayed = 5;
  static const _minDaysBetweenPrompts = 30;
  static const _maxLifetimePrompts = 3;

  bool _promptedThisSession = false;

  Future<void> maybeRequestReview() async {
    if (_promptedThisSession) return;

    final prefs = await SharedPreferences.getInstance();

    final promptCount = prefs.getInt(_kPromptCount) ?? 0;
    if (promptCount >= _maxLifetimePrompts) return;

    if (ScoreService().getTotalGamesPlayed() < _minGamesPlayed) return;

    final lastPrompted = prefs.getInt(_kLastPrompted) ?? 0;
    final daysSince = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(lastPrompted))
        .inDays;
    if (lastPrompted > 0 && daysSince < _minDaysBetweenPrompts) return;

    final review = InAppReview.instance;
    if (!await review.isAvailable()) return;

    _promptedThisSession = true;
    await prefs.setInt(
        _kLastPrompted, DateTime.now().millisecondsSinceEpoch);
    await prefs.setInt(_kPromptCount, promptCount + 1);

    await Future.delayed(const Duration(seconds: 2));
    await review.requestReview();
    AnalyticsService().externalLinkOpened(link: 'auto_review_prompt');
  }
}

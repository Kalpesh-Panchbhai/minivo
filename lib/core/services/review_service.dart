import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'analytics_service.dart';
import 'score_service.dart';

class ReviewService {
  ReviewService._();
  static final ReviewService _instance = ReviewService._();
  factory ReviewService() => _instance;

  static const _kLastPrompted = 'review_last_prompted';
  static const _kCompleted = 'review_completed';

  static const _minGamesPlayed = 5;
  static const _minDaysBetweenPrompts = 7;

  bool _promptedThisSession = false;

  Future<void> maybeRequestReview() async {
    if (_promptedThisSession) return;

    final prefs = await SharedPreferences.getInstance();

    if (prefs.getBool(_kCompleted) ?? false) return;

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
    await prefs.setBool(_kCompleted, true);

    await Future.delayed(const Duration(seconds: 2));
    await review.requestReview();
    AnalyticsService().externalLinkOpened(link: 'auto_review_prompt');
  }
}

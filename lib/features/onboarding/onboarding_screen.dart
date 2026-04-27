import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/score_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  final _pages = [
    _OnboardingPage(
      icon: Icons.sports_esports_rounded,
      color: AppColors.primary,
      title: AppStrings.onboarding1Title,
      description: AppStrings.onboarding1Desc,
    ),
    _OnboardingPage(
      icon: Icons.emoji_events_rounded,
      color: AppColors.accent,
      title: AppStrings.onboarding2Title,
      description: AppStrings.onboarding2Desc,
    ),
    _OnboardingPage(
      icon: Icons.bolt_rounded,
      color: AppColors.categoryBoard,
      title: AppStrings.onboarding3Title,
      description: AppStrings.onboarding3Desc,
    ),
  ];

  void _onNext() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    ScoreService().setOnboardingSeen();
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    AppStrings.skip,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: page.color.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            page.icon,
                            size: 56,
                            color: page.color,
                          ),
                        )
                            .animate(key: ValueKey(index))
                            .scale(
                              begin: const Offset(0.7, 0.7),
                              end: const Offset(1, 1),
                              duration: 500.ms,
                              curve: Curves.easeOutBack,
                            )
                            .fadeIn(duration: 400.ms),
                        const SizedBox(height: 32),
                        Text(
                          page.title,
                          style: Theme.of(context).textTheme.displayMedium,
                          textAlign: TextAlign.center,
                        )
                            .animate(key: ValueKey('t$index'))
                            .fadeIn(delay: 200.ms, duration: 400.ms)
                            .slideY(begin: 0.2, delay: 200.ms, duration: 400.ms),
                        const SizedBox(height: 16),
                        Text(
                          page.description,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                          textAlign: TextAlign.center,
                        )
                            .animate(key: ValueKey('d$index'))
                            .fadeIn(delay: 350.ms, duration: 400.ms),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SmoothPageIndicator(
                    controller: _controller,
                    count: _pages.length,
                    effect: ExpandingDotsEffect(
                      activeDotColor: AppColors.primary,
                      dotColor: AppColors.shimmer,
                      dotHeight: 8,
                      dotWidth: 8,
                      expansionFactor: 3,
                    ),
                  ),
                  GestureDetector(
                    onTap: _onNext,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: _currentPage == _pages.length - 1 ? 140 : 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _currentPage == _pages.length - 1
                            ? const Text(
                                'Get Started',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              )
                            : const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _OnboardingPage({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });
}

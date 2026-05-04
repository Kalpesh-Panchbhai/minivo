import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

// ── Data model for animated tutorial steps ─────────────────────────────────

/// A single tutorial step with an optional animated demo widget.
///
/// Pass a list of these to [showHowToPlaySheet] via the [steps] parameter.
/// When [steps] is provided the sheet renders the animated [demo] instead of
/// the generic icon art.
class GameHowToPlayStep {
  final String text;
  final Widget demo;

  const GameHowToPlayStep({required this.text, required this.demo});
}

// ── Public API ──────────────────────────────────────────────────────────────

/// Opens a full-screen, game-style "How to Play" tutorial overlay.
///
/// Pass [steps] to show animated gameplay demonstrations for each step.
/// If [steps] is omitted (or null), the sheet falls back to parsing
/// [howToPlay] (a newline-separated string) and showing generic icons —
/// preserving backward compatibility.
Future<void> showHowToPlaySheet(
  BuildContext context, {
  required String title,
  String howToPlay = '',
  required Color accent,
  List<GameHowToPlayStep>? steps,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'How to play',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, _, _) => HowToPlaySheet(
      title: title,
      howToPlay: howToPlay,
      accent: accent,
      steps: steps,
    ),
    transitionBuilder: (_, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween(begin: 0.85, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// The tutorial overlay itself. Public so it can be referenced from tests.
class HowToPlaySheet extends StatefulWidget {
  final String title;
  final String howToPlay;
  final Color accent;
  final List<GameHowToPlayStep>? steps;

  const HowToPlaySheet({
    super.key,
    required this.title,
    this.howToPlay = '',
    required this.accent,
    this.steps,
  });

  @override
  State<HowToPlaySheet> createState() => _HowToPlaySheetState();
}

class _HowToPlaySheetState extends State<HowToPlaySheet> {
  final _pageCtrl = PageController();
  int _page = 0;

  // Whimsical icons cycled per step — keeps each tutorial page visually
  // distinct without hard-coding per-game art.
  static const _stepIcons = <IconData>[
    Icons.touch_app_rounded,
    Icons.flag_rounded,
    Icons.bolt_rounded,
    Icons.emoji_events_rounded,
    Icons.auto_awesome_rounded,
    Icons.celebration_rounded,
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  List<String> _parseSteps(String raw) {
    final lines = raw
        .trim()
        .split(RegExp(r'\n+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return lines
        .map((s) => s.replaceFirst(RegExp(r'^(\d+[\.\)]|[\-\*•])\s*'), ''))
        .toList();
  }

  void _next(int total) {
    if (_page >= total - 1) {
      Navigator.of(context).pop();
      return;
    }
    _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Prefer animated steps; fall back to string-parsed steps.
    final hasAnimatedSteps =
        widget.steps != null && widget.steps!.isNotEmpty;

    final stepCount = hasAnimatedSteps
        ? widget.steps!.length
        : _parseSteps(widget.howToPlay).length;

    if (stepCount == 0) {
      return const SizedBox.shrink();
    }

    final parsedTexts =
        hasAnimatedSteps ? <String>[] : _parseSteps(widget.howToPlay);
    final isLast = _page >= stepCount - 1;

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(widget.accent, Colors.white, 0.82)!,
                      Color.lerp(widget.accent, Colors.white, 0.92)!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: widget.accent.withValues(alpha: 0.28),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Header(
                      title: widget.title,
                      accent: widget.accent,
                      onClose: () => Navigator.of(context).pop(),
                    ),
                    SizedBox(
                      height: 320,
                      child: PageView.builder(
                        controller: _pageCtrl,
                        onPageChanged: (i) => setState(() => _page = i),
                        itemCount: stepCount,
                        itemBuilder: (context, i) {
                          if (hasAnimatedSteps) {
                            final step = widget.steps![i];
                            return _StepPage(
                              index: i + 1,
                              total: stepCount,
                              text: step.text,
                              icon: _stepIcons[i % _stepIcons.length],
                              accent: widget.accent,
                              demo: step.demo,
                            );
                          } else {
                            return _StepPage(
                              index: i + 1,
                              total: stepCount,
                              text: parsedTexts[i],
                              icon: _stepIcons[i % _stepIcons.length],
                              accent: widget.accent,
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                    _PageDots(
                      count: stepCount,
                      active: _page,
                      accent: widget.accent,
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                      child: _PrimaryButton(
                        label: isLast ? "Got it! Let's play" : 'Next',
                        accent: widget.accent,
                        onTap: () => _next(stepCount),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String title;
  final Color accent;
  final VoidCallback onClose;
  const _Header({
    required this.title,
    required this.accent,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 6),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.sports_esports_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How to Play',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    height: 1.0,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step page ──────────────────────────────────────────────────────────────

class _StepPage extends StatelessWidget {
  final int index;
  final int total;
  final String text;
  final IconData icon;
  final Color accent;
  final Widget? demo;

  const _StepPage({
    required this.index,
    required this.total,
    required this.text,
    required this.icon,
    required this.accent,
    this.demo,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Hero art: animated demo or generic icon.
          if (demo != null)
            Container(
              width: 180,
              height: 160,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: demo,
            )
          else
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.30),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(icon, color: accent, size: 44),
              ),
            ),
          const SizedBox(height: 20),
          // STEP X / Y eyebrow.
          Text(
            'STEP $index OF $total',
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          // Step description.
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Page dots ──────────────────────────────────────────────────────────────

class _PageDots extends StatelessWidget {
  final int count;
  final int active;
  final Color accent;
  const _PageDots({
    required this.count,
    required this.active,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 22 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: isActive ? accent : accent.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }
}

// ── Primary CTA button ─────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final String label;
  final Color accent;
  final VoidCallback onTap;
  const _PrimaryButton({
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

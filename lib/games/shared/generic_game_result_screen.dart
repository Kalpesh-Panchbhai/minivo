import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/services/analytics_service.dart';
import '../../core/services/share_service.dart';
import '../../core/utils/responsive.dart';
import '../game_registry.dart';

class StatItem {
  final String label;
  final int value;
  final String? displayValue;
  final Color color;

  StatItem({
    required this.label,
    required this.value,
    this.displayValue,
    required this.color,
  });
}

class GameResultAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  final Color? color;
  final String? actionId;

  GameResultAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.color,
    this.actionId,
  });
}

class GenericGameResultScreen extends StatelessWidget {
  final String headline;
  final String? subtitle;
  final String badgeContent;
  final Color badgeColor;
  final Widget? statsWidget;
  final List<GameResultAction> actions;
  final List<Color>? gradientColors;
  final bool showNewBestBadge;
  final List<Widget> extraBadges;
  final String? gameId;
  final int? score;
  final int? stars;

  const GenericGameResultScreen({
    super.key,
    required this.headline,
    this.subtitle,
    required this.badgeContent,
    required this.badgeColor,
    this.statsWidget,
    required this.actions,
    this.gradientColors,
    this.showNewBestBadge = false,
    this.extraBadges = const [],
    this.gameId,
    this.score,
    this.stars,
  });

  @override
  Widget build(BuildContext context) {
    final colors = gradientColors ??
        [
          const Color(0xFFF6F0FF),
          const Color(0xFFEDE3FB),
          const Color(0xFFFFE2E8),
        ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
            // Badge medallion
            Container(
              width: 148,
              height: 148,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: badgeColor.withValues(alpha: 0.40),
                    blurRadius: 36,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    badgeContent,
                    maxLines: 1,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: context.fontSize(92, max: 100),
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
            )
                .animate()
                .scale(
                  begin: const Offset(0.4, 0.4),
                  end: const Offset(1.0, 1.0),
                  duration: 480.ms,
                  curve: Curves.easeOutBack,
                )
                .fadeIn(duration: 320.ms),
            const SizedBox(height: 22),
            // Headline
            Text(
              headline,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF3A2D55),
                fontSize: context.fontSize(30, max: 36),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ).animate().fadeIn(delay: 220.ms, duration: 320.ms),
            // Subtitle
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ).animate().fadeIn(delay: 240.ms, duration: 280.ms),
            ],
            // New Best badge
            if (showNewBestBadge) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFEC84B), Color(0xFFFFB800)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFEC84B).withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                // Scale down on narrow cards / large text scale so the badge
                // never overflows the width-capped result card.
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '🎉',
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'New High Score!',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 280.ms, duration: 320.ms)
                  .scale(
                    begin: const Offset(0.6, 0.6),
                    end: const Offset(1.0, 1.0),
                    duration: 380.ms,
                    curve: Curves.easeOutBack,
                  ),
            ],
            // Extra badges (e.g. streak, new best for games that handle them separately)
            if (extraBadges.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...extraBadges.map((b) => b
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 320.ms)
                  .scale(
                    begin: const Offset(0.85, 0.85),
                    end: const Offset(1.0, 1.0),
                    duration: 320.ms,
                    curve: Curves.easeOutBack,
                  )),
            ],
            // Stats widget
            if (statsWidget != null) ...[
              const SizedBox(height: 22),
              statsWidget!.animate().fadeIn(delay: 320.ms, duration: 320.ms),
            ],
            const SizedBox(height: 24),
            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...List.generate(
                    actions.length,
                    (i) => [
                      _ActionButton(
                        label: actions[i].label,
                        icon: actions[i].icon,
                        onTap: () {
                          if (gameId != null && actions[i].actionId != null) {
                            AnalyticsService().resultAction(
                              gameId: gameId!,
                              action: actions[i].actionId!,
                            );
                          }
                          actions[i].onTap();
                        },
                        filled: actions[i].filled,
                        color: actions[i].color ?? badgeColor,
                      ),
                      if (i < actions.length - 1) const SizedBox(height: 10),
                    ],
                  ).expand((e) => e),
                  if (gameId != null) ...[
                    const SizedBox(height: 16),
                    _ActionButton(
                      label: '📤 Share Score',
                      icon: Icons.share_rounded,
                      onTap: () {
                        AnalyticsService().resultAction(
                          gameId: gameId!,
                          action: 'share_score',
                        );
                        final gameName =
                            GameRegistry.getById(gameId!)?.name ?? gameId!;
                        ShareService().shareScore(
                          context: context,
                          gameName: gameName,
                          score: score ?? 0,
                          stars: stars ?? 0,
                          emoji: badgeContent,
                        );
                      },
                      filled: true,
                      color: badgeColor,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class GameResultStatsRow extends StatelessWidget {
  final List<StatItem> stats;

  const GameResultStatsRow({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();

    final children = <Widget>[];
    for (int i = 0; i < stats.length; i++) {
      children.add(
        _StatColumn(
          label: stats[i].label,
          value: stats[i].value,
          displayValue: stats[i].displayValue,
          color: stats[i].color,
        ),
      );
      if (i < stats.length - 1) {
        children.add(
          _StatDivider(),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8475C2).withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      // The result card has a capped width; 4 stats with wide values (or
      // large text scale) would otherwise overflow this Row even on tablets.
      // Scale the stats down to fit instead of overflowing.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final int value;
  final String? displayValue;
  final Color color;

  const _StatColumn({
    required this.label,
    required this.value,
    this.displayValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          displayValue ?? '$value',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: context.fontSize(24, max: 30),
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: 1,
        height: 48,
        color: Colors.black.withValues(alpha: 0.1),
      ),
    );
  }
}

class GameResultPlayersRow extends StatelessWidget {
  final String p1Label;
  final String p2Label;
  final int p1Score;
  final int p2Score;
  final Color p1Color;
  final Color p2Color;
  final bool p1IsWinner;
  final bool p2IsWinner;
  final String scoreUnit;

  const GameResultPlayersRow({
    super.key,
    required this.p1Label,
    required this.p2Label,
    required this.p1Score,
    required this.p2Score,
    required this.p1Color,
    required this.p2Color,
    required this.p1IsWinner,
    required this.p2IsWinner,
    this.scoreUnit = 'pairs',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8475C2).withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PlayerColumn(
                label: p1Label,
                score: p1Score,
                color: p1Color,
                isWinner: p1IsWinner,
                scoreUnit: scoreUnit,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(width: 1, height: 60, color: Colors.black.withValues(alpha: 0.1)),
              ),
              _PlayerColumn(
                label: p2Label,
                score: p2Score,
                color: p2Color,
                isWinner: p2IsWinner,
                scoreUnit: scoreUnit,
              ),
            ],
          ),
        );
  }
}

class _PlayerColumn extends StatelessWidget {
  final String label;
  final int score;
  final Color color;
  final bool isWinner;
  final String scoreUnit;

  const _PlayerColumn({
    required this.label,
    required this.score,
    required this.color,
    required this.isWinner,
    required this.scoreUnit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isWinner) ...[
          const Text('🏆', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 2),
        ] else
          const SizedBox(height: 18),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$score',
          style: TextStyle(
            color: color,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        Text(
          scoreUnit,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: color.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  final Color color;

  const _ActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    required this.filled,
    required this.color,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: widget.filled ? widget.color : Colors.transparent,
            border: widget.filled ? null : Border.all(
              color: widget.color.withValues(alpha: 0.35),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          // Long labels (e.g. "Change Difficulty") at large text scale would
          // overflow a narrow full-width button. Scale the icon+label down to
          // fit rather than overflow; keeps the full label centered.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.icon,
                  size: 20,
                  color: widget.filled ? Colors.white : widget.color,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: widget.filled ? Colors.white : widget.color,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

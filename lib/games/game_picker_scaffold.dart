import 'package:flutter/material.dart';
import '../core/services/score_service.dart';
import '../core/utils/responsive.dart';

/// A reusable scaffold for game entry/picker screens.
/// Both TicTacToe and 2048 use it for consistent layout and styling.
class GamePickerScaffold extends StatefulWidget {
  final Color bgColorTop;
  final Color bgColorBottom;
  /// Optional fully-formed background widget (typically [AnimatedBackground]).
  /// Painted behind the foreground content via [IgnorePointer]. Use this
  /// instead of a static painter so the bg can animate.
  final Widget? animatedBg;

  // Icon area
  final List<Color> iconRingColors; // 3 colors for SweepGradient
  final Widget iconChild; // widget shown inside the ring circle

  // Title area
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Color? subtitleColor;

  // Nav
  final VoidCallback onBack;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  // Body
  final Widget body;

  /// Opens the "How to play" sheet. Renders as a `?` icon in the top-right
  /// of the header (the universally-recognized re-entry point in 2025
  /// casual games — Wordle, Block Blast, NYT puzzles, Sudoku.com).
  /// If null, the icon is hidden.
  final VoidCallback? onHowToPlay;

  /// Game ID for first-visit tutorial auto-trigger.
  /// When set and the user has never seen this game's tutorial,
  /// [onHowToPlay] fires automatically after the first frame.
  final String? gameId;

  // Layout threshold
  final double tallThreshold;

  const GamePickerScaffold({
    super.key,
    required this.bgColorTop,
    required this.bgColorBottom,
    this.animatedBg,
    required this.iconRingColors,
    required this.iconChild,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.subtitleColor,
    required this.onBack,
    required this.isFavorite,
    required this.onFavoriteToggle,
    required this.body,
    this.onHowToPlay,
    this.gameId,
    this.tallThreshold = 800,
  });

  @override
  State<GamePickerScaffold> createState() => _GamePickerScaffoldState();
}

class _GamePickerScaffoldState extends State<GamePickerScaffold> {
  @override
  void initState() {
    super.initState();
    _maybeShowTutorial();
  }

  void _maybeShowTutorial() {
    final id = widget.gameId;
    final callback = widget.onHowToPlay;
    if (id == null || callback == null) return;
    if (ScoreService().hasTutorialSeen(id)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScoreService().setTutorialSeen(id);
      callback();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [widget.bgColorTop, widget.bgColorBottom],
          ),
        ),
        child: Stack(
          children: [
            if (widget.animatedBg != null)
              Positioned.fill(child: widget.animatedBg!),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isTall = constraints.maxHeight >= widget.tallThreshold;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(context),
                      Expanded(
                        child: isTall
                            ? _buildTallBody(context)
                            : _buildScrollBody(context),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final ringColor = widget.iconRingColors.isNotEmpty ? widget.iconRingColors[0] : Colors.grey;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _GameNavButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: widget.onBack,
            ringColor: ringColor,
          ),
          const Spacer(),
          if (widget.onHowToPlay != null) ...[
            _GameNavButton(
              icon: Icons.help_outline_rounded,
              onTap: widget.onHowToPlay!,
              ringColor: ringColor,
            ),
            const SizedBox(width: 10),
          ],
          _GameNavButton(
            icon: widget.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            onTap: widget.onFavoriteToggle,
            ringColor: ringColor,
            iconColor: widget.isFavorite ? const Color(0xFFE85D75) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildMascot(BuildContext context) {
    final size = context.isCompactWidth ? 92.0 : 110.0;
    return _GamePickerIcon(
      ringColors: widget.iconRingColors,
      size: size,
      child: widget.iconChild,
    );
  }

  Widget _buildTitleArea(BuildContext context) {
    final textColor = widget.titleColor ?? const Color(0xFF1C1B1F);
    final mutedColor = widget.subtitleColor ?? const Color(0xFF9E9E9E);
    return Column(
      children: [
        _buildMascot(context),
        const SizedBox(height: 16),
        Text(
          widget.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: context.fontSize(28, max: 34),
            fontWeight: FontWeight.w900,
            color: textColor,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: context.fontSize(13, max: 16),
              fontWeight: FontWeight.w500,
              color: mutedColor,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildTallBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(flex: 2),
          _buildTitleArea(context),
          const Spacer(flex: 3),
          widget.body,
        ],
      ),
    );
  }

  Widget _buildScrollBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTitleArea(context),
          const SizedBox(height: 22),
          widget.body,
        ],
      ),
    );
  }
}

// ── Nav button: white, 44x44, 14px radius, subtle shadow ────────────────────

class _GameNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color ringColor;
  final Color? iconColor;

  const _GameNavButton({
    required this.icon,
    required this.onTap,
    required this.ringColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: ringColor.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 20,
          color: iconColor ?? const Color(0xFF1C1B1F),
        ),
      ),
    );
  }
}

// ── Icon ring: SweepGradient ring + white inner + content ───────────────────

class _GamePickerIcon extends StatelessWidget {
  final List<Color> ringColors;
  final Widget child;
  final double size;

  const _GamePickerIcon({
    required this.ringColors,
    required this.child,
    this.size = 110,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ringColors.length >= 3
        ? ringColors
        : [...ringColors, ringColors.first];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: SweepGradient(
          colors: colors,
          stops: const [0.0, 0.5, 1.0],
        ),
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(4),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(10),
        child: child,
      ),
    );
  }
}

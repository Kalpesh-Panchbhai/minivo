import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/best_stats_registry.dart';
import '../../core/services/score_service.dart';
import '../../core/widgets/how_to_play_sheet.dart';
import '../game_picker_scaffold.dart';
import '../game_registry.dart';
import 'animated_background.dart';
import 'game_detail_widgets.dart';

/// Generic detail/picker screen for games that don't have a mode selector.
///
/// Renders [GamePickerScaffold] with:
/// - About card
/// - Best stats card (per the BestStatsRegistry)
/// - Similar games row
/// - Play Now button → routes to /play/<gameId>
///
/// The decorative background is pulled from [bgPainterFactory]; if omitted,
/// the screen falls back to a solid gradient.
class SingleModeGameScreen extends StatefulWidget {
  final String gameId;

  /// Optional animated-bg painter factory (e.g. each game can pass its own
  /// themed painter). Falls back to no painter if null.
  final AnimatedBgPainter Function(double t)? bgPainterFactory;

  /// Two ring-gradient colors (mid stop is auto-derived). Falls back to game
  /// accent + lighter shade.
  final List<Color>? iconRingColors;

  const SingleModeGameScreen({
    super.key,
    required this.gameId,
    this.bgPainterFactory,
    this.iconRingColors,
  });

  @override
  State<SingleModeGameScreen> createState() => _SingleModeGameScreenState();
}

class _SingleModeGameScreenState extends State<SingleModeGameScreen> {
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(widget.gameId);
  }

  void _toggleFavorite() {
    ScoreService().toggleFavorite(widget.gameId);
    setState(() => _isFavorite = !_isFavorite);
  }

  void _showHelp(String name, String howToPlay, Color accent) {
    showHowToPlaySheet(
      context,
      title: name,
      howToPlay: howToPlay,
      accent: accent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = GameRegistry.getById(widget.gameId);
    if (game == null) {
      return const Scaffold(body: Center(child: Text('Game not found')));
    }

    final accent = game.color;
    final bgTop = game.bgColor;
    final bgBot = Color.lerp(game.bgColor, Colors.white, 0.5)!;
    final ringColors = widget.iconRingColors ??
        [accent, Color.lerp(accent, Colors.white, 0.4)!, accent];

    final similar = GameRegistry.getByCategory(game.category)
        .where((g) => g.id != game.id)
        .toList();

    // Default bg: animated, themed by the game's accent and primary icon.
    final bgFactory = widget.bgPainterFactory ??
        ((t) => GenericAnimatedBgPainter(
              t,
              accent: accent,
              icon: game.icon,
            ));

    return GamePickerScaffold(
      bgColorTop: bgTop,
      bgColorBottom: bgBot,
      animatedBg: AnimatedBackground(
        factory: bgFactory,
        period: const Duration(seconds: 10),
      ),
      iconRingColors: ringColors,
      iconChild: Container(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: game.hasBrandedLogo
            ? ClipOval(child: game.buildBrandedLogo(size: 84))
            : Icon(game.icon, size: 38, color: accent),
      ),
      title: game.name,
      subtitle: _firstSentence(game.description),
      onBack: () => context.pop(),
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: () => _showHelp(game.name, game.howToPlay, accent),
      tallThreshold: 760,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (BestStatsRegistry.statsFor(widget.gameId).isNotEmpty) ...[
            BestStatsCard(gameId: widget.gameId, accent: accent),
            const SizedBox(height: 12),
          ],
          AboutCard(description: game.description, accent: accent),
          const SizedBox(height: 12),
          PlayNowButton(
            label: 'Play Now',
            gradientColors: [
              accent,
              Color.lerp(accent, Colors.white, 0.22)!,
            ],
            onTap: () => context.push('/play/${game.id}'),
          ),
          if (similar.isNotEmpty) ...[
            const SizedBox(height: 18),
            SimilarGamesRow(
              games: similar,
              onTap: (g) => context.push('/game/${g.id}'),
            ),
          ],
        ],
      ),
    );
  }

  /// Picker subtitle stays short — pull just the first sentence/clause of the
  /// game's description so the hero section doesn't sprawl.
  String _firstSentence(String text) {
    final dot = text.indexOf('. ');
    if (dot == -1) return text;
    return text.substring(0, dot + 1);
  }
}

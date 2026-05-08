import 'package:flutter/material.dart';

import '../framework/game_definition.dart';
import '../framework/game_session.dart';
import '../shared/generic_game_result_screen.dart' as game_result;
import '../../core/models/game_info.dart';
import 'color_tap_logo.dart';
import 'color_tap_screen.dart';
import 'color_tap_tutorial.dart';

final colorTapGame = GameDefinition(
  info: const GameInfo(
    id: 'color_tap',
    name: 'Color Tap',
    description:
        'Match the color circle to the target. Tap fast, skip smart — 3 lives!',
    howToPlay:
        'Choose your difficulty (Easy, Medium, Hard) — more colors and faster rounds at higher levels.\n'
        'A large colored circle appears in the center. The "TARGET" color is shown at the top.\n'
        'TAP the circle if its color matches the target to score points.\n'
        'Tap the SKIP button if the colors do NOT match to safely advance.\n'
        'Wrong action (tap a non-match, or skip a match, or let the timer run out) costs one life.\n'
        'You have 3 lives — game ends when all lives are lost.',
    category: GameCategory.arcade,
    icon: Icons.circle_rounded,
    color: Color(0xFFFF6B35),
    bgColor: Color(0xFFFFDEC0),
    playCount: 7600,
    customLogo: buildColorTapLogo,
  ),
  difficulties: const [
    DifficultyDef(
      key: 'easy',
      label: 'EASY',
      kind: DifficultyKind.easy,
      color: Color(0xFF22C55E),
      hint: '3 colors • slow timer • 10 pts/match',
      scoreLabel: _pts,
      statSublabel: '10 pts/match',
    ),
    DifficultyDef(
      key: 'medium',
      label: 'MEDIUM',
      kind: DifficultyKind.medium,
      color: Color(0xFFF59E0B),
      hint: '5 colors • medium timer • 15 pts/match',
      scoreLabel: _pts,
      statSublabel: '15 pts/match',
    ),
    DifficultyDef(
      key: 'hard',
      label: 'HARD',
      kind: DifficultyKind.hard,
      color: Color(0xFFEF4444),
      hint: '7 colors • fast timer • 20 pts/match',
      scoreLabel: _pts,
      statSublabel: '20 pts/match',
    ),
  ],
  playerSupport: PlayerSupport.soloOnly,
  screenBuilder: () => const ColorTapScreen(),
  logoBuilder: buildColorTapLogo,
  tutorialSteps: colorTapSteps,
  boardBuilder: _buildColorTapBoard,
  bgPainterBuilder: _buildColorTapBg,
  resultStatsBuilder: _buildColorTapResultStats,
);

Widget _buildColorTapBoard(GameSession session) =>
    ColorTapBoard(session: session);

ColorTapBgPainter _buildColorTapBg(double t) => ColorTapBgPainter(t);

Widget _buildColorTapResultStats(GameSession session, DifficultyDef diff) =>
    game_result.GameResultStatsRow(
      stats: [
        game_result.StatItem(
          label: 'SCORE',
          value: session.currentScore,
          color: diff.color,
        ),
        game_result.StatItem(
          label: 'BEST',
          value: session.bestScore,
          color: const Color(0xFF8B7BA7),
        ),
        game_result.StatItem(
          label: 'MISTAKES',
          value: session.mistakes,
          color: const Color(0xFFEF4444),
        ),
      ],
    );

String _pts(int s) => '$s pts';

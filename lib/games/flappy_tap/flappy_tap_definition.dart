import 'package:flutter/material.dart';

import '../framework/game_definition.dart';
import '../framework/game_session.dart';
import '../shared/generic_game_result_screen.dart' as game_result;
import '../../core/models/game_info.dart';
import 'flappy_tap_logo.dart';
import 'flappy_tap_screen.dart';
import 'flappy_tap_tutorial.dart';

final flappyTapGame = GameDefinition(
  info: const GameInfo(
    id: 'flappy_tap',
    name: 'Flappy Tap',
    description:
        'Tap to fly through the gaps. How far can you go? Simple yet addictive!',
    howToPlay:
        'Choose your difficulty (Easy, Medium, Hard) — pipe speed and gap size scale with the level.\n'
        'Tap anywhere on the screen to make the bird flap upward.\n'
        'Gravity pulls the bird down continuously — tap rhythmically to stay in the air.\n'
        'Fly through the gaps between the green pipes to score points (5/10/20 pts per pipe on Easy/Medium/Hard).\n'
        'The game ends if the bird hits a pipe or the ground.\n'
        'Stay calm and find your rhythm — panic-tapping makes you overshoot!',
    category: GameCategory.action,
    icon: Icons.air_rounded,
    color: Color(0xFF4ECDC4),
    bgColor: Color(0xFFE8FAF8),
    playCount: 12500,
    isFeatured: true,
    customLogo: buildFlappyTapLogo,
  ),
  difficulties: const [
    DifficultyDef(
      key: 'easy',
      label: 'EASY',
      kind: DifficultyKind.easy,
      color: Color(0xFF22C55E),
      hint: 'Slow pipes • wide gaps • 5 pts/pipe',
      scoreLabel: _pts,
      statSublabel: '5 pts/pipe',
    ),
    DifficultyDef(
      key: 'medium',
      label: 'MEDIUM',
      kind: DifficultyKind.medium,
      color: Color(0xFFF59E0B),
      hint: 'Normal speed • 10 pts/pipe',
      scoreLabel: _pts,
      statSublabel: '10 pts/pipe',
    ),
    DifficultyDef(
      key: 'hard',
      label: 'HARD',
      kind: DifficultyKind.hard,
      color: Color(0xFFEF4444),
      hint: 'Fast pipes • narrow gaps • 20 pts/pipe',
      scoreLabel: _pts,
      statSublabel: '20 pts/pipe',
    ),
  ],
  playerSupport: PlayerSupport.soloOnly,
  screenBuilder: () => const FlappyTapScreen(),
  logoBuilder: buildFlappyTapLogo,
  tutorialSteps: flappyTapSteps,
  boardBuilder: _buildFlappyTapBoard,
  bgPainterBuilder: _buildFlappyTapBg,
  resultStatsBuilder: _buildFlappyTapResultStats,
);

Widget _buildFlappyTapBoard(GameSession session) =>
    FlappyTapBoard(session: session);

FlappyTapBgPainter _buildFlappyTapBg(double t) => FlappyTapBgPainter(t);

Widget _buildFlappyTapResultStats(GameSession session, DifficultyDef diff) {
  final pointsPerPipe = switch (diff.key) {
    'easy' => 5,
    'medium' => 10,
    'hard' => 20,
    _ => 10,
  };
  return game_result.GameResultStatsRow(
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
        label: 'PIPES',
        value: session.currentScore ~/ pointsPerPipe,
        color: const Color(0xFF2AA39A),
      ),
    ],
  );
}

String _pts(int s) => '$s pts';

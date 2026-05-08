import 'package:flutter/material.dart';

import '../framework/game_definition.dart';
import '../framework/game_session.dart';
import '../../core/models/game_info.dart';
import 'snake_classic_logo.dart';
import 'snake_classic_screen.dart';
import 'snake_classic_tutorial.dart';

final snakeClassicGame = GameDefinition(
  info: const GameInfo(
    id: 'snake_classic',
    name: 'Snake Classic',
    description:
        'Guide the snake to eat apples and grow longer. How long can you survive?',
    howToPlay:
        'Choose your difficulty (Easy, Medium, Hard) — speed and points scale with the level.\n'
        'Swipe up, down, left, or right to steer the snake. The snake moves on its own; you only choose direction.\n'
        'You can\'t reverse 180° — pivot through a perpendicular turn first.\n'
        'Eat the red apple to grow longer and score 5/10/20 points (Easy/Medium/Hard).\n'
        'The game ends if the snake hits a wall or runs into its own body.\n'
        'Plan your turns — fast modes punish hesitation!',
    category: GameCategory.action,
    icon: Icons.pest_control_rounded,
    color: Color(0xFF20C997),
    bgColor: Color(0xFFE6FCF5),
    playCount: 11000,
    isFeatured: true,
    customLogo: buildSnakeLogo,
  ),
  difficulties: const [
    DifficultyDef(
      key: 'easy',
      label: 'EASY',
      kind: DifficultyKind.easy,
      color: Color(0xFF22C55E),
      hint: 'Relaxed pace • 5 pts/apple',
      scoreLabel: _pts,
      statSublabel: '5 pts/apple',
    ),
    DifficultyDef(
      key: 'medium',
      label: 'MEDIUM',
      kind: DifficultyKind.medium,
      color: Color(0xFFF59E0B),
      hint: 'Balanced speed • 10 pts/apple',
      scoreLabel: _pts,
      statSublabel: '10 pts/apple',
    ),
    DifficultyDef(
      key: 'hard',
      label: 'HARD',
      kind: DifficultyKind.hard,
      color: Color(0xFFEF4444),
      hint: 'Fast & furious • 20 pts/apple',
      scoreLabel: _pts,
      statSublabel: '20 pts/apple',
    ),
  ],
  playerSupport: PlayerSupport.soloOnly,
  screenBuilder: () => const SnakeClassicScreen(),
  logoBuilder: buildSnakeLogo,
  tutorialSteps: snakeClassicSteps,
  boardBuilder: _buildSnakeBoard,
  scoreDisplay: _scoreDisplay,
  bgPainterBuilder: _buildSnakeBg,
);

Widget _buildSnakeBoard(GameSession session) =>
    SnakeClassicBoard(session: session);

SnakeBgPainter _buildSnakeBg(double t) => SnakeBgPainter(t);

final ScoreDisplay _scoreDisplay = ScoreDisplay.scoreAndBest();

String _pts(int s) => '$s pts';

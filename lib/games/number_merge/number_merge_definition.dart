import 'package:flutter/material.dart';

import '../framework/game_definition.dart';
import '../../core/models/game_info.dart';
import 'number_merge_logo.dart';
import 'number_merge_screen.dart';
import 'number_merge_tutorial.dart';

final numberMergeGame = GameDefinition(
  info: const GameInfo(
    id: 'number_merge',
    name: '2048 Merge',
    description: 'Slide tiles and merge numbers. Can you reach 2048?',
    howToPlay:
        'Swipe left, right, up, or down to slide all tiles on the board.\n'
        'When two tiles with the same number collide, they merge into one tile worth double the value.\n'
        'Every swipe spawns a new tile (usually a 2, occasionally a 4).\n'
        'Reach the target tile for your chosen difficulty — 1024 on Easy, 2048 on Medium, 4096 on Hard.\n'
        'The game ends when the board is full and no moves remain.\n'
        'Plan your moves — avoid cornering your highest tile!',
    category: GameCategory.puzzle,
    icon: Icons.calculate_rounded,
    color: Color(0xFFFF6B6B),
    bgColor: Color(0xFFFFF0F0),
    playCount: 18200,
    isFeatured: true,
    customLogo: build2048Logo,
  ),
  difficulties: const [
    DifficultyDef(
      key: 'easy',
      label: 'EASY',
      kind: DifficultyKind.easy,
      color: Color(0xFF22C55E),
      hint: 'Target 1024 • relaxed',
      scoreLabel: _pts,
      statSublabel: 'target 1024',
      statIcon: Icons.grid_4x4_rounded,
    ),
    DifficultyDef(
      key: 'medium',
      label: 'MEDIUM',
      kind: DifficultyKind.medium,
      color: Color(0xFFF59E0B),
      hint: 'Target 2048 • balanced',
      scoreLabel: _pts,
      statSublabel: 'target 2048',
      statIcon: Icons.grid_4x4_rounded,
    ),
    DifficultyDef(
      key: 'hard',
      label: 'HARD',
      kind: DifficultyKind.hard,
      color: Color(0xFFEF4444),
      hint: 'Target 4096 • challenge',
      scoreLabel: _pts,
      statSublabel: 'target 4096',
      statIcon: Icons.grid_4x4_rounded,
    ),
  ],
  playerSupport: PlayerSupport.soloOnly,
  screenBuilder: () => const NumberMergeScreen(),
  logoBuilder: build2048Logo,
  tutorialSteps: numberMergeSteps,
);

String _pts(int s) => '$s pts';

import 'package:flutter/material.dart';

import '../framework/game_definition.dart';
import '../../core/models/game_info.dart';
import 'memory_match_logo.dart';
import 'memory_match_screen.dart';
import 'memory_match_tutorial.dart';

final memoryMatchGame = GameDefinition(
  info: const GameInfo(
    id: 'memory_match',
    name: 'Memory Match',
    description: 'Flip cards and find matching emoji pairs. Train your memory!',
    howToPlay:
        'Choose your difficulty (Easy = 4×3, Medium = 4×4, Hard = 6×4).\n'
        'All cards start face-down. Tap any card to flip it over and reveal the emoji.\n'
        'Tap a second card — if the emojis match, both cards stay face-up and you score points.\n'
        'If they don\'t match, both cards flip back face-down after a short delay.\n'
        'First-attempt matches score +20 pts; later matches score +10 pts.\n'
        'Match all pairs to win a +50 completion bonus!\n'
        'Remember the positions — the fewer wrong flips, the higher your score.',
    category: GameCategory.puzzle,
    icon: Icons.flip_rounded,
    color: Color(0xFF339AF0),
    bgColor: Color(0xFFD0E8FF),
    playCount: 5400,
    customLogo: buildMemoryMatchLogo,
  ),
  difficulties: const [
    DifficultyDef(
      key: 'easy',
      label: 'EASY',
      kind: DifficultyKind.easy,
      color: Color(0xFF22C55E),
      hint: '4×3 grid • 6 pairs',
      scoreLabel: _pts,
      statSublabel: '4×3 grid',
    ),
    DifficultyDef(
      key: 'medium',
      label: 'MEDIUM',
      kind: DifficultyKind.medium,
      color: Color(0xFFF59E0B),
      hint: '4×4 grid • 8 pairs',
      scoreLabel: _pts,
      statSublabel: '4×4 grid',
    ),
    DifficultyDef(
      key: 'hard',
      label: 'HARD',
      kind: DifficultyKind.hard,
      color: Color(0xFFEF4444),
      hint: '6×4 grid • 12 pairs',
      scoreLabel: _pts,
      statSublabel: '6×4 grid',
    ),
  ],
  playerSupport: PlayerSupport.soloOnly,
  screenBuilder: () => const MemoryMatchScreen(),
  logoBuilder: buildMemoryMatchLogo,
  tutorialSteps: memoryMatchSteps,
);

String _pts(int s) => '$s pts';

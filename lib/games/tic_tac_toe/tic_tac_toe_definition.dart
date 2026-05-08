import 'package:flutter/material.dart';

import '../../core/models/best_stat.dart';
import '../../core/services/score_service.dart';
import '../framework/game_definition.dart';
import '../../core/models/game_info.dart';
import 'tic_tac_toe_logo.dart';
import 'tic_tac_toe_screen.dart';
import 'tic_tac_toe_tutorial.dart';

const String _kGameId = 'tic_tac_toe';

const Color _kEasyColor = Color(0xFF4CB97A);
const Color _kMediumColor = Color(0xFFEFA63A);
const Color _kHardColor = Color(0xFFE8533D);

int _bestStreak(String subKey) =>
    ScoreService().getHighScore(_kGameId, subKey: subKey);

BestStat _row(String emoji, String label, int streak, Color color) => BestStat(
      label: '$emoji  $label',
      value: streak == 0 ? '—' : '$streak',
      sublabel: streak == 0 ? 'no wins yet' : 'win streak',
      icon: Icons.local_fire_department_rounded,
      color: color,
    );

List<BestStat> _buildTicTacToeStats() {
  final easy = _bestStreak('ai_easy');
  final medium = _bestStreak('ai_medium');
  final hard = _bestStreak('ai_hard');

  if (easy == 0 && medium == 0 && hard == 0) return const [];

  return [
    _row('🌱', 'EASY', easy, _kEasyColor),
    _row('🔥', 'MEDIUM', medium, _kMediumColor),
    _row('💀', 'HARD', hard, _kHardColor),
  ];
}

final ticTacToeGame = GameDefinition(
  info: const GameInfo(
    id: _kGameId,
    name: 'Tic Tac Toe',
    description: 'Classic X and O. Play against the computer!',
    howToPlay:
        'Choose your difficulty (Easy, Medium, Hard) or play with a friend on the same device.\n'
        'Players take turns — X always goes first in any given round.\n'
        'Tap an empty cell on the 3x3 grid to place your mark there.\n'
        'Get three of your marks in a row, column, or diagonal to win the round.\n'
        'Win two rounds in a row to start a Streak — keep it going for bragging rights!\n'
        'After each round the starter alternates, so you both get a fair go.',
    category: GameCategory.board,
    icon: Icons.close_rounded,
    color: Color(0xFFBE4BDB),
    bgColor: Color(0xFFF8F0FC),
    playCount: 8900,
    customLogo: buildTicTacToeLogo,
  ),
  // No standard difficulty picker for tic-tac-toe —
  // mode selection (vs AI / pass-and-play) is handled in-screen.
  difficulties: const [],
  playerSupport: PlayerSupport(
    modes: [PlayerMode.vsAI, PlayerMode.localCoop],
    playerCounts: [2],
  ),
  screenBuilder: () => const TicTacToeScreen(),
  logoBuilder: buildTicTacToeLogo,
  tutorialSteps: ticTacToeSteps,
  statsBuilder: _buildTicTacToeStats,
);

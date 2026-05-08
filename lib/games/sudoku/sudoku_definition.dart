import 'package:flutter/material.dart';

import '../framework/game_definition.dart';
import '../framework/game_session.dart';
import '../shared/generic_game_result_screen.dart' as game_result;
import '../../core/models/game_info.dart';
import 'sudoku_logo.dart';
import 'sudoku_screen.dart';
import 'sudoku_tutorial.dart';

// Score is stored as (kSudokuMaxScore - seconds) so higher stored = faster time.
const int _kSudokuMaxScore = 100000;

String _formatTime(int score) {
  final secs = _kSudokuMaxScore - score;
  final m = secs ~/ 60;
  final s = (secs % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

final sudokuGame = GameDefinition(
  info: const GameInfo(
    id: 'sudoku',
    name: 'Sudoku',
    description:
        'Fill the 9×9 grid — every row, column and box must contain 1–9.',
    howToPlay:
        'Choose Easy (46 givens), Medium (36 givens), or Hard (28 givens).\n'
        'Tap a cell to select it, then tap a number on the keypad to fill it in.\n'
        'Every row, column, and 3×3 box must contain each digit from 1 to 9 exactly once.\n'
        'Tapping a number that conflicts with the rules counts as an error.\n'
        'Your score is based on completion time — faster is better!\n'
        'Tap the eraser to clear a cell.',
    category: GameCategory.puzzle,
    icon: Icons.grid_on_rounded,
    color: Color(0xFF6366F1),
    bgColor: Color(0xFFEEF2FF),
    playCount: 0,
    isFeatured: false,
    customLogo: buildSudokuLogo,
  ),
  difficulties: [
    DifficultyDef(
      key: 'easy',
      label: 'EASY',
      kind: DifficultyKind.easy,
      color: const Color(0xFF22C55E),
      hint: '46 givens • relaxed solve',
      maxScore: _kSudokuMaxScore,
      scoreLabel: _formatTime,
      statSublabel: 'fastest solve • relaxed',
      statIcon: Icons.timer_rounded,
    ),
    DifficultyDef(
      key: 'medium',
      label: 'MEDIUM',
      kind: DifficultyKind.medium,
      color: const Color(0xFFF59E0B),
      hint: '36 givens • balanced',
      maxScore: _kSudokuMaxScore,
      scoreLabel: _formatTime,
      statSublabel: 'fastest solve • balanced',
      statIcon: Icons.timer_rounded,
    ),
    DifficultyDef(
      key: 'hard',
      label: 'HARD',
      kind: DifficultyKind.hard,
      color: const Color(0xFFEF4444),
      hint: '28 givens • expert challenge',
      maxScore: _kSudokuMaxScore,
      scoreLabel: _formatTime,
      statSublabel: 'fastest solve • expert',
      statIcon: Icons.timer_rounded,
    ),
  ],
  playerSupport: PlayerSupport.soloOnly,
  screenBuilder: () => const SudokuScreen(),
  logoBuilder: buildSudokuLogo,
  tutorialSteps: sudokuSteps,
  boardBuilder: _buildSudokuBoard,
  scoreDisplay: _scoreDisplay,
  bgPainterBuilder: _buildSudokuBg,
  resultStatsBuilder: _buildSudokuResultStats,
);

Widget _buildSudokuBoard(GameSession session) =>
    SudokuBoard(session: session);

SudokuBgPainter _buildSudokuBg(double t) => SudokuBgPainter(t);

final ScoreDisplay _scoreDisplay =
    ScoreDisplay.timeAndMistakes(maxScore: _kSudokuMaxScore);

Widget _buildSudokuResultStats(GameSession session, DifficultyDef diff) =>
    game_result.GameResultStatsRow(
      stats: [
        game_result.StatItem(
          label: 'TIME',
          value: session.elapsedTime.inSeconds,
          color: diff.color,
        ),
        game_result.StatItem(
          label: 'MISTAKES',
          value: session.mistakes,
          color: const Color(0xFFEF4444),
        ),
      ],
    );

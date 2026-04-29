import 'package:flutter/material.dart';

/// A single row in a game's "best" stats panel.
///
/// Designed to be flexible enough for both score-based games (one row with
/// the high score) and record-based games like Tic Tac Toe (one row per
/// difficulty showing wins / losses / draws).
class BestStat {
  /// Short eyebrow / category label, e.g. "BEST", "EASY", "MEDIUM".
  final String label;

  /// Primary value, e.g. "247" or "3W".
  final String value;

  /// Optional secondary value rendered next to [value], e.g. "1L · 0D".
  final String? sublabel;

  /// Optional icon shown on the leading side of the row.
  final IconData? icon;

  /// Optional accent colour. Falls back to the game's accent if null.
  final Color? color;

  const BestStat({
    required this.label,
    required this.value,
    this.sublabel,
    this.icon,
    this.color,
  });
}

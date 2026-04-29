import 'package:flutter/material.dart';

/// Standard in-game HUD bar.
///
/// Three slots, left → right:
///   1. Leading slot — typically a back button. Pass `null` for a 48-px
///      spacer so [centerContent] stays optically centered.
///   2. Centered content — usually the game's score pill.
///   3. Trailing slot — typically a restart button. Pass `null` for a 48-px
///      spacer so [centerContent] stays optically centered.
///
/// Used by every game's playing-state UI so the menu surface
/// (button shapes, paddings, action behaviour) stays consistent across
/// the app. Layout matches the original Tic Tac Toe header.
class GameHudBar extends StatelessWidget {
  /// Leading widget (left side). When `null` we render a 48-px spacer
  /// so [centerContent] stays optically centred.
  final Widget? leading;

  /// Score pill / status indicator that sits in the middle.
  final Widget centerContent;

  /// Trailing widget (right side). When `null` we render a 48-px spacer
  /// so [centerContent] stays optically centred.
  final Widget? trailing;

  /// Padding around the bar. Defaults match the existing 2048/Tic Tac Toe
  /// horizontal inset.
  final EdgeInsetsGeometry padding;

  const GameHudBar({
    super.key,
    this.leading,
    required this.centerContent,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 0),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading ?? const SizedBox(width: 48),
          Expanded(child: Center(child: centerContent)),
          trailing ?? const SizedBox(width: 48),
        ],
      ),
    );
  }
}

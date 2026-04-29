import 'package:flutter/material.dart';

import 'restart_dialog.dart';

/// Reusable back button for game HUD — exits the game and returns to picker/home.
/// Styled consistently across all games with white background and press animation.
class GameBackButton extends StatefulWidget {
  final VoidCallback onTap;
  final Color bgColor;
  final Color iconColor;

  const GameBackButton({
    super.key,
    required this.onTap,
    this.bgColor = Colors.white,
    this.iconColor = const Color(0xFF1B3A2A),
  });

  @override
  State<GameBackButton> createState() => _GameBackButtonState();
}

class _GameBackButtonState extends State<GameBackButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: widget.bgColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(Icons.arrow_back_ios_new_rounded, size: 22, color: widget.iconColor),
        ),
      ),
    );
  }
}

/// Reusable restart button for game HUD — shows confirmation dialog before restarting.
/// Styled consistently across all games with white background and press animation.
///
/// Pass [onDialogOpened] / [onDialogDismissed] to freeze / thaw game-specific
/// timers (e.g. Snake's tick controller) without going through GameWrapper's
/// pause state, which would also show the pause overlay.
class GameRestartButton extends StatefulWidget {
  final String gameName;
  final Color accentColor;
  final VoidCallback onRestart;
  final Color bgColor;
  final Color iconColor;
  /// Called just before the restart dialog is shown — use to stop game timers.
  final VoidCallback? onDialogOpened;
  /// Called when the dialog is dismissed without restarting — use to resume.
  final VoidCallback? onDialogDismissed;

  const GameRestartButton({
    super.key,
    required this.gameName,
    required this.accentColor,
    required this.onRestart,
    this.bgColor = Colors.white,
    this.iconColor = const Color(0xFF1B3A2A),
    this.onDialogOpened,
    this.onDialogDismissed,
  });

  @override
  State<GameRestartButton> createState() => _GameRestartButtonState();
}

class _GameRestartButtonState extends State<GameRestartButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) async {
        setState(() => _pressed = false);
        // Freeze game-specific timers before the dialog opens so the game
        // doesn't keep running behind it. We do NOT call wrapper.pauseGame()
        // here because that would also show the GameWrapper pause overlay.
        widget.onDialogOpened?.call();
        final confirmed = await showRestartDialog(
          context,
          gameName: widget.gameName,
          accentColor: widget.accentColor,
        );
        if (!mounted) return;
        if (confirmed) {
          widget.onRestart();
        } else {
          // User cancelled — resume the game-specific timers.
          widget.onDialogDismissed?.call();
        }
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: widget.bgColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(Icons.refresh_rounded, size: 22, color: widget.iconColor),
        ),
      ),
    );
  }
}

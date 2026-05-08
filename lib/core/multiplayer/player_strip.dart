import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PlayerStrip — reusable turn-indicator card for any 2-player game.
//
// Place two of these flanking the game board:
//   • Opponent strip at the TOP    (isActive: opponentTurn)
//   • Local player strip at BOTTOM (isActive: localTurn)
//
// Active  → solid color fill, white text, pulsing shadow  (unmissable)
// Inactive → ghost card at 28% opacity                    (clearly "not your turn")
//
// Example usage in a game screen:
//
//   Column(children: [
//     PlayerStrip(label: 'AI',  mark: 'O', color: kOColor,
//                 isActive: !isMyTurn, isThinking: aiThinking,
//                 avatarIcon: Icons.smart_toy_rounded),
//     Expanded(child: GameBoard(...)),
//     PlayerStrip(label: 'You', mark: 'X', color: kXColor,
//                 isActive: isMyTurn),
//   ])
// ─────────────────────────────────────────────────────────────────────────────

class PlayerStrip extends StatefulWidget {
  /// Display name shown on the strip (e.g. "You", "AI", "P1", "P2").
  final String label;

  /// Single-character mark drawn in the badge (e.g. "X", "O", "1").
  /// Ignored when [markIcon] is provided.
  final String mark;

  /// Optional icon to use instead of [mark] in the right-hand badge
  /// (e.g. `Icons.close_rounded` for X, `Icons.radio_button_unchecked_rounded` for O).
  final IconData? markIcon;

  /// Accent color driving the active fill, border, and shadow.
  final Color color;

  /// Whether it is currently this player's turn.
  final bool isActive;

  /// Shows a circular progress spinner orbiting the avatar — use when an AI
  /// or remote opponent is computing their move.
  final bool isThinking;

  /// Optional icon displayed inside the avatar circle instead of initials.
  /// Useful for AI opponents (e.g. `Icons.smart_toy_rounded`).
  final IconData? avatarIcon;

  const PlayerStrip({
    super.key,
    required this.label,
    required this.mark,
    required this.color,
    required this.isActive,
    this.markIcon,
    this.isThinking = false,
    this.avatarIcon,
  });

  @override
  State<PlayerStrip> createState() => _PlayerStripState();
}

class _PlayerStripState extends State<PlayerStrip>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _thinkCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _thinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _syncAnims();
  }

  @override
  void didUpdateWidget(PlayerStrip old) {
    super.didUpdateWidget(old);
    if (old.isActive != widget.isActive ||
        old.isThinking != widget.isThinking) {
      _syncAnims();
    }
  }

  void _syncAnims() {
    if (widget.isActive) {
      _pulseCtrl.repeat(reverse: true);
    } else {
      _pulseCtrl
        ..stop()
        ..reset();
    }
    if (widget.isThinking) {
      _thinkCtrl.repeat();
    } else {
      _thinkCtrl
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _thinkCtrl.dispose();
    super.dispose();
  }

  String get _statusLabel {
    if (widget.isThinking) return 'THINKING…';
    if (widget.isActive) return 'YOUR TURN';
    return 'WAITING';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
        duration: const Duration(milliseconds: 280),
        opacity: widget.isActive ? 1.0 : 0.28,
        child: AnimatedBuilder(
          animation: _pulseAnim,
          builder: (context, child) {
            final shadowBlur =
                widget.isActive ? 18.0 + _pulseAnim.value * 14.0 : 0.0;
            final shadowAlpha =
                widget.isActive ? 0.30 + _pulseAnim.value * 0.18 : 0.0;

            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: widget.isActive ? widget.color : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: widget.isActive
                      ? widget.color
                      : widget.color.withValues(alpha: 0.40),
                  width: 1.5,
                ),
                boxShadow: widget.isActive
                    ? [
                        BoxShadow(
                          color:
                              widget.color.withValues(alpha: shadowAlpha),
                          blurRadius: shadowBlur,
                          spreadRadius: 1,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : [],
              ),
              child: child,
            );
          },
          child: Row(
            children: [
              // Avatar circle
              PlayerStripAvatar(
                iconColor: widget.isActive ? Colors.white : widget.color,
                bgColor: widget.isActive
                    ? Colors.white.withValues(alpha: 0.25)
                    : widget.color.withValues(alpha: 0.15),
                activeColor: widget.color,
                mark: widget.mark,
                avatarIcon: widget.avatarIcon,
                isThinking: widget.isThinking,
                thinkCtrl: _thinkCtrl,
                size: 40,
              ),
              const SizedBox(width: 12),
              // Name + status label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color:
                            widget.isActive ? Colors.white : widget.color,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _statusLabel,
                        key: ValueKey(_statusLabel),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: widget.isActive
                              ? Colors.white.withValues(alpha: 0.80)
                              : widget.color.withValues(alpha: 0.60),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Mark badge (right side)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.isActive
                      ? Colors.white.withValues(alpha: 0.20)
                      : widget.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: widget.markIcon != null
                    ? Icon(
                        widget.markIcon,
                        size: 20,
                        color: widget.isActive
                            ? Colors.white
                            : widget.color.withValues(alpha: 0.70),
                      )
                    : Text(
                        widget.mark,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: widget.isActive
                              ? Colors.white
                              : widget.color.withValues(alpha: 0.70),
                        ),
                      ),
              ),
            ],
          ),
        ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PlayerStripAvatar — the circular avatar inside a PlayerStrip.
// Exposed publicly so games can embed it standalone if needed.
// ─────────────────────────────────────────────────────────────────────────────

class PlayerStripAvatar extends StatelessWidget {
  /// Color of the icon/text drawn inside the circle.
  final Color iconColor;

  /// Background fill of the circle.
  final Color bgColor;

  /// Color used for the thinking spinner ring.
  final Color activeColor;

  /// Fallback mark text when [avatarIcon] is null (e.g. "X", "O").
  final String mark;

  /// Optional icon overriding [mark] text (e.g. `Icons.smart_toy_rounded`).
  final IconData? avatarIcon;

  /// When true, a rotating progress ring is drawn around the avatar.
  final bool isThinking;

  /// Controller driving the thinking spinner (must be repeating).
  final AnimationController thinkCtrl;

  final double size;

  const PlayerStripAvatar({
    super.key,
    required this.iconColor,
    required this.bgColor,
    required this.activeColor,
    required this.mark,
    required this.avatarIcon,
    required this.isThinking,
    required this.thinkCtrl,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bgColor),
      alignment: Alignment.center,
      child: avatarIcon != null
          ? Icon(avatarIcon, color: iconColor, size: size * 0.46)
          : Text(
              mark,
              style: TextStyle(
                color: iconColor,
                fontSize: size * 0.40,
                fontWeight: FontWeight.w900,
              ),
            ),
    );

    if (!isThinking) return inner;

    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: thinkCtrl,
        builder: (_, child) => Stack(
          alignment: Alignment.center,
          children: [
            child!,
            Positioned.fill(
              child: CircularProgressIndicator(
                value: thinkCtrl.value,
                strokeWidth: 2.5,
                color: activeColor,
                backgroundColor: activeColor.withValues(alpha: 0.20),
              ),
            ),
          ],
        ),
        child: inner,
      ),
    );
  }
}

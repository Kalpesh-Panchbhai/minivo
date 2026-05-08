import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/services/audio_service.dart';
import '../framework/game_definition.dart';
import '../framework/game_scaffold.dart';
import '../framework/game_session.dart';
import '../shared/animated_background.dart';
import 'memory_match_definition.dart';

// ── Palette ────────────────────────────────────────────────────────────────
const Color _kAccentDk = Color(0xFF1971C2);

// ── Emoji categories ───────────────────────────────────────────────────────
const _kEmojiCategories = <String, List<String>>{
  'Animals': [
    '🐶','🐱','🦊','🐸','🦁','🐻','🐼','🐧','🐨','🐯',
    '🦄','🐮','🐷','🐙','🦀','🦋','🐝','🦚','🦜','🦩',
  ],
  'Fruits': [
    '🍎','🍊','🍋','🍇','🍓','🍒','🍑','🥭','🍍','🥝',
    '🍌','🍉','🍈','🫐','🍏','🍐','🥥','🍅','🥑','🍆',
  ],
  'Plants & Nature': [
    '🌸','🌺','🌻','🌹','🌷','🌴','🌵','🌿','🍁','🍄',
    '🌾','🎋','🎍','🪷','🌼','🌱','🪴','🍃','🪻','🌲',
  ],
  'Space & Weather': [
    '🌙','⭐','🌟','☀️','🌈','⚡','❄️','🌊','🔥','🌪️',
    '🪐','🌍','🌕','☁️','🌠','🌌','🌀','⛄','🌋','🏔️',
  ],
  'Food & Drinks': [
    '🍕','🍔','🌮','🍣','🍜','🍩','🍦','🧁','🎂','🍫',
    '🍿','🧃','🍵','☕','🧋','🥤','🍺','🧇','🥞','🍟',
  ],
  'Sports & Activities': [
    '⚽','🏀','🎾','🏈','⚾','🎱','🏓','🏊','🚴','🧗',
    '🎯','🏹','🎮','🎲','♟️','🎸','🎺','🎻','🥊','🤿',
  ],
  'Travel & Places': [
    '✈️','🚀','🚂','🚢','🏝️','🏕️','🗼','🗽','🏯','⛩️',
    '🎡','🎢','🎠','🏟️','🌉','🗿','🕌','🛸','🚁','🏖️',
  ],
};

List<String> _pickEmojiPool(math.Random rng) {
  final keys = _kEmojiCategories.keys.toList();
  return List<String>.from(_kEmojiCategories[keys[rng.nextInt(keys.length)]]!);
}

// ── Pair colors ────────────────────────────────────────────────────────────
const _kPairColors = [
  Color(0xFF4DABF7), Color(0xFFFF8787), Color(0xFFFF922B),
  Color(0xFF51CF66), Color(0xFFCC5DE8), Color(0xFFFFD43B),
  Color(0xFF20C997), Color(0xFFF06595), Color(0xFFA9E34B),
  Color(0xFF74C0FC), Color(0xFFFF6B6B), Color(0xFF9775FA),
];

// ── Per-difficulty grid config ─────────────────────────────────────────────
class _MMConfig {
  final int cols;
  final int rows;
  final int flipBackMs;
  const _MMConfig({
    required this.cols,
    required this.rows,
    required this.flipBackMs,
  });
  int get pairCount => (cols * rows) ~/ 2;
}

const Map<String, _MMConfig> _kConfigs = {
  'easy':   _MMConfig(cols: 4, rows: 3, flipBackMs: 1100),
  'medium': _MMConfig(cols: 4, rows: 4, flipBackMs: 800),
  'hard':   _MMConfig(cols: 6, rows: 4, flipBackMs: 550),
};

_MMConfig _configFor(DifficultyDef d) =>
    _kConfigs[d.key] ?? _kConfigs['medium']!;

// ── Card model ─────────────────────────────────────────────────────────────
class _Card {
  final int id;
  final String emoji;
  final int pairColorIdx;
  bool faceUp;
  bool matched;
  bool mismatch;
  bool seen; // tracked first-flip for scoring

  _Card({required this.id, required this.emoji, required this.pairColorIdx})
      : faceUp = false,
        matched = false,
        mismatch = false,
        seen = false;
}

// ════════════════════════════════════════════════════════════════
// Root screen — thin wrapper around GameScaffold
// ════════════════════════════════════════════════════════════════

class MemoryMatchScreen extends StatelessWidget {
  const MemoryMatchScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      GameScaffold(definition: memoryMatchGame);
}

// ════════════════════════════════════════════════════════════════
// Board — playing-state widget driven by GameSession
// ════════════════════════════════════════════════════════════════

class MemoryMatchBoard extends StatefulWidget {
  final GameSession session;
  const MemoryMatchBoard({required this.session, super.key});

  @override
  State<MemoryMatchBoard> createState() => _MemoryMatchBoardState();
}

class _MemoryMatchBoardState extends State<MemoryMatchBoard>
    with TickerProviderStateMixin {
  final _rng = math.Random();

  List<_Card> _cards = [];
  int _matchedPairs = 0;
  int? _firstFlipIdx;
  bool _lockInput = false;
  bool _gameOver = false;

  List<AnimationController> _flipCtrl = [];
  List<AnimationController> _bounceCtrl = [];
  List<AnimationController> _matchCtrl = [];
  late AnimationController _celebrationCtrl;

  Timer? _flipBackTimer;

  DifficultyDef get _diff => widget.session.difficulty;
  _MMConfig get _cfg => _configFor(_diff);

  @override
  void initState() {
    super.initState();
    _celebrationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _setupGame();
    });
  }

  @override
  void dispose() {
    _flipBackTimer?.cancel();
    for (final c in _flipCtrl)   { c.dispose(); }
    for (final c in _bounceCtrl) { c.dispose(); }
    for (final c in _matchCtrl)  { c.dispose(); }
    _celebrationCtrl.dispose();
    super.dispose();
  }

  void _setupGame() {
    final cfg = _cfg;
    final pool = _pickEmojiPool(_rng)..shuffle(_rng);
    final emojis = pool.take(cfg.pairCount).toList();
    final cardEmojis = [...emojis, ...emojis]..shuffle(_rng);

    final cards = List.generate(cardEmojis.length, (i) {
      final emoji = cardEmojis[i];
      final colorIdx = emojis.indexOf(emoji) % _kPairColors.length;
      return _Card(id: i, emoji: emoji, pairColorIdx: colorIdx);
    });

    final flipControllers = List.generate(
      cards.length,
      (_) => AnimationController(vsync: this, duration: const Duration(milliseconds: 320)),
    );
    final bounceControllers = List.generate(
      cards.length,
      (_) => AnimationController(vsync: this, duration: const Duration(milliseconds: 420)),
    );
    final matchControllers = List.generate(
      cards.length,
      (_) => AnimationController(vsync: this, duration: const Duration(milliseconds: 500)),
    );

    setState(() {
      _cards = cards;
      _flipCtrl = flipControllers;
      _bounceCtrl = bounceControllers;
      _matchCtrl = matchControllers;
      _matchedPairs = 0;
      _firstFlipIdx = null;
      _lockInput = false;
      _gameOver = false;
    });

    // Stagger bounce-in
    for (int i = 0; i < bounceControllers.length; i++) {
      final delay = Duration(milliseconds: (i * 40).clamp(0, 600));
      Future.delayed(delay, () {
        if (mounted) bounceControllers[i].forward();
      });
    }
  }

  void _onCardTap(int index) {
    if (_lockInput || _gameOver) return;
    final card = _cards[index];
    if (card.faceUp || card.matched) return;

    AudioService().playTap();

    setState(() {
      card.faceUp = true;
    });
    _flipCtrl[index].forward(from: 0);

    if (_firstFlipIdx == null) {
      setState(() => _firstFlipIdx = index);
    } else {
      final firstIdx = _firstFlipIdx!;
      setState(() {
        _firstFlipIdx = null;
        _lockInput = true;
      });
      _evaluate(firstIdx, index);
    }
  }

  void _evaluate(int firstIdx, int secondIdx) {
    final cfg = _cfg;
    final first  = _cards[firstIdx];
    final second = _cards[secondIdx];

    if (first.emoji == second.emoji) {
      // ── MATCH ──────────────────────────────────────────────────
      AudioService().playScore();

      // First-attempt match = both cards never seen before.
      final firstAttempt = !first.seen && !second.seen;
      final pts = firstAttempt ? 20 : 10;

      setState(() {
        first.matched  = true;
        second.matched = true;
        first.seen = true;
        second.seen = true;
        _matchedPairs++;
        _lockInput = false;
      });

      _matchCtrl[firstIdx].forward(from: 0);
      _matchCtrl[secondIdx].forward(from: 0);

      widget.session.incrementScore(pts);

      if (_matchedPairs == cfg.pairCount) {
        _finishGame();
      }
    } else {
      // ── MISMATCH ───────────────────────────────────────────────
      widget.session.incrementMistakes();
      setState(() {
        first.mismatch  = true;
        second.mismatch = true;
      });

      _flipBackTimer?.cancel();
      _flipBackTimer = Timer(Duration(milliseconds: cfg.flipBackMs), () {
        if (!mounted) return;
        _flipCtrl[firstIdx].reverse();
        _flipCtrl[secondIdx].reverse();
        setState(() {
          first.faceUp   = false;
          first.mismatch = false;
          first.seen     = true;
          second.faceUp   = false;
          second.mismatch = false;
          second.seen     = true;
          _lockInput      = false;
        });
      });
    }
  }

  void _finishGame() {
    _flipBackTimer?.cancel();
    setState(() => _gameOver = true);
    // +50 completion bonus
    widget.session.incrementScore(50);

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _celebrationCtrl.forward();
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) widget.session.completeGame();
      });
    });
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg;
    return Column(
      children: [
        _ProgressBar(
          matched: _matchedPairs,
          total: cfg.pairCount,
          color: _diff.color,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _cards.isEmpty
                    ? const SizedBox.shrink()
                    : _CardGrid(
                        cards: _cards,
                        flipControllers: _flipCtrl,
                        bounceControllers: _bounceCtrl,
                        matchControllers: _matchCtrl,
                        cols: cfg.cols,
                        rows: cfg.rows,
                        onCardTap: _onCardTap,
                      ),
              ),
              AnimatedBuilder(
                animation: _celebrationCtrl,
                builder: (_, _) {
                  if (_celebrationCtrl.value == 0) {
                    return const SizedBox.shrink();
                  }
                  return Positioned.fill(
                    child: IgnorePointer(
                      child: _WinCelebrationOverlay(
                        progress: _celebrationCtrl.value,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PROGRESS BAR
// ════════════════════════════════════════════════════════════════

class _ProgressBar extends StatelessWidget {
  final int matched;
  final int total;
  final Color color;

  const _ProgressBar({
    required this.matched,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : matched / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$matched / $total pairs found',
                style: TextStyle(
                  color: _kAccentDk.withValues(alpha: 0.75),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  color: color.withValues(alpha: 0.85),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(
                  height: 5,
                  color: color.withValues(alpha: 0.14),
                ),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  widthFactor: progress,
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, Color.lerp(color, Colors.white, 0.30)!],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.45),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// WIN CELEBRATION OVERLAY
// ════════════════════════════════════════════════════════════════

class _WinCelebrationOverlay extends StatelessWidget {
  final double progress;
  const _WinCelebrationOverlay({required this.progress});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ConfettiPainter(progress));
  }
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  static final _rng = math.Random(42);
  static final _particles = List.generate(60, (i) => _ConfettiParticle(
    x: _rng.nextDouble(),
    startY: -0.05 - _rng.nextDouble() * 0.3,
    speedY: 0.35 + _rng.nextDouble() * 0.45,
    speedX: (_rng.nextDouble() - 0.5) * 0.18,
    size: 5 + _rng.nextDouble() * 8,
    color: _randomColor(_rng),
    rotation: _rng.nextDouble() * math.pi * 2,
    rotSpeed: (_rng.nextDouble() - 0.5) * 8,
    delay: _rng.nextDouble() * 0.4,
    shape: _rng.nextInt(3),
  ));

  static Color _randomColor(math.Random rng) {
    const colors = [
      Color(0xFFFFD43B), Color(0xFF74C0FC), Color(0xFF51CF66),
      Color(0xFFFF6B6B), Color(0xFFCC5DE8), Color(0xFFFF922B),
      Color(0xFFA9E34B), Color(0xFFF06595),
    ];
    return colors[rng.nextInt(colors.length)];
  }

  const _ConfettiPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final pt = ((t - p.delay) / (1.0 - p.delay)).clamp(0.0, 1.0);
      if (pt <= 0) continue;
      final x = (p.x + p.speedX * pt) * size.width;
      final y = (p.startY + p.speedY * pt) * size.height;
      final alpha = (1.0 - math.max(0.0, pt - 0.7) / 0.3).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withValues(alpha: alpha.toDouble());
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + p.rotSpeed * pt);
      switch (p.shape) {
        case 0:
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
            paint,
          );
        case 1:
          canvas.drawCircle(Offset.zero, p.size * 0.45, paint);
        default:
          final path = Path()
            ..moveTo(0, -p.size * 0.5)
            ..lineTo(p.size * 0.5, p.size * 0.5)
            ..lineTo(-p.size * 0.5, p.size * 0.5)
            ..close();
          canvas.drawPath(path, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

class _ConfettiParticle {
  final double x, startY, speedY, speedX, size, rotation, rotSpeed, delay;
  final Color color;
  final int shape;
  const _ConfettiParticle({
    required this.x, required this.startY, required this.speedY,
    required this.speedX, required this.size, required this.color,
    required this.rotation, required this.rotSpeed, required this.delay,
    required this.shape,
  });
}

// ════════════════════════════════════════════════════════════════
// CARD GRID
// ════════════════════════════════════════════════════════════════

class _CardGrid extends StatelessWidget {
  final List<_Card> cards;
  final List<AnimationController> flipControllers;
  final List<AnimationController> bounceControllers;
  final List<AnimationController> matchControllers;
  final int cols;
  final int rows;
  final ValueChanged<int> onCardTap;

  const _CardGrid({
    required this.cards,
    required this.flipControllers,
    required this.bounceControllers,
    required this.matchControllers,
    required this.cols,
    required this.rows,
    required this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 8.0;
        final cardW = (c.maxWidth  - gap * (cols - 1)) / cols;
        final cardH = (c.maxHeight - gap * (rows - 1)) / rows;

        return Stack(
          children: List.generate(cards.length, (i) {
            final col = i % cols;
            final row = i ~/ cols;
            return Positioned(
              left: col * (cardW + gap),
              top:  row * (cardH + gap),
              width: cardW,
              height: cardH,
              child: _FlipCard(
                card: cards[i],
                controller: flipControllers[i],
                bounceController: bounceControllers[i],
                matchController: matchControllers[i],
                onTap: () => onCardTap(i),
              ),
            );
          }),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
// FLIP CARD
// ════════════════════════════════════════════════════════════════

class _FlipCard extends StatelessWidget {
  final _Card card;
  final AnimationController controller;
  final AnimationController bounceController;
  final AnimationController matchController;
  final VoidCallback onTap;

  const _FlipCard({
    required this.card,
    required this.controller,
    required this.bounceController,
    required this.matchController,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([bounceController, matchController]),
      builder: (_, child) {
        final bounceAnim = CurvedAnimation(
          parent: bounceController, curve: Curves.easeOutBack,
        );
        final bounceScale = bounceController.status == AnimationStatus.completed
            ? 1.0
            : Tween<double>(begin: 0.0, end: 1.0).evaluate(bounceAnim);

        final matchAnim = CurvedAnimation(parent: matchController, curve: Curves.easeOut);
        final matchScale = (matchController.isAnimating || matchController.isCompleted)
            ? TweenSequence<double>([
                TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.18), weight: 40),
                TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.0), weight: 60),
              ]).evaluate(matchAnim)
            : 1.0;

        return Transform.scale(
          scale: bounceScale * matchScale,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              child!,
              if (card.matched && matchController.isAnimating)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: matchController,
                    builder: (context, _) => CustomPaint(
                      painter: _SparkleOverlayPainter(
                        progress: matchController.value,
                        color: _kPairColors[card.pairColorIdx % _kPairColors.length],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final anim = controller.value;
            final scaleX = anim < 0.5 ? 1.0 - anim * 2 : (anim - 0.5) * 2;
            final showFront = anim >= 0.5 || card.faceUp;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(scaleX, 1.0, 1.0),
              child: _CardFace(card: card, faceUp: showFront),
            );
          },
        ),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  final _Card card;
  final bool faceUp;

  const _CardFace({required this.card, required this.faceUp});

  @override
  Widget build(BuildContext context) {
    final pairColor = _kPairColors[card.pairColorIdx % _kPairColors.length];
    final glowColor = card.matched
        ? const Color(0xFF22C55E)
        : card.mismatch
            ? const Color(0xFFEF4444)
            : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: faceUp ? const Color(0xFFFAFDFF) : null,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          if (glowColor != null)
            BoxShadow(
              color: glowColor.withValues(alpha: card.matched ? 0.55 : 0.45),
              blurRadius: card.matched ? 14 : 10,
              spreadRadius: card.matched ? 2 : 1,
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.13),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
        ],
        border: card.matched
            ? Border.all(color: const Color(0xFF22C55E), width: 2.5)
            : card.mismatch
                ? Border.all(color: const Color(0xFFEF4444), width: 2.0)
                : faceUp
                    ? Border.all(color: pairColor.withValues(alpha: 0.55), width: 2.0)
                    : null,
        gradient: faceUp
            ? null
            : const LinearGradient(
                colors: [Color(0xFF4C3F91), Color(0xFF3949AB), Color(0xFF1A237E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: faceUp ? _FaceSide(card: card) : const _BackSide(),
      ),
    );
  }
}

class _FaceSide extends StatelessWidget {
  final _Card card;
  const _FaceSide({required this.card});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (card.matched)
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF22C55E).withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        Center(
          child: FittedBox(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: card.matched
                  ? Text(card.emoji, style: const TextStyle(fontSize: 32))
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scaleXY(begin: 1.0, end: 1.08, duration: 700.ms, curve: Curves.easeInOut)
                  : Text(card.emoji, style: const TextStyle(fontSize: 32)),
            ),
          ),
        ),
      ],
    );
  }
}

class _BackSide extends StatelessWidget {
  const _BackSide();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CardBackPainter());
  }
}

class _CardBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.20);
    const dotCols = 3, dotRows = 4;
    final rr = math.min(size.width, size.height) * 0.06;
    for (int r = 0; r < dotRows; r++) {
      for (int c = 0; c < dotCols; c++) {
        canvas.drawCircle(
          Offset(size.width * (c + 1) / (dotCols + 1), size.height * (r + 1) / (dotRows + 1)),
          rr, dotPaint,
        );
      }
    }
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    var offset = -size.height;
    while (offset < size.width + size.height) {
      canvas.drawLine(Offset(offset, 0), Offset(offset + size.height, size.height), linePaint);
      offset += 12.0;
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(size.width * 0.1),
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_CardBackPainter old) => false;
}

class _SparkleOverlayPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _SparkleOverlayPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1.0) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = size.width * 0.9;
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * math.pi + progress * 0.5;
      final dist = maxR * progress;
      final radius = ((1.0 - progress) * size.width * 0.09).clamp(0.0, 20.0);
      paint.color = color.withValues(alpha: (1.0 - progress) * 0.85);
      canvas.drawCircle(
        Offset(cx + math.cos(angle) * dist, cy + math.sin(angle) * dist),
        radius, paint,
      );
    }
    for (int i = 0; i < 4; i++) {
      final angle = (i / 4 + 0.125) * 2 * math.pi;
      final dist = maxR * 0.55 * progress;
      final radius = ((1.0 - progress) * size.width * 0.06).clamp(0.0, 12.0);
      paint.color = Colors.white.withValues(alpha: (1.0 - progress) * 0.75);
      canvas.drawCircle(
        Offset(cx + math.cos(angle) * dist, cy + math.sin(angle) * dist),
        radius, paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SparkleOverlayPainter old) => old.progress != progress;
}

// ════════════════════════════════════════════════════════════════
// ANIMATED BACKGROUND
// ════════════════════════════════════════════════════════════════

class MemoryMatchBgPainter extends AnimatedBgPainter {
  const MemoryMatchBgPainter(super.t);

  @override
  void paintAt(Canvas canvas, Size size, double t) {
    final phase = t * 2 * math.pi;
    const items = [
      (0.08, 0.10, 56.0, 72.0, 0.0, false),
      (0.87, 0.15, 46.0, 60.0, 1.1, true),
      (0.12, 0.70, 52.0, 68.0, 2.2, false),
      (0.85, 0.72, 42.0, 55.0, 3.3, true),
      (0.50, 0.05, 40.0, 52.0, 4.4, false),
      (0.04, 0.42, 36.0, 47.0, 5.5, true),
      (0.72, 0.42, 44.0, 58.0, 0.7, false),
      (0.30, 0.88, 48.0, 63.0, 2.9, true),
      (0.92, 0.55, 34.0, 44.0, 4.1, false),
      (0.55, 0.60, 38.0, 50.0, 1.6, true),
    ];

    for (final (xRel, yRel, cw, ch, p, faceUp) in items) {
      final yBob = math.sin(phase + p) * 8;
      final rot  = math.sin(phase * 0.6 + p) * 0.10;
      final alpha = 0.14 + (math.sin(phase * 0.8 + p) + 1) / 2 * 0.10;
      final cx = size.width * xRel;
      final cy = size.height * yRel + yBob;

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rot);

      final rect = Rect.fromCenter(center: Offset.zero, width: cw, height: ch);
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(cw * 0.15));

      if (faceUp) {
        canvas.drawRRect(rr, Paint()..color = Colors.white.withValues(alpha: alpha));
        canvas.drawRRect(rr, Paint()
          ..color = Colors.white.withValues(alpha: alpha * 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
      } else {
        canvas.drawRRect(rr, Paint()..color = _kAccentDk.withValues(alpha: alpha));
        canvas.drawRRect(rr, Paint()
          ..color = Colors.white.withValues(alpha: alpha * 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
      }
      canvas.restore();
    }
  }
}

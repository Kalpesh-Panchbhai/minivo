import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/services/ads_service.dart';

class RewardedUndoButton extends StatefulWidget {
  final VoidCallback onUndo;
  final VoidCallback onExpired;
  final Color accentColor;

  const RewardedUndoButton({
    super.key,
    required this.onUndo,
    required this.onExpired,
    required this.accentColor,
  });

  @override
  State<RewardedUndoButton> createState() => _RewardedUndoButtonState();
}

class _RewardedUndoButtonState extends State<RewardedUndoButton> {
  static const _totalSeconds = 3;
  int _secondsLeft = _totalSeconds;
  Timer? _timer;
  bool _adTapped = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        widget.onExpired();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onTap() {
    if (_adTapped) return;
    _adTapped = true;
    _timer?.cancel();
    bool earned = false;
    AdsService().showRewarded(
      rewardType: RewardType.undo,
      onRewarded: (_) => earned = true,
      onComplete: () {
        if (earned) widget.onUndo();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.accentColor;
    return GestureDetector(
      onTap: _onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [c.withValues(alpha: 0.15), c.withValues(alpha: 0.08)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withValues(alpha: 0.25), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.undo_rounded, size: 16, color: c),
            const SizedBox(width: 6),
            Text(
              'Undo',
              style: TextStyle(
                color: c, fontSize: 12,
                fontWeight: FontWeight.w800, letterSpacing: 0.4,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_outline_rounded, size: 11, color: c),
                  const SizedBox(width: 2),
                  Text(
                    'AD',
                    style: TextStyle(
                      color: c, fontSize: 9,
                      fontWeight: FontWeight.w900, letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.withValues(alpha: 0.12),
              ),
              child: Center(
                child: Text(
                  '$_secondsLeft',
                  style: TextStyle(
                    color: c, fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.3, end: 0);
  }
}

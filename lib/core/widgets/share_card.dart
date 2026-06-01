import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';

class ShareCard extends StatelessWidget {
  final String? gameName;
  final int? score;
  final int? stars;
  final String? emoji;

  const ShareCard({
    super.key,
    this.gameName,
    this.score,
    this.stars,
    this.emoji,
  });

  bool get _isScoreCard => gameName != null && score != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 420,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF9B8FFF), Color(0xFFFF6B9D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isScoreCard) ..._buildScoreContent() else ..._buildAppContent(),
          const SizedBox(height: 24),
          _buildFooter(),
        ],
      ),
    );
  }

  List<Widget> _buildScoreContent() {
    final starCount = stars ?? 0;
    return [
      if (emoji != null)
        Text(emoji!, style: const TextStyle(fontSize: 48, height: 1)),
      if (emoji != null) const SizedBox(height: 12),
      Text(
        gameName!,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white70,
          letterSpacing: 0.5,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '$score',
        style: const TextStyle(
          fontSize: 72,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          height: 1,
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'SCORE',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white60,
          letterSpacing: 2,
        ),
      ),
      if (starCount > 0) ...[
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Icon(
                Icons.star_rounded,
                size: 32,
                color: i < starCount
                    ? AppColors.starFilled
                    : Colors.white.withValues(alpha: 0.25),
              ),
            );
          }),
        ),
      ],
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Can you beat me? 🏆',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildAppContent() {
    return [
      const Text('🎮', style: TextStyle(fontSize: 48, height: 1)),
      const SizedBox(height: 16),
      const Text(
        AppStrings.appName,
        style: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        AppStrings.appTagline,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white70,
        ),
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          '100+ free mini games 🕹️',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    ];
  }

  Widget _buildFooter() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.videogame_asset_rounded,
              size: 16, color: Colors.white),
        ),
        const SizedBox(width: 8),
        const Text(
          AppStrings.appName,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white70,
          ),
        ),
        const SizedBox(width: 4),
        const Text(
          '•',
          style: TextStyle(fontSize: 13, color: Colors.white38),
        ),
        const SizedBox(width: 4),
        const Text(
          'Free on Play Store',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white54,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

/// 2048 Merge brand logo. Renders as a [size]×[size] square that fills the
/// host tile (used by mosaic_game_tile, game_card, home_screen, etc).
///
/// Design: the iconic 2048 golden gradient tile with a large "2048" wordmark.
/// `FittedBox` keeps the digits readable at every size from the 60×60 home
/// thumbnail to the 96×96 detail-screen badge.
///
/// Referenced from `GameRegistry`'s `number_merge` entry as a const tear-off
/// so it can sit inside `const GameInfo(...)`.
Widget build2048Logo(double size) {
  return Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFEDC22E), Color(0xFFF67C5F)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.10),
          child: const Text(
            '2048',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 100, // FittedBox scales down to fit the host tile
              letterSpacing: -2,
              height: 1,
              shadows: [
                Shadow(
                  color: Color(0x33000000),
                  offset: Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'game_registry.dart';
import 'game_wrapper.dart';

class GamePlayScreen extends StatelessWidget {
  final String gameId;

  const GamePlayScreen({super.key, required this.gameId});

  @override
  Widget build(BuildContext context) {
    return GameWrapper(
      gameId: gameId,
      child: GameRegistry.buildGame(gameId),
    );
  }
}

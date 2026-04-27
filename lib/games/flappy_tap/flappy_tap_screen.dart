import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../game_wrapper.dart';
import 'flappy_tap_game.dart';

class FlappyTapScreen extends StatefulWidget {
  const FlappyTapScreen({super.key});

  @override
  State<FlappyTapScreen> createState() => _FlappyTapScreenState();
}

class _FlappyTapScreenState extends State<FlappyTapScreen> {
  FlappyTapGame? _game;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_game == null) {
      _game = FlappyTapGame();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _game!.setWrapper(GameWrapper.of(context));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameWidget(game: _game!);
  }
}

import 'package:flutter/material.dart';
import '../core/services/analytics_service.dart';
import '../core/services/crash_reporter.dart';
import 'game_registry.dart';
import 'game_wrapper.dart';

class GamePlayScreen extends StatefulWidget {
  final String gameId;

  const GamePlayScreen({super.key, required this.gameId});

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService().gameOpen(gameId: widget.gameId);
    CrashReporter().setCurrentScreen('game/${widget.gameId}');
    CrashReporter().setCurrentGame(widget.gameId);
    CrashReporter().log('game_open', {'game_id': widget.gameId});
  }

  @override
  void dispose() {
    CrashReporter().clearCurrentGame();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GameWrapper(
      gameId: widget.gameId,
      child: GameRegistry.buildGame(widget.gameId),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../game/boss_ball_game.dart';
import '../game/game_state.dart';
import 'game_over_screen.dart';

class GameScreen extends StatelessWidget {
  final OrbType orbType;
  const GameScreen({super.key, required this.orbType});

  @override
  Widget build(BuildContext context) {
    final game = BossBallGame(orbType: orbType);
    return GameWidget(
      game: game,
      overlayBuilderMap: {
        'GameOver': (ctx, g) => GameOverScreen(game: g as BossBallGame),
      },
    );
  }
}

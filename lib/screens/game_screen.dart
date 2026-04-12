import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../game/boss_ball_game.dart';
import '../orbs/orb_behavior.dart';
import '../modes/game_mode.dart';
import 'game_over_screen.dart';

class GameScreen extends StatelessWidget {
  final OrbBehavior orbBehavior;
  final GameMode mode;

  const GameScreen({
    super.key,
    required this.orbBehavior,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    final game = BossBallGame(orbBehavior: orbBehavior, mode: mode);
    return GameWidget(
      game: game,
      overlayBuilderMap: {
        'GameOver': (ctx, g) => GameOverScreen(game: g as BossBallGame),
      },
    );
  }
}

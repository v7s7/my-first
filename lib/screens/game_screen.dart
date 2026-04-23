import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../game/boss_ball_game.dart';
import '../game/arena_config.dart';
import '../orbs/orb_behavior.dart';
import '../modes/game_mode.dart';
import 'game_over_screen.dart';

class GameScreen extends StatelessWidget {
  final OrbBehavior orbBehavior;
  final GameMode mode;
  final ArenaPreset arenaPreset;
  final int? customBossHp;

  /// Image bytes for each player orb (index matches orb index).
  final List<Uint8List?> orbImageBytes;

  /// Image bytes for the boss ball face.
  final Uint8List? bossImageBytes;

  const GameScreen({
    super.key,
    required this.orbBehavior,
    required this.mode,
    this.arenaPreset = ArenaPreset.normal,
    this.customBossHp,
    this.orbImageBytes = const [],
    this.bossImageBytes,
  });

  @override
  Widget build(BuildContext context) {
    final game = BossBallGame(
      orbBehavior: orbBehavior,
      mode: mode,
      arenaPreset: arenaPreset,
      customBossHp: customBossHp,
      orbImageBytes: orbImageBytes,
      bossImageBytes: bossImageBytes,
    );
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AspectRatio(
          aspectRatio: 9 / 19.5,
          child: GameWidget(
            game: game,
            overlayBuilderMap: {
              'GameOver': (ctx, g) => GameOverScreen(game: g as BossBallGame),
            },
          ),
        ),
      ),
    );
  }
}

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../game/boss_ball_game.dart';
import '../game/arena_config.dart';
import '../game/pickup_type.dart';
import '../orbs/orb_behavior.dart';
import '../modes/game_mode.dart';
import 'game_over_screen.dart';

class _CountdownOverlay extends StatefulWidget {
  final BossBallGame game;
  const _CountdownOverlay({required this.game});

  @override
  State<_CountdownOverlay> createState() => _CountdownOverlayState();
}

class _CountdownOverlayState extends State<_CountdownOverlay> {
  int _count = 3;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await Future.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;
    setState(() => _count = 2);
    await Future.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;
    setState(() => _count = 1);
    await Future.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;
    setState(() => _count = 0);
    await Future.delayed(const Duration(milliseconds: 550));
    if (mounted) widget.game.startPlaying();
  }

  @override
  Widget build(BuildContext context) {
    final isGo = _count == 0;
    final label = isGo ? 'GO!' : '$_count';
    final color = isGo ? const Color(0xFF00FFEE) : Colors.white;
    return Material(
      color: Colors.black38,
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 88,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            shadows: [
              Shadow(color: color.withOpacity(0.6), blurRadius: 48),
              Shadow(color: color.withOpacity(0.3), blurRadius: 96),
            ],
          ),
        ),
      ),
    );
  }
}

class GameScreen extends StatelessWidget {
  final OrbBehavior orbBehavior;
  final GameMode mode;
  final ArenaPreset arenaPreset;
  final int? customBossHp;

  /// Image bytes for each player orb (index matches orb index).
  final List<Uint8List?> orbImageBytes;

  /// Image bytes for the boss ball face.
  final Uint8List? bossImageBytes;

  /// Custom orb colours for PVP mode.
  final List<Color> pvpOrbColors;

  /// Which items are allowed to spawn (null = all).
  final Set<PickupType>? pvpAllowedItems;

  const GameScreen({
    super.key,
    required this.orbBehavior,
    required this.mode,
    this.arenaPreset = ArenaPreset.normal,
    this.customBossHp,
    this.orbImageBytes = const [],
    this.bossImageBytes,
    this.pvpOrbColors = const [],
    this.pvpAllowedItems,
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
      pvpOrbColors: pvpOrbColors,
      pvpAllowedItems: pvpAllowedItems,
    );
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AspectRatio(
          aspectRatio: 9 / 19.5,
          child: GameWidget(
            game: game,
            overlayBuilderMap: {
              'GameOver':   (ctx, g) => GameOverScreen(game: g as BossBallGame),
              'Countdown':  (ctx, g) => _CountdownOverlay(game: g as BossBallGame),
            },
          ),
        ),
      ),
    );
  }
}

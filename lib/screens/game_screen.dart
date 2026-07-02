import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../game/boss_ball_game.dart';
import '../game/arena_config.dart';
import '../game/pickup_type.dart';
import '../orbs/orb_behavior.dart';
import '../modes/game_mode.dart';
import 'game_over_screen.dart';
import 'start_screen.dart';

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

  /// Per-player gun loadouts for the revolver pickup (empty = random pool).
  final Set<PvpGunType> pvpGunLoadout1;
  final Set<PvpGunType> pvpGunLoadout2;

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
    this.pvpGunLoadout1 = const {},
    this.pvpGunLoadout2 = const {},
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
      pvpGunLoadout1: pvpGunLoadout1,
      pvpGunLoadout2: pvpGunLoadout2,
    );
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AspectRatio(
          aspectRatio: 9 / 19.5,
          child: Stack(
            children: [
              GameWidget(
                game: game,
                overlayBuilderMap: {
                  'GameOver':   (ctx, g) => GameOverScreen(game: g as BossBallGame),
                  'Countdown':  (ctx, g) => _CountdownOverlay(game: g as BossBallGame),
                },
              ),
              Positioned(
                top: 10,
                left: 10,
                child: SafeArea(
                  child: _QuitButton(onTap: () => _confirmQuit(context, game)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmQuit(BuildContext context, BossBallGame game) async {
    game.paused = true;
    final quit = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E0E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'QUIT MATCH?',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        content: const Text(
          'Your progress in this match will be lost.',
          style: TextStyle(color: Color(0xAAFFFFFF)),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Color(0xFF00FFEE), fontWeight: FontWeight.w800),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'QUIT',
              style: TextStyle(color: Color(0xFFFF4433), fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    game.paused = false;
    if (quit == true && context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const StartScreen()),
        (_) => false,
      );
    }
  }
}

class _QuitButton extends StatelessWidget {
  final VoidCallback onTap;
  const _QuitButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0x33000000),
          border: Border.all(color: const Color(0x33FFFFFF), width: 1),
        ),
        child: const Icon(Icons.close, color: Color(0xAAFFFFFF), size: 20),
      ),
    );
  }
}

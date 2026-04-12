import 'package:flutter/material.dart';
import '../game/boss_ball_game.dart';
import '../game/game_state.dart';
import 'start_screen.dart';
import 'game_screen.dart';

class GameOverScreen extends StatelessWidget {
  final BossBallGame game;
  const GameOverScreen({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final destroyed = game.bossDestroyed;
    final hpLeft = game.bossHp;
    final pctDealt =
        ((BossBallGame.bossMaxHp - hpLeft) / BossBallGame.bossMaxHp * 100);

    return Material(
      color: const Color(0xCC050510),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Result title
            Text(
              destroyed ? 'DESTROYED!' : "TIME'S UP",
              style: TextStyle(
                color: destroyed
                    ? const Color(0xFF00FFEE)
                    : const Color(0xFFFF4433),
                fontSize: 44,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                shadows: [
                  Shadow(
                    color: destroyed ? Colors.cyan : Colors.red,
                    blurRadius: 24,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            if (!destroyed) ...[
              Text(
                'BOSS HP: ${_fmt(hpLeft)}',
                style: const TextStyle(
                  color: Color(0xFFFF6655),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${pctDealt.toStringAsFixed(1)}% DAMAGE DEALT',
                style: const TextStyle(
                  color: Color(0x99FFFFFF),
                  fontSize: 14,
                  letterSpacing: 2,
                ),
              ),
            ] else ...[
              const Text(
                'PERFECT RUN!',
                style: TextStyle(
                  color: Color(0xAAFFFFFF),
                  fontSize: 16,
                  letterSpacing: 3,
                ),
              ),
            ],

            const SizedBox(height: 52),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Btn(
                  label: 'RETRY',
                  color: const Color(0xFF00FFEE),
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GameScreen(orbType: game.orbType),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                _Btn(
                  label: 'MENU',
                  color: const Color(0x99FFFFFF),
                  onTap: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const StartScreen()),
                    (_) => false,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(int hp) {
    if (hp >= 1000000) return '${(hp / 1000000).toStringAsFixed(3)}M';
    if (hp >= 1000) return '${(hp / 1000).toStringAsFixed(1)}K';
    return '$hp';
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _Btn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 34, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(4),
          color: Color.fromARGB(20, color.red, color.green, color.blue),
          boxShadow: [
            BoxShadow(
              color: Color.fromARGB(60, color.red, color.green, color.blue),
              blurRadius: 16,
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
          ),
        ),
      ),
    );
  }
}

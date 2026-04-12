import 'dart:math';
import 'package:flutter/material.dart';
import '../game/boss_ball_game.dart';
import '../modes/game_mode.dart';
import 'start_screen.dart';
import 'game_screen.dart';

class GameOverScreen extends StatelessWidget {
  final BossBallGame game;
  const GameOverScreen({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final mode = game.mode;
    final title = _resolveTitle();
    final titleColor = game.bossDestroyed
        ? const Color(0xFF00FFEE)
        : const Color(0xFFFF4433);
    final titleGlow = game.bossDestroyed ? Colors.cyan : Colors.red;

    return Material(
      color: const Color(0xCC050510),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Mode badge
            Text(
              mode.name,
              style: TextStyle(
                color: mode.accentColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 10),

            // Result title
            Text(
              title,
              style: TextStyle(
                color: titleColor,
                fontSize: 44,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                shadows: [Shadow(color: titleGlow, blurRadius: 24)],
              ),
            ),
            const SizedBox(height: 28),

            // Stats block — adapts to score mode
            ..._buildStats(mode),

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
                      builder: (_) => GameScreen(
                        orbBehavior: game.orbBehavior,
                        mode: game.mode,
                      ),
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

  String _resolveTitle() {
    if (game.bossDestroyed) return 'DESTROYED!';
    if (game.mode.timeLimitSeconds > 0) return "TIME'S UP";
    return 'ROUND OVER';
  }

  List<Widget> _buildStats(GameMode mode) {
    final dmg = game.totalDamage;
    final maxHp = game.bossMaxHp;
    final elapsed = max(1.0, game.totalTime);

    switch (mode.scoreMode) {
      case ScoreMode.damagePerSecond:
        final dps = (dmg / elapsed).round();
        return [
          _StatLine('DAMAGE DEALT', _fmt(dmg)),
          _StatLine('TIME', '${elapsed.toStringAsFixed(1)}s'),
          _StatLine('AVG DPS', _fmt(dps)),
        ];

      case ScoreMode.timeRemaining:
        if (game.bossDestroyed) {
          return [
            _StatLine('TIME LEFT', '${game.timeLeft.toStringAsFixed(1)}s'),
            const Text(
              'PERFECT RUN!',
              style: TextStyle(color: Color(0xAAFFFFFF), fontSize: 16, letterSpacing: 3),
            ),
          ];
        }
        final pct = (dmg / maxHp * 100).clamp(0.0, 100.0);
        return [
          _StatLine('BOSS HP LEFT', _fmt(game.bossHp)),
          _StatLine('DAMAGE DEALT', '${pct.toStringAsFixed(1)}%'),
        ];

      case ScoreMode.damageDealt:
        final pct = (dmg / maxHp * 100).clamp(0.0, 100.0);
        return [
          _StatLine('DAMAGE DEALT', _fmt(dmg)),
          _StatLine('OF BOSS HP', '${pct.toStringAsFixed(1)}%'),
        ];
    }
  }

  static String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(2)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _StatLine extends StatelessWidget {
  final String label;
  final String value;
  const _StatLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: Color(0x88FFFFFF), fontSize: 14, letterSpacing: 1),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
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
        padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 14),
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

import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';
import '../game/mine_component.dart';

/// Plants an explosive mine on the arena floor every time the ball bounces
/// off a wall (up to [_maxMines] mines active at once).
///
/// When the boss walks into a mine: 8 000 instant damage + large explosion.
/// Direct boss contact with the orb: 500 dmg.
///
/// Visual: rotating danger arcs + 6 spiked bolt-dots circling the orb,
/// plus a live counter showing how many mines are currently active.
class MineOrb extends OrbBehavior {
  @override String get id   => 'mine';
  @override String get name => 'MINE';
  @override String get description => '8K trap\nmax 5 mines';
  @override Color  get color => const Color(0xFFFF9900);

  static const int _maxMines     = 5;
  static const int _mineDamage   = 8000;
  static const int _contactDamage = 500;

  int    _activeMines = 0;
  double _time        = 0;

  @override void onAttach(PlayerOrb orb) { _activeMines = 0; _time = 0; }
  @override void onUpdate(double dt, PlayerOrb orb) { _time += dt; }

  @override
  void onWallBounce(PlayerOrb orb) {
    if (_activeMines >= _maxMines) return;
    _activeMines++;
    orb.gameRef.add(
      MineComponent(
        position: orb.position.clone(),
        gameRef: orb.gameRef,
        damage: _mineDamage,
        onDetonated: () => _activeMines--,
      ),
    );
  }

  @override
  void onBossHit(PlayerOrb orb) {
    orb.gameRef.onOrbHitBoss(_contactDamage);
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t = _time;

    // 3 rotating danger arcs
    for (int i = 0; i < 3; i++) {
      final angle = t * (2.0 + i * 0.5) + i * (2 * pi / 3);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius + 8.0 + i * 4.5),
        angle,
        pi * 0.6,
        false,
        Paint()
          ..color = const Color(0xDDFF9900).withOpacity(0.72)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // 6 spinning spike-bolt dots
    const boltCount = 6;
    for (int i = 0; i < boltCount; i++) {
      final a  = i * (2 * pi / boltCount) + t * 0.5;
      final px = cx + cos(a) * (radius + 5);
      final py = cy + sin(a) * (radius + 5);
      canvas.drawCircle(
        Offset(px, py),
        3.2,
        Paint()
          ..color = const Color(0xCCFF9900)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }

    // Active mine counter badge
    if (_activeMines > 0) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'x$_activeMines',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx + radius + 4, cy - 7));
    }
  }
}

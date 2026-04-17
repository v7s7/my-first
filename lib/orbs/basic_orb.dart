import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';
import '../game/shockwave_ring_component.dart';

/// Every boss hit releases a neon shockwave ring that expands across the
/// entire arena.  When the ring edge reaches the boss it deals an extra
/// 3 000 bonus damage on top of the base 6 000 direct hit.
///
/// Visual: three concentric neon rings that pulse outward continuously.
class BasicOrb extends OrbBehavior {
  @override String get id   => 'basic';
  @override String get name => 'SHOCK';
  @override String get description => '6K + shockwave\n+3K ring bonus';
  @override Color  get color => const Color(0xFF00FFEE);

  static const int _hitDamage   = 6000;
  static const int _bonusDamage = 3000;

  double _time = 0;

  @override void onAttach(PlayerOrb orb) { _time = 0; }
  @override void onUpdate(double dt, PlayerOrb orb) { _time += dt; }

  @override
  void onBossHit(PlayerOrb orb) {
    orb.gameRef.onOrbHitBoss(_hitDamage);
    // Spawn expanding shockwave ring at orb's current position
    orb.gameRef.add(ShockwaveRingComponent(
      position: orb.position.clone(),
      gameRef: orb.gameRef,
      bonusDamage: _bonusDamage,
      ringColor: color,
    ));
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t = _time;

    // Three concentric pulsing rings at different phases
    for (int i = 0; i < 3; i++) {
      final phase = (t * 1.8 + i / 3.0) % 1.0;
      final ringR = radius + 4 + phase * radius * 1.8;
      final alpha = ((1.0 - phase) * 200).round().clamp(0, 200);
      canvas.drawCircle(
        Offset(cx, cy),
        ringR,
        Paint()
          ..color = color.withOpacity(alpha / 255.0 * 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * (1.0 - phase)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * (1.0 - phase)),
      );
    }

    // Bright outer ring accent
    canvas.drawCircle(
      Offset(cx, cy),
      radius + 7,
      Paint()
        ..color = color.withOpacity(0.35 + sin(t * 8) * 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }
}

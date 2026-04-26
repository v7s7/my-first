import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';
import '../game/bullet_component.dart';

/// Mirror orb — every wall bounce fires a homing bullet at the boss.
///
/// The orb itself deals only 3 000 on direct contact, but each wall
/// bounce launches a 15 000-damage homing round. In a typical 60 s game
/// with 280 bounces that's 4.2 M potential bullet damage on top of contacts.
///
/// Visual: angled mirror-like facets rotating around the orb, bright
/// reflection sparks on each bounce.
class ReflectOrb extends OrbBehavior {
  @override String get id   => 'reflect';
  @override String get name => 'REFLECT';
  @override String get description => '3K contact\n+15K bullet/bounce';
  @override Color  get color => const Color(0xFFCCEEFF);

  double _time      = 0;
  bool   _spark     = false;
  double _sparkTimer = 0;
  static const double _sparkDuration = 0.25;

  @override
  void onAttach(PlayerOrb orb) { _time = 0; _spark = false; _sparkTimer = 0; }

  @override
  void onUpdate(double dt, PlayerOrb orb) {
    _time += dt;
    if (_spark) {
      _sparkTimer -= dt;
      if (_sparkTimer <= 0) _spark = false;
    }
  }

  @override
  void onWallBounce(PlayerOrb orb) {
    final boss = orb.gameRef.boss;
    if (boss == null) return; // PVP — no boss to target
    orb.gameRef.add(BulletComponent.boss(
      position: orb.position.clone(),
      target:   boss.position.clone(),
      damage:   15000,
    ));
    _spark      = true;
    _sparkTimer = _sparkDuration;
  }

  @override
  void onBossHit(PlayerOrb orb) {
    orb.gameRef.onOrbHitBoss(3000);
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t = _time;

    // 6 mirror facets rotating around the orb
    const facetCount = 6;
    for (int i = 0; i < facetCount; i++) {
      final a    = t * 1.8 + i * (2 * pi / facetCount);
      final dist = radius + 7;
      final px   = cx + cos(a) * dist;
      final py   = cy + sin(a) * dist;

      // Tiny angled mirror shard
      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(a + pi / 4);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: 8, height: 3),
        Paint()
          ..color = const Color(0xCCCCEEFF)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      // Bright glint line
      canvas.drawLine(
        const Offset(-4, 0), const Offset(4, 0),
        Paint()
          ..color = Colors.white.withOpacity(0.85)
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    }

    // Rotating outer shimmer arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius + 14),
      t * 3.0,
      pi * 0.7,
      false,
      Paint()
        ..color = const Color(0x88CCEEFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius + 14),
      -t * 2.2 + pi,
      pi * 0.5,
      false,
      Paint()
        ..color = const Color(0x55AADDFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Bounce spark flash
    if (_spark) {
      final p = 1.0 - (_sparkTimer / _sparkDuration);
      canvas.drawCircle(
        Offset(cx, cy),
        radius * (1.0 + p * 1.8),
        Paint()
          ..color = Colors.white.withOpacity((1.0 - p) * 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5 * (1.0 - p)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * (1.0 - p)),
      );
    }
  }
}

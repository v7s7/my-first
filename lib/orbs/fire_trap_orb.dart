import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';
import '../game/fire_zone_component.dart';

/// On every wall bounce, plants a fire zone on the arena floor at the
/// bounce point (max [_maxZones] active at once).
///
/// Each zone deals 600 dmg / 0.4 s while the boss stands in it.
/// Direct orb hit on the boss: 800 dmg.
///
/// Visual: five orbiting flame embers + a pulsing hot-orange core,
/// plus a counter showing how many fire zones are currently burning.
class FireTrapOrb extends OrbBehavior {
  @override String get id   => 'firetrap';
  @override String get name => 'FIRETRAP';
  @override String get description => '600 DoT/zone\nmax 4 zones';
  @override Color  get color => const Color(0xFFFF5500);

  static const int _maxZones      = 4;
  static const int _contactDamage = 800;

  int    _activeZones = 0;
  double _time        = 0;

  @override void onAttach(PlayerOrb orb) { _activeZones = 0; _time = 0; }
  @override void onUpdate(double dt, PlayerOrb orb) { _time += dt; }

  @override
  void onWallBounce(PlayerOrb orb) {
    if (_activeZones >= _maxZones) return;
    _activeZones++;
    orb.gameRef.add(
      FireZoneComponent(
        position: orb.position.clone(),
        gameRef: orb.gameRef,
        onExpired: () => _activeZones--,
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

    // 5 orbiting flame embers
    const emberCount = 5;
    for (int i = 0; i < emberCount; i++) {
      final angle  = t * 3.8 + i * (2 * pi / emberCount);
      final orbitR = radius * 0.72 + sin(t * 7 + i) * 4;
      final px     = cx + cos(angle) * orbitR;
      final py     = cy + sin(angle) * orbitR;
      final sz     = 4.5 + sin(t * 9 + i * 1.2) * 1.5;
      final lick   = 11 + sin(t * 11 + i) * 4;

      // Ember body
      canvas.drawCircle(
        Offset(px, py),
        sz,
        Paint()
          ..color = Color.fromARGB(
              (175 + sin(t * 5 + i) * 40).round().clamp(100, 215), 255, 75, 0)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      // Bright tip
      canvas.drawCircle(
        Offset(px, py - lick * 0.55),
        sz * 0.45,
        Paint()
          ..color = const Color(0xCCFFCC00),
      );
    }

    // Hot pulsing core
    canvas.drawCircle(
      Offset(cx, cy),
      radius * 0.58 + sin(t * 12) * 3,
      Paint()
        ..color = const Color(0x44FF3300)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Active zone counter badge
    if (_activeZones > 0) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'x$_activeZones',
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

import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';
import '../game/fire_zone_component.dart';

/// INFERNO: on hit, 8 000 instant + 12 burn ticks × 2 000 = 24 000 DoT.
/// Also plants a fire zone at the boss's location on every hit.
/// Total potential damage per hit cycle: 32 000+.
///
/// Visual: a crown of large lava drip particles orbiting the orb,
/// plus a molten inner core that flares when burning.
class FireOrb extends OrbBehavior {
  @override String get id   => 'fire';
  @override String get name => 'INFERNO';
  @override String get description => '8K hit\n+24K DoT+zone';
  @override Color  get color => const Color(0xFFFF5500);

  static const int    _baseDamage   = 8000;
  static const int    _burnTicks    = 12;
  static const int    _tickDamage   = 2000;
  static const double _tickInterval = 0.35;

  bool   _burning      = false;
  double _burnTimer    = 0;
  int    _ticksLeft    = 0;
  double _pulseTimer   = 0;

  @override
  void onAttach(PlayerOrb orb) {
    _burning    = false;
    _ticksLeft  = 0;
    _burnTimer  = 0;
    _pulseTimer = 0;
  }

  @override
  void onUpdate(double dt, PlayerOrb orb) {
    _pulseTimer += dt;
    if (!_burning) return;
    _burnTimer -= dt;
    if (_burnTimer <= 0 && _ticksLeft > 0) {
      _burnTimer = _tickInterval;
      orb.gameRef.onOrbHitBoss(_tickDamage, isLaserTick: true);
      _ticksLeft--;
      if (_ticksLeft <= 0) _burning = false;
    }
  }

  @override
  void onBossHit(PlayerOrb orb) {
    orb.gameRef.onOrbHitBoss(_baseDamage);
    _burning   = true;
    _burnTimer = _tickInterval;
    _ticksLeft = _burnTicks;
    // Drop a fire zone at the boss position
    orb.gameRef.add(FireZoneComponent(
      position: orb.gameRef.boss.position.clone(),
      gameRef: orb.gameRef,
    ));
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t = _pulseTimer;

    // Molten core — flares while burning
    if (_burning) {
      canvas.drawCircle(
        Offset(cx, cy),
        radius * 0.7 + sin(t * 16) * 5,
        Paint()
          ..color = const Color(0x77FF6600)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }

    // Crown of large lava drip orbs — 8 particles
    const count = 8;
    for (int i = 0; i < count; i++) {
      final angle  = t * 3.0 + i * (2 * pi / count);
      final orbitR = radius * 0.85 + sin(t * 5.5 + i * 1.1) * 5;
      final px     = cx + cos(angle) * orbitR;
      final py     = cy + sin(angle) * orbitR;
      final sz     = 5.5 + sin(t * 8 + i * 1.4) * 2.0;

      // Lava drop colour: orange core → yellow tip
      final green = (60 + (i % 4) * 20 + (sin(t * 4 + i) * 25).round()).clamp(0, 200);
      final alpha = (170 + (sin(t * 6 + i) * 45).round()).clamp(80, 255);

      // Glow
      canvas.drawCircle(
        Offset(px, py - 3),
        sz + 3,
        Paint()
          ..color = Color.fromARGB(alpha ~/ 2, 255, green, 0)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      // Core
      canvas.drawCircle(
        Offset(px, py - 3),
        sz,
        Paint()
          ..color = Color.fromARGB(alpha, 255, green, 0),
      );
      // Yellow tip
      canvas.drawCircle(
        Offset(px, py - 5),
        sz * 0.4,
        Paint()..color = const Color(0xCCFFFF55),
      );
    }
  }
}

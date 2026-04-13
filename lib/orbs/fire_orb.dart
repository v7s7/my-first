import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

/// On each boss hit: 1 000 immediate damage, then ignites the boss for
/// 6 burn ticks of 800 damage every 0.45 s (4 800 DoT) = 5 800 total.
///
/// Re-hitting while already burning refreshes the DoT timer.
///
/// Visual: six flame particles orbit the orb, animated with a pulse timer.
/// An inner heat glow flares while burn is active.
class FireOrb extends OrbBehavior {
  @override String get id   => 'fire';
  @override String get name => 'FIRE';
  @override String get description => 'ignite\n5.8K DoT';
  @override Color  get color => const Color(0xFFFF6600);

  static const int    _baseDamage  = 1000;
  static const int    _burnTicks   = 6;
  static const int    _tickDamage  = 800;
  static const double _tickInterval = 0.45;

  bool   _burning       = false;
  double _burnTickTimer = 0;
  int    _ticksLeft     = 0;
  double _pulseTimer    = 0;

  @override
  void onAttach(PlayerOrb orb) {
    _burning       = false;
    _ticksLeft     = 0;
    _burnTickTimer = 0;
    _pulseTimer    = 0;
  }

  @override
  void onUpdate(double dt, PlayerOrb orb) {
    _pulseTimer += dt;

    if (!_burning) return;

    _burnTickTimer -= dt;
    if (_burnTickTimer <= 0) {
      _burnTickTimer = _tickInterval;
      orb.gameRef.onOrbHitBoss(_tickDamage, isLaserTick: true);
      _ticksLeft--;
      if (_ticksLeft <= 0) _burning = false;
    }
  }

  @override
  void onBossHit(PlayerOrb orb) {
    orb.gameRef.onOrbHitBoss(_baseDamage);
    // Refresh burn (restart even if already active)
    _burning       = true;
    _burnTickTimer = _tickInterval;
    _ticksLeft     = _burnTicks;
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t = _pulseTimer;

    // Inner heat glow — brighter while burning
    if (_burning) {
      canvas.drawCircle(
        Offset(cx, cy),
        radius * 0.65 + sin(t * 14) * 4,
        Paint()
          ..color = const Color(0x66FF8800)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    // 6 animated flame particles orbiting the orb
    for (int i = 0; i < 6; i++) {
      final angle  = t * 2.6 + i * (pi / 3);
      final orbitR = radius * 0.82 + sin(t * 5.5 + i * 1.1) * 4;
      final px     = cx + cos(angle) * orbitR;
      final py     = cy + sin(angle) * orbitR;

      // Particle grows and pulses with an offset wave
      final sz = 4.5 + sin(t * 8 + i * 1.4) * 1.8;

      // Color: yellow core → orange glow
      final r = 255;
      final g = (80 + (i % 3) * 30 + (sin(t * 4 + i) * 30).round()).clamp(0, 200);
      canvas.drawCircle(
        Offset(px, py - 2), // slight upward offset — flames rise
        sz,
        Paint()
          ..color = Color.fromARGB(
              (160 + (sin(t * 6 + i) * 40).round()).clamp(60, 255), r, g, 0)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      // Bright yellow tip
      canvas.drawCircle(
        Offset(px, py - 4),
        sz * 0.45,
        Paint()..color = const Color(0xCCFFFF44),
      );
    }
  }
}

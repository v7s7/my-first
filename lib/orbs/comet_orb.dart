import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

/// A blazing comet whose fire halo points opposite to the ball's velocity.
///
/// On boss hit: 3 000 damage + 3 burn ticks of 1 500 each = 7 500 total.
///
/// Visual: a directional flame tail aligned with movement direction,
/// orbiting ember sparks, and a heat glow that brightens while burning.
/// The tail fans out like a real comet streaking across the arena.
class CometOrb extends OrbBehavior {
  @override String get id   => 'comet';
  @override String get name => 'COMET';
  @override String get description => '3K + embers\n7.5K total';
  @override Color  get color => const Color(0xFFFF8800);

  static const int    _baseDamage   = 3000;
  static const int    _burnTicks    = 3;
  static const int    _tickDamage   = 1500;
  static const double _tickInterval = 0.35;

  double _time          = 0;
  double _velocityAngle = 0; // radians — direction the orb is currently moving
  bool   _burning       = false;
  int    _ticksLeft     = 0;
  double _tickTimer     = 0;

  @override
  void onAttach(PlayerOrb orb) {
    _time          = 0;
    _velocityAngle = 0;
    _burning       = false;
    _ticksLeft     = 0;
    _tickTimer     = 0;
  }

  @override
  void onUpdate(double dt, PlayerOrb orb) {
    _time += dt;

    // Track velocity direction so the flame tail always faces backward
    if (orb.velocity.length > 1.0) {
      _velocityAngle = atan2(orb.velocity.y, orb.velocity.x);
    }

    if (_burning) {
      _tickTimer -= dt;
      if (_tickTimer <= 0 && _ticksLeft > 0) {
        _tickTimer = _tickInterval;
        orb.gameRef.onOrbHitBoss(_tickDamage, isLaserTick: true);
        _ticksLeft--;
        if (_ticksLeft <= 0) _burning = false;
      }
    }
  }

  @override
  void onBossHit(PlayerOrb orb) {
    orb.gameRef.onOrbHitBoss(_baseDamage);
    _burning   = true;
    _ticksLeft = _burnTicks;
    _tickTimer = _tickInterval;
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t = _time;

    // Tail points opposite to direction of travel (classic comet look)
    final tailAngle = _velocityAngle + pi;

    // Layered directional flame — 3 layers spread outward from tail angle
    for (int layer = 0; layer < 3; layer++) {
      final spread = 0.30 + layer * 0.18;

      for (int side = -1; side <= 1; side += 2) {
        final a   = tailAngle + side * spread * (layer + 1) / 3.0;
        final len = radius * (1.3 + layer * 0.55) + sin(t * 12 + layer * 1.3) * 4;
        final tx  = cx + cos(a) * len;
        final ty  = cy + sin(a) * len;

        // Hotter layers are brighter / more yellow
        final green = (40 + layer * 55 + (sin(t * 10 + layer) * 25).round())
            .clamp(0, 200);
        final alpha = (185 - layer * 38).clamp(60, 185);

        canvas.drawLine(
          Offset(cx, cy),
          Offset(tx, ty),
          Paint()
            ..color = Color.fromARGB(alpha, 255, green, 0)
            ..strokeWidth = (4.0 - layer * 0.9).clamp(1.0, 4.0)
            ..strokeCap = StrokeCap.round
            ..maskFilter =
                MaskFilter.blur(BlurStyle.normal, 4.5 + layer * 2.0),
        );
      }

      // Centre flame lick (middle of spread)
      final centreLen =
          radius * (1.6 + layer * 0.4) + sin(t * 15 + layer * 2.1) * 5;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(
          cx + cos(tailAngle) * centreLen,
          cy + sin(tailAngle) * centreLen,
        ),
        Paint()
          ..color = Color.fromARGB(
              (200 - layer * 45).clamp(80, 200), 255, 200 - layer * 50, 0)
          ..strokeWidth = (2.5 - layer * 0.5).clamp(0.8, 2.5)
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }

    // Orbiting ember sparks
    const sparkCount = 6;
    for (int i = 0; i < sparkCount; i++) {
      final angle  = t * 4.5 + i * (2 * pi / sparkCount);
      final orbitR = radius * 0.72 + sin(t * 7 + i) * 3.5;
      final px     = cx + cos(angle) * orbitR;
      final py     = cy + sin(angle) * orbitR;
      final sz     = 3.0 + sin(t * 9 + i * 1.3) * 1.5;

      canvas.drawCircle(
        Offset(px, py),
        sz,
        Paint()
          ..color = Color.fromARGB(
              (160 + sin(t * 5 + i) * 60).round().clamp(80, 220), 255, 150, 20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // Heat glow intensifies while burn DoT is active
    if (_burning) {
      canvas.drawCircle(
        Offset(cx, cy),
        radius * 0.72 + sin(t * 18) * 4,
        Paint()
          ..color = const Color(0x66FF4400)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }
  }
}

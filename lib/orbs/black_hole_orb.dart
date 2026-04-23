import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

/// SINGULARITY: on hit, 20 000 instant damage + activates a 2.5 s
/// gravity vortex.  During the vortex the boss is continuously pulled
/// toward the orb (harder to escape), and takes 1 500 dmg every 0.3 s.
///
/// Visual: a spinning accretion disk of galaxy-arc segments, a deep dark
/// event horizon, and an outer gravitational lens distortion ring.
class BlackHoleOrb extends OrbBehavior {
  @override String get id   => 'blackhole';
  @override String get name => 'VOID STAR';
  @override String get description => '20K + pull\n1.5K DoT';
  @override Color  get color => const Color(0xFF220066);

  static const int    _baseDamage   = 20000;
  static const double _vortexDur    = 2.5;
  static const int    _pullTickDmg  = 1500;
  static const double _pullTickRate = 0.30;
  static const double _pullForce    = 280.0;

  bool   _vortex    = false;
  double _vortexTimer = 0;
  double _tickTimer = 0;
  double _time      = 0;

  @override
  void onAttach(PlayerOrb orb) {
    _vortex      = false;
    _vortexTimer = 0;
    _tickTimer   = 0;
    _time        = 0;
  }

  @override
  void onUpdate(double dt, PlayerOrb orb) {
    _time += dt;
    if (!_vortex) return;

    _vortexTimer -= dt;
    _tickTimer   -= dt;

    // Pull boss toward orb
    final vortexBoss = orb.gameRef.boss;
    if (vortexBoss != null) {
      final toOrb = (orb.position - vortexBoss.position);
      if (toOrb.length > 1) {
        vortexBoss.velocity += toOrb.normalized() * _pullForce * dt;
      }
    }

    // DoT ticks
    if (_tickTimer <= 0) {
      _tickTimer = _pullTickRate;
      orb.gameRef.onOrbHitBoss(_pullTickDmg, isLaserTick: true);
    }

    if (_vortexTimer <= 0) _vortex = false;
  }

  @override
  void onBossHit(PlayerOrb orb) {
    orb.gameRef.onOrbHitBoss(_baseDamage);
    _vortex      = true;
    _vortexTimer = _vortexDur;
    _tickTimer   = _pullTickRate;
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t = _time;

    // Gravitational lens ring (outermost)
    canvas.drawCircle(
      Offset(cx, cy),
      radius + 18,
      Paint()
        ..color = const Color(0x336600FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Accretion disk — spinning colour arcs (galaxy segments)
    const diskSegments = 8;
    for (int i = 0; i < diskSegments; i++) {
      final hue      = (i * (360.0 / diskSegments) + t * 60) % 360;
      final diskC    = HSLColor.fromAHSL(0.75, hue, 0.9, 0.55).toColor();
      final segAngle = t * (2.0 + i * 0.25) + i * (2 * pi / diskSegments);
      final diskR    = radius + 5.0 + sin(t * 3 + i) * 3;

      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: diskR),
        segAngle,
        pi * 0.5,
        false,
        Paint()
          ..color = diskC
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }

    // Inner swirl rings
    for (int r = 0; r < 3; r++) {
      final swR = radius * (0.55 - r * 0.12);
      canvas.drawCircle(
        Offset(cx, cy),
        swR + sin(t * 8 + r) * 2,
        Paint()
          ..color = const Color(0xFF7700FF).withOpacity(0.25 - r * 0.06)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // Event horizon (dark solid core)
    canvas.drawCircle(
      Offset(cx, cy),
      radius * 0.45,
      Paint()
        ..color = Colors.black.withOpacity(0.92)
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 6),
    );

    // Vortex pull beams while active
    if (_vortex) {
      final p = 1.0 - (_vortexTimer / _vortexDur);
      for (int i = 0; i < 6; i++) {
        final angle = t * 8 + i * (pi / 3);
        final len   = radius * 1.2 + p * radius * 2.5;
        canvas.drawLine(
          Offset(cx, cy),
          Offset(cx + cos(angle) * len, cy + sin(angle) * len),
          Paint()
            ..color = const Color(0x88AA00FF)
                .withOpacity((1.0 - p) * 0.7 + 0.15)
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
    }
  }
}

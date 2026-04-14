import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';
import '../game/laser_beam.dart';

/// Fires a continuous laser beam at the boss for 1.2 s.
/// 30 ticks × 1 000 dmg = 30 000 total.
///
/// Visual: before firing, a tight spiral of charge rings winds up on the orb.
/// While firing, an intense pulsing red halo throbs with each damage tick.
class LaserOrb extends OrbBehavior {
  @override String get id   => 'laser';
  @override String get name => 'LASER';
  @override String get description => '30K beam\n1 000/tick';
  @override Color  get color => const Color(0xFFFF2200);

  static const double _laserDuration = 1.2;
  static const double _tickRate      = 0.04; // 30 ticks
  static const int    _tickDamage    = 1000;

  bool      _firing       = false;
  double    _firingTimer  = 0;
  double    _tickTimer    = 0;
  double    _time         = 0;
  LaserBeam? _beam;

  @override
  void onAttach(PlayerOrb orb) {
    _firing      = false;
    _firingTimer = 0;
    _tickTimer   = 0;
    _time        = 0;
    _beam        = null;
  }

  @override
  void onUpdate(double dt, PlayerOrb orb) {
    _time += dt;
    if (!_firing) return;

    _firingTimer -= dt;
    _tickTimer   -= dt;

    _beam?.startPos = orb.position;
    _beam?.endPos   = orb.gameRef.boss.position;
    _beam?.timeLeft = _firingTimer;

    if (_tickTimer <= 0) {
      _tickTimer = _tickRate;
      orb.gameRef.onOrbHitBoss(_tickDamage, isLaserTick: true);
    }

    if (_firingTimer <= 0) {
      _firing = false;
      _beam?.removeFromParent();
      _beam = null;
    }
  }

  @override
  void onBossHit(PlayerOrb orb) {
    if (_firing) return;
    _firing      = true;
    _firingTimer = _laserDuration;
    _tickTimer   = 0;
    _beam = LaserBeam(
      startPos: orb.position.clone(),
      endPos: orb.gameRef.boss.position.clone(),
      totalDuration: _laserDuration,
      timeLeft: _laserDuration,
    );
    orb.gameRef.add(_beam!);
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t = _time;

    if (_firing) {
      // Intense throb while firing
      final throb = sin(t * 40) * 0.5 + 0.5;
      canvas.drawCircle(
        Offset(cx, cy),
        radius * 1.5 + throb * 8,
        Paint()
          ..color = color.withOpacity(0.5 + throb * 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0 + throb * 2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      // Energy ring
      canvas.drawCircle(
        Offset(cx, cy),
        radius + 6,
        Paint()
          ..color = Colors.white.withOpacity(throb * 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    } else {
      // Charge-up spiral rings (always spinning)
      for (int i = 0; i < 4; i++) {
        final angle = t * (4.0 + i * 0.8) + i * (pi / 2);
        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: radius + 6.0 + i * 4.5),
          angle,
          pi * 0.7,
          false,
          Paint()
            ..color = color.withOpacity(0.65 - i * 0.1)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5 - i * 0.3
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
      // Hot centre
      canvas.drawCircle(
        Offset(cx, cy),
        radius * 0.55 + sin(t * 12) * 3,
        Paint()
          ..color = color.withOpacity(0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
  }
}

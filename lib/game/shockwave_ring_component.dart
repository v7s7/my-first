import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'boss_ball_game.dart';

/// An expanding neon shockwave ring spawned by ShockwaveOrb on every boss hit.
///
/// The ring grows outward at [speed] px/s from the orb's position.
/// When its edge passes through the boss, it deals [bonusDamage] extra.
/// Fades and disappears after [_totalLife] seconds.
class ShockwaveRingComponent extends PositionComponent {
  final BossBallGame gameRef;
  final int bonusDamage;
  final Color ringColor;

  double _radius = 8.0;
  double _life;
  bool   _bonusHit = false;

  static const double speed     = 480.0; // px / s
  static const double maxRadius = 350.0;
  static const double _totalLife = 0.75;

  ShockwaveRingComponent({
    required Vector2 position,
    required this.gameRef,
    required this.bonusDamage,
    this.ringColor = const Color(0xFF00FFEE),
  })  : _life = _totalLife,
        super(
          position: position,
          size: Vector2.all(maxRadius * 2),
          anchor: Anchor.center,
          priority: 6,
        );

  @override
  void update(double dt) {
    _life   -= dt;
    _radius += speed * dt;

    if (_life <= 0 || _radius > maxRadius) {
      removeFromParent();
      return;
    }

    // Fire bonus damage once when ring edge sweeps through boss
    if (!_bonusHit) {
      final bossCenter = gameRef.boss.position;
      final dist       = position.distanceTo(bossCenter);
      final bossR      = gameRef.boss.radius;
      // Ring edge is at _radius from this component's centre
      if ((dist - bossR - _radius).abs() < 28) {
        _bonusHit = true;
        gameRef.onOrbHitBoss(bonusDamage, isLaserTick: true);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final fade = (_life / _totalLife).clamp(0.0, 1.0);
    final cx   = maxRadius;
    final cy   = maxRadius;

    // Outer glow ring
    canvas.drawCircle(
      Offset(cx, cy),
      _radius,
      Paint()
        ..color = ringColor.withOpacity(fade * 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0 * fade
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * fade),
    );
    // Bright core ring
    canvas.drawCircle(
      Offset(cx, cy),
      _radius,
      Paint()
        ..color = ringColor.withOpacity(fade * 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * fade,
    );
  }
}

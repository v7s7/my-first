import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'boss_ball_game.dart';

/// Dangerous projectile fired by the boss at the player's orb.
/// Bounces off arena walls and freezes the orb on impact.
class BossProjectile extends PositionComponent with HasGameRef<BossBallGame> {
  static const double _baseSpeed  = 390.0;
  static const double _hitRadius  = 20.0;
  static const double _maxLife    = 6.0;
  static const double _freezeTime = 1.6;

  final Vector2 _velocity;
  double _life = _maxLife;
  double _time = 0.0;
  bool _hit = false;

  BossProjectile({
    required Vector2 position,
    required Vector2 target,
    double speedMultiplier = 1.0,
  })  : _velocity = _dirTo(position, target) * _baseSpeed * speedMultiplier,
        super(position: position, priority: 8, anchor: Anchor.center);

  static Vector2 _dirTo(Vector2 from, Vector2 to) {
    final d = to - from;
    return d.length > 0.01 ? d.normalized() : Vector2(0, 1);
  }

  @override
  void update(double dt) {
    if (_hit) return;
    _life -= dt;
    _time += dt;
    if (_life <= 0) { removeFromParent(); return; }

    position += _velocity * dt * gameRef.timeWarpMultiplier;

    final arena = gameRef.arenaConfig;
    if (position.x < arena.innerLeft) {
      position.x = arena.innerLeft; _velocity.x = _velocity.x.abs();
    } else if (position.x > arena.innerRight) {
      position.x = arena.innerRight; _velocity.x = -_velocity.x.abs();
    }
    if (position.y < arena.innerTop) {
      position.y = arena.innerTop; _velocity.y = _velocity.y.abs();
    } else if (position.y > arena.innerBottom) {
      position.y = arena.innerBottom; _velocity.y = -_velocity.y.abs();
    }

    // Bounce off internal obstacles (pillars, maze walls, etc.)
    arena.bounceOffObstacles(position, _velocity, _hitRadius);

    for (final orb in gameRef.orbs) {
      if (position.distanceTo(orb.position) < _hitRadius + orb.orbRadius) {
        _hit = true;
        orb.freeze(_freezeTime);
        gameRef.spawnFreezeExplosion(position.clone());
        gameRef.triggerShake(intensity: 16, duration: 0.25);
        removeFromParent();
        return;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final pulse = sin(_time * 10) * 0.15 + 1.0;
    final r = 9.0 * pulse;
    final norm = _velocity.length > 0.01 ? 1.0 / _velocity.length : 0.0;
    final dx = _velocity.x * norm;
    final dy = _velocity.y * norm;

    // Trail
    canvas.drawLine(
      Offset.zero,
      Offset(-dx * 32, -dy * 32),
      Paint()
        ..color = const Color(0xBBCC22FF)
        ..strokeWidth = 7.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    // Outer glow
    canvas.drawCircle(
      Offset.zero, r + 9,
      Paint()
        ..color = const Color(0x66FF2288)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    // Core
    canvas.drawCircle(Offset.zero, r, Paint()..color = const Color(0xFFDD22FF));
    // Hot center
    canvas.drawCircle(Offset.zero, r * 0.45, Paint()..color = Colors.white);
  }
}

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'boss_ball_game.dart';

/// A visible projectile spawned by the Revolver pickup.
/// Travels toward the target position it was aimed at when spawned,
/// then deals damage and triggers a fire explosion on impact.
class BulletComponent extends PositionComponent with HasGameRef<BossBallGame> {
  final int damage;
  final int? pvpVictimIndex; // null = boss target, int = PVP orb index
  final Color color;

  static const double _speed     = 1400.0;
  static const double _hitRadius = 26.0;
  static const double _maxLife   = 3.0;

  final Vector2 _velocity;
  double _lifetime = _maxLife;

  BulletComponent({
    required Vector2 position,
    required Vector2 target,
    required this.damage,
    this.pvpVictimIndex,
    this.color = const Color(0xFFFFCC00),
  })  : _velocity = _dirTo(position, target) * _speed,
        super(position: position, priority: 9, anchor: Anchor.center);

  static Vector2 _dirTo(Vector2 from, Vector2 to) {
    final d = to - from;
    return d.length > 0.01 ? d.normalized() : Vector2(1, 0);
  }

  Vector2? get _currentTargetPos {
    if (pvpVictimIndex != null) {
      final orbs = gameRef.orbs;
      return pvpVictimIndex! < orbs.length ? orbs[pvpVictimIndex!].position : null;
    }
    return gameRef.boss?.position;
  }

  @override
  void update(double dt) {
    _lifetime -= dt;
    if (_lifetime <= 0) {
      removeFromParent();
      return;
    }

    position += _velocity * dt;

    final tgt = _currentTargetPos;
    if (tgt != null && position.distanceTo(tgt) < _hitRadius) {
      _impact();
    }
  }

  void _impact() {
    if (pvpVictimIndex != null) {
      gameRef.onPvpOrbHit(victimIndex: pvpVictimIndex!, damage: damage);
    } else {
      gameRef.onOrbHitBoss(damage);
    }
    gameRef.spawnFireExplosion(position.clone());
    removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final dx = _velocity.x / _speed;
    final dy = _velocity.y / _speed;

    // Glow trail (behind the bullet)
    const trailLen = 24.0;
    final trailEnd = Offset(-dx * trailLen, -dy * trailLen);

    canvas.drawLine(
      Offset.zero,
      trailEnd,
      Paint()
        ..color = color.withOpacity(0.55)
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Bright core trail
    canvas.drawLine(
      Offset.zero,
      Offset(-dx * trailLen * 0.45, -dy * trailLen * 0.45),
      Paint()
        ..color = Colors.white.withOpacity(0.85)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );

    // Outer bullet glow
    canvas.drawCircle(
      Offset.zero,
      9.0,
      Paint()
        ..color = color.withOpacity(0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    // Mid ring
    canvas.drawCircle(
      Offset.zero,
      5.5,
      Paint()..color = color,
    );

    // White hot core
    canvas.drawCircle(
      Offset.zero,
      2.8,
      Paint()..color = Colors.white,
    );
  }
}

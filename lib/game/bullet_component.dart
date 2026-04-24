import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'boss_ball_game.dart';

/// A visible projectile that flies toward a target and deals damage on impact.
/// Use the named factory constructors to create different gun types.
class BulletComponent extends PositionComponent with HasGameRef<BossBallGame> {
  final int damage;
  final int? pvpVictimIndex;
  final Color color;
  final double _bulletSpeed;
  final double _hitRadius;
  final double _visualScale;
  final double? _maxRange;
  final bool _bigExplosion;

  static const double _maxLife = 3.0;

  final Vector2 _velocity;
  double _lifetime = _maxLife;
  double _distTraveled = 0.0;

  BulletComponent._({
    required Vector2 position,
    required Vector2 target,
    required this.damage,
    this.pvpVictimIndex,
    required this.color,
    double speed = 1400.0,
    double hitRadius = 26.0,
    double visualScale = 1.0,
    double? maxRange,
    bool bigExplosion = false,
    double spreadAngleRad = 0.0,
  })  : _bulletSpeed = speed,
        _hitRadius = hitRadius,
        _visualScale = visualScale,
        _maxRange = maxRange,
        _bigExplosion = bigExplosion,
        _velocity = _dirTo(position, target, spreadAngleRad) * speed,
        super(position: position, priority: 9, anchor: Anchor.center);

  // ── Gun-type factory constructors ─────────────────────────────────────────

  /// Standard bullet for boss-fight revolver (non-PVP).
  factory BulletComponent.boss({
    required Vector2 position,
    required Vector2 target,
    int damage = 28000,
  }) =>
      BulletComponent._(
        position: position,
        target: target,
        damage: damage,
        color: const Color(0xFFFFCC00),
        speed: 1400.0,
        hitRadius: 26.0,
      );

  /// PVP pistol — steady 6-shot burst, balanced damage.
  factory BulletComponent.pistol({
    required Vector2 position,
    required Vector2 target,
    required int? pvpVictimIndex,
  }) =>
      BulletComponent._(
        position: position,
        target: target,
        damage: 20000,
        pvpVictimIndex: pvpVictimIndex,
        color: const Color(0xFFFFCC00),
        speed: 1400.0,
        hitRadius: 26.0,
      );

  /// PVP shotgun pellet — short range, fires in a spread pattern.
  factory BulletComponent.shotgunPellet({
    required Vector2 position,
    required Vector2 target,
    required int? pvpVictimIndex,
    double spreadAngleRad = 0.0,
  }) =>
      BulletComponent._(
        position: position,
        target: target,
        damage: 14000,
        pvpVictimIndex: pvpVictimIndex,
        color: const Color(0xFFFF6600),
        speed: 900.0,
        hitRadius: 22.0,
        maxRange: 380.0,
        spreadAngleRad: spreadAngleRad,
      );

  /// PVP sniper — one-shot, extreme speed and damage.
  factory BulletComponent.sniper({
    required Vector2 position,
    required Vector2 target,
    required int? pvpVictimIndex,
  }) =>
      BulletComponent._(
        position: position,
        target: target,
        damage: 180000,
        pvpVictimIndex: pvpVictimIndex,
        color: const Color(0xFF00EEFF),
        speed: 3200.0,
        hitRadius: 18.0,
        visualScale: 0.75,
      );

  /// PVP machine gun — rapid fire, each bullet deals moderate damage.
  factory BulletComponent.machineGun({
    required Vector2 position,
    required Vector2 target,
    required int? pvpVictimIndex,
    double spreadAngleRad = 0.0,
  }) =>
      BulletComponent._(
        position: position,
        target: target,
        damage: 5000,
        pvpVictimIndex: pvpVictimIndex,
        color: const Color(0xFFFF3300),
        speed: 1300.0,
        hitRadius: 20.0,
        spreadAngleRad: spreadAngleRad,
      );

  /// PVP rocket — slow, massive damage, huge explosion on impact.
  factory BulletComponent.rocket({
    required Vector2 position,
    required Vector2 target,
    required int? pvpVictimIndex,
  }) =>
      BulletComponent._(
        position: position,
        target: target,
        damage: 200000,
        pvpVictimIndex: pvpVictimIndex,
        color: const Color(0xFFFF2200),
        speed: 480.0,
        hitRadius: 40.0,
        visualScale: 2.2,
        bigExplosion: true,
      );

  /// PVP grenade — slow arcing shot, massive explosion, 3 rounds.
  factory BulletComponent.grenade({
    required Vector2 position,
    required Vector2 target,
    required int? pvpVictimIndex,
  }) =>
      BulletComponent._(
        position: position,
        target: target,
        damage: 120000,
        pvpVictimIndex: pvpVictimIndex,
        color: const Color(0xFF88FF00),
        speed: 520.0,
        hitRadius: 36.0,
        visualScale: 1.8,
        bigExplosion: true,
      );

  /// PVP burst — 3-round tight spread, fires in sets of 3.
  factory BulletComponent.burst({
    required Vector2 position,
    required Vector2 target,
    required int? pvpVictimIndex,
    double spreadAngleRad = 0.0,
  }) =>
      BulletComponent._(
        position: position,
        target: target,
        damage: 18000,
        pvpVictimIndex: pvpVictimIndex,
        color: const Color(0xFFFFAA00),
        speed: 1600.0,
        hitRadius: 24.0,
        spreadAngleRad: spreadAngleRad,
      );

  /// PVP minigun — rapid-fire light rounds with spread.
  factory BulletComponent.minigun({
    required Vector2 position,
    required Vector2 target,
    required int? pvpVictimIndex,
    double spreadAngleRad = 0.0,
  }) =>
      BulletComponent._(
        position: position,
        target: target,
        damage: 4000,
        pvpVictimIndex: pvpVictimIndex,
        color: const Color(0xFFFF5500),
        speed: 1500.0,
        hitRadius: 18.0,
        visualScale: 0.65,
        spreadAngleRad: spreadAngleRad,
      );

  /// PVP railgun — single instant penetrating shot, very high damage.
  factory BulletComponent.railgun({
    required Vector2 position,
    required Vector2 target,
    required int? pvpVictimIndex,
  }) =>
      BulletComponent._(
        position: position,
        target: target,
        damage: 240000,
        pvpVictimIndex: pvpVictimIndex,
        color: const Color(0xFF00FFCC),
        speed: 4500.0,
        hitRadius: 16.0,
        visualScale: 0.55,
      );

  // ── Internals ─────────────────────────────────────────────────────────────

  static Vector2 _dirTo(Vector2 from, Vector2 to, double spreadAngleRad) {
    final d = to - from;
    final base = d.length > 0.01 ? d.normalized() : Vector2(1, 0);
    if (spreadAngleRad == 0.0) return base;
    final angle = atan2(base.y, base.x) + spreadAngleRad;
    return Vector2(cos(angle), sin(angle));
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

    final step = _velocity * dt;
    position += step;
    _distTraveled += step.length;

    if (_maxRange != null && _distTraveled >= _maxRange!) {
      removeFromParent();
      return;
    }

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
    if (_bigExplosion) {
      gameRef.spawnRocketExplosion(position.clone());
    } else {
      gameRef.spawnFireExplosion(position.clone());
    }
    removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final norm = _bulletSpeed > 0 ? 1.0 / _bulletSpeed : 1.0;
    final dx = _velocity.x * norm;
    final dy = _velocity.y * norm;
    final s = _visualScale;

    final trailLen = 24.0 * s;
    final trailEnd = Offset(-dx * trailLen, -dy * trailLen);

    // Glow trail
    canvas.drawLine(
      Offset.zero,
      trailEnd,
      Paint()
        ..color = color.withOpacity(0.55)
        ..strokeWidth = 5.0 * s
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * s),
    );

    // Bright core trail
    canvas.drawLine(
      Offset.zero,
      Offset(-dx * trailLen * 0.45, -dy * trailLen * 0.45),
      Paint()
        ..color = Colors.white.withOpacity(0.85)
        ..strokeWidth = 2.2 * s
        ..strokeCap = StrokeCap.round,
    );

    // Outer bullet glow
    canvas.drawCircle(
      Offset.zero,
      9.0 * s,
      Paint()
        ..color = color.withOpacity(0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 7 * s),
    );

    // Mid ring
    canvas.drawCircle(Offset.zero, 5.5 * s, Paint()..color = color);

    // White hot core
    canvas.drawCircle(Offset.zero, 2.8 * s, Paint()..color = Colors.white);
  }
}

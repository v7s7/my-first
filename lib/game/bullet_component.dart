import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'boss_ball_game.dart';

enum _BShape { round, pellet, needle, small, missile, sphere, medium, tiny, beam }

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
  final bool _homing;
  final _BShape _shape;

  static const double _maxLife = 8.0; // extended so all bullets hit

  Vector2 _velocity;
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
    bool homing = false,
    _BShape shape = _BShape.round,
  })  : _bulletSpeed = speed,
        _hitRadius = hitRadius,
        _visualScale = visualScale,
        _maxRange = maxRange,
        _bigExplosion = bigExplosion,
        _homing = homing,
        _shape = shape,
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
        homing: true,
        shape: _BShape.round,
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
        homing: true,
        shape: _BShape.round,
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
        maxRange: 480.0,
        spreadAngleRad: spreadAngleRad,
        homing: true,
        shape: _BShape.pellet,
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
        hitRadius: 22.0,
        homing: true,
        shape: _BShape.needle,
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
        homing: true,
        shape: _BShape.small,
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
        bigExplosion: true,
        homing: true,
        shape: _BShape.missile,
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
        bigExplosion: true,
        homing: true,
        shape: _BShape.sphere,
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
        homing: true,
        shape: _BShape.medium,
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
        spreadAngleRad: spreadAngleRad,
        homing: true,
        shape: _BShape.tiny,
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
        hitRadius: 20.0,
        homing: true,
        shape: _BShape.beam,
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

    // Strong homing: bullets aggressively track the target for guaranteed hits
    if (_homing) {
      final tgt = _currentTargetPos;
      if (tgt != null) {
        final toTarget = tgt - position;
        if (toTarget.length > 5.0) {
          final desired = toTarget.normalized() * _bulletSpeed;
          _velocity += (desired - _velocity) * (dt * 22.0);
          if (_velocity.length > 0.01) {
            _velocity = _velocity.normalized() * _bulletSpeed;
          }
        }
      }
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
    final angle = atan2(_velocity.y, _velocity.x);

    // Rotate canvas so +x = direction of travel for all shape drawing
    canvas.save();
    canvas.rotate(angle);
    _renderShape(canvas, dx, dy);
    canvas.restore();
  }

  void _renderShape(Canvas canvas, double dx, double dy) {
    final c = color;
    switch (_shape) {
      case _BShape.round: // Pistol — classic bullet: oval body + glowing trail
        _trail(canvas, 22, 4.5, c);
        canvas.drawOval(
            Rect.fromCenter(center: Offset.zero, width: 14, height: 8),
            Paint()..color = c);
        canvas.drawOval(
            Rect.fromCenter(center: Offset.zero, width: 14, height: 8),
            Paint()
              ..color = c.withOpacity(0.4)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
        canvas.drawCircle(Offset.zero, 3, Paint()..color = Colors.white);

      case _BShape.pellet: // Shotgun — small bright sphere
        _trail(canvas, 12, 3.5, c);
        canvas.drawCircle(Offset.zero, 5,
            Paint()..color = c.withOpacity(0.5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
        canvas.drawCircle(Offset.zero, 4, Paint()..color = c);
        canvas.drawCircle(Offset.zero, 2, Paint()..color = Colors.white);

      case _BShape.needle: // Sniper — long thin needle
        _trail(canvas, 35, 2.5, c);
        // Glow
        canvas.drawLine(Offset(-20, 0), Offset(8, 0),
            Paint()..color = c.withOpacity(0.5)..strokeWidth = 6..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
        // Sharp needle body
        canvas.drawLine(Offset(-20, 0), Offset(8, 0),
            Paint()..color = Colors.white..strokeWidth = 2..strokeCap = StrokeCap.round);
        // Bright tip
        canvas.drawCircle(const Offset(8, 0), 2.5, Paint()..color = c);

      case _BShape.small: // Machine gun — compact fast round
        _trail(canvas, 16, 3.5, c);
        canvas.drawOval(
            Rect.fromCenter(center: Offset.zero, width: 10, height: 6),
            Paint()..color = c);
        canvas.drawCircle(Offset.zero, 2.2, Paint()..color = Colors.white);

      case _BShape.missile: // Rocket — elongated missile with flame tail
        // Flame exhaust (behind missile = negative x)
        canvas.drawCircle(const Offset(-18, 0), 7,
            Paint()..color = Colors.orange.withOpacity(0.6)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
        canvas.drawCircle(const Offset(-14, 0), 4,
            Paint()..color = Colors.yellow.withOpacity(0.8)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
        // Missile body
        final bodyPath = Path()
          ..moveTo(16, 0) // nose tip
          ..lineTo(6, -5)
          ..lineTo(-14, -4)
          ..lineTo(-18, 0)
          ..lineTo(-14, 4)
          ..lineTo(6, 5)
          ..close();
        canvas.drawPath(bodyPath, Paint()..color = c);
        // Fins
        canvas.drawPath(
          Path()..moveTo(-10, -4)..lineTo(-18, -10)..lineTo(-14, -4),
          Paint()..color = c.withOpacity(0.8));
        canvas.drawPath(
          Path()..moveTo(-10, 4)..lineTo(-18, 10)..lineTo(-14, 4),
          Paint()..color = c.withOpacity(0.8));
        // Nose glow
        canvas.drawCircle(const Offset(16, 0), 3,
            Paint()..color = Colors.white.withOpacity(0.9));

      case _BShape.sphere: // Grenade — round green ball with cross line
        canvas.drawCircle(Offset.zero, 9,
            Paint()..color = c.withOpacity(0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
        canvas.drawCircle(Offset.zero, 8, Paint()..color = c);
        canvas.drawCircle(Offset.zero, 8,
            Paint()..color = Colors.black.withOpacity(0.25)..style = PaintingStyle.stroke..strokeWidth = 1.5);
        canvas.drawLine(const Offset(-8, 0), const Offset(8, 0),
            Paint()..color = Colors.black.withOpacity(0.3)..strokeWidth = 1.2);
        canvas.drawCircle(Offset.zero, 3, Paint()..color = Colors.white.withOpacity(0.7));

      case _BShape.medium: // Burst rifle — medium tapered bullet
        _trail(canvas, 20, 4, c);
        final path = Path()
          ..moveTo(10, 0) // nose
          ..lineTo(2, -4)
          ..lineTo(-10, -3)
          ..lineTo(-10, 3)
          ..lineTo(2, 4)
          ..close();
        canvas.drawPath(path, Paint()..color = c);
        canvas.drawPath(path,
            Paint()..color = c.withOpacity(0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
        canvas.drawCircle(const Offset(8, 0), 2, Paint()..color = Colors.white);

      case _BShape.tiny: // Minigun — tiny dot with bright glow
        canvas.drawCircle(Offset.zero, 5,
            Paint()..color = c.withOpacity(0.5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
        canvas.drawCircle(Offset.zero, 3, Paint()..color = c);
        canvas.drawCircle(Offset.zero, 1.5, Paint()..color = Colors.white);

      case _BShape.beam: // Railgun — thin crackling energy beam
        // Outer glow
        canvas.drawLine(const Offset(-28, 0), const Offset(10, 0),
            Paint()..color = c.withOpacity(0.35)..strokeWidth = 10..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
        // Core beam
        canvas.drawLine(const Offset(-28, 0), const Offset(10, 0),
            Paint()..color = c..strokeWidth = 3..strokeCap = StrokeCap.round);
        // White hot center line
        canvas.drawLine(const Offset(-28, 0), const Offset(10, 0),
            Paint()..color = Colors.white..strokeWidth = 1.2);
        // Tip spark
        canvas.drawCircle(const Offset(10, 0), 4,
            Paint()..color = Colors.white.withOpacity(0.9)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }
  }

  // Draws a glowing speed trail behind the bullet (in rotated local space,
  // trail goes in -x direction from origin).
  static void _trail(Canvas canvas, double len, double width, Color c) {
    canvas.drawLine(
      Offset.zero, Offset(-len, 0),
      Paint()
        ..color = c.withOpacity(0.5)
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.9),
    );
    canvas.drawLine(
      Offset.zero, Offset(-len * 0.4, 0),
      Paint()
        ..color = Colors.white.withOpacity(0.8)
        ..strokeWidth = width * 0.45
        ..strokeCap = StrokeCap.round,
    );
  }
}

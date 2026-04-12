import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'boss_ball_game.dart';
import 'boss_component.dart';
import 'game_state.dart';
import 'laser_beam.dart';

class PlayerOrb extends PositionComponent {
  final OrbType orbType;
  final BossBallGame gameRef;

  static const double radius = 18.0;
  static const double baseSpeed = 280.0;
  static const double speedGrowthPerBounce = 0.03; // +3% per bounce
  static const double maxSpeed = 900.0;
  static const double laserDuration = 1.0;
  static const double laserTickRate = 0.05; // damage every 50ms
  static const int laserTickDamage = 500;   // 20 ticks × 500 = 10K total
  static const double hitCooldown = 0.3;

  double _speed = baseSpeed;
  late Vector2 _velocity;
  final Random _rng = Random();

  // Combo orb: wall bounces since last boss hit
  int _wallBounces = 0;

  // Laser orb state
  bool _laserActive = false;
  double _laserTimer = 0.0;
  double _laserTickTimer = 0.0;
  LaserBeam? _activeLaser;

  // Boss hit cooldown
  double _hitCooldownTimer = 0.0;

  // Bounce squash animation
  double _bounceSquashTimer = 0.0;

  PlayerOrb({required this.orbType, required this.gameRef})
      : super(
          size: Vector2.all(radius * 2),
          anchor: Anchor.center,
          priority: 10,
        );

  @override
  Future<void> onLoad() async {
    // Start near top-left quadrant, clear of boss
    position = Vector2(
      gameRef.size.x * (0.15 + _rng.nextDouble() * 0.15),
      gameRef.size.y * (0.12 + _rng.nextDouble() * 0.12),
    );

    // Random launch angle roughly aimed toward center-right
    final angle = (pi * 0.25) + _rng.nextDouble() * (pi * 0.5);
    _velocity = Vector2(cos(angle), sin(angle)) * _speed;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!gameRef.playing) return;

    if (_hitCooldownTimer > 0) _hitCooldownTimer -= dt;
    if (_bounceSquashTimer > 0) _bounceSquashTimer -= dt;

    // Laser tick damage
    if (_laserActive) {
      _laserTimer -= dt;
      _laserTickTimer -= dt;

      // Update beam position each frame
      _activeLaser?.startPos = position;
      _activeLaser?.endPos = gameRef.boss.position;
      _activeLaser?.timeLeft = _laserTimer;

      if (_laserTickTimer <= 0) {
        _laserTickTimer = laserTickRate;
        gameRef.onOrbHitBoss(laserTickDamage, isLaserTick: true);
      }

      if (_laserTimer <= 0) {
        _laserActive = false;
        _activeLaser?.removeFromParent();
        _activeLaser = null;
      }
    }

    // Physics: move and bounce
    position += _velocity * dt;
    _handleWallBounce();

    // Boss collision
    if (_hitCooldownTimer <= 0) {
      _checkBossCollision();
    }
  }

  void _handleWallBounce() {
    final t = BossBallGame.wallThickness;
    final minX = t + radius;
    final maxX = gameRef.size.x - t - radius;
    final minY = t + radius;
    final maxY = gameRef.size.y - t - radius;

    bool bounced = false;

    if (position.x <= minX) {
      position.x = minX;
      _velocity.x = _velocity.x.abs();
      bounced = true;
    } else if (position.x >= maxX) {
      position.x = maxX;
      _velocity.x = -_velocity.x.abs();
      bounced = true;
    }

    if (position.y <= minY) {
      position.y = minY;
      _velocity.y = _velocity.y.abs();
      bounced = true;
    } else if (position.y >= maxY) {
      position.y = maxY;
      _velocity.y = -_velocity.y.abs();
      bounced = true;
    }

    if (bounced) {
      // Accelerate
      _speed = min(_speed * (1.0 + speedGrowthPerBounce), maxSpeed);
      _velocity = _velocity.normalized() * _speed;

      if (orbType == OrbType.combo) _wallBounces++;
      _bounceSquashTimer = 0.08;

      gameRef.triggerShake(intensity: 1.5, duration: 0.05);
    }
  }

  void _checkBossCollision() {
    final dist = position.distanceTo(gameRef.boss.position);
    if (dist >= BossComponent.radius + radius) return;

    // Push orb away from boss surface
    final dir = (position - gameRef.boss.position).normalized();
    position = gameRef.boss.position + dir * (BossComponent.radius + radius + 1.0);
    _velocity = dir * _speed;

    _hitCooldownTimer = hitCooldown;
    _onBossHit();
  }

  void _onBossHit() {
    gameRef.boss.triggerHitAnimation();

    switch (orbType) {
      case OrbType.basic:
        gameRef.onOrbHitBoss(1000);

      case OrbType.laser:
        if (!_laserActive) {
          _laserActive = true;
          _laserTimer = laserDuration;
          _laserTickTimer = 0;
          _activeLaser = LaserBeam(
            startPos: position.clone(),
            endPos: gameRef.boss.position.clone(),
            totalDuration: laserDuration,
            timeLeft: laserDuration,
          );
          gameRef.add(_activeLaser!);
        }

      case OrbType.combo:
        final bounces = _wallBounces.clamp(0, 10);
        final multiplier = bounces > 0 ? pow(2, bounces).toInt() : 1;
        gameRef.onOrbHitBoss(500 * multiplier);
        _wallBounces = 0;
    }
  }

  Color get _color {
    switch (orbType) {
      case OrbType.basic: return const Color(0xFF00FFEE);
      case OrbType.laser: return const Color(0xFFFF4400);
      case OrbType.combo: return const Color(0xFFCC44FF);
    }
  }

  @override
  void render(Canvas canvas) {
    final squash = _bounceSquashTimer > 0 ? 1.15 : 1.0;
    final stretch = _bounceSquashTimer > 0 ? 0.88 : 1.0;
    final laserFlash = _laserActive ? 1.3 : 1.0;
    final drawRadius = radius * laserFlash;
    final cx = radius;
    final cy = radius;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(squash, stretch);
    canvas.translate(-cx, -cy);

    final color = _color;

    // Outer glow
    canvas.drawCircle(
      Offset(cx, cy),
      drawRadius + 10,
      Paint()
        ..color = Color.fromARGB(100, color.red, color.green, color.blue)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // Core body
    canvas.drawCircle(
      Offset(cx, cy),
      drawRadius,
      Paint()..color = color,
    );

    // Shine
    canvas.drawCircle(
      Offset(cx - drawRadius * 0.32, cy - drawRadius * 0.32),
      drawRadius * 0.32,
      Paint()..color = const Color(0x88FFFFFF),
    );

    // Rim
    canvas.drawCircle(
      Offset(cx, cy),
      drawRadius,
      Paint()
        ..color = const Color(0x66FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    canvas.restore();

    // Combo multiplier badge
    if (orbType == OrbType.combo && _wallBounces > 0) {
      final multi = pow(2, _wallBounces.clamp(0, 10)).toInt();
      final tp = TextPainter(
        text: TextSpan(
          text: 'x$multi',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx + drawRadius + 3, cy - 7));
    }
  }
}

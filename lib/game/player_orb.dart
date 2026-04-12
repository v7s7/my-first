import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'boss_ball_game.dart';
import 'boss_component.dart';
import '../orbs/orb_behavior.dart';

/// Physics shell for the player's bouncing orb.
///
/// This class owns ONLY what is universal to every orb:
///   - position, velocity, speed ramp
///   - elastic wall-bounce geometry
///   - boss-collision geometry (distance check, push-out, cooldown)
///   - shared base-sphere rendering (glow, body, shine, rim)
///   - bounce squash animation
///
/// Everything that varies per orb type is delegated to [behavior].
/// To add a new orb, create a new [OrbBehavior] subclass — no edits here.
class PlayerOrb extends PositionComponent {
  final OrbBehavior behavior;
  final BossBallGame gameRef;

  static const double radius = 18.0;
  static const double baseSpeed = 280.0;
  static const double speedGrowthPerBounce = 0.03;
  static const double maxSpeed = 900.0;
  static const double hitCooldown = 0.3;

  // Package-accessible so OrbBehavior subclasses can read/mutate if needed.
  double speed = baseSpeed;
  late Vector2 velocity;

  final Random _rng = Random();
  double _hitCooldownTimer = 0.0;
  double _bounceSquashTimer = 0.0;

  PlayerOrb({required this.behavior, required this.gameRef})
      : super(
          size: Vector2.all(radius * 2),
          anchor: Anchor.center,
          priority: 10,
        );

  @override
  Future<void> onLoad() async {
    position = Vector2(
      gameRef.size.x * (0.15 + _rng.nextDouble() * 0.15),
      gameRef.size.y * (0.12 + _rng.nextDouble() * 0.12),
    );
    final angle = (pi * 0.25) + _rng.nextDouble() * (pi * 0.5);
    velocity = Vector2(cos(angle), sin(angle)) * speed;

    behavior.onAttach(this);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!gameRef.playing) return;

    if (_hitCooldownTimer > 0) _hitCooldownTimer -= dt;
    if (_bounceSquashTimer > 0) _bounceSquashTimer -= dt;

    behavior.onUpdate(dt, this);

    position += velocity * dt;
    _handleWallBounce();

    if (_hitCooldownTimer <= 0) _checkBossCollision();
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
      velocity.x = velocity.x.abs();
      bounced = true;
    } else if (position.x >= maxX) {
      position.x = maxX;
      velocity.x = -velocity.x.abs();
      bounced = true;
    }

    if (position.y <= minY) {
      position.y = minY;
      velocity.y = velocity.y.abs();
      bounced = true;
    } else if (position.y >= maxY) {
      position.y = maxY;
      velocity.y = -velocity.y.abs();
      bounced = true;
    }

    if (bounced) {
      speed = min(speed * (1.0 + speedGrowthPerBounce), maxSpeed);
      velocity = velocity.normalized() * speed;
      _bounceSquashTimer = 0.08;
      gameRef.triggerShake(intensity: 1.5, duration: 0.05);
      behavior.onWallBounce(this);
    }
  }

  void _checkBossCollision() {
    final dist = position.distanceTo(gameRef.boss.position);
    if (dist >= BossComponent.radius + radius) return;

    final dir = (position - gameRef.boss.position).normalized();
    position = gameRef.boss.position + dir * (BossComponent.radius + radius + 1.0);
    velocity = dir * speed;

    _hitCooldownTimer = hitCooldown;
    gameRef.boss.triggerHitAnimation();
    behavior.onBossHit(this);
  }

  @override
  void render(Canvas canvas) {
    final squash = _bounceSquashTimer > 0 ? 1.15 : 1.0;
    final stretch = _bounceSquashTimer > 0 ? 0.88 : 1.0;
    const cx = radius;
    const cy = radius;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(squash, stretch);
    canvas.translate(-cx, -cy);

    final color = behavior.color;

    // Outer glow
    canvas.drawCircle(
      const Offset(cx, cy),
      radius + 10,
      Paint()
        ..color = Color.fromARGB(100, color.red, color.green, color.blue)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // Core body
    canvas.drawCircle(const Offset(cx, cy), radius, Paint()..color = color);

    // Shine
    canvas.drawCircle(
      const Offset(cx - radius * 0.32, cy - radius * 0.32),
      radius * 0.32,
      Paint()..color = const Color(0x88FFFFFF),
    );

    // Rim
    canvas.drawCircle(
      const Offset(cx, cy),
      radius,
      Paint()
        ..color = const Color(0x66FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    canvas.restore();

    // Orb-specific overlay (combo badge, laser ring, etc.)
    behavior.renderOverlay(canvas, radius, cx, cy);
  }
}

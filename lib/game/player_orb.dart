import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'boss_ball_game.dart';
import 'boss_component.dart';
import 'arena_config.dart';
import '../orbs/orb_behavior.dart';

/// Physics shell for the player's bouncing orb.
///
/// Owns: position, velocity, speed ramp, wall-bounce geometry,
/// two-body elastic collision with the boss, base sphere rendering,
/// and bounce squash animation.
///
/// All orb-type-specific logic is delegated to [behavior].
class PlayerOrb extends PositionComponent {
  final OrbBehavior behavior;
  final BossBallGame gameRef;
  final ArenaConfig arena;

  static const double radius = 18.0;
  static const double baseSpeed = 280.0;
  static const double speedGrowthPerBounce = 0.03;
  static const double maxSpeed = 900.0;
  static const double hitCooldown = 0.25; // seconds between damage events

  // Package-accessible — OrbBehavior subclasses can read/modify these.
  double speed = baseSpeed;
  late Vector2 velocity;

  final Random _rng = Random();
  double _hitCooldownTimer = 0.0;
  double _bounceSquashTimer = 0.0;

  PlayerOrb({
    required this.behavior,
    required this.gameRef,
    required this.arena,
  }) : super(
          size: Vector2.all(radius * 2),
          anchor: Anchor.center,
          priority: 10,
        );

  // ── Flame lifecycle ────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    // Spawn in the upper portion of the arena, away from the boss
    position = Vector2(
      arena.minX(radius) + _rng.nextDouble() * (arena.maxX(radius) - arena.minX(radius)) * 0.35,
      arena.minY(radius) + _rng.nextDouble() * (arena.maxY(radius) - arena.minY(radius)) * 0.25,
    );

    // Random angle aimed roughly toward center-right
    final angle = (pi * 0.2) + _rng.nextDouble() * (pi * 0.6);
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

    // Physics collision runs every frame (separation + impulse).
    // Damage is gated by _hitCooldownTimer inside _resolveCollision.
    _resolveCollision();
  }

  // ── Physics ────────────────────────────────────────────────────────────────

  void _handleWallBounce() {
    bool bounced = false;

    if (position.x <= arena.minX(radius)) {
      position.x = arena.minX(radius);
      velocity.x = velocity.x.abs();
      bounced = true;
    } else if (position.x >= arena.maxX(radius)) {
      position.x = arena.maxX(radius);
      velocity.x = -velocity.x.abs();
      bounced = true;
    }

    if (position.y <= arena.minY(radius)) {
      position.y = arena.minY(radius);
      velocity.y = velocity.y.abs();
      bounced = true;
    } else if (position.y >= arena.maxY(radius)) {
      position.y = arena.maxY(radius);
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

    // Obstacle collision (pillars / maze walls)
    if (arena.bounceOffObstacles(position, velocity, radius)) {
      speed = min(speed * (1.0 + speedGrowthPerBounce), maxSpeed);
      if (velocity.length > 0.01) velocity = velocity.normalized() * speed;
      _bounceSquashTimer = 0.08;
      gameRef.triggerShake(intensity: 1.5, duration: 0.05);
      behavior.onWallBounce(this);
    }
  }

  /// Two-body elastic collision between orb (mass 1) and boss (mass [BossComponent.mass]).
  ///
  /// Runs every frame. Separates overlapping circles first, then exchanges
  /// momentum along the collision normal. Damage is only applied once per
  /// cooldown window.
  void _resolveCollision() {
    final boss = gameRef.boss;
    final dist = position.distanceTo(boss.position);
    final minDist = BossComponent.radius + radius;

    if (dist >= minDist) return;

    // ── Step 1: Positional separation (prevent overlap) ──────────────────────
    final n = dist < 0.001
        ? Vector2(1, 0) // degenerate case: same position
        : (position - boss.position).normalized();

    final overlap = minDist - dist;
    const m1 = 1.0;
    const m2 = BossComponent.mass;
    const total = m1 + m2;

    position += n * (overlap * m2 / total);
    boss.position -= n * (overlap * m1 / total);

    // Clamp both back into arena after separation
    position = arena.clamp(position, radius);
    boss.position = arena.clamp(boss.position, BossComponent.radius);

    // ── Step 2: Impulse exchange (elastic collision) ──────────────────────────
    // n = boss→orb (outward). relVel < 0 means orb and boss are approaching.
    final relVel = (velocity - boss.velocity).dot(n);
    if (relVel < 0) {
      // j = impulse scalar (positive)
      final j = 2.0 * m1 * m2 * (-relVel) / total;
      velocity = velocity + n * (j / m1);       // push orb away from boss (+n)
      boss.applyImpulse(-n * (j / m2));          // push boss in -n direction

      // Keep the orb from going dead (minimum speed guarantee)
      if (velocity.length < speed * 0.3) {
        velocity = velocity.length < 0.01
            ? n * (speed * 0.5)
            : velocity.normalized() * (speed * 0.45);
      }
    }

    // ── Step 3: Damage event (cooldown-gated) ────────────────────────────────
    if (_hitCooldownTimer <= 0) {
      _hitCooldownTimer = hitCooldown;
      behavior.onBossHit(this);
    }
  }

  // ── Rendering ──────────────────────────────────────────────────────────────

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

    // Orb-type overlay (combo badge, laser ring, etc.)
    behavior.renderOverlay(canvas, radius, cx, cy);
  }
}

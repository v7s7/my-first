import 'dart:collection';
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'boss_ball_game.dart';
import 'boss_component.dart';
import 'arena_config.dart';
import '../orbs/orb_behavior.dart';

/// Physics shell for the player's bouncing orb.
class PlayerOrb extends PositionComponent {
  final OrbBehavior behavior;
  final BossBallGame gameRef;
  final ArenaConfig arena;

  static const double radius = 18.0;
  static const double baseSpeed = 280.0;
  static const double speedGrowthPerBounce = 0.03;
  static const double maxSpeed = 900.0;
  static const double hitCooldown = 0.25; // ثواني بين كل ضرر والآخر

  double speed = baseSpeed;
  double speedMultiplier = 1.0; // multiplied by Speed pickup
  late Vector2 velocity;

  final Random _rng = Random();
  double _hitCooldownTimer = 0.0;
  double _bounceSquashTimer = 0.0;

  // 🔴 قائمة لتخزين المواقع السابقة للكرة لرسم الذيل الحركي
  final Queue<Vector2> _trail = Queue<Vector2>();
  static const int _maxTrailLength = 24;

  PlayerOrb({
    required this.behavior,
    required this.gameRef,
    required this.arena,
  }) : super(
          size: Vector2.all(radius * 2),
          anchor: Anchor.center,
          priority: 10,
        );

  @override
  Future<void> onLoad() async {
    // تحديد موقع بداية الكرة داخل الميدان
    position = Vector2(
      arena.minX(radius) + _rng.nextDouble() * (arena.maxX(radius) - arena.minX(radius)) * 0.35,
      arena.minY(radius) + _rng.nextDouble() * (arena.maxY(radius) - arena.minY(radius)) * 0.25,
    );

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

    // Update motion trail
    _trail.addFirst(position.clone());
    if (_trail.length > _maxTrailLength) {
      _trail.removeLast();
    }

    behavior.onUpdate(dt, this);

    // Hook Orb homing behavior
    if (behavior.id == 'hook') {
      final bossPos = gameRef.boss.position;
      final distanceToBoss = position.distanceTo(bossPos);
      
      if (distanceToBoss < 400) {
        final directionToBoss = (bossPos - position).normalized();
        velocity.lerp(directionToBoss * speed, dt * 2.5);
        velocity = velocity.normalized() * speed;
      }
    }

    position += velocity * dt * speedMultiplier;
    
    _handleWallBounce();
    _resolveCollision();
  }

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

    // الاصطدام مع الجدران الداخلية والعقبات في الميدان
    if (arena.bounceOffObstacles(position, velocity, radius)) {
      speed = min(speed * (1.0 + speedGrowthPerBounce), maxSpeed);
      if (velocity.length > 0.01) velocity = velocity.normalized() * speed;
      _bounceSquashTimer = 0.08;
      gameRef.triggerShake(intensity: 1.5, duration: 0.05);
      behavior.onWallBounce(this);
    }
  }

  void _resolveCollision() {
    final boss = gameRef.boss;
    final dist = position.distanceTo(boss.position);
    final minDist = boss.radius + radius;

    if (dist >= minDist) return;

    final n = dist < 0.001
        ? Vector2(1, 0)
        : (position - boss.position).normalized();

    final overlap = minDist - dist;
    position += n * overlap;
    position = arena.clamp(position, radius);

    // Calculate relative velocity and apply collision physics
    final relVel = velocity - boss.velocity;
    final velAlongNormal = relVel.dot(n);

    if (velAlongNormal < 0) {
      // Bounce with realistic physics
      const m1 = 1.0; // Orb mass
      final m2 = BossComponent.mass; // Boss mass
      
      // Impulse calculation
      final restitution = 0.8; // Bounciness
      final j = -(1.0 + restitution) * velAlongNormal / (m1 + m2);
      
      // Apply impulse to orb
      final impulse = n * j;
      velocity = velocity + impulse * m2;
      
      // Apply impulse to boss
      boss.velocity = boss.velocity - impulse * m1 * 0.7;
      
      // Maintain orb speed
      if (velocity.length < speed * 0.3) {
        velocity = velocity.length < 0.01
            ? n * (speed * 0.5)
            : velocity.normalized() * (speed * 0.45);
      }
    }

    if (_hitCooldownTimer <= 0) {
      _hitCooldownTimer = hitCooldown;
      behavior.onBossHit(this);
    }
  }

  @override
  void render(Canvas canvas) {
    const cx = radius;
    const cy = radius;

    // 🔴 رسم الذيل الحركي أولاً ليكون خلف الكرة
    int i = 0;
    for (final trailPos in _trail) {
      final progress = i / _trail.length; // قيمة من 0 إلى 1
      final trailOpacity = (1.0 - progress) * 0.65;
      final trailRadius = radius * (1.0 - progress * 0.6);

      // تحويل إحداثيات الذيل العالمية إلى إحداثيات محلية ليتم رسمها في المكان الصحيح
      final dx = trailPos.x - position.x;
      final dy = trailPos.y - position.y;

      canvas.drawCircle(
        Offset(cx + dx, cy + dy),
        trailRadius,
        Paint()
          ..color = behavior.color.withOpacity(trailOpacity)
          ..blendMode = BlendMode.screen,
      );
      i++;
    }

    // Bounce squash effect
    final squash = _bounceSquashTimer > 0 ? 1.15 : 1.0;
    final stretch = _bounceSquashTimer > 0 ? 0.88 : 1.0;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(squash, stretch);
    canvas.translate(-cx, -cy);

    final color = behavior.color;

    // Speed-reactive outer glow — intensifies and expands as ball accelerates
    final speedRatio = (speed / maxSpeed).clamp(0.25, 1.0);
    canvas.drawCircle(
      const Offset(cx, cy),
      radius + 10.0 + speedRatio * 12.0,
      Paint()
        ..color = color.withOpacity(0.18 + speedRatio * 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 16.0 + speedRatio * 12.0),
    );

    // Bounce flash ring — expands outward and fades when squash is active
    if (_bounceSquashTimer > 0) {
      final flashProgress = (1.0 - _bounceSquashTimer / 0.08).clamp(0.0, 1.0);
      final flashR = radius + 6.0 + flashProgress * radius * 1.4;
      canvas.drawCircle(
        const Offset(cx, cy),
        flashR,
        Paint()
          ..color = color.withOpacity((1.0 - flashProgress) * 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    // Main sphere body
    canvas.drawCircle(const Offset(cx, cy), radius, Paint()..color = color);

    // Metallic highlight
    canvas.drawCircle(
      const Offset(cx - radius * 0.35, cy - radius * 0.35),
      radius * 0.38,
      Paint()
        ..color = Colors.white.withOpacity(0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Inner glow for depth
    canvas.drawCircle(
      const Offset(cx, cy),
      radius * 0.8,
      Paint()
        ..color = color.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Rim highlight
    canvas.drawCircle(
      const Offset(cx, cy),
      radius,
      Paint()
        ..color = Colors.white.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    canvas.restore();

    behavior.renderOverlay(canvas, radius, cx, cy);
  }
}
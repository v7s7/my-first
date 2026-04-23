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
  final int orbIndex; // 0 = primary, 1+ = additional orbs
  final double orbRadius;

  static const double defaultRadius    = 18.0;
  static const double weaponLength     = 50.0; // PVP sword length past orb edge
  static const double baseSpeed        = 280.0;
  static const double speedGrowthPerBounce = 0.03;
  static const double maxSpeed         = 900.0;
  static const double hitCooldown      = 0.25;

  double speed = baseSpeed;
  double speedMultiplier = 1.0;
  late Vector2 velocity;

  final Random _rng = Random();
  double _hitCooldownTimer = 0.0;
  double _bounceSquashTimer = 0.0;
  double _frozenTimer = 0.0;

  // Self-rotation angle — drives the orbiting highlight
  double _rotationAngle = 0.0;
  // Weapon spin angle — independent of velocity direction; spins continuously
  double _weaponAngle = 0.0;

  bool get isFrozen => _frozenTimer > 0;

  void freeze(double duration) {
    if (duration > _frozenTimer) _frozenTimer = duration;
  }

  /// World-space position of the spinning weapon tip (used for PVP hit detection).
  Vector2 get weaponTip {
    return position +
        Vector2(cos(_weaponAngle), sin(_weaponAngle)) * (orbRadius + weaponLength);
  }

  final Queue<Vector2> _trail = Queue<Vector2>();
  static const int _maxTrailLength = 24;

  PlayerOrb({
    required this.behavior,
    required this.gameRef,
    required this.arena,
    this.orbIndex = 0,
    this.orbRadius = defaultRadius,
  }) : super(
          size: Vector2.all(orbRadius * 2),
          anchor: Anchor.center,
          priority: 10,
        );

  @override
  Future<void> onLoad() async {
    // Initial weapon angle: orbs point toward each other
    _weaponAngle = orbIndex == 0 ? 0.0 : pi;

    if (orbIndex == 0) {
      position = Vector2(
        arena.minX(orbRadius) +
            _rng.nextDouble() *
                (arena.maxX(orbRadius) - arena.minX(orbRadius)) *
                0.35,
        arena.minY(orbRadius) +
            _rng.nextDouble() *
                (arena.maxY(orbRadius) - arena.minY(orbRadius)) *
                0.25,
      );
      final angle = (pi * 0.2) + _rng.nextDouble() * (pi * 0.6);
      velocity = Vector2(cos(angle), sin(angle)) * speed;
    } else {
      position = Vector2(
        arena.maxX(orbRadius) -
            _rng.nextDouble() *
                (arena.maxX(orbRadius) - arena.minX(orbRadius)) *
                0.35,
        arena.maxY(orbRadius) -
            _rng.nextDouble() *
                (arena.maxY(orbRadius) - arena.minY(orbRadius)) *
                0.25,
      );
      final angle = pi + (pi * 0.2) + _rng.nextDouble() * (pi * 0.6);
      velocity = Vector2(cos(angle), sin(angle)) * speed;
    }

    behavior.onAttach(this);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!gameRef.playing) return;

    // Self-rotation (orbiting highlight)
    _rotationAngle += dt * pi * 1.5;

    // Weapon spin — orb 0 clockwise, orb 1 counter-clockwise
    if (gameRef.mode.isPvp) {
      final spinDir = orbIndex == 0 ? 1.0 : -1.0;
      _weaponAngle += dt * pi * 2.2 * spinDir;
    }

    // Freeze mechanic
    if (_frozenTimer > 0) {
      _frozenTimer -= dt;
      velocity.scale(max(0.0, 1.0 - dt * 6.0));
      if (_frozenTimer <= 0 && velocity.length < 30) {
        final a = _rng.nextDouble() * 2 * pi;
        velocity = Vector2(cos(a), sin(a)) * speed;
      }
    }

    if (_hitCooldownTimer > 0) _hitCooldownTimer -= dt;
    if (_bounceSquashTimer > 0) _bounceSquashTimer -= dt;

    _trail.addFirst(position.clone());
    if (_trail.length > _maxTrailLength) {
      _trail.removeLast();
    }

    if (_frozenTimer <= 0) {
      behavior.onUpdate(dt, this);
    }

    // Hook orb homing toward boss (non-PVP only)
    if (behavior.id == 'hook' && !gameRef.mode.isPvp) {
      final boss = gameRef.boss;
      if (boss != null) {
        final bossPos = boss.position;
        final distanceToBoss = position.distanceTo(bossPos);
        if (distanceToBoss < 400) {
          final directionToBoss = (bossPos - position).normalized();
          velocity.lerp(directionToBoss * speed, dt * 2.5);
          velocity = velocity.normalized() * speed;
        }
      }
    }

    // Magnet pickup homing
    if (gameRef.magnetTimer > 0 && _frozenTimer <= 0) {
      if (gameRef.mode.isPvp) {
        // Home toward the opponent orb
        final opponentIndex = 1 - orbIndex;
        final orbs = gameRef.orbs;
        if (orbs.length > opponentIndex) {
          final opponentPos = orbs[opponentIndex].position;
          final dist = position.distanceTo(opponentPos);
          if (dist > 0.01) {
            final dir = (opponentPos - position).normalized();
            velocity.lerp(dir * speed, dt * 3.5);
            velocity = velocity.normalized() * speed;
          }
        }
      } else {
        final boss = gameRef.boss;
        if (boss != null) {
          final bossPos = boss.position;
          final dist = position.distanceTo(bossPos);
          if (dist > 0.01) {
            final dir = (bossPos - position).normalized();
            velocity.lerp(dir * speed, dt * 3.5);
            velocity = velocity.normalized() * speed;
          }
        }
      }
    }

    if (_frozenTimer <= 0) {
      position += velocity * dt * speedMultiplier;
    }

    _handleWallBounce();

    // Boss collision only in non-PVP modes (PVP handled centrally)
    if (!gameRef.mode.isPvp) {
      _resolveCollision();
    }
  }

  void _handleWallBounce() {
    bool bounced = false;

    if (position.x <= arena.minX(orbRadius)) {
      position.x = arena.minX(orbRadius);
      velocity.x = velocity.x.abs();
      bounced = true;
    } else if (position.x >= arena.maxX(orbRadius)) {
      position.x = arena.maxX(orbRadius);
      velocity.x = -velocity.x.abs();
      bounced = true;
    }

    if (position.y <= arena.minY(orbRadius)) {
      position.y = arena.minY(orbRadius);
      velocity.y = velocity.y.abs();
      bounced = true;
    } else if (position.y >= arena.maxY(orbRadius)) {
      position.y = arena.maxY(orbRadius);
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

    if (arena.bounceOffObstacles(position, velocity, orbRadius)) {
      speed = min(speed * (1.0 + speedGrowthPerBounce), maxSpeed);
      if (velocity.length > 0.01) velocity = velocity.normalized() * speed;
      _bounceSquashTimer = 0.08;
      gameRef.triggerShake(intensity: 1.5, duration: 0.05);
      behavior.onWallBounce(this);
    }
  }

  void _resolveCollision() {
    final boss = gameRef.boss;
    if (boss == null) return;

    final dist = position.distanceTo(boss.position);
    final minDist = boss.radius + orbRadius;

    if (dist >= minDist) return;

    final n = dist < 0.001
        ? Vector2(1, 0)
        : (position - boss.position).normalized();

    final overlap = minDist - dist;
    position += n * overlap;
    position = arena.clamp(position, orbRadius);

    final relVel = velocity - boss.velocity;
    final velAlongNormal = relVel.dot(n);

    if (velAlongNormal < 0) {
      const m1 = 1.0;
      final m2 = BossComponent.mass;
      const restitution = 0.8;
      final j = -(1.0 + restitution) * velAlongNormal / (m1 + m2);
      final impulse = n * j;
      velocity = velocity + impulse * m2;
      boss.velocity = boss.velocity - impulse * m1 * 0.7;

      if (velocity.length < speed * 0.3) {
        velocity = velocity.length < 0.01
            ? n * (speed * 0.5)
            : velocity.normalized() * (speed * 0.45);
      }
    }

    final effectiveCooldown =
        hitCooldown * (gameRef.rapidTimer > 0 ? 0.5 : 1.0);
    if (_hitCooldownTimer <= 0) {
      _hitCooldownTimer = effectiveCooldown;
      behavior.onBossHit(this);
    }
  }

  @override
  void render(Canvas canvas) {
    final cx = orbRadius;
    final cy = orbRadius;

    // Motion trail
    int i = 0;
    for (final trailPos in _trail) {
      final progress = i / _trail.length;
      final trailOpacity = (1.0 - progress) * 0.65;
      final trailRadius = orbRadius * (1.0 - progress * 0.6);
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

    final squash = _bounceSquashTimer > 0 ? 1.15 : 1.0;
    final stretch = _bounceSquashTimer > 0 ? 0.88 : 1.0;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(squash, stretch);
    canvas.translate(-cx, -cy);

    final color = behavior.color;

    final speedRatio = (speed / maxSpeed).clamp(0.25, 1.0);
    canvas.drawCircle(
      Offset(cx, cy),
      orbRadius + 10.0 + speedRatio * 12.0,
      Paint()
        ..color = color.withOpacity(0.18 + speedRatio * 0.22)
        ..maskFilter =
            MaskFilter.blur(BlurStyle.normal, 16.0 + speedRatio * 12.0),
    );

    if (_bounceSquashTimer > 0) {
      final flashProgress =
          (1.0 - _bounceSquashTimer / 0.08).clamp(0.0, 1.0);
      final flashR = orbRadius + 6.0 + flashProgress * orbRadius * 1.4;
      canvas.drawCircle(
        Offset(cx, cy),
        flashR,
        Paint()
          ..color = color.withOpacity((1.0 - flashProgress) * 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    // Frozen overlay
    if (isFrozen) {
      canvas.drawCircle(
        Offset(cx, cy),
        orbRadius + 6,
        Paint()
          ..color = const Color(0x5588CCFF)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    // Main sphere body — solid color OR custom face image
    final faceImg = gameRef.orbImage(orbIndex);
    if (faceImg != null) {
      final dst = Rect.fromCircle(center: Offset(cx, cy), radius: orbRadius);
      canvas.save();
      canvas.clipPath(Path()..addOval(dst));
      canvas.drawImageRect(
        faceImg,
        Rect.fromLTWH(0, 0, faceImg.width.toDouble(), faceImg.height.toDouble()),
        dst,
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
    } else {
      canvas.drawCircle(Offset(cx, cy), orbRadius, Paint()..color = color);
    }

    // Orbiting specular highlight — rotates with _rotationAngle
    final hlAngle = _rotationAngle * 0.65;
    final hlX = cx + cos(hlAngle) * orbRadius * 0.42;
    final hlY = cy + sin(hlAngle) * orbRadius * 0.42;
    canvas.drawCircle(
      Offset(hlX, hlY),
      orbRadius * 0.38,
      Paint()
        ..color = Colors.white.withOpacity(0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Secondary inner glow ring (counter-rotates for depth)
    final glowAngle = -_rotationAngle * 0.4 + pi * 0.5;
    canvas.drawCircle(
      Offset(cx, cy),
      orbRadius * 0.8,
      Paint()
        ..color = color.withOpacity(0.25 + sin(glowAngle) * 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    canvas.drawCircle(
      Offset(cx, cy),
      orbRadius,
      Paint()
        ..color = Colors.white.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Magnet pickup indicator ring
    if (gameRef.magnetTimer > 0) {
      canvas.drawCircle(
        Offset(cx, cy),
        orbRadius + 8,
        Paint()
          ..color = const Color(0xAAFF44CC)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // Rapid pickup indicator ring
    if (gameRef.rapidTimer > 0) {
      canvas.drawCircle(
        Offset(cx, cy),
        orbRadius + 14,
        Paint()
          ..color = const Color(0xAAFF6600)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }

    canvas.restore();

    // PVP weapon sword — rendered outside squash transform, uses _weaponAngle
    if (gameRef.mode.isPvp) {
      final wDir = Vector2(cos(_weaponAngle), sin(_weaponAngle));
      final sx = cx + wDir.x * orbRadius;
      final sy = cy + wDir.y * orbRadius;
      final ex = cx + wDir.x * (orbRadius + weaponLength);
      final ey = cy + wDir.y * (orbRadius + weaponLength);
      final start = Offset(sx, sy);
      final end   = Offset(ex, ey);

      // Outer sword glow
      canvas.drawLine(start, end,
        Paint()
          ..color = color.withOpacity(0.38)
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));

      // Blade body
      canvas.drawLine(start, end,
        Paint()
          ..color = color.withOpacity(0.92)
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round);

      // Bright shine along 60% of blade toward tip
      canvas.drawLine(
        Offset(sx + wDir.x * weaponLength * 0.12, sy + wDir.y * weaponLength * 0.12),
        Offset(sx + wDir.x * weaponLength * 0.7,  sy + wDir.y * weaponLength * 0.7),
        Paint()
          ..color = Colors.white.withOpacity(0.65)
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round);

      // Tip glow
      canvas.drawCircle(end, 8.0,
        Paint()
          ..color = color.withOpacity(0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawCircle(end, 3.5,
        Paint()..color = Colors.white);
    }

    behavior.renderOverlay(canvas, orbRadius, cx, cy);
  }
}

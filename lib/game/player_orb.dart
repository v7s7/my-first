import 'dart:math';
import 'dart:ui' as ui;
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

  // Weapon spin angle — independent of velocity direction; spins continuously
  double _weaponAngle = 0.0;

  /// Custom ball colour — overrides behavior.color when set (used in PVP).
  final Color? customColor;

  bool get isFrozen => _frozenTimer > 0;

  void freeze(double duration) {
    if (duration > _frozenTimer) _frozenTimer = duration;
  }

  /// World-space position of the spinning weapon tip (used for PVP hit detection).
  Vector2 get weaponTip {
    return position +
        Vector2(cos(_weaponAngle), sin(_weaponAngle)) * (orbRadius + weaponLength);
  }

  PlayerOrb({
    required this.behavior,
    required this.gameRef,
    required this.arena,
    this.orbIndex = 0,
    this.orbRadius = defaultRadius,
    this.customColor,
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

    final squash = _bounceSquashTimer > 0 ? 1.15 : 1.0;
    final stretch = _bounceSquashTimer > 0 ? 0.88 : 1.0;

    // Visual radius may grow beyond physics radius for math orbs (non-PVP only)
    final displayRadius = gameRef.mode.isPvp
        ? orbRadius
        : orbRadius + behavior.visualGrowth;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(squash, stretch);
    canvas.translate(-cx, -cy);

    final color = customColor ?? behavior.color;

    // Frozen overlay
    if (isFrozen) {
      canvas.drawCircle(
        Offset(cx, cy),
        displayRadius + 4,
        Paint()..color = const Color(0x5588CCFF),
      );
    }

    // Main sphere body — solid color OR custom face image
    final faceImg = gameRef.orbImage(orbIndex);
    if (faceImg != null) {
      final dst = Rect.fromCircle(center: Offset(cx, cy), radius: displayRadius);
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
      canvas.drawCircle(Offset(cx, cy), displayRadius, Paint()..color = color);
    }

    canvas.drawCircle(
      Offset(cx, cy),
      displayRadius,
      Paint()
        ..color = Colors.white.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Magnet pickup indicator ring
    if (gameRef.magnetTimer > 0) {
      canvas.drawCircle(
        Offset(cx, cy),
        displayRadius + 8,
        Paint()
          ..color = const Color(0xAAFF44CC)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    // Rapid pickup indicator ring
    if (gameRef.rapidTimer > 0) {
      canvas.drawCircle(
        Offset(cx, cy),
        displayRadius + 14,
        Paint()
          ..color = const Color(0xAAFF6600)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    canvas.restore();

    // Shield ring (PVP: blocks all incoming damage)
    if (gameRef.isOrbShielded(orbIndex)) {
      canvas.drawCircle(
        Offset(cx, cy),
        displayRadius + 11,
        Paint()
          ..color = const Color(0xCC44AAFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5,
      );
    }

    // Ghost invincibility ring (PVP only)
    if (gameRef.isOrbGhosted(orbIndex)) {
      canvas.drawCircle(
        Offset(cx, cy),
        displayRadius + 10,
        Paint()
          ..color = const Color(0x6688FFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0,
      );
    }

    // Weapon: gun image when a pickup is active (pointing at target), sword otherwise
    final aimAngle = _getAimAngle();
    if (aimAngle != null) {
      final gunType = gameRef.mode.isPvp
          ? (gameRef.activeGunType ?? PvpGunType.pistol)
          : PvpGunType.pistol;
      final gunImg = gameRef.gunImage(gunType);

      if (gameRef.revolverIsHolding && gameRef.revolverShooterIndex == orbIndex) {
        // Hold phase: charge-arc + gun image at edge (fading in)
        _drawHoldUI(canvas, cx, cy, aimAngle, gunType, color,
            gameRef.revolverHoldFraction, orbRadius, gunImg);
      } else {
        // Firing phase: gun image at orb edge pointing at target
        _drawGunAtEdge(canvas, cx, cy, aimAngle, orbRadius, gunType, gunImg, color);
      }
    } else if (gameRef.mode.isPvp) {
      // No gun active — spinning melee sword
      final wDir = Vector2(cos(_weaponAngle), sin(_weaponAngle));
      final sx = cx + wDir.x * orbRadius;
      final sy = cy + wDir.y * orbRadius;
      final ex = cx + wDir.x * (orbRadius + weaponLength);
      final ey = cy + wDir.y * (orbRadius + weaponLength);
      final start = Offset(sx, sy);
      final end   = Offset(ex, ey);

      canvas.drawLine(start, end,
        Paint()
          ..color = color.withOpacity(0.92)
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round);

      canvas.drawLine(
        Offset(sx + wDir.x * weaponLength * 0.12, sy + wDir.y * weaponLength * 0.12),
        Offset(sx + wDir.x * weaponLength * 0.7,  sy + wDir.y * weaponLength * 0.7),
        Paint()
          ..color = Colors.white.withOpacity(0.65)
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round);

      canvas.drawCircle(end, 3.5, Paint()..color = Colors.white);
    }

    if (!gameRef.mode.isPvp) {
      behavior.renderOverlay(canvas, displayRadius, cx, cy);
    }
  }

  // Returns the angle (radians) from this orb toward its current shooting target,
  // or null when no gun pickup is active on this orb.
  double? _getAimAngle() {
    if (gameRef.activeGunType == null) return null;
    if (gameRef.revolverShooterIndex != orbIndex) return null;
    if (gameRef.mode.isPvp) {
      final opponentIndex = 1 - orbIndex;
      final orbs = gameRef.orbs;
      if (orbs.length > opponentIndex) {
        final diff = orbs[opponentIndex].position - position;
        if (diff.length > 0.1) return atan2(diff.y, diff.x);
      }
    } else {
      final boss = gameRef.boss;
      if (boss != null) {
        final diff = boss.position - position;
        if (diff.length > 0.1) return atan2(diff.y, diff.x);
      }
    }
    return null;
  }

  // Hold-phase UI: charge-progress ring + gun image at edge fading in.
  static void _drawHoldUI(Canvas canvas, double cx, double cy, double aimAngle,
      PvpGunType gunType, Color color, double holdFraction,
      double r, ui.Image? gunImg) {
    // Charge progress arc (fills clockwise as weapon readies)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: 26),
      -pi / 2,
      2 * pi * holdFraction,
      false,
      Paint()
        ..color = color.withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
    // Dim background ring
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: 26),
      -pi / 2 + 2 * pi * holdFraction,
      2 * pi * (1.0 - holdFraction),
      false,
      Paint()
        ..color = color.withOpacity(0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );
    // Gun at edge, fades in as charge builds
    _drawGunAtEdge(canvas, cx, cy, aimAngle, r, gunType, gunImg, color,
        opacity: 0.45 + 0.55 * holdFraction);
  }

  // Draws the gun PNG image at the orb edge rotated toward the aim direction.
  // Falls back to canvas gun shape when image is unavailable.
  static void _drawGunAtEdge(Canvas canvas, double cx, double cy,
      double aimAngle, double r, PvpGunType gunType, ui.Image? img, Color color,
      {double opacity = 1.0}) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(aimAngle);
    if (img != null) {
      const gunH = 52.0;
      final iw = img.width.toDouble();
      final ih = img.height.toDouble();
      final gunW = ih > 0 ? gunH * (iw / ih) : gunH * 2.0;
      // Grip/stock starts just past the orb edge; barrel extends outward (+x)
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, iw, ih),
        Rect.fromLTWH(r + 2.0, -gunH / 2, gunW, gunH),
        Paint()
          ..filterQuality = FilterQuality.medium
          ..color = Colors.white.withOpacity(opacity),
      );
    } else {
      _drawGunShape(canvas, r, gunType, color);
    }
    canvas.restore();
  }

  // Gun shapes — canvas is pre-translated to orb center and rotated toward
  // target. Barrel extends in the +x direction starting at x = orbRadius (r).
  static void _drawGunShape(
      Canvas canvas, double r, PvpGunType type, Color color) {
    switch (type) {
      case PvpGunType.pistol:
        _drawPistol(canvas, r, color);
      case PvpGunType.shotgun:
        _drawShotgun(canvas, r, color);
      case PvpGunType.sniper:
        _drawSniper(canvas, r, color);
      case PvpGunType.machineGun:
        _drawMachineGun(canvas, r, color);
      case PvpGunType.rocket:
        _drawRocketLauncher(canvas, r, color);
      case PvpGunType.grenade:
        _drawGrenadeLauncher(canvas, r, color);
      case PvpGunType.burst:
        _drawBurstRifle(canvas, r, color);
      case PvpGunType.minigun:
        _drawMinigun(canvas, r, color);
      case PvpGunType.railgun:
        _drawRailgun(canvas, r, color);
    }
  }

  static Paint _gp(Color c, {double opacity = 0.95}) =>
      Paint()..color = c.withOpacity(opacity);
  static Paint _gDark() => Paint()..color = Colors.black.withOpacity(0.5);
  static Paint _gHighlight() => Paint()..color = Colors.white.withOpacity(0.55);
  static Paint _gStroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w;
  static RRect _rr(double x, double y, double w, double h, double rad) =>
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(rad));

  // Pistol: compact body + medium barrel + downward grip
  static void _drawPistol(Canvas canvas, double r, Color c) {
    // Body
    canvas.drawRRect(_rr(r + 1, -4, 15, 8, 2), _gp(c));
    // Barrel
    canvas.drawRect(Rect.fromLTWH(r + 16, -2.5, 13, 5), _gp(c));
    // Slide detail line
    canvas.drawLine(
        Offset(r + 3, -4.5), Offset(r + 14, -4.5), _gDark()..strokeWidth = 1.5);
    // Grip
    canvas.drawRRect(_rr(r + 4, 4, 6, 9, 1.5), _gp(c, opacity: 0.75));
    // Barrel top highlight
    canvas.drawLine(
        Offset(r + 17, -3), Offset(r + 28, -3), _gHighlight()..strokeWidth = 1);
  }

  // Shotgun: wide stock + double side-by-side barrel
  static void _drawShotgun(Canvas canvas, double r, Color c) {
    // Stock
    canvas.drawRRect(_rr(r + 1, -5.5, 13, 11, 2.5), _gp(c));
    // Upper barrel
    canvas.drawRect(Rect.fromLTWH(r + 14, -5.5, 20, 4.5), _gp(c));
    // Lower barrel
    canvas.drawRect(Rect.fromLTWH(r + 14, 1, 20, 4.5), _gp(c));
    // Gap between barrels
    canvas.drawLine(
        Offset(r + 14, -0.5), Offset(r + 34, -0.5), _gDark()..strokeWidth = 1.5);
    // Muzzle end-cap line
    canvas.drawLine(
        Offset(r + 33, -6), Offset(r + 33, 6), _gDark()..strokeWidth = 2.5);
  }

  // Sniper: very long thin barrel + scope dot above
  static void _drawSniper(Canvas canvas, double r, Color c) {
    // Stock
    canvas.drawRRect(_rr(r + 1, -3.5, 15, 7, 2), _gp(c));
    // Long barrel
    canvas.drawRect(Rect.fromLTWH(r + 16, -1.8, 34, 3.6), _gp(c));
    // Barrel highlight
    canvas.drawLine(
        Offset(r + 17, -2.2), Offset(r + 49, -2.2), _gHighlight()..strokeWidth = 1);
    // Scope circle
    canvas.drawCircle(Offset(r + 20, -7), 4, _gp(c));
    canvas.drawCircle(
        Offset(r + 20, -7), 4, _gStroke(Colors.white.withOpacity(0.5), 0.8));
    // Scope crosshair
    canvas.drawLine(
        Offset(r + 17, -7), Offset(r + 23, -7), _gDark()..strokeWidth = 0.9);
    canvas.drawLine(
        Offset(r + 20, -10.5), Offset(r + 20, -3.5), _gDark()..strokeWidth = 0.9);
  }

  // Machine gun: body + medium barrel + box magazine below
  static void _drawMachineGun(Canvas canvas, double r, Color c) {
    // Body
    canvas.drawRRect(_rr(r + 1, -4.5, 20, 9, 2), _gp(c));
    // Barrel
    canvas.drawRect(Rect.fromLTWH(r + 21, -2.5, 16, 5), _gp(c));
    // Box magazine (below body)
    canvas.drawRRect(_rr(r + 8, 4.5, 9, 11, 1.5), _gp(c, opacity: 0.8));
    // Vent slots on barrel
    for (int i = 0; i < 3; i++) {
      final x = r + 22.0 + i * 4.5;
      canvas.drawLine(Offset(x, -4.5), Offset(x, -2.5), _gDark()..strokeWidth = 1);
    }
  }

  // Rocket launcher: wide round tube + open muzzle ring
  static void _drawRocketLauncher(Canvas canvas, double r, Color c) {
    // Main tube
    canvas.drawRRect(_rr(r + 2, -7, 30, 14, 6), _gp(c));
    // Muzzle ring (hollow opening)
    canvas.drawCircle(
        Offset(r + 32, 0), 6.5, _gStroke(Colors.white.withOpacity(0.6), 2));
    canvas.drawCircle(Offset(r + 32, 0), 4.5, _gp(Colors.black, opacity: 0.55));
    // Handle grip under tube
    canvas.drawRRect(_rr(r + 8, 7, 8, 8, 1.5), _gp(c, opacity: 0.7));
    // Top highlight
    canvas.drawLine(
        Offset(r + 3, -5.5), Offset(r + 30, -5.5), _gHighlight()..strokeWidth = 1.2);
  }

  // Grenade launcher: short body + fat round barrel
  static void _drawGrenadeLauncher(Canvas canvas, double r, Color c) {
    // Short body
    canvas.drawRRect(_rr(r + 1, -4.5, 13, 9, 2.5), _gp(c));
    // Fat round barrel
    canvas.drawRRect(_rr(r + 14, -6, 16, 12, 5.5), _gp(c));
    // Barrel bore (dark inner circle)
    canvas.drawCircle(Offset(r + 30, 0), 4.5, _gp(Colors.black, opacity: 0.55));
    // Grip
    canvas.drawRRect(_rr(r + 4, 4.5, 6, 8, 1.5), _gp(c, opacity: 0.7));
  }

  // Burst rifle: body + 3 stacked parallel barrels at the muzzle
  static void _drawBurstRifle(Canvas canvas, double r, Color c) {
    // Body
    canvas.drawRRect(_rr(r + 1, -5, 20, 10, 2), _gp(c));
    // 3 stacked muzzle barrels
    for (int i = 0; i < 3; i++) {
      canvas.drawRect(
          Rect.fromLTWH(r + 21, -5.0 + i * 3.5, 15, 2.5), _gp(c));
    }
    // Separator lines between barrels
    canvas.drawLine(
        Offset(r + 21, -1.5), Offset(r + 36, -1.5), _gDark()..strokeWidth = 0.8);
    canvas.drawLine(
        Offset(r + 21, 2.0), Offset(r + 36, 2.0), _gDark()..strokeWidth = 0.8);
  }

  // Minigun: rotating drum hub + 3 barrels at 120° spacing
  static void _drawMinigun(Canvas canvas, double r, Color c) {
    // 3 barrels radiating from the hub
    for (int i = 0; i < 3; i++) {
      canvas.save();
      canvas.translate(r + 6, 0);
      canvas.rotate(i * 2 * pi / 3);
      canvas.drawRect(Rect.fromLTWH(5, -2, 20, 4), _gp(c));
      canvas.restore();
    }
    // Drum hub
    canvas.drawCircle(Offset(r + 6, 0), 6.5, _gp(c, opacity: 0.9));
    canvas.drawCircle(
        Offset(r + 6, 0), 6.5, _gStroke(Colors.white.withOpacity(0.4), 1.2));
    // Center bolt
    canvas.drawCircle(
        Offset(r + 6, 0), 2.5, Paint()..color = Colors.white.withOpacity(0.7));
  }

  // Railgun: rectangular frame + two parallel rails + glowing tip
  static void _drawRailgun(Canvas canvas, double r, Color c) {
    // Frame
    canvas.drawRRect(_rr(r + 1, -4.5, 38, 9, 1.5), _gp(c, opacity: 0.6));
    // Top rail
    canvas.drawRect(Rect.fromLTWH(r + 2, -3.5, 36, 2.5), _gp(c));
    // Bottom rail
    canvas.drawRect(Rect.fromLTWH(r + 2, 1, 36, 2.5), _gp(c));
    // Energy channel (dark gap between rails)
    canvas.drawRect(
        Rect.fromLTWH(r + 2, -1, 36, 2), _gp(Colors.black, opacity: 0.4));
    // Glowing tip
    canvas.drawCircle(
      Offset(r + 40, 0),
      5.5,
      Paint()
        ..color = c.withOpacity(0.75)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }
}

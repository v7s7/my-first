import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'boss_ball_game.dart';

class BossComponent extends PositionComponent with HasGameRef<BossBallGame> {
  double radius = 60.0;
  double _time = 0.0;
  double _moveTimer = 0.0;
  
  late Vector2 velocity;
  late Vector2 targetVelocity;
  late Vector2 centerPosition;
  
  static const double friction = 0.88; // Velocity damping per frame
  static const double mass = 3.0; // Boss mass for collision physics
  static const double moveSpeed = 120.0; // Continuous movement speed
  static const double moveChangePeriod = 4.0; // Change direction every 4 seconds

  BossComponent({required Vector2 position})
      : super(position: position, anchor: Anchor.center);

  @override
  void onLoad() {
    velocity = Vector2.zero();
    targetVelocity = Vector2.zero();
    centerPosition = position.clone();
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Update movement timer and change direction periodically
    _moveTimer += dt;
    if (_moveTimer >= moveChangePeriod) {
      _moveTimer -= moveChangePeriod;
      // Generate new target direction
      final randomAngle = Random().nextDouble() * pi * 2;
      targetVelocity = Vector2(cos(randomAngle), sin(randomAngle)) * moveSpeed;
    }
    
    // Smoothly interpolate current velocity towards target velocity
    final lerpAmount = (dt * 1.5).clamp(0.0, 1.0);
    velocity.x = velocity.x + (targetVelocity.x - velocity.x) * lerpAmount;
    velocity.y = velocity.y + (targetVelocity.y - velocity.y) * lerpAmount;
    
    // Update position based on velocity
    position += velocity * dt;
    
    // Clamp position to arena bounds
    final arena = gameRef.arenaConfig;
    position.x = position.x.clamp(arena.minX(radius), arena.maxX(radius));
    position.y = position.y.clamp(arena.minY(radius), arena.maxY(radius));
    
    // Bounce velocity if hitting walls (reverse direction)
    if (position.x <= arena.minX(radius) || position.x >= arena.maxX(radius)) {
      velocity.x *= -0.9;
      targetVelocity.x *= -0.9;
    }
    if (position.y <= arena.minY(radius) || position.y >= arena.maxY(radius)) {
      velocity.y *= -0.9;
      targetVelocity.y *= -0.9;
    }
    
    // Breathing animation (no scale, just visual effect)  
    final hpRatio = gameRef.bossHp / gameRef.bossMaxHp;
    final breatheSpeed = 3.0 + ((1.0 - hpRatio) * 7.0);
    _time += dt * breatheSpeed;
  }

  @override
  void render(Canvas canvas) {
    final hpRatio = gameRef.bossHp / gameRef.bossMaxHp;
    
    // Breathing glow animation
    final breathe = sin(_time) * 0.08;
    final glowRadius = radius + 10 + breathe * 8;

    // Beautiful gradient: Purple/Blue -> Pink -> Red
    Color bossColor;
    if (hpRatio > 0.6) {
      // Purple to Blue: 60-100% HP
      bossColor = Color.lerp(const Color(0xFF6A5AFF), const Color(0xFF7155FF), 1.0 - (hpRatio - 0.6) / 0.4)!;
    } else if (hpRatio > 0.3) {
      // Blue to Pink: 30-60% HP
      bossColor = Color.lerp(const Color(0xFFFF4488), const Color(0xFF6A5AFF), (hpRatio - 0.3) / 0.3)!;
    } else {
      // Pink to Red: 0-30% HP
      bossColor = Color.lerp(const Color(0xFFFF0033), const Color(0xFFFF4488), hpRatio / 0.3)!;
    }

    // Outer glow
    final glowPaint = Paint()
      ..color = bossColor.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 20);
    canvas.drawCircle(Offset.zero, glowRadius, glowPaint);

    // Inner glow
    final innerGlowPaint = Paint()
      ..color = bossColor.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 8);
    canvas.drawCircle(Offset.zero, radius + 3, innerGlowPaint);

    // Main body
    final mainPaint = Paint()..color = bossColor;
    canvas.drawCircle(Offset.zero, radius, mainPaint);

    // Metallic highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset(-radius * 0.3, -radius * 0.3), radius * 0.45, highlightPaint);

    // Rage aura when low HP
    if (hpRatio < 0.2) {
      final ragePaint = Paint()
        ..color = Colors.red.withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 15);
      canvas.drawCircle(Offset.zero, radius + 25, ragePaint);
    }
    
    // HP text in center
    final hpText = '${gameRef.bossHp} / ${gameRef.bossMaxHp}';
    final textPainter = TextPainter(
      text: TextSpan(
        text: hpText,
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.8),
              blurRadius: 4,
              offset: const Offset(1, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );
  }
}
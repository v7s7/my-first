import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class BossComponent extends PositionComponent {
  static const double radius = 60.0;

  // Squash-and-stretch state
  double _scaleX = 1.0;
  double _scaleY = 1.0;
  double _hitTimer = 0.0;
  static const double _hitDuration = 0.25;

  // Idle pulse state
  double _pulseTimer = 0.0;

  BossComponent({required Vector2 position})
      : super(
          position: position,
          size: Vector2.all(radius * 2),
          anchor: Anchor.center,
        );

  void triggerHitAnimation() {
    _hitTimer = _hitDuration;
    // Squash horizontally, stretch vertically
    _scaleX = 1.35;
    _scaleY = 0.75;
  }

  @override
  void update(double dt) {
    super.update(dt);

    _pulseTimer += dt;

    if (_hitTimer > 0) {
      _hitTimer -= dt;
      final progress = 1.0 - (_hitTimer / _hitDuration);
      // Spring-like return to normal with slight overshoot
      final spring = 1.0 + cos(progress * pi * 2.5) * (1.0 - progress);
      _scaleX = 1.0 + (1.35 - 1.0) * spring * (1.0 - progress);
      _scaleY = 1.0 + (0.75 - 1.0) * spring * (1.0 - progress);
      if (_hitTimer <= 0) {
        _scaleX = 1.0;
        _scaleY = 1.0;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final cx = radius;
    final cy = radius;
    final pulse = 1.0 + sin(_pulseTimer * 1.8) * 0.04;
    final sr = radius * pulse;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(_scaleX, _scaleY);
    canvas.translate(-cx, -cy);

    // Outer aura glow
    final auraPaint = Paint()
      ..color = const Color(0x33FF2200)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    canvas.drawCircle(Offset(cx, cy), sr + 24, auraPaint);

    // Mid glow
    final glowPaint = Paint()
      ..color = const Color(0x55FF4400)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(Offset(cx, cy), sr + 10, glowPaint);

    // Core body
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        colors: const [Color(0xFFFF6633), Color(0xFFCC1100)],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: sr));
    canvas.drawCircle(Offset(cx, cy), sr, bodyPaint);

    // Rim highlight
    final rimPaint = Paint()
      ..color = const Color(0xAAFF7755)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(Offset(cx, cy), sr, rimPaint);

    // Shine spot
    final shinePaint = Paint()..color = const Color(0x55FFFFFF);
    canvas.drawCircle(
      Offset(cx - sr * 0.3, cy - sr * 0.3),
      sr * 0.28,
      shinePaint,
    );

    canvas.restore();
  }
}

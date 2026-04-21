import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'boss_ball_game.dart';

/// A freestanding vortex spawned by the Vortex pickup item.
/// Pulls the boss toward its position and deals DoT for 5 s.
class VortexPickupZone extends PositionComponent {
  final BossBallGame gameRef;

  static const double _lifetime     = 5.0;
  static const int    _tickDamage   = 15000;
  static const double _tickInterval = 0.3;
  static const double _pullForce    = 320.0;

  double _timeLeft  = _lifetime;
  double _tickTimer = 0.0;
  double _time      = 0.0;

  VortexPickupZone({
    required Vector2 position,
    required this.gameRef,
  }) : super(
          position: position,
          size: Vector2.all(80),
          anchor: Anchor.center,
          priority: 4,
        );

  @override
  void update(double dt) {
    _timeLeft  -= dt;
    _tickTimer -= dt;
    _time      += dt;

    if (_timeLeft <= 0) {
      removeFromParent();
      return;
    }

    // Pull boss toward this position
    final toZone = position - gameRef.boss.position;
    if (toZone.length > 1) {
      gameRef.boss.velocity += toZone.normalized() * _pullForce * dt;
    }

    // DoT ticks
    if (_tickTimer <= 0) {
      _tickTimer = _tickInterval;
      gameRef.onOrbHitBoss(_tickDamage, isLaserTick: true);
    }
  }

  @override
  void render(Canvas canvas) {
    final cx = 40.0;
    final cy = 40.0;
    final progress = 1.0 - (_timeLeft / _lifetime);
    final fadeOut = _timeLeft < 0.8 ? _timeLeft / 0.8 : 1.0;

    // Spinning arcs (accretion disk style, like BlackHoleOrb)
    const segments = 6;
    for (int i = 0; i < segments; i++) {
      final hue = (i * (360.0 / segments) + _time * 80) % 360;
      final color = HSLColor.fromAHSL(
        0.7 * fadeOut,
        hue,
        0.85,
        0.55,
      ).toColor();
      final angle = _time * (3.0 + i * 0.3) + i * (2 * pi / segments);
      final r = 28.0 + sin(_time * 2 + i) * 4;

      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        angle,
        pi * 0.55,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }

    // Outer pull-beam ring
    canvas.drawCircle(
      Offset(cx, cy),
      36 + sin(_time * 4) * 3,
      Paint()
        ..color = const Color(0xFFAA44FF).withOpacity(0.4 * fadeOut)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Dark core
    canvas.drawCircle(
      Offset(cx, cy),
      14,
      Paint()
        ..color = Colors.black.withOpacity(0.85 * fadeOut)
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 5),
    );

    // Pull lines toward boss (visual)
    for (int i = 0; i < 4; i++) {
      final angle = _time * 6 + i * (pi / 2);
      final len = 18 + progress * 22.0;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + cos(angle) * len, cy + sin(angle) * len),
        Paint()
          ..color = const Color(0xFFCC88FF).withOpacity(0.5 * fadeOut)
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }
}

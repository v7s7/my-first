import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'boss_ball_game.dart';
import 'damage_number.dart';
import 'pickup_type.dart';
import 'player_orb.dart';

class PickupItemComponent extends PositionComponent {
  final PickupType type;
  final BossBallGame gameRef;

  static const double pickupRadius = 22.0;
  static const double _totalLifetime = 12.0;
  static const double _fadeInDuration = 0.4;
  static const double _fadeOutStart = 2.5; // start fading when this many seconds remain

  double _lifetime = _totalLifetime;
  double _pulseTimer = 0.0;
  bool _collected = false;

  final Random _rng = Random();

  PickupItemComponent({
    required Vector2 position,
    required this.type,
    required this.gameRef,
  }) : super(
          position: position,
          size: Vector2.all(pickupRadius * 2),
          anchor: Anchor.center,
          priority: 5,
        );

  @override
  void update(double dt) {
    if (_collected) return;

    _lifetime -= dt;
    _pulseTimer += dt * 2.8;

    if (_lifetime <= 0) {
      gameRef.onPickupExpired();
      removeFromParent();
      return;
    }

    // Collision with any active orb (supports Dual Ball / PVP mode)
    final orbs = gameRef.orbs;
    for (int i = 0; i < orbs.length; i++) {
      final o = orbs[i];
      if (o.position.distanceTo(position) < pickupRadius + o.orbRadius) {
        _collected = true;
        _collect(collectorIndex: i);
        removeFromParent();
        return;
      }
    }
  }

  void _collect({int collectorIndex = 0}) {
    gameRef.onPickupCollected(type, collectorIndex: collectorIndex);
    gameRef.onPickupExpired(); // decrement active count

    // Floating name label
    gameRef.add(DamageNumber(
      position: position.clone() + Vector2(0, -20),
      damage: 0,
      label: '+${type.displayName}',
      labelColor: type.ringColor,
      isSmall: false,
      driftX: (_rng.nextDouble() - 0.5) * 40,
    ));
  }

  @override
  void render(Canvas canvas) {
    if (_collected) return;

    final age = _totalLifetime - _lifetime;
    final fadeIn = (age / _fadeInDuration).clamp(0.0, 1.0);
    final fadeOut = _lifetime < _fadeOutStart
        ? (_lifetime / _fadeOutStart).clamp(0.0, 1.0)
        : 1.0;
    final alpha = fadeIn * fadeOut;

    final cx = pickupRadius;
    final cy = pickupRadius;

    // Ring color: type color normally, red when < 3s
    final isUrgent = _lifetime < 3.0;
    final ringColor = isUrgent
        ? Color.lerp(type.ringColor, const Color(0xFFFF2222), 1.0 - (_lifetime / 3.0))!
        : type.ringColor;

    // Pulsing outer ring
    final pulse = 1.0 + 0.18 * sin(_pulseTimer);
    final ringR = pickupRadius * pulse + 6;

    canvas.drawCircle(
      Offset(cx, cy),
      ringR,
      Paint()
        ..color = ringColor.withOpacity(alpha * 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + 4 * sin(_pulseTimer)),
    );

    // Secondary inner glow ring
    canvas.drawCircle(
      Offset(cx, cy),
      pickupRadius + 3,
      Paint()
        ..color = ringColor.withOpacity(alpha * 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Background circle
    canvas.drawCircle(
      Offset(cx, cy),
      pickupRadius,
      Paint()
        ..color = const Color(0xFF111122).withOpacity(alpha * 0.8),
    );

    // Subtle ring border
    canvas.drawCircle(
      Offset(cx, cy),
      pickupRadius,
      Paint()
        ..color = ringColor.withOpacity(alpha * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Emoji text
    final tp = TextPainter(
      text: TextSpan(
        text: type.emoji,
        style: TextStyle(
          fontSize: 26,
          color: Colors.white.withOpacity(alpha),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(cx - tp.width / 2, cy - tp.height / 2);
    tp.paint(canvas, Offset.zero);
    canvas.restore();
  }
}

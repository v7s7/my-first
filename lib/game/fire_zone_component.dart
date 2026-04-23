import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'boss_ball_game.dart';

/// A burning fire patch placed on the arena floor by FireTrapOrb.
///
/// Renders as a ring of animated licking flames with a glowing ember core.
/// The boss takes 600 damage every 0.4 s while standing inside the zone.
/// Zone lasts [lifetime] seconds then fades out.
class FireZoneComponent extends PositionComponent {
  final BossBallGame gameRef;
  final VoidCallback? onExpired;

  double _lifetime;
  double _tick    = 0;
  double _visual  = 0;

  static const double zoneR        = 44.0;
  static const int    tickDamage   = 600;
  static const double tickInterval = 0.40;
  static const double totalLife    = 5.0;

  FireZoneComponent({
    required Vector2 position,
    required this.gameRef,
    this.onExpired,
  })  : _lifetime = totalLife,
        super(
          position: position,
          size: Vector2.all(zoneR * 2),
          anchor: Anchor.center,
          priority: 3,
        );

  @override
  void update(double dt) {
    _visual  += dt;
    _lifetime -= dt;
    _tick    -= dt;

    if (_lifetime <= 0) {
      onExpired?.call();
      removeFromParent();
      return;
    }

    // Deal DoT while boss is in zone
    final fzBoss = gameRef.boss;
    if (fzBoss == null) return;
    final dist = position.distanceTo(fzBoss.position);
    if (dist < fzBoss.radius + zoneR && _tick <= 0) {
      _tick = tickInterval;
      gameRef.onOrbHitBoss(tickDamage, isLaserTick: true);
    }
  }

  @override
  void render(Canvas canvas) {
    final t    = _visual;
    final cx   = zoneR;
    final cy   = zoneR;
    final fade = (_lifetime / totalLife).clamp(0.0, 1.0);

    // Ground scorched zone
    canvas.drawCircle(
      Offset(cx, cy),
      zoneR,
      Paint()
        ..color = const Color(0xFF330800).withOpacity(fade * 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Licking flame pillars around the perimeter
    const flameCount = 10;
    for (int i = 0; i < flameCount; i++) {
      final rng    = Random((t * 12 + i * 31).floor());
      final angle  = (i / flameCount) * 2 * pi + t * 0.7;
      final orbitR = zoneR * 0.6 + rng.nextDouble() * zoneR * 0.35;
      final bx     = cx + cos(angle) * orbitR;
      final by     = cy + sin(angle) * orbitR;
      final sz     = 5.5 + rng.nextDouble() * 5 + sin(t * 9 + i) * 2.5;
      final lick   = 10 + rng.nextDouble() * 14 + sin(t * 11 + i * 1.3) * 5;

      // Ember base
      canvas.drawCircle(
        Offset(bx, by),
        sz,
        Paint()
          ..color = Color.fromARGB(
              (170 * fade).round(), 255, 70 + (i % 3) * 20, 0)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      // Bright yellow flame tip
      canvas.drawCircle(
        Offset(bx, by - lick),
        sz * 0.5,
        Paint()
          ..color = Color.fromARGB(
              (190 * fade).round(), 255, 210, 20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // Hot centre glow
    canvas.drawCircle(
      Offset(cx, cy),
      zoneR * 0.38 + sin(t * 6) * 3,
      Paint()
        ..color = const Color(0xAAFF3300).withOpacity(fade * 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
  }
}

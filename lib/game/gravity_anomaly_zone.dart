import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'boss_ball_game.dart';

/// Gravity anomaly spawned by the 🌐 Gravity Well pickup.
///
/// For [_lifetime] seconds every moving object within [_effectRadius] px is
/// pulled toward the anomaly's centre.  The pull is inverse-linear so objects
/// near the centre are strongly attracted while those at the edge feel a gentle
/// deflection.  The boss velocity is clamped by its own speed limit; orb
/// velocities are nudged but wall-bounce normalisation keeps them from
/// permanently accelerating.
class GravityAnomalyZone extends PositionComponent {
  final BossBallGame gameRef;

  static const double _effectRadius = 210.0;
  static const double _pullStrength = 18000.0;
  static const double _lifetime     = 5.0;

  double _timeLeft = _lifetime;
  double _time     = 0.0;

  GravityAnomalyZone({
    required Vector2 position,
    required this.gameRef,
  }) : super(
          position: position,
          size: Vector2.all(_effectRadius * 2),
          anchor: Anchor.center,
          priority: 4,
        );

  @override
  void update(double dt) {
    _timeLeft -= dt;
    _time     += dt;

    if (_timeLeft <= 0) {
      removeFromParent();
      return;
    }

    // Pull boss
    final gb = gameRef.boss;
    if (gb != null) {
      final toCenter = position - gb.position;
      final dist = toCenter.length;
      if (dist > 1 && dist < _effectRadius) {
        gb.velocity += toCenter.normalized() *
            (_pullStrength / max(dist, 40.0)) * dt;
      }
    }

    // Pull orbs
    for (final orb in gameRef.orbs) {
      final toCenter = position - orb.position;
      final dist = toCenter.length;
      if (dist > 1 && dist < _effectRadius) {
        orb.velocity += toCenter.normalized() *
            (_pullStrength / max(dist, 40.0)) * dt;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final cx      = _effectRadius;
    final cy      = _effectRadius;
    final fadeOut = _timeLeft < 0.8 ? _timeLeft / 0.8 : 1.0;

    // Outer reach ring
    canvas.drawCircle(
      Offset(cx, cy),
      _effectRadius,
      Paint()
        ..color = const Color(0xFF44FFCC).withOpacity(0.06 * fadeOut)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Spinning accretion arcs
    const arcCount = 5;
    for (int i = 0; i < arcCount; i++) {
      final hue  = (i * (360.0 / arcCount) + _time * 70) % 360;
      final col  = HSLColor.fromAHSL(0.75 * fadeOut, hue, 0.9, 0.55).toColor();
      final ang  = _time * (2.8 + i * 0.25) + i * (2 * pi / arcCount);
      final r    = 24.0 + sin(_time * 1.8 + i) * 6;

      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        ang,
        pi * 0.6,
        false,
        Paint()
          ..color = col
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }

    // Mid pull-beam ring
    canvas.drawCircle(
      Offset(cx, cy),
      38 + sin(_time * 3) * 4,
      Paint()
        ..color = const Color(0xFF44FFCC).withOpacity(0.35 * fadeOut)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    // Singularity core
    canvas.drawCircle(
      Offset(cx, cy),
      11,
      Paint()
        ..color = Colors.black.withOpacity(0.95 * fadeOut)
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 6),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      6,
      Paint()
        ..color = const Color(0xFF88FFEE).withOpacity(0.9 * fadeOut)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Radial gravity lines
    for (int i = 0; i < 8; i++) {
      final angle = _time * 1.2 + i * (pi / 4);
      final inner = 14.0;
      final outer = 32.0 + sin(_time * 3 + i) * 6;
      canvas.drawLine(
        Offset(cx + cos(angle) * inner, cy + sin(angle) * inner),
        Offset(cx + cos(angle) * outer, cy + sin(angle) * outer),
        Paint()
          ..color = const Color(0xFF44FFCC).withOpacity(0.45 * fadeOut)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }
}

import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

/// A rainbow-cycling orb inspired by viral TikTok neon ball simulations.
///
/// The ball constantly sweeps through the full hue wheel, leaving a vivid
/// colour-shifting trail.  On boss hit: 2 000 dmg + an expanding rainbow
/// shockwave of 6 colour rings.
///
/// Five spinning arc-rings at staggered radii and speeds give the orb a
/// hypnotic halo that pulses with every rotation.
class RainbowOrb extends OrbBehavior {
  @override String get id   => 'rainbow';
  @override String get name => 'RAINBOW';
  @override String get description => '2K/hit\nneon frenzy';

  double _time  = 0;
  bool   _burst = false;
  double _burstTimer = 0;
  static const double _burstDuration = 0.5;

  /// Hue sweeps the full 360° roughly every 4 s — vivid, always lit.
  @override
  Color get color {
    final hue = (_time * 90) % 360;
    return HSLColor.fromAHSL(1.0, hue, 1.0, 0.60).toColor();
  }

  @override void onAttach(PlayerOrb orb) { _time = 0; _burst = false; }

  @override void onUpdate(double dt, PlayerOrb orb) {
    _time += dt;
    if (_burst) {
      _burstTimer -= dt;
      if (_burstTimer <= 0) _burst = false;
    }
  }

  @override void onBossHit(PlayerOrb orb) {
    orb.gameRef.onOrbHitBoss(2000);
    _burst      = true;
    _burstTimer = _burstDuration;
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t = _time;

    // 5 spinning rainbow arcs at staggered radii + speeds
    for (int i = 0; i < 5; i++) {
      final hue   = (t * 160 + i * 72) % 360.0;
      final c     = HSLColor.fromAHSL(0.85, hue, 1.0, 0.60).toColor();
      final arcR  = radius + 6.0 + i * 5.5;
      final speed = 2.2 + i * 0.45;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: arcR),
        t * speed + i * (2 * pi / 5),
        pi * 1.1,
        false,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }

    // On-hit: expanding rainbow shockwave (6 colour rings)
    if (_burst) {
      final progress = 1.0 - (_burstTimer / _burstDuration);
      for (int i = 0; i < 6; i++) {
        final hue   = (i * 60 + t * 200) % 360.0;
        final alpha = ((1.0 - progress) * 220).round().clamp(0, 220);
        final pulseR = radius + progress * (radius * 2.8 + i * 7.0);
        canvas.drawCircle(
          Offset(cx, cy),
          pulseR,
          Paint()
            ..color = HSLColor.fromAHSL(1.0, hue, 1.0, 0.65)
                .toColor()
                .withOpacity(alpha / 255.0 * 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
        );
      }
    }
  }
}

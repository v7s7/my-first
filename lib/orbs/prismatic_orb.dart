import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

/// Damage oscillates on a sine wave between 400 and 18 000 every 7 s.
///
/// The orb's colour continuously shifts through the full HSL hue wheel.
/// Three spinning arc-rings show the current position in the cycle —
/// hit near the peak (full gold glow) for maximum damage.
class PrismaticOrb extends OrbBehavior {
  @override String get id   => 'prismatic';
  @override String get name => 'PRISM';
  @override String get description => '400-18K\ntimed hit';

  static const double _cyclePeriod = 7.0;  // seconds for one full wave
  static const int    _minDamage   = 400;
  static const int    _maxDamage   = 18000;

  double _cycleTimer = 0.0;

  /// 0..1 — position in the damage curve (0 = trough, 1 = peak).
  double get _cyclePos => (sin(_cycleTimer * 2 * pi / _cyclePeriod) + 1) / 2;

  @override
  Color get color {
    // Hue sweeps 360° every ~4 s; starts at a vivid cyan-purple
    final hue = (_cycleTimer * 90 + 200) % 360;
    return HSLColor.fromAHSL(1.0, hue, 1.0, 0.58).toColor();
  }

  @override void onAttach(PlayerOrb orb) { _cycleTimer = 0; }

  @override void onUpdate(double dt, PlayerOrb orb) { _cycleTimer += dt; }

  @override
  void onBossHit(PlayerOrb orb) {
    final damage =
        (_minDamage + (_maxDamage - _minDamage) * _cyclePos).round();
    orb.gameRef.onOrbHitBoss(damage);
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t = _cycleTimer;

    // Three arcs at different radii, each with a different colour and speed
    for (int i = 0; i < 3; i++) {
      final hue   = (t * 120 + i * 120) % 360.0;
      final c     = HSLColor.fromAHSL(0.75, hue, 1.0, 0.6).toColor();
      final arcR  = radius + 9.0 + i * 7.0;
      final speed = 2.0 + i * 0.8; // faster inner arcs
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: arcR),
        t * speed + i * (2 * pi / 3),
        pi * 0.85,            // arc length
        false,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // Cycle-position ring: glows gold at peak, dim at trough
    final glowAlpha = (_cyclePos * 200).round().clamp(20, 200);
    canvas.drawCircle(
      Offset(cx, cy),
      radius * 1.1,
      Paint()
        ..color = Color.fromARGB(glowAlpha, 255, 220, 60)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }
}

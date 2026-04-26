import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

/// Stacks wall-bounce energy before unleashing it.
///
/// Each wall bounce (without hitting the boss) adds one charge, up to
/// [_maxCharges].  The next boss hit consumes all charges and deals:
///   base (4 000) + charges × 1 200 per charge.
///   0 charges:  4 000     5 charges:  10 000
///   3 charges:  7 600     8 charges:  13 600 (max)
///
/// Unlike NOVA (which doubles per charge), BOUNCER scales linearly —
/// great for consistent high output when the boss is hard to reach.
///
/// Visual: concentric glow rings pile up with each bounce; rings pulse
/// out when the boss is hit.
class BouncerOrb extends OrbBehavior {
  @override String get id   => 'bouncer';
  @override String get name => 'BOUNCER';
  @override String get description => '4K + 1.2K/bounce\nmax 8 bounces';
  @override Color  get color => const Color(0xFF00DDFF);

  static const int _baseDamage     = 4000;
  static const int _bonusPerCharge = 1200;
  static const int _maxCharges     = 8;

  int    _charges   = 0;
  double _time      = 0;
  bool   _burst     = false;
  double _burstTimer = 0;
  static const double _burstDuration = 0.45;

  @override
  void onAttach(PlayerOrb orb) {
    _charges   = 0;
    _time      = 0;
    _burst     = false;
    _burstTimer = 0;
  }

  @override
  void onUpdate(double dt, PlayerOrb orb) {
    _time += dt;
    if (_burst) {
      _burstTimer -= dt;
      if (_burstTimer <= 0) _burst = false;
    }
  }

  @override
  void onWallBounce(PlayerOrb orb) {
    if (_charges < _maxCharges) _charges++;
  }

  @override
  void onBossHit(PlayerOrb orb) {
    final damage = _baseDamage + _charges * _bonusPerCharge;
    orb.gameRef.onOrbHitBoss(damage);
    _burst      = true;
    _burstTimer = _burstDuration;
    _charges    = 0;
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t    = _time;
    final norm = _charges / _maxCharges;

    // Concentric charge rings — one per charge
    for (int i = 0; i < _charges; i++) {
      final ringFrac = (i + 1) / _maxCharges;
      final ringR    = radius + 5 + i * 4.5 + sin(t * 8 + i) * 2.0;
      final hue      = 190.0 + i * 10.0;
      final c        = HSLColor.fromAHSL(1.0, hue, 1.0, 0.62).toColor();

      canvas.drawCircle(
        Offset(cx, cy),
        ringR,
        Paint()
          ..color = c.withOpacity(0.28 + ringFrac * 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 + ringFrac * 1.2
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + ringFrac * 4),
      );
    }

    // Rotating arc indicator for charge level
    if (_charges > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius + 11),
        -pi / 2,
        2 * pi * norm,
        false,
        Paint()
          ..color = const Color(0xFF00DDFF).withOpacity(0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }

    // Full-charge inner glow
    if (_charges >= _maxCharges) {
      canvas.drawCircle(
        Offset(cx, cy),
        radius * 0.6 + sin(t * 20) * 5,
        Paint()
          ..color = const Color(0x8800DDFF)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }

    // Burst — rings explode outward on hit
    if (_burst) {
      final p = 1.0 - (_burstTimer / _burstDuration);
      for (int i = 0; i < 4; i++) {
        final bR = radius + p * (radius * 3 + i * 18);
        canvas.drawCircle(
          Offset(cx, cy),
          bR,
          Paint()
            ..color = const Color(0xFF00DDFF)
                .withOpacity((1.0 - p) * 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0 * (1.0 - p)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * (1.0 - p)),
        );
      }
    }
  }
}

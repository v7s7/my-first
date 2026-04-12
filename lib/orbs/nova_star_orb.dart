import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

/// Charges up with wall bounces.  Each bounce adds one star ray (0–5).
/// Damage on hit = 1 500 × 2^charges: 1.5 K → 3 K → 6 K → 12 K → 24 K → 48 K.
/// Charges reset to zero after every hit.
///
/// Visual: golden star rays that grow in length and brightness with charge level.
/// A charge ring around the orb fills as charges build.
class NovaStarOrb extends OrbBehavior {
  @override String get id   => 'nova';
  @override String get name => 'NOVA';
  @override String get description => '1.5K-48K\n★ charge';
  @override Color  get color => const Color(0xFFFFDD00);

  static const int    _maxCharges = 5;
  static const int    _baseDamage = 1500;

  int    _charges    = 0;
  double _pulseTimer = 0;

  @override void onAttach(PlayerOrb orb)     { _charges = 0; _pulseTimer = 0; }
  @override void onUpdate(double dt, PlayerOrb orb) { _pulseTimer += dt; }

  @override
  void onWallBounce(PlayerOrb orb) {
    if (_charges < _maxCharges) _charges++;
  }

  @override
  void onBossHit(PlayerOrb orb) {
    final damage = _baseDamage * (1 << _charges); // 2^charges
    orb.gameRef.onOrbHitBoss(damage);
    _charges = 0;
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t = _pulseTimer;

    // Charge ring (fills proportionally)
    if (_charges > 0) {
      final ratio    = _charges / _maxCharges;
      final ringAlpha = (80 + (ratio * 140).round()).clamp(0, 255);
      // Background ring
      canvas.drawCircle(
        Offset(cx, cy),
        radius + 10,
        Paint()
          ..color = const Color(0x22FFDD00)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5,
      );
      // Filled arc
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius + 10),
        -pi / 2,
        2 * pi * ratio,
        false,
        Paint()
          ..color = Color.fromARGB(ringAlpha, 255, 220, 60)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    if (_charges <= 0) return;

    // Star rays — count matches charge level
    final chargeRatio = _charges / _maxCharges;
    final rayLen   = radius * 0.5 + chargeRatio * radius * 0.9;
    final pulse    = 1.0 + sin(t * 10) * 0.12;
    final rayWidth = 1.8 + chargeRatio * 1.5;

    for (int i = 0; i < _charges; i++) {
      final angle = (i / _charges) * 2 * pi + t * 1.8;
      final tipX  = cx + cos(angle) * rayLen * pulse;
      final tipY  = cy + sin(angle) * rayLen * pulse;

      // Glow layer
      canvas.drawLine(
        Offset(cx, cy),
        Offset(tipX, tipY),
        Paint()
          ..color = Color.fromARGB((100 + (chargeRatio * 100).round()).clamp(0, 255), 255, 240, 80)
          ..strokeWidth = rayWidth + 3
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      // Core ray
      canvas.drawLine(
        Offset(cx, cy),
        Offset(tipX, tipY),
        Paint()
          ..color = const Color(0xEEFFFF88)
          ..strokeWidth = rayWidth
          ..strokeCap = StrokeCap.round,
      );
    }

    // At max charge: extra bright core burst
    if (_charges >= _maxCharges) {
      canvas.drawCircle(
        Offset(cx, cy),
        radius * 0.6 + sin(t * 18) * 4,
        Paint()
          ..color = const Color(0x88FFFFFF)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
  }
}

import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

/// Charges with wall bounces.  Each bounce adds one star ray (max 5).
/// Damage: 3 000 × 2^charges.
///   0 charges: 3 000   3 charges: 24 000
///   1 charge:  6 000   4 charges: 48 000
///   2 charges: 12 000  5 charges: 96 000 — SUPERNOVA
///
/// At max charge the core erupts in a supernova burst on hit.
class NovaStarOrb extends OrbBehavior {
  @override String get id   => 'nova';
  @override String get name => 'NOVA';
  @override String get description => '3K–96K\n★ supernova';
  @override Color  get color => const Color(0xFFFFEE00);

  static const int _maxCharges = 5;
  static const int _baseDamage = 3000;

  int    _charges     = 0;
  double _pulseTimer  = 0;
  bool   _nova        = false;
  double _novaTimer   = 0;

  @override void onAttach(PlayerOrb orb) { _charges = 0; _pulseTimer = 0; }

  @override void onUpdate(double dt, PlayerOrb orb) {
    _pulseTimer += dt;
    if (_nova) {
      _novaTimer -= dt;
      if (_novaTimer <= 0) _nova = false;
    }
  }

  @override
  void onWallBounce(PlayerOrb orb) {
    if (_charges < _maxCharges) _charges++;
  }

  @override
  void onBossHit(PlayerOrb orb) {
    final damage = _baseDamage * (1 << _charges);
    orb.gameRef.onOrbHitBoss(damage);
    if (_charges >= _maxCharges) {
      _nova      = true;
      _novaTimer = 0.6;
    }
    _charges = 0;
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t     = _pulseTimer;
    final ratio = _charges / _maxCharges;

    // Charge arc ring
    if (_charges > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius + 11),
        -pi / 2,
        2 * pi * ratio,
        false,
        Paint()
          ..color = Color.fromARGB(
              (80 + (ratio * 160).round()).clamp(0, 240), 255, 220, 60)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.8
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    if (_charges <= 0) return;

    // Star rays — one per charge, growing longer
    final rayLen   = radius * 0.6 + ratio * radius * 1.2;
    final pulse    = 1.0 + sin(t * 10) * 0.12;
    final rayWidth = 2.0 + ratio * 2.0;

    for (int i = 0; i < _charges; i++) {
      final angle = (i / _charges) * 2 * pi + t * 2.0;
      final tipX  = cx + cos(angle) * rayLen * pulse;
      final tipY  = cy + sin(angle) * rayLen * pulse;

      // Glow
      canvas.drawLine(
        Offset(cx, cy), Offset(tipX, tipY),
        Paint()
          ..color = Color.fromARGB(
              (100 + (ratio * 120).round()).clamp(0, 220), 255, 240, 80)
          ..strokeWidth = rayWidth + 4
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      // Core
      canvas.drawLine(
        Offset(cx, cy), Offset(tipX, tipY),
        Paint()
          ..color = const Color(0xEEFFFF99)
          ..strokeWidth = rayWidth
          ..strokeCap = StrokeCap.round,
      );
    }

    // Max charge inner burst
    if (_charges >= _maxCharges) {
      canvas.drawCircle(
        Offset(cx, cy),
        radius * 0.65 + sin(t * 20) * 5,
        Paint()
          ..color = const Color(0xAAFFFFFF)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    // Supernova hit explosion
    if (_nova) {
      final p = 1.0 - (_novaTimer / 0.6);
      for (int i = 0; i < 8; i++) {
        final angle  = i * (pi / 4) + p * pi * 0.5;
        final nLen   = radius * 0.8 + p * radius * 4.0;
        canvas.drawLine(
          Offset(cx, cy),
          Offset(cx + cos(angle) * nLen, cy + sin(angle) * nLen),
          Paint()
            ..color = const Color(0xFFFFFF88)
                .withOpacity((1.0 - p) * 0.9)
            ..strokeWidth = (4.0 * (1.0 - p)).clamp(0.5, 4.0)
            ..strokeCap = StrokeCap.round
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * (1.0 - p)),
        );
      }
      canvas.drawCircle(
        Offset(cx, cy),
        radius + p * radius * 5,
        Paint()
          ..color = const Color(0xFFFFEE00)
              .withOpacity((1.0 - p) * 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0 * (1.0 - p)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * (1.0 - p)),
      );
    }
  }
}

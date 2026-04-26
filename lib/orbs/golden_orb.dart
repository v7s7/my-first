import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

/// Wall bounces compound damage by the golden ratio φ = 1.618…
///
/// Bounce 0 : 3 000    Bounce 3 : 12 708
/// Bounce 1 : 4 854    Bounce 4 : 20 562
/// Bounce 2 : 7 854    Bounce 5 : 33 270 (cap)
///
/// Every boss hit resets the multiplier back to 1×.
/// The golden-spiral visual shows current φⁿ level.
class GoldenOrb extends OrbBehavior {
  @override String get id   => 'golden';
  @override String get name => 'GOLDEN';
  @override String get description => '3K × φⁿ bounces\nmax 33K';
  @override Color  get color => const Color(0xFFFFAA00);

  static const double _phi      = 1.6180339887;
  static const int    _base     = 3000;
  static const int    _maxBounce = 5;

  int    _bounces   = 0;
  double _time      = 0;
  bool   _hit       = false;
  double _hitTimer  = 0;
  static const double _hitDur = 0.4;

  @override
  void onAttach(PlayerOrb orb) { _bounces = 0; _time = 0; _hit = false; }

  @override
  void onUpdate(double dt, PlayerOrb orb) {
    _time += dt;
    if (_hit) {
      _hitTimer -= dt;
      if (_hitTimer <= 0) _hit = false;
    }
  }

  @override
  void onWallBounce(PlayerOrb orb) {
    if (_bounces < _maxBounce) _bounces++;
  }

  @override
  void onBossHit(PlayerOrb orb) {
    final mult   = pow(_phi, _bounces).toDouble();
    final damage = (_base * mult).round().clamp(_base, 40000);
    orb.gameRef.onOrbHitBoss(damage);
    _hit      = true;
    _hitTimer = _hitDur;
    _bounces  = 0;
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t    = _time;
    final norm = _bounces / _maxBounce;

    // Golden ratio spiral — 5 arcs of progressively φ-scaled radii
    double arcR   = radius * 0.18;
    double pivotX = cx;
    double pivotY = cy + arcR;
    for (int i = 0; i < _bounces + 1 && i < 6; i++) {
      final active = i <= _bounces;
      final hue    = 38.0 + i * 6.0;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(pivotX, pivotY), radius: arcR),
        pi * (i % 4 * 0.5),
        pi * 0.5,
        false,
        Paint()
          ..color = HSLColor.fromAHSL(active ? 0.85 : 0.20, hue, 1.0, 0.58).toColor()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..maskFilter = active
              ? const MaskFilter.blur(BlurStyle.normal, 3)
              : null,
      );
      switch (i % 4) {
        case 0: pivotY -= arcR;
        case 1: pivotX += arcR; pivotY -= arcR;
        case 2: pivotX += arcR;
        case 3: pivotY += arcR;
      }
      arcR *= _phi;
      if (arcR > radius * 3) break;
    }

    // φⁿ charge arc
    if (_bounces > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius + 12),
        -pi / 2,
        2 * pi * norm,
        false,
        Paint()
          ..color = const Color(0xFFFFAA00).withOpacity(0.80)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // φ symbol badge
    final tp = TextPainter(
      text: TextSpan(
        text: 'φ${_bounces > 0 ? '${_bounces}' : ''}',
        style: TextStyle(
          color: const Color(0xFFFFAA00).withOpacity(0.75),
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx + radius + 3, cy - 6));

    // Hit burst
    if (_hit) {
      final p = 1.0 - (_hitTimer / _hitDur);
      for (int i = 0; i < 3; i++) {
        final bR = radius + p * (radius * 3 + i * 14);
        canvas.drawCircle(
          Offset(cx, cy),
          bR,
          Paint()
            ..color = const Color(0xFFFFAA00).withOpacity((1.0 - p) * 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5 * (1.0 - p)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * (1.0 - p)),
        );
      }
    }
  }
}

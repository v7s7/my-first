import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

/// Every 5th boss hit is a phantom strike — dealing 3× damage.
///
/// The orb counts hits since the last phantom strike.  When the counter
/// reaches 5, the next hit triggers the phantom: ghostly visuals erupt
/// and damage is tripled (5 000 → 15 000).
///
/// Hit 1–4 : 5 000        Hit 5 (phantom) : 15 000
/// Sustained DPS is higher than it looks because the phantom fires
/// without resetting combo, making it combo-friendly.
///
/// Visual: spectral ghost trail, hit counter orbiting dots, bright purple
/// nova burst on phantom strikes.
class PhantomOrb extends OrbBehavior {
  @override String get id   => 'phantom';
  @override String get name => 'PHANTOM';
  @override String get description => '5K normal\n15K every 5th hit';
  @override Color  get color => const Color(0xFFCC44FF);

  static const int _normalDamage  = 5000;
  static const int _phantomDamage = 15000;
  static const int _phantomEvery  = 5;

  int    _hitsSincePhantom = 0;
  double _time             = 0;
  bool   _phantomFired     = false;
  double _phantomTimer     = 0;
  static const double _phantomDuration = 0.55;

  @override
  void onAttach(PlayerOrb orb) {
    _hitsSincePhantom = 0;
    _time             = 0;
    _phantomFired     = false;
    _phantomTimer     = 0;
  }

  @override
  void onUpdate(double dt, PlayerOrb orb) {
    _time += dt;
    if (_phantomFired) {
      _phantomTimer -= dt;
      if (_phantomTimer <= 0) _phantomFired = false;
    }
  }

  @override
  void onBossHit(PlayerOrb orb) {
    _hitsSincePhantom++;
    if (_hitsSincePhantom >= _phantomEvery) {
      orb.gameRef.onOrbHitBoss(_phantomDamage);
      _hitsSincePhantom = 0;
      _phantomFired     = true;
      _phantomTimer     = _phantomDuration;
    } else {
      orb.gameRef.onOrbHitBoss(_normalDamage);
    }
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t          = _time;
    final hitsToGo   = _phantomEvery - _hitsSincePhantom;
    final chargeNorm = _hitsSincePhantom / _phantomEvery;

    // Ghost aura pulses brighter as charge builds
    if (_hitsSincePhantom > 0) {
      canvas.drawCircle(
        Offset(cx, cy),
        radius * (0.6 + chargeNorm * 0.4) + sin(t * 10) * 4,
        Paint()
          ..color = const Color(0xFFCC44FF).withOpacity(0.15 + chargeNorm * 0.3)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 + chargeNorm * 8),
      );
    }

    // Orbiting hit-counter dots (filled = landed, empty = remaining)
    for (int i = 0; i < _phantomEvery; i++) {
      final a    = -pi / 2 + i * (2 * pi / _phantomEvery) + t * 0.6;
      final dR   = radius + 12;
      final px   = cx + cos(a) * dR;
      final py   = cy + sin(a) * dR;
      final done = i < _hitsSincePhantom;
      canvas.drawCircle(
        Offset(px, py),
        done ? 4.5 : 3.0,
        Paint()
          ..color = done
              ? const Color(0xFFCC44FF).withOpacity(0.90)
              : const Color(0xFFCC44FF).withOpacity(0.25)
          ..maskFilter = done
              ? const MaskFilter.blur(BlurStyle.normal, 5)
              : null,
      );
    }

    // Phantom text counter when 1 hit away
    if (hitsToGo == 1) {
      final tp = TextPainter(
        text: TextSpan(
          text: '!',
          style: TextStyle(
            color: const Color(0xFFCC44FF).withOpacity(0.9 + sin(t * 18) * 0.1),
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx + radius + 3, cy - 8));
    }

    // Phantom strike burst
    if (_phantomFired) {
      final p = 1.0 - (_phantomTimer / _phantomDuration);
      // 8-way ghost rays
      for (int i = 0; i < 8; i++) {
        final a    = i * (pi / 4) + t * 0.4;
        final rLen = radius * (0.8 + p * 4.5);
        canvas.drawLine(
          Offset(cx, cy),
          Offset(cx + cos(a) * rLen, cy + sin(a) * rLen),
          Paint()
            ..color = const Color(0xFFCC44FF).withOpacity((1.0 - p) * 0.8)
            ..strokeWidth = (3.5 * (1.0 - p)).clamp(0.5, 3.5)
            ..strokeCap = StrokeCap.round
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * (1.0 - p)),
        );
      }
      // Expanding ring
      canvas.drawCircle(
        Offset(cx, cy),
        radius + p * radius * 4,
        Paint()
          ..color = const Color(0xFFCC44FF).withOpacity((1.0 - p) * 0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0 * (1.0 - p)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * (1.0 - p)),
      );
    }
  }
}

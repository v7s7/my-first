import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

/// Each wall bounce doubles the next hit's damage (up to ×32 at 5 bounces).
/// Base: 2 000.  Max at 5 bounces: 2 000 × 32 = 64 000.
/// Bounces reset to 0 after every hit.
///
/// Visual: a ring of energy orbs orbits the ball — one orb per bounce.
/// The ring pulses faster and brighter with each added bounce.
/// At max charges the entire ring erupts in a golden flare.
class ComboOrb extends OrbBehavior {
  @override String get id   => 'combo';
  @override String get name => 'COMBO';
  @override String get description => '2K×2^bounce\nmax 64K';
  @override Color  get color => const Color(0xFFCC44FF);

  static const int    _baseDamage = 2000;
  static const int    _maxBounces = 5;

  int    _bounces = 0;
  double _time    = 0;
  bool   _hitFlash = false;
  double _flashTimer = 0;

  @override void onAttach(PlayerOrb orb) { _bounces = 0; _time = 0; }

  @override void onUpdate(double dt, PlayerOrb orb) {
    _time += dt;
    if (_hitFlash) {
      _flashTimer -= dt;
      if (_flashTimer <= 0) _hitFlash = false;
    }
  }

  @override
  void onWallBounce(PlayerOrb orb) {
    if (_bounces < _maxBounces) _bounces++;
  }

  @override
  void onBossHit(PlayerOrb orb) {
    final multi  = _bounces > 0 ? (1 << _bounces) : 1; // 2^bounces
    orb.gameRef.onOrbHitBoss(_baseDamage * multi);
    _bounces   = 0;
    _hitFlash  = true;
    _flashTimer = 0.35;
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t      = _time;
    final ratio  = _bounces / _maxBounces;
    final speed  = 2.5 + ratio * 5.0;  // orbit speed grows with bounces

    // Orbit ring of energy nodes — one per bounce
    if (_bounces > 0) {
      final orbitR = radius + 14 + ratio * 8;
      for (int i = 0; i < _bounces; i++) {
        final angle  = t * speed + i * (2 * pi / _bounces);
        final px     = cx + cos(angle) * orbitR;
        final py     = cy + sin(angle) * orbitR;
        final glow   = (0.6 + ratio * 0.4 + sin(t * 10 + i) * 0.15).clamp(0.0, 1.0);

        // Node glow
        canvas.drawCircle(
          Offset(px, py),
          5.0 + ratio * 3,
          Paint()
            ..color = color.withOpacity(glow * 0.6)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        // Node core
        canvas.drawCircle(
          Offset(px, py),
          3.0 + ratio * 1.5,
          Paint()..color = Color.lerp(color, Colors.white, ratio * 0.6)!,
        );
      }

      // Ring border
      canvas.drawCircle(
        Offset(cx, cy),
        orbitR,
        Paint()
          ..color = color.withOpacity(0.15 + ratio * 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }

    // Multiplier text
    if (_bounces > 0) {
      final multi = 1 << _bounces;
      final tp = TextPainter(
        text: TextSpan(
          text: 'x$multi',
          style: TextStyle(
            color: Color.lerp(Colors.white, const Color(0xFFFFDD00), ratio)!,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx + radius + 16, cy - 7));
    }

    // Hit flash: golden burst rings
    if (_hitFlash) {
      final p = 1.0 - (_flashTimer / 0.35);
      for (int i = 0; i < 3; i++) {
        final bR    = radius + 5 + p * (30 + i * 12);
        final alpha = ((1.0 - p) * 200).round().clamp(0, 200);
        canvas.drawCircle(
          Offset(cx, cy),
          bR,
          Paint()
            ..color = const Color(0xFFFFDD00).withOpacity(alpha / 255.0 * 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
        );
      }
    }
  }
}

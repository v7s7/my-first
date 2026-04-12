import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

/// Each wall bounce stacks one Void charge (max 8).
/// On boss hit: damage = stacks × 3 000.  Stacks reset to 0 after each hit.
///
/// Visual: dark expanding ripple rings (inverted glow), stack indicator dots
/// arranged in a ring around the orb.  At max stacks the core flares purple.
class VoidOrb extends OrbBehavior {
  @override String get id   => 'void';
  @override String get name => 'VOID';
  @override String get description => '3K/bounce\nmax 24K';
  @override Color  get color => const Color(0xFF9900FF);

  static const int _maxStacks  = 8;
  static const int _stackDamage = 3000;

  int    _stacks      = 0;
  double _rippleTimer = 0;

  @override void onAttach(PlayerOrb orb)     { _stacks = 0; _rippleTimer = 0; }
  @override void onUpdate(double dt, PlayerOrb orb) { _rippleTimer += dt; }

  @override
  void onWallBounce(PlayerOrb orb) {
    if (_stacks < _maxStacks) _stacks++;
  }

  @override
  void onBossHit(PlayerOrb orb) {
    final damage = (_stacks > 0 ? _stacks : 1) * _stackDamage;
    orb.gameRef.onOrbHitBoss(damage);
    _stacks = 0;
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t = _rippleTimer;

    // Dark inverted glow under the orb (void aura)
    canvas.drawCircle(
      Offset(cx, cy),
      radius + 8,
      Paint()
        ..color = const Color(0x44000022)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // 3 expanding void rings — each at a different phase
    for (int i = 0; i < 3; i++) {
      final phase  = (t * 1.4 + i / 3.0) % 1.0;
      final ringR  = radius + phase * radius * 1.6;
      final alpha  = ((1.0 - phase) * 180).round().clamp(0, 180);
      canvas.drawCircle(
        Offset(cx, cy),
        ringR,
        Paint()
          ..color = Color.fromARGB(alpha, 140, 0, 255)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }

    // Stack indicator dots arranged in a circle
    if (_stacks > 0) {
      const dotR = 3.5;
      const orbitR = 1.45; // as a multiple of radius
      for (int i = 0; i < _stacks; i++) {
        final angle = (i / _maxStacks) * 2 * pi - pi / 2 + t * 0.8;
        final dx = cx + cos(angle) * radius * orbitR;
        final dy = cy + sin(angle) * radius * orbitR;
        // Glow
        canvas.drawCircle(
          Offset(dx, dy),
          dotR + 2,
          Paint()
            ..color = const Color(0x88AA00FF)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        // Core
        canvas.drawCircle(
          Offset(dx, dy),
          dotR,
          Paint()..color = const Color(0xFFCC44FF),
        );
      }

      // Max-stack flare — deep purple core bloom
      if (_stacks >= _maxStacks) {
        canvas.drawCircle(
          Offset(cx, cy),
          radius * 0.7 + sin(t * 16) * 5,
          Paint()
            ..color = const Color(0x66AA00FF)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );
      }
    }
  }
}

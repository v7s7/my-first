import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

/// Each wall bounce adds one Void charge (max 8).
/// Damage: stacks × 5 000.  Max: 40 000 at 8 stacks.
/// Stacks reset after each hit.
///
/// Visual: dark void tendrils spiral outward from the orb as stacks build.
/// Three expanding dark ripple rings constantly emanate.
/// At max stacks the core collapses inward with a deep purple implosion.
class VoidOrb extends OrbBehavior {
  @override String get id   => 'void';
  @override String get name => 'VOID';
  @override String get description => '5K/bounce\nmax 40K';
  @override Color  get color => const Color(0xFFAA00FF);

  static const int _maxStacks  = 8;
  static const int _stackDamage = 5000;

  int    _stacks      = 0;
  double _rippleTimer = 0;
  bool   _implosion   = false;
  double _impTimer    = 0;

  @override void onAttach(PlayerOrb orb) { _stacks = 0; _rippleTimer = 0; }

  @override void onUpdate(double dt, PlayerOrb orb) {
    _rippleTimer += dt;
    if (_implosion) {
      _impTimer -= dt;
      if (_impTimer <= 0) _implosion = false;
    }
  }

  @override
  void onWallBounce(PlayerOrb orb) {
    if (_stacks < _maxStacks) _stacks++;
  }

  @override
  void onBossHit(PlayerOrb orb) {
    final damage = (_stacks > 0 ? _stacks : 1) * _stackDamage;
    orb.gameRef.onOrbHitBoss(damage);
    if (_stacks >= _maxStacks) {
      _implosion = true;
      _impTimer  = 0.45;
    }
    _stacks = 0;
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t     = _rippleTimer;
    final ratio = _stacks / _maxStacks;

    // 3 expanding void ripple rings
    for (int i = 0; i < 3; i++) {
      final phase  = (t * 1.6 + i / 3.0) % 1.0;
      final ringR  = radius + phase * radius * 2.0;
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

    // Void tendrils — count = stacks
    if (_stacks > 0) {
      for (int i = 0; i < _stacks; i++) {
        final baseAngle = t * (1.8 + ratio) + i * (2 * pi / _stacks);
        final rng       = Random(i * 999 + (t * 6).floor());
        final len       = radius * 0.7 + ratio * radius * 0.9;

        final path = Path()..moveTo(cx, cy);
        const segs = 4;
        for (int s = 1; s <= segs; s++) {
          final prog = s / segs;
          final a    = baseAngle + (rng.nextDouble() - 0.5) * 1.0 * prog;
          path.lineTo(
              cx + cos(a) * len * prog, cy + sin(a) * len * prog);
        }

        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0x88AA00FF)
            ..strokeWidth = 2.5
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xBBCC44FF)
            ..strokeWidth = 1.0
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
        );
      }

      // Stack indicator dots
      const dotR = 3.5;
      for (int i = 0; i < _stacks; i++) {
        final angle = (i / _maxStacks) * 2 * pi - pi / 2 + t * 0.9;
        final dx    = cx + cos(angle) * (radius * 1.5);
        final dy    = cy + sin(angle) * (radius * 1.5);
        canvas.drawCircle(
          Offset(dx, dy), dotR + 2,
          Paint()
            ..color = const Color(0x88BB00FF)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        canvas.drawCircle(
          Offset(dx, dy), dotR,
          Paint()..color = const Color(0xFFDD66FF),
        );
      }

      // Max-stack implosion core
      if (_stacks >= _maxStacks) {
        canvas.drawCircle(
          Offset(cx, cy),
          radius * 0.75 + sin(t * 20) * 6,
          Paint()
            ..color = const Color(0x99BB00FF)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
        );
      }
    }

    // Implosion burst on hit
    if (_implosion) {
      final p = 1.0 - (_impTimer / 0.45);
      // Rings collapse inward
      for (int i = 0; i < 4; i++) {
        final bR    = radius * 4 * (1.0 - p) + i * 10;
        final alpha = (p * 220).round().clamp(0, 220);
        canvas.drawCircle(
          Offset(cx, cy),
          bR.clamp(0.0, radius * 5),
          Paint()
            ..color = Color.fromARGB(alpha, 180, 0, 255)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }
    }
  }
}

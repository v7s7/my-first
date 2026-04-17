import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

/// Electric plasma tendrils arc outward continuously.
///
/// On boss hit: 4 000 burst damage + an expanding plasma ring.
/// Six animated tendrils flicker and writhe around the orb at all times,
/// creating a crackling electric-blue neon effect.
class PlasmaOrb extends OrbBehavior {
  @override String get id   => 'plasma';
  @override String get name => 'PLASMA';
  @override String get description => '4K burst\nplasma arcs';
  @override Color  get color => const Color(0xFF3399FF);

  double _time  = 0;
  bool   _burst = false;
  double _burstTimer = 0;
  static const double _burstDuration = 0.55;
  static const int    _baseDamage    = 4000;

  @override void onAttach(PlayerOrb orb) { _time = 0; _burst = false; }

  @override void onUpdate(double dt, PlayerOrb orb) {
    _time += dt;
    if (_burst) {
      _burstTimer -= dt;
      if (_burstTimer <= 0) _burst = false;
    }
  }

  @override void onBossHit(PlayerOrb orb) {
    orb.gameRef.onOrbHitBoss(_baseDamage);
    _burst      = true;
    _burstTimer = _burstDuration;
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t = _time;

    // 6 animated plasma tendrils
    for (int i = 0; i < 6; i++) {
      final baseAngle = t * 2.8 + i * (pi / 3);
      _drawTendril(canvas, radius, cx, cy, baseAngle, t, i);
    }

    // Pulsing inner plasma glow
    final pulse = sin(t * 14) * 0.15 + 0.85;
    canvas.drawCircle(
      Offset(cx, cy),
      radius * 0.55 * pulse,
      Paint()
        ..color = const Color(0x553399FF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // Rotating outer electric arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius + 9),
      t * 5.0,
      pi * 1.6,
      false,
      Paint()
        ..color = const Color(0xAA66CCFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Counter-rotating second arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius + 14),
      -t * 3.5 + pi,
      pi * 0.9,
      false,
      Paint()
        ..color = const Color(0x7799EEFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Burst ring on hit
    if (_burst) {
      final p     = 1.0 - (_burstTimer / _burstDuration);
      final bR    = radius + p * radius * 3.0;
      final alpha = ((1.0 - p) * 220).round().clamp(0, 220);
      canvas.drawCircle(
        Offset(cx, cy),
        bR,
        Paint()
          ..color = Color.fromARGB(alpha, 80, 180, 255)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }
  }

  void _drawTendril(
    Canvas canvas,
    double radius,
    double cx,
    double cy,
    double baseAngle,
    double t,
    int i,
  ) {
    final rng = Random(i * 1337 + (t * 8).floor());
    final len = radius * 0.85 + sin(t * 6 + i * 1.2) * radius * 0.35;

    const segs = 4;
    final pts  = <Offset>[Offset(cx, cy)];
    for (int s = 1; s <= segs; s++) {
      final progress = s / segs;
      final a = baseAngle + (rng.nextDouble() - 0.5) * 1.1 * progress;
      final d = len * progress;
      pts.add(Offset(cx + cos(a) * d, cy + sin(a) * d));
    }

    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int j = 1; j < pts.length; j++) {
      path.lineTo(pts[j].dx, pts[j].dy);
    }

    // Glow layer
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x8866CCFF)
        ..strokeWidth = 3.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // Bright core line
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xCCBBEEFF)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }
}

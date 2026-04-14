import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';
import '../game/thunder_zone_component.dart';

/// THUNDERSTORM: on boss hit, 12 000 instant damage + spawns a crackling
/// thunder zone at the boss's position.
/// The zone deals 800 DoT every 0.35 s and lasts 4 s.
///
/// Visual: continuous Tesla coil arcs erupting outward,
/// a bright electric core, and an outer spinning voltage ring.
class ZapperOrb extends OrbBehavior {
  @override String get id   => 'zapper';
  @override String get name => 'THUNDER';
  @override String get description => '12K burst\n+thunder zone';
  @override Color  get color => const Color(0xFF00DDFF);

  static const int    _burstDamage = 12000;

  bool   _zapActive = false;
  double _zapTimer  = 0;
  double _time      = 0;
  static const double _zapDuration = 0.8; // visual-only active phase

  @override
  void onAttach(PlayerOrb orb) {
    _zapActive = false;
    _zapTimer  = 0;
    _time      = 0;
  }

  @override
  void onUpdate(double dt, PlayerOrb orb) {
    _time += dt;
    if (_zapActive) {
      _zapTimer -= dt;
      if (_zapTimer <= 0) _zapActive = false;
    }
  }

  @override
  void onBossHit(PlayerOrb orb) {
    orb.gameRef.onOrbHitBoss(_burstDamage);
    _zapActive = true;
    _zapTimer  = _zapDuration;
    // Spawn thunder zone at boss position
    orb.gameRef.add(ThunderZoneComponent(
      position: orb.gameRef.boss.position.clone(),
      gameRef: orb.gameRef,
    ));
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t = _time;

    // Outer spinning voltage ring
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius + 10),
      t * 6.0,
      pi * 1.55,
      false,
      Paint()
        ..color = const Color(0xAA00DDFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius + 16),
      -t * 4.2 + pi,
      pi * 1.0,
      false,
      Paint()
        ..color = const Color(0x7766EEFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Tesla arcs — 5 crackling arms
    const arcCount = 5;
    for (int i = 0; i < arcCount; i++) {
      final baseAngle = t * 3.5 + i * (2 * pi / arcCount);
      final rng       = Random(i * 337 + (t * 14).floor());
      final len       = radius * 0.9 + sin(t * 7 + i * 1.3) * radius * 0.35;

      final path = Path()..moveTo(cx, cy);
      for (int s = 1; s <= 4; s++) {
        final prog = s / 4;
        final a    = baseAngle + (rng.nextDouble() - 0.5) * 1.2 * prog;
        path.lineTo(cx + cos(a) * len * prog, cy + sin(a) * len * prog);
      }
      // Glow
      canvas.drawPath(path,
          Paint()
            ..color = const Color(0x8800CCFF)
            ..strokeWidth = 3.5
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      // Core
      canvas.drawPath(path,
          Paint()
            ..color = const Color(0xCCDDFFFF)
            ..strokeWidth = 1.2
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round);
    }

    // Electric burst on hit
    if (_zapActive) {
      final p     = 1.0 - (_zapTimer / _zapDuration);
      final bR    = radius + p * radius * 3.5;
      final alpha = ((1.0 - p) * 240).round().clamp(0, 240);
      canvas.drawCircle(
        Offset(cx, cy),
        bR,
        Paint()
          ..color = Color.fromARGB(alpha, 0, 200, 255)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }

    // Bright electric core
    canvas.drawCircle(
      Offset(cx, cy),
      radius * 0.5 + sin(t * 18) * 3,
      Paint()
        ..color = Colors.white.withOpacity(0.35 + sin(t * 22) * 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }
}

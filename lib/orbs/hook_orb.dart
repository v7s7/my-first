import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

/// Homing orb that steers toward the boss within 400 px.
/// Deals 800 damage per hit.
///
/// Visual: three rotating targeting arcs that close in when lock-on is active,
/// plus a pulsing direction arrow that points at the boss while homing.
class HookOrb extends OrbBehavior {
  @override String get id   => 'hook';
  @override String get name => 'HOOK';
  @override String get description => 'homing\n800/hit';
  @override Color  get color => Colors.purpleAccent;

  double _time      = 0;
  Offset _bossDir   = Offset.zero; // unit vector toward boss in local coords
  bool   _locked    = false;       // within homing range

  @override
  void onAttach(PlayerOrb orb) {
    _time   = 0;
    _locked = false;
  }

  @override
  void onUpdate(double dt, PlayerOrb orb) {
    _time += dt;
    final bp   = orb.gameRef.boss.position;
    final dist = orb.position.distanceTo(bp);
    _locked    = dist < 400;
    if (dist > 1) {
      final dx = bp.x - orb.position.x;
      final dy = bp.y - orb.position.y;
      final len = sqrt(dx * dx + dy * dy);
      _bossDir = Offset(dx / len, dy / len);
    }
  }

  @override
  void onWallBounce(PlayerOrb orb) {}

  @override
  void onBossHit(PlayerOrb orb) {
    orb.gameRef.onOrbHitBoss(800);
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t = _time;

    // Three rotating targeting arcs — tighten when locked
    const arcCount  = 3;
    final arcRadius = _locked
        ? radius + 7.0 + sin(t * 12) * 2.0 // vibrate tight when homing
        : radius + 11.0;
    final arcAlpha  = _locked ? 0.85 : 0.45;

    for (int i = 0; i < arcCount; i++) {
      final startAngle =
          t * (_locked ? 5.5 : 3.0) + i * (2 * pi / arcCount);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: arcRadius + i * 4.5),
        startAngle,
        pi * 0.55,
        false,
        Paint()
          ..color = Colors.purpleAccent.withOpacity(arcAlpha - i * 0.1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }

    // Direction arrow toward boss while lock-on is active
    if (_locked && _bossDir != Offset.zero) {
      final arrowLen  = radius + 22.0;
      final tipX      = cx + _bossDir.dx * arrowLen;
      final tipY      = cy + _bossDir.dy * arrowLen;
      final pulseFade = (sin(t * 10) * 0.25 + 0.65).clamp(0.0, 1.0);

      // Glow line
      canvas.drawLine(
        Offset(cx, cy),
        Offset(tipX, tipY),
        Paint()
          ..color = Colors.purpleAccent.withOpacity(pulseFade * 0.55)
          ..strokeWidth = 4.0
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      // Core line
      canvas.drawLine(
        Offset(cx, cy),
        Offset(tipX, tipY),
        Paint()
          ..color = Colors.white.withOpacity(pulseFade * 0.85)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );

      // Arrowhead at tip
      final perpX = -_bossDir.dy;
      final perpY =  _bossDir.dx;
      const headSize = 6.0;
      final path = Path()
        ..moveTo(tipX, tipY)
        ..lineTo(
          tipX - _bossDir.dx * headSize + perpX * headSize * 0.5,
          tipY - _bossDir.dy * headSize + perpY * headSize * 0.5,
        )
        ..lineTo(
          tipX - _bossDir.dx * headSize - perpX * headSize * 0.5,
          tipY - _bossDir.dy * headSize - perpY * headSize * 0.5,
        )
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.purpleAccent.withOpacity(pulseFade * 0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }
}

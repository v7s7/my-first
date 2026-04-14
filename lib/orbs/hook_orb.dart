import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

/// Homing orb that steers toward the boss within 450 px.
/// On hit: 5 000 damage.  While locked on, the orb accelerates — more hits.
///
/// Visual: three rotating targeting arcs that tighten on lock-on,
/// magnetic field lines stretching toward the boss,
/// and a pulsing direction arrow with arrowhead.
class HookOrb extends OrbBehavior {
  @override String get id   => 'hook';
  @override String get name => 'MAGNET';
  @override String get description => '5K/hit\nhoming lock';
  @override Color  get color => Colors.purpleAccent;

  static const int _hitDamage = 5000;

  double _time    = 0;
  Offset _bossDir = Offset.zero;
  bool   _locked  = false;

  @override void onAttach(PlayerOrb orb) { _time = 0; _locked = false; }

  @override
  void onUpdate(double dt, PlayerOrb orb) {
    _time  += dt;
    final bp   = orb.gameRef.boss.position;
    final dist = orb.position.distanceTo(bp);
    _locked    = dist < 450;
    if (dist > 1) {
      final dx = bp.x - orb.position.x;
      final dy = bp.y - orb.position.y;
      final len = sqrt(dx * dx + dy * dy);
      _bossDir = Offset(dx / len, dy / len);
    }
  }

  @override void onWallBounce(PlayerOrb orb) {}

  @override void onBossHit(PlayerOrb orb) {
    orb.gameRef.onOrbHitBoss(_hitDamage);
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t = _time;

    // Three rotating targeting arcs
    const arcCount = 3;
    final arcR     = _locked
        ? radius + 7.0 + sin(t * 14) * 2.5
        : radius + 12.0;

    for (int i = 0; i < arcCount; i++) {
      final startAngle = t * (_locked ? 6.0 : 3.2) + i * (2 * pi / arcCount);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: arcR + i * 5.0),
        startAngle,
        pi * 0.55,
        false,
        Paint()
          ..color = Colors.purpleAccent.withOpacity(
              _locked ? (0.85 - i * 0.1) : (0.45 - i * 0.08))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }

    if (!_locked || _bossDir == Offset.zero) return;

    // Magnetic field lines (3 parallel curving lines toward boss)
    for (int line = -1; line <= 1; line++) {
      final perpAngle = atan2(_bossDir.dy, _bossDir.dx) + pi / 2;
      final offsetX   = cos(perpAngle) * line * 5.0;
      final offsetY   = sin(perpAngle) * line * 5.0;
      final arrowLen  = radius + 18.0 + line.abs() * 4;

      canvas.drawLine(
        Offset(cx + offsetX, cy + offsetY),
        Offset(
          cx + _bossDir.dx * arrowLen + offsetX,
          cy + _bossDir.dy * arrowLen + offsetY,
        ),
        Paint()
          ..color = Colors.purpleAccent.withOpacity(
              (0.7 - line.abs() * 0.2 + sin(t * 10) * 0.2).clamp(0.0, 1.0))
          ..strokeWidth = line == 0 ? 2.0 : 1.0
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // Arrowhead at centre line tip
    final arrowLen = radius + 18.0;
    final tipX     = cx + _bossDir.dx * arrowLen;
    final tipY     = cy + _bossDir.dy * arrowLen;
    final perpX    = -_bossDir.dy;
    final perpY    =  _bossDir.dx;
    const headSize = 7.0;

    final headPath = Path()
      ..moveTo(tipX, tipY)
      ..lineTo(tipX - _bossDir.dx * headSize + perpX * headSize * 0.5,
               tipY - _bossDir.dy * headSize + perpY * headSize * 0.5)
      ..lineTo(tipX - _bossDir.dx * headSize - perpX * headSize * 0.5,
               tipY - _bossDir.dy * headSize - perpY * headSize * 0.5)
      ..close();

    final pulseFade = (sin(t * 10) * 0.2 + 0.7).clamp(0.0, 1.0);
    canvas.drawPath(
      headPath,
      Paint()
        ..color = Colors.purpleAccent.withOpacity(pulseFade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }
}

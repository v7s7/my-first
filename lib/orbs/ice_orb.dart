import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

/// Freezes the boss on contact for 2.5 s — slows it to ~10 % of its normal
/// speed.  Ice crystals appear on the boss while frozen (rendered in
/// BossComponent).
///
/// Bonus: all orb hits while the boss is frozen deal 2× damage.
///
/// Visual: a rotating snowflake with branching arms on the orb itself.
class IceOrb extends OrbBehavior {
  @override String get id   => 'ice';
  @override String get name => 'ICE';
  @override String get description => 'freeze 2.5s\n1.5K + ×2 bonus';
  @override Color  get color => const Color(0xFF99DDFF);

  static const int    _hitDamage = 1500;
  static const double _freezeDur = 2.5;

  double _time = 0;

  @override void onAttach(PlayerOrb orb) { _time = 0; }
  @override void onUpdate(double dt, PlayerOrb orb) { _time += dt; }

  @override
  void onBossHit(PlayerOrb orb) {
    final boss = orb.gameRef.boss;
    // 2× bonus while boss is already frozen
    final dmg  = boss.isFrozen ? _hitDamage * 2 : _hitDamage;
    orb.gameRef.onOrbHitBoss(dmg);
    boss.freezeBoss(_freezeDur);
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t = _time;

    // 6 snowflake spokes
    const spokes = 6;
    for (int i = 0; i < spokes; i++) {
      final angle = i * (pi / spokes) + t * 0.45;
      final len   = radius * 0.88 + sin(t * 5 + i) * 2.5;
      final tipX  = cx + cos(angle) * len;
      final tipY  = cy + sin(angle) * len;

      // Main spoke
      canvas.drawLine(
        Offset(cx, cy),
        Offset(tipX, tipY),
        Paint()
          ..color = const Color(0xBBCCEEFF)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );

      // Two branch arms at 1/3 and 2/3 along the spoke
      for (int b = 1; b <= 2; b++) {
        final frac  = b / 3.0;
        final bx    = cx + cos(angle) * len * frac;
        final by    = cy + sin(angle) * len * frac;
        final armL  = len * 0.22;
        for (int side = -1; side <= 1; side += 2) {
          final branchAngle = angle + side * pi / 2;
          canvas.drawLine(
            Offset(bx, by),
            Offset(bx + cos(branchAngle) * armL, by + sin(branchAngle) * armL),
            Paint()
              ..color = const Color(0x99AADDFF)
              ..strokeWidth = 1.0
              ..strokeCap = StrokeCap.round,
          );
        }
      }
    }

    // Icy outer ring
    canvas.drawCircle(
      Offset(cx, cy),
      radius + 10,
      Paint()
        ..color = const Color(0x5599DDFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Spinning inner ring of ice dots
    const dotCount = 8;
    for (int i = 0; i < dotCount; i++) {
      final a  = i * (2 * pi / dotCount) + t * 1.2;
      final px = cx + cos(a) * (radius - 4);
      final py = cy + sin(a) * (radius - 4);
      canvas.drawCircle(
        Offset(px, py),
        2.0,
        Paint()
          ..color = const Color(0xAADDEEFF)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }
}

import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

class ComboOrb extends OrbBehavior {
  @override
  String get id => 'combo';

  @override
  String get name => 'COMBO';

  @override
  String get description => 'x2/x4/x8\nbounce mult';

  @override
  Color get color => const Color(0xFFCC44FF);

  int _wallBounces = 0;

  @override
  void onAttach(PlayerOrb orb) => _wallBounces = 0;

  @override
  void onWallBounce(PlayerOrb orb) => _wallBounces++;

  @override
  void onBossHit(PlayerOrb orb) {
    final bounces = _wallBounces.clamp(0, 10);
    final multiplier = bounces > 0 ? pow(2, bounces).toInt() : 1;
    orb.gameRef.onOrbHitBoss(500 * multiplier);
    _wallBounces = 0;
  }

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    if (_wallBounces <= 0) return;
    final multi = pow(2, _wallBounces.clamp(0, 10)).toInt();
    final tp = TextPainter(
      text: TextSpan(
        text: 'x$multi',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx + radius + 3, cy - 7));
  }
}

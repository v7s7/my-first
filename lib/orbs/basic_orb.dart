import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

class BasicOrb extends OrbBehavior {
  @override
  String get id => 'basic';

  @override
  String get name => 'BASIC';

  @override
  String get description => '1K dmg\nper hit';

  @override
  Color get color => const Color(0xFF00FFEE);

  @override
  void onBossHit(PlayerOrb orb) {
    orb.gameRef.onOrbHitBoss(1000);
  }
}

import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

class HookOrb extends OrbBehavior {
  @override
  String get id => 'hook';

  @override
  String get name => 'Hook Orb';

  @override
  String get description => 'Intelligent homing medium damage';

  @override
  Color get color => Colors.purpleAccent;

  @override
  void onAttach(PlayerOrb orb) {}

  @override
  void onUpdate(double dt, PlayerOrb orb) {}

  @override
  void onWallBounce(PlayerOrb orb) {}

  @override
  void onBossHit(PlayerOrb orb) {
    orb.gameRef.onOrbHitBoss(800);
  }
}
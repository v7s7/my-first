import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';
import '../game/laser_beam.dart';

class LaserOrb extends OrbBehavior {
  @override
  String get id => 'laser';

  @override
  String get name => 'LASER';

  @override
  String get description => '10K dmg\nbeam burst';

  @override
  Color get color => const Color(0xFFFF4400);

  // All laser state lives here — zero trace in PlayerOrb.
  static const double _laserDuration = 1.0;
  static const double _laserTickRate = 0.05; // 20 ticks × 500 = 10K total
  static const int _laserTickDamage = 500;

  bool _laserActive = false;
  double _laserTimer = 0.0;
  double _laserTickTimer = 0.0;
  LaserBeam? _activeLaser;

  @override
  void onAttach(PlayerOrb orb) {
    _laserActive = false;
    _laserTimer = 0.0;
    _laserTickTimer = 0.0;
    _activeLaser = null;
  }

  @override
  void onUpdate(double dt, PlayerOrb orb) {
    if (!_laserActive) return;

    _laserTimer -= dt;
    _laserTickTimer -= dt;

    // Keep beam tracking both endpoints
    _activeLaser?.startPos = orb.position;
    _activeLaser?.endPos = orb.gameRef.boss.position;
    _activeLaser?.timeLeft = _laserTimer;

    if (_laserTickTimer <= 0) {
      _laserTickTimer = _laserTickRate;
      orb.gameRef.onOrbHitBoss(_laserTickDamage, isLaserTick: true);
    }

    if (_laserTimer <= 0) {
      _laserActive = false;
      _activeLaser?.removeFromParent();
      _activeLaser = null;
    }
  }

  @override
  void onBossHit(PlayerOrb orb) {
    if (_laserActive) return; // already firing
    _laserActive = true;
    _laserTimer = _laserDuration;
    _laserTickTimer = 0;
    _activeLaser = LaserBeam(
      startPos: orb.position.clone(),
      endPos: orb.gameRef.boss.position.clone(),
      totalDuration: _laserDuration,
      timeLeft: _laserDuration,
    );
    orb.gameRef.add(_activeLaser!);
  }

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    if (!_laserActive) return;
    // Pulsing outer ring to indicate active laser
    canvas.drawCircle(
      Offset(cx, cy),
      radius * 1.35,
      Paint()
        ..color = const Color(0x66FF4400)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }
}

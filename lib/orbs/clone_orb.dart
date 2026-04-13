import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

/// Creates 2 temporary clones that attack alongside the main orb.
/// Each hit deals 1.5K. Total: 4.5K over 3 seconds.
class CloneOrb extends OrbBehavior {
  @override
  String get id => 'clone';

  @override
  String get name => 'CLONE';

  @override
  String get description => '2 clones spawn\n4.5K multi-hit';

  @override
  Color get color => const Color(0xFFDD00FF);

  bool _clonesActive = false;
  double _cloneTimer = 0;
  static const double _cloneDuration = 3.5;
  static const int _cloneCount = 2;
  static const int _hitDamage = 1500;
  double _hitCooldown = 0;
  static const double _hitInterval = 0.6;

  @override
  void onAttach(PlayerOrb orb) {
    _clonesActive = false;
    _cloneTimer = 0;
    _hitCooldown = 0;
  }

  @override
  void onUpdate(double dt, PlayerOrb orb) {
    if (!_clonesActive) return;
    
    _cloneTimer -= dt;
    _hitCooldown -= dt;
    
    if (_hitCooldown <= 0) {
      _hitCooldown = _hitInterval;
      orb.gameRef.onOrbHitBoss(_hitDamage);
    }
    
    if (_cloneTimer <= 0) {
      _clonesActive = false;
    }
  }

  @override
  void onBossHit(PlayerOrb orb) {
    orb.gameRef.onOrbHitBoss(1500);
    
    // Activate clones
    _clonesActive = true;
    _cloneTimer = _cloneDuration;
    _hitCooldown = 0;
  }

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    if (!_clonesActive) return;
    
    final progress = 1.0 - (_cloneTimer / _cloneDuration);
    
    // Draw 2 orbiting clones
    for (int i = 0; i < _cloneCount; i++) {
      final angle = (i / _cloneCount) * pi * 2 + progress * pi * 4;
      final distance = radius + 30 + sin(progress * pi * 3) * 15;
      final x = cx + cos(angle) * distance;
      final y = cy + sin(angle) * distance;
      
      // Clone sphere
      canvas.drawCircle(
        Offset(x, y),
        radius * 0.5,
        Paint()
          ..color = color.withOpacity(0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      
      // Highlight on clone
      canvas.drawCircle(
        Offset(x - radius * 0.15, y - radius * 0.15),
        radius * 0.2,
        Paint()
          ..color = Colors.white.withOpacity(0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      
      // Connection line to main orb
      canvas.drawLine(
        Offset(cx, cy),
        Offset(x, y),
        Paint()
          ..color = color.withOpacity((sin(progress * pi * 8) * 0.3 + 0.4))
          ..strokeWidth = 2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }
}

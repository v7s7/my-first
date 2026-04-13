import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

/// Creates a black hole vortex that pulls and damages the boss.
/// 8K instant + massive pull effect.
class BlackHoleOrb extends OrbBehavior {
  @override
  String get id => 'blackhole';

  @override
  String get name => 'BLACK HOLE';

  @override
  String get description => 'gravity pull\n8K + vortex';

  @override
  Color get color => const Color(0xFF1A1A2E);

  bool _vortexActive = false;
  double _vortexTimer = 0;
  static const double _vortexDuration = 2.0;
  static const int _baseDamage = 8000;

  @override
  void onAttach(PlayerOrb orb) {
    _vortexActive = false;
    _vortexTimer = 0;
  }

  @override
  void onUpdate(double dt, PlayerOrb orb) {
    if (!_vortexActive) return;
    
    _vortexTimer -= dt;
    
    // Pull boss toward vortex center
    final bossPos = orb.gameRef.boss.position;
    final orbPos = orb.position;
    final direction = (orbPos - bossPos).normalized();
    
    // Apply pull force to boss
    orb.gameRef.boss.velocity += direction * 200 * dt;
    
    if (_vortexTimer <= 0) {
      _vortexActive = false;
    }
  }

  @override
  void onBossHit(PlayerOrb orb) {
    orb.gameRef.onOrbHitBoss(_baseDamage);
    
    _vortexActive = true;
    _vortexTimer = _vortexDuration;
  }

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    if (!_vortexActive) return;
    
    final progress = 1.0 - (_vortexTimer / _vortexDuration);
    final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
    
    // Multiple spinning rings with fade effect
    const ringCount = 5;
    for (int ring = 0; ring < ringCount; ring++) {
      final ringRadius = radius * 0.3 + (ring / ringCount) * radius * 1.2;
      final ringProgress = (progress + ring * 0.2) % 1.0;
      final opacity = (1.0 - ringProgress) * 0.6;
      
      // Draw spiral segments
      const segments = 12;
      for (int i = 0; i < segments; i++) {
        final angle = (i / segments) * pi * 2 + time * 8;
        final x1 = cx + cos(angle) * ringRadius;
        final y1 = cy + sin(angle) * ringRadius;
        final angle2 = ((i + 1) / segments) * pi * 2 + time * 8;
        final x2 = cx + cos(angle2) * ringRadius;
        final y2 = cy + sin(angle2) * ringRadius;
        
        canvas.drawLine(
          Offset(x1, y1),
          Offset(x2, y2),
          Paint()
            ..color = Color.lerp(Colors.purple, Colors.black, ring / ringCount)!
                .withOpacity(opacity)
            ..strokeWidth = 2
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      }
    }
    
    // Center event horizon
    canvas.drawCircle(
      Offset(cx, cy),
      radius * 0.25,
      Paint()
        ..color = Colors.black.withOpacity(0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 8),
    );
    
    // Accretion disk glow
    canvas.drawCircle(
      Offset(cx, cy),
      radius * 0.35 + sin(time * 6) * 5,
      Paint()
        ..color = Colors.deepPurple.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
  }
}

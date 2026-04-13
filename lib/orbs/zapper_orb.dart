import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

/// Creates electric arcs that zap the boss. 5 arcs spawn, each dealing 1.2K damage.
/// Total: 6K instant + 0.5K DoT ticks = 6.5K.
class ZapperOrb extends OrbBehavior {
  @override
  String get id => 'zapper';

  @override
  String get name => 'ZAPPER';

  @override
  String get description => 'electric arcs\n6.5K + chain';

  @override
  Color get color => const Color(0xFF00FFFF);

  bool _zapActive = false;
  double _zapTimer = 0;
  static const double _zapDuration = 1.8;
  static const int _arcCount = 5;
  static const int _baseDamage = 3000;
  static const int _tickDamage = 100;
  double _tickTimer = 0;
  int _ticksLeft = 5;

  @override
  void onAttach(PlayerOrb orb) {
    _zapActive = false;
    _zapTimer = 0;
    _ticksLeft = 5;
    _tickTimer = 0;
  }

  @override
  void onUpdate(double dt, PlayerOrb orb) {
    if (!_zapActive) return;
    
    _zapTimer -= dt;
    _tickTimer -= dt;
    
    // Continuous zap damage
    if (_tickTimer <= 0) {
      _tickTimer = 0.3;
      if (_ticksLeft > 0) {
        orb.gameRef.onOrbHitBoss(_tickDamage, isLaserTick: true);
        _ticksLeft--;
      }
    }
    
    if (_zapTimer <= 0) {
      _zapActive = false;
    }
  }

  @override
  void onBossHit(PlayerOrb orb) {
    // Initial burst damage
    orb.gameRef.onOrbHitBoss(_baseDamage);
    
    // Activate zap sequence
    _zapActive = true;
    _zapTimer = _zapDuration;
    _ticksLeft = 5;
    _tickTimer = 0.1;
  }

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    if (!_zapActive) return;
    
    final progress = 1.0 - (_zapTimer / _zapDuration);
    // Draw arcing electric lines
    for (int i = 0; i < _arcCount; i++) {
      final angle = (i / _arcCount) * pi * 2;
      final distance = radius + 40;
      
      // Zigzag path
      final points = <Offset>[Offset(cx, cy)];
      const segments = 5;
      for (int j = 1; j <= segments; j++) {
        final t = j / segments;
        final x = cx + cos(angle) * distance * t;
        final y = cy + sin(angle) * distance * t;
        final jitter = sin(progress * pi * 8 + i + j) * 8;
        points.add(Offset(x + jitter, y + jitter));
      }
      
      for (int j = 0; j < points.length - 1; j++) {
        canvas.drawLine(
          points[j],
          points[j + 1],
          Paint()
            ..color = Color.lerp(Colors.cyan, Colors.white, sin(progress * pi) * 0.5 + 0.5)!
            ..strokeWidth = 2
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
    }
    
    // Core glow
    canvas.drawCircle(
      Offset(cx, cy),
      radius * 0.6,
      Paint()
        ..color = Colors.cyan.withOpacity(sin(progress * pi * 6) * 0.3 + 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }
}

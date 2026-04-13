import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

/// Splits into 3 spinning projectiles on impact. Each deals 2K damage.
/// Total: 2K initial + 6K from splits = 8K.
class SplitterOrb extends OrbBehavior {
  @override
  String get id => 'splitter';

  @override
  String get name => 'SPLITTER';

  @override
  String get description => 'splits into 3\n8K total burst';

  @override
  Color get color => const Color(0xFFFFAA00);

  bool _splitActive = false;
  double _splitTimer = 0;
  static const double _splitDuration = 2.5;
  static const int _splitCount = 3;
  static const int _baseDamage = 2000;
  static const int _splitDamage = 2000;

  @override
  void onAttach(PlayerOrb orb) {
    _splitActive = false;
    _splitTimer = 0;
  }

  @override
  void onUpdate(double dt, PlayerOrb orb) {
    if (!_splitActive) return;
    
    _splitTimer -= dt;
    if (_splitTimer <= 0) {
      _splitActive = false;
    }
  }

  @override
  void onBossHit(PlayerOrb orb) {
    // Initial damage
    orb.gameRef.onOrbHitBoss(_baseDamage);
    
    // Activate split mode
    _splitActive = true;
    _splitTimer = _splitDuration;
    
    // Fire 3 projectiles in a spread
    final bossPos = orb.gameRef.boss.position;
    for (int i = 0; i < _splitCount; i++) {
      final angle = (i / _splitCount) * pi * 2 - pi / 6;
      final direction = Vector2(cos(angle), sin(angle));
      
      // Create a projectile component
      orb.gameRef.add(
        _SplitProjectile(
          position: bossPos.clone(),
          direction: direction,
          damage: _splitDamage,
          lifetime: _splitDuration,
          gameRef: orb.gameRef,
        ),
      );
    }
  }

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    if (!_splitActive) return;
    
    final progress = 1.0 - (_splitTimer / _splitDuration);
    final size = radius * (0.4 + progress * 0.6);
    const count = 3;
    
    for (int i = 0; i < count; i++) {
      final angle = (i / count) * pi * 2 + progress * pi * 4;
      final x = cx + cos(angle) * size;
      final y = cy + sin(angle) * size;
      
      canvas.drawCircle(
        Offset(x, y),
        radius * 0.3,
        Paint()
          ..color = color.withOpacity(0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }
}

/// Visual projectile from splitter that deals damage on hit
class _SplitProjectile extends PositionComponent {
  final Vector2 direction;
  final int damage;
  final double lifetime;
  final dynamic gameRef;
  
  double _lifeRemaining;
  static const double speed = 350;
  static const double radius = 12;

  _SplitProjectile({
    required Vector2 position,
    required this.direction,
    required this.damage,
    required this.lifetime,
    required this.gameRef,
  })  : _lifeRemaining = lifetime,
        super(position: position, priority: 50);

  @override
  void update(double dt) {
    _lifeRemaining -= dt;
    position += direction * speed * dt;
    
    // Fade out and shrink
    if (_lifeRemaining < 0) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final opacity = (_lifeRemaining / lifetime).clamp(0.0, 1.0);
    final currentRadius = radius * opacity;
    
    canvas.drawCircle(
      Offset.zero,
      currentRadius,
      Paint()
        ..color = const Color(0xFFFFAA00).withOpacity(opacity * 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    
    canvas.drawCircle(
      Offset.zero,
      currentRadius,
      Paint()
        ..color = Colors.white.withOpacity(opacity * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }
}

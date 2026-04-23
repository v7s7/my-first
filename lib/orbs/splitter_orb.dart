import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

/// On boss hit: 5 000 instant + fires 3 spinning shuriken blades
/// that bounce inside the arena, each dealing 8 000 on contact.
/// Total: 5 000 + 24 000 = 29 000.
///
/// Visual: three spinning blade arcs orbit the orb continuously.
/// On impact they explode outward as real projectiles.
class SplitterOrb extends OrbBehavior {
  @override String get id   => 'splitter';
  @override String get name => 'SHURIKEN';
  @override String get description => '5K + 3 blades\n29K total';
  @override Color  get color => const Color(0xFFFFAA00);

  static const int    _baseDamage  = 5000;
  static const int    _bladeDamage = 8000;
  static const int    _bladeCount  = 3;

  bool   _active    = false;
  double _activeTimer = 0;
  double _time      = 0;
  static const double _activeDuration = 2.5;

  @override void onAttach(PlayerOrb orb) { _active = false; _time = 0; }

  @override void onUpdate(double dt, PlayerOrb orb) {
    _time += dt;
    if (_active) {
      _activeTimer -= dt;
      if (_activeTimer <= 0) _active = false;
    }
  }

  @override
  void onBossHit(PlayerOrb orb) {
    orb.gameRef.onOrbHitBoss(_baseDamage);
    _active      = true;
    _activeTimer = _activeDuration;
    // Spawn 3 shuriken projectiles
    final bossPos = orb.gameRef.boss.position;
    for (int i = 0; i < _bladeCount; i++) {
      final angle = i * (2 * pi / _bladeCount) + _time;
      orb.gameRef.add(_ShurikenBlade(
        position: bossPos.clone(),
        direction: Vector2(cos(angle), sin(angle)),
        damage: _bladeDamage,
        gameRef: orb.gameRef,
      ));
    }
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t = _time;
    // 3 spinning blade arcs always orbiting
    for (int i = 0; i < 3; i++) {
      final startAngle = t * 5.5 + i * (2 * pi / 3);
      // Blade arc — looks like a shuriken tine
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius + 5 + i * 4),
        startAngle,
        pi * 0.45,
        false,
        Paint()
          ..color = color.withOpacity(0.80 - i * 0.1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5 - i * 0.5
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      // Bright tip
      final tipAngle = startAngle + pi * 0.45;
      canvas.drawCircle(
        Offset(cx + cos(tipAngle) * (radius + 5 + i * 4),
               cy + sin(tipAngle) * (radius + 5 + i * 4)),
        3.0,
        Paint()
          ..color = Colors.white.withOpacity(0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    // Active flash: bright orange burst
    if (_active) {
      final p     = 1.0 - (_activeTimer / _activeDuration);
      final bR    = radius + p * radius * 2.5;
      final alpha = ((1.0 - min(p, 0.6) / 0.6) * 200).round().clamp(0, 200);
      canvas.drawCircle(
        Offset(cx, cy),
        bR,
        Paint()
          ..color = color.withOpacity(alpha / 255.0 * 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
  }
}

// ── Shuriken blade projectile ─────────────────────────────────────────────────

class _ShurikenBlade extends PositionComponent {
  final Vector2 direction;
  final int     damage;
  final dynamic gameRef;

  double _life = 2.2;
  double _spin = 0;
  bool   _hit  = false;
  static const double speed  = 420.0;
  static const double bladeR = 10.0;

  _ShurikenBlade({
    required Vector2 position,
    required this.direction,
    required this.damage,
    required this.gameRef,
  }) : super(
    position: position,
    size: Vector2.all(bladeR * 2),
    anchor: Anchor.center,
    priority: 55,
  );

  @override
  void update(double dt) {
    _life -= dt;
    _spin += dt * 14;
    if (_life < 0) { removeFromParent(); return; }

    position += direction * speed * dt;

    // Crude boundary bounce (no arena ref, use screen edges)
    final game = gameRef;
    final arena = game.arenaConfig;
    if (position.x < arena.innerLeft || position.x > arena.innerRight) {
      direction.x = -direction.x;
    }
    if (position.y < arena.innerTop  || position.y > arena.innerBottom) {
      direction.y = -direction.y;
    }

    // Hit boss
    final shurikenBoss = game.boss;
    if (!_hit && shurikenBoss != null &&
        position.distanceTo(shurikenBoss.position) < shurikenBoss.radius + bladeR) {
      _hit = true;
      game.onOrbHitBoss(damage);
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final fade = (_life / 2.2).clamp(0.0, 1.0);
    canvas.save();
    canvas.translate(bladeR, bladeR); // centre
    canvas.rotate(_spin);

    // 4 blade tines (short arcs)
    for (int i = 0; i < 4; i++) {
      final a = i * (pi / 2);
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: bladeR),
        a,
        pi * 0.4,
        false,
        Paint()
          ..color = const Color(0xFFFFAA00).withOpacity(fade * 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
    canvas.drawCircle(
      Offset.zero,
      4,
      Paint()
        ..color = Colors.white.withOpacity(fade * 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.restore();
  }
}

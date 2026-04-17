import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'boss_ball_game.dart';

/// A landmine placed on the arena floor by MineOrb.
///
/// Renders as a dark spiked disc with a pulsing orange core and expanding
/// warning rings.  When the boss steps within [triggerRadius], the mine
/// detonates: 8 000 damage + big screen shake + fire explosion.
class MineComponent extends PositionComponent {
  final BossBallGame gameRef;
  final int damage;
  final VoidCallback? onDetonated;

  double _lifetime;
  double _pulse = 0;
  bool   _triggered = false;

  static const double mineR       = 16.0;
  static const double triggerR    = 42.0;
  static const double _totalLife  = 9.0;

  MineComponent({
    required Vector2 position,
    required this.gameRef,
    required this.damage,
    this.onDetonated,
  })  : _lifetime = _totalLife,
        super(
          position: position,
          size: Vector2.all(mineR * 2),
          anchor: Anchor.center,
          priority: 4,
        );

  @override
  void update(double dt) {
    if (_triggered) return;
    _pulse    += dt;
    _lifetime -= dt;

    if (_lifetime <= 0) {
      onDetonated?.call();
      removeFromParent();
      return;
    }

    // Detonate when boss enters trigger radius
    if (position.distanceTo(gameRef.boss.position) < gameRef.boss.radius + triggerR) {
      _detonate();
    }
  }

  void _detonate() {
    if (_triggered) return;
    _triggered = true;
    gameRef.onOrbHitBoss(damage);
    gameRef.triggerShake(intensity: 40, duration: 0.45);
    gameRef.spawnFireExplosion(position.clone());
    // Second explosion a frame later for extra drama
    gameRef.spawnFireExplosion(
        position.clone() + Vector2((_pulse * 10 % 20) - 10, (_pulse * 7 % 18) - 9));
    onDetonated?.call();
    removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t  = _pulse;
    final cx = mineR;
    final cy = mineR;
    // Urgency ramps up in the last 2 s
    final urgency = (1.0 - (_lifetime / _totalLife)).clamp(0.0, 1.0);

    // ── Expanding warning rings ──────────────────────────────────────────────
    for (int i = 0; i < 2; i++) {
      final phase = (t * (1.5 + urgency * 2) + i * 0.5) % 1.0;
      final ringR = mineR + phase * triggerR * 0.6;
      final alpha = ((1.0 - phase) * (100 + urgency * 80)).round().clamp(0, 180);
      canvas.drawCircle(
        Offset(cx, cy),
        ringR,
        Paint()
          ..color = Color.fromARGB(alpha, 255, 120, 0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }

    // ── Mine body ────────────────────────────────────────────────────────────
    canvas.drawCircle(
      Offset(cx, cy),
      mineR,
      Paint()
        ..color = const Color(0xFF1A1A1A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    // Dark steel rim
    canvas.drawCircle(
      Offset(cx, cy),
      mineR,
      Paint()
        ..color = const Color(0xFF555555)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    // ── Pulsing core glow ────────────────────────────────────────────────────
    final coreG   = (80 + urgency * 60 + sin(t * 8) * 30).round().clamp(0, 150);
    final coreR   = mineR * (0.45 + sin(t * (6 + urgency * 6)) * 0.12);
    canvas.drawCircle(
      Offset(cx, cy),
      coreR,
      Paint()
        ..color = Color.fromARGB(200, 255, coreG, 0)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    // ── Metal spikes (6 bolts around the rim) ───────────────────────────────
    const spikeCount = 6;
    for (int i = 0; i < spikeCount; i++) {
      final a  = i * (2 * pi / spikeCount);
      final sx = cx + cos(a) * mineR;
      final sy = cy + sin(a) * mineR;
      canvas.drawCircle(
        Offset(sx, sy),
        3.2,
        Paint()..color = const Color(0xFF888888),
      );
    }

    // ── ! warning text ───────────────────────────────────────────────────────
    final tp = TextPainter(
      text: TextSpan(
        text: '!',
        style: TextStyle(
          color: Colors.white.withOpacity(0.9),
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }
}

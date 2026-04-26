import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

/// Shatters on boss impact, releasing crystal shards that each deal damage.
///
/// On boss hit: 5 000 immediate + 6 shard ticks of 2 000 each over 1.2 s.
/// Total: 5 000 + 12 000 = 17 000.
///
/// Visual: six rotating crystalline facet lines around the orb (cyan/white),
/// plus an expanding shard burst of 6 coloured spikes when a hit lands.
class CrystalOrb extends OrbBehavior {
  @override String get id   => 'crystal';
  @override String get name => 'CRYSTAL';
  @override String get description => '5K + 6 shards\n17K total';
  @override Color  get color => const Color(0xFF88FFEE);

  static const int    _baseDamage   = 5000;
  static const int    _shardDamage  = 2000;
  static const int    _shardCount   = 6;
  static const double _shardInterval = 0.20; // s between shard ticks

  double _time         = 0;
  int    _shardsLeft   = 0;
  double _shardTimer   = 0;

  bool   _burst        = false;
  double _burstTimer   = 0;
  static const double _burstDuration = 0.55;

  @override
  void onAttach(PlayerOrb orb) {
    _time        = 0;
    _shardsLeft  = 0;
    _shardTimer  = 0;
    _burst       = false;
    _burstTimer  = 0;
  }

  @override
  void onUpdate(double dt, PlayerOrb orb) {
    _time += dt;
    if (_burst) {
      _burstTimer -= dt;
      if (_burstTimer <= 0) _burst = false;
    }
    if (_shardsLeft > 0) {
      _shardTimer -= dt;
      if (_shardTimer <= 0) {
        _shardTimer = _shardInterval;
        orb.gameRef.onOrbHitBoss(_shardDamage, isLaserTick: true);
        _shardsLeft--;
      }
    }
  }

  @override
  void onBossHit(PlayerOrb orb) {
    orb.gameRef.onOrbHitBoss(_baseDamage);
    _shardsLeft  = _shardCount;
    _shardTimer  = _shardInterval;
    _burst       = true;
    _burstTimer  = _burstDuration;
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t = _time;

    // 6 rotating crystal facet lines
    for (int i = 0; i < 6; i++) {
      final a1  = t * 1.4 + i * (pi / 3);
      final a2  = a1 + pi * 0.22;
      final r1  = radius + 6;
      final r2  = radius + 13;
      final hue = 170.0 + i * 14.0;

      canvas.drawLine(
        Offset(cx + cos(a1) * r1, cy + sin(a1) * r1),
        Offset(cx + cos(a2) * r2, cy + sin(a2) * r2),
        Paint()
          ..color = HSLColor.fromAHSL(0.85, hue, 1.0, 0.7).toColor()
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      // White core
      canvas.drawLine(
        Offset(cx + cos(a1) * r1, cy + sin(a1) * r1),
        Offset(cx + cos(a2) * r2, cy + sin(a2) * r2),
        Paint()
          ..color = Colors.white.withOpacity(0.55)
          ..strokeWidth = 0.9
          ..strokeCap = StrokeCap.round,
      );
    }

    // Shard counter glow ring when shards are active
    if (_shardsLeft > 0) {
      canvas.drawCircle(
        Offset(cx, cy),
        radius + 4 + sin(t * 18) * 3,
        Paint()
          ..color = const Color(0x4488FFEE)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    // Hit burst — 6 crystal spike rays
    if (_burst) {
      final p = 1.0 - (_burstTimer / _burstDuration);
      for (int i = 0; i < 6; i++) {
        final a    = i * (pi / 3) + p * 0.3;
        final sLen = radius * 0.8 + p * radius * 4.0;
        final hue  = 170.0 + i * 14.0;
        final c    = HSLColor.fromAHSL(1.0, hue, 1.0, 0.72).toColor();

        canvas.drawLine(
          Offset(cx, cy),
          Offset(cx + cos(a) * sLen, cy + sin(a) * sLen),
          Paint()
            ..color = c.withOpacity((1.0 - p) * 0.85)
            ..strokeWidth = (3.5 * (1.0 - p)).clamp(0.5, 3.5)
            ..strokeCap = StrokeCap.round
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * (1.0 - p)),
        );
      }
    }
  }
}

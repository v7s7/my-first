import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

/// Speed is power — the faster this orb moves, the harder it hits.
///
/// The arena naturally accelerates the orb with every wall bounce, so smart
/// play means building speed before crashing into the boss.
///
/// Damage = (currentSpeed / 280) × 6 000, clamped 3 000–20 000.
///   At base speed  280 px/s  →  6 000
///   At mid speed   500 px/s  →  10 700
///   At max speed   900 px/s  →  19 300
///
/// Visual: velocity streaks pointing backward, heat-shifted colour (blue→
/// white→orange→red) that tracks the orb's speed ratio.
class TurboOrb extends OrbBehavior {
  @override String get id   => 'turbo';
  @override String get name => 'TURBO';
  @override String get description => 'Speed = power\n3K–20K/hit';

  static const double _baseSpeed = 280.0;

  double _time        = 0;
  double _speedRatio  = 1.0; // updated each frame
  bool   _hit         = false;
  double _hitTimer    = 0;
  double _velAngle    = 0;
  static const double _hitDuration = 0.3;

  @override
  Color get color {
    // Interpolate blue → cyan → white → orange → red with speed
    final r = _speedRatio.clamp(0.0, 1.0);
    if (r < 0.33) {
      final t = r / 0.33;
      return Color.fromARGB(255, (0 + t * 80).round(), (200 - t * 60).round(), 255);
    } else if (r < 0.66) {
      final t = (r - 0.33) / 0.33;
      return Color.fromARGB(255, (80 + t * 175).round(), (140 + t * 60).round(),
          (255 - t * 200).round());
    } else {
      final t = (r - 0.66) / 0.34;
      return Color.fromARGB(255, 255, (200 - t * 140).round(), (55 - t * 55).round());
    }
  }

  @override
  void onAttach(PlayerOrb orb) {
    _time       = 0;
    _speedRatio = 1.0;
    _hit        = false;
    _hitTimer   = 0;
    _velAngle   = 0;
  }

  @override
  void onUpdate(double dt, PlayerOrb orb) {
    _time += dt;
    if (orb.velocity.length > 1.0) {
      _speedRatio = (orb.velocity.length / _baseSpeed).clamp(0.5, 3.5);
      _velAngle   = atan2(orb.velocity.y, orb.velocity.x);
    }
    if (_hit) {
      _hitTimer -= dt;
      if (_hitTimer <= 0) _hit = false;
    }
  }

  @override
  void onBossHit(PlayerOrb orb) {
    final speed  = orb.velocity.length;
    final damage = (speed / _baseSpeed * 6000).round().clamp(3000, 20000);
    orb.gameRef.onOrbHitBoss(damage);
    _hit      = true;
    _hitTimer = _hitDuration;
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t     = _time;
    final ratio = _speedRatio.clamp(0.5, 3.5);
    final norm  = ((ratio - 0.5) / 3.0).clamp(0.0, 1.0); // 0–1

    // Velocity streaks pointing backward from the orb
    final streakCount = 4 + (norm * 4).round();
    final tailAngle   = _velAngle + pi;

    for (int i = 0; i < streakCount; i++) {
      final spread = (i - streakCount / 2.0) * 0.22;
      final a      = tailAngle + spread;
      final len    = radius * (0.8 + norm * 2.0) + sin(t * 14 + i) * 4;
      final alpha  = (120 + norm * 100).round().clamp(60, 220);

      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + cos(a) * len, cy + sin(a) * len),
        Paint()
          ..color = color.withOpacity(alpha / 255.0 * 0.75)
          ..strokeWidth = (2.5 - i * 0.2).clamp(0.8, 2.5)
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + norm * 6),
      );
    }

    // Speed ring that pulsates faster as speed increases
    if (norm > 0.1) {
      final ringR = radius + 7 + sin(t * (6 + norm * 14)) * 4;
      canvas.drawCircle(
        Offset(cx, cy),
        ringR,
        Paint()
          ..color = color.withOpacity(norm * 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 + norm * 5),
      );
    }

    // Hit burst ring
    if (_hit) {
      final p  = 1.0 - (_hitTimer / _hitDuration);
      final bR = radius + p * radius * 3.5;
      canvas.drawCircle(
        Offset(cx, cy),
        bR,
        Paint()
          ..color = color.withOpacity((1.0 - p) * 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0 * (1.0 - p)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12),
      );
    }
  }
}

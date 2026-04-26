import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

/// Grows permanently stronger with each boss hit this round.
///
/// The first hit deals 3 000. Every subsequent hit adds +500, capping at
/// 15 000 (after 24 hits). At max power the orb enters a rage state and
/// flashes a white explosion on every hit.
///
/// Damage = clamp(3 000 + hits × 500, 3 000, 15 000).
///   Hit  1:  3 000     Hit  6:  6 000
///   Hit 12:  9 000     Hit 24: 15 000 (max)
///
/// Visual: jagged spike ring that grows more menacing with each hit, plus
/// a pulsing blood-red aura that intensifies at max power.
class BerserkerOrb extends OrbBehavior {
  @override String get id   => 'berserker';
  @override String get name => 'BERSERK';
  @override String get description => '3K→15K per hit\ngrows each strike';

  static const int _baseDamage  = 3000;
  static const int _bonusPerHit = 500;
  static const int _maxDamage   = 15000;
  static const int _maxHits     = (_maxDamage - _baseDamage) ~/ _bonusPerHit; // 24

  int    _hits      = 0;
  double _time      = 0;
  bool   _rage      = false;
  double _rageTimer = 0;
  static const double _rageDuration = 0.35;

  @override
  Color get color {
    final t = (_hits / _maxHits).clamp(0.0, 1.0);
    // Interpolate orange → deep red with hits
    return Color.fromARGB(
      255,
      255,
      (160 - t * 130).round().clamp(0, 255),
      (30 - t * 30).round().clamp(0, 255),
    );
  }

  @override
  void onAttach(PlayerOrb orb) {
    _hits      = 0;
    _time      = 0;
    _rage      = false;
    _rageTimer = 0;
  }

  @override
  void onUpdate(double dt, PlayerOrb orb) {
    _time += dt;
    if (_rage) {
      _rageTimer -= dt;
      if (_rageTimer <= 0) _rage = false;
    }
  }

  @override
  void onBossHit(PlayerOrb orb) {
    _hits++;
    final damage = (_baseDamage + _hits * _bonusPerHit).clamp(_baseDamage, _maxDamage);
    orb.gameRef.onOrbHitBoss(damage);
    _rage      = true;
    _rageTimer = _rageDuration;
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t    = _time;
    final norm = (_hits / _maxHits).clamp(0.0, 1.0);

    // Pulsing aura — grows with hit count
    if (_hits > 0) {
      final auraR = radius * (0.6 + norm * 0.5) + sin(t * 12) * 4;
      canvas.drawCircle(
        Offset(cx, cy),
        auraR,
        Paint()
          ..color = color.withOpacity(0.18 + norm * 0.25)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 + norm * 12),
      );
    }

    // Spike ring — number and size of spikes scale with _hits
    final spikeCount = 4 + (_hits ~/ 3).clamp(0, 8); // 4 to 12 spikes
    final innerR     = radius + 4;
    final outerR     = radius + 6 + norm * 14;
    final rotSpeed   = 1.2 + norm * 2.0;

    for (int i = 0; i < spikeCount; i++) {
      final a    = (i / spikeCount) * 2 * pi + t * rotSpeed;
      final tip  = Offset(cx + cos(a) * outerR, cy + sin(a) * outerR);
      final base = Offset(cx + cos(a) * innerR, cy + sin(a) * innerR);

      canvas.drawLine(
        base, tip,
        Paint()
          ..color = color.withOpacity(0.55 + norm * 0.35)
          ..strokeWidth = 2.5 + norm * 2.0
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }

    // Bright spike tips at max power
    if (norm >= 1.0) {
      for (int i = 0; i < spikeCount; i++) {
        final a   = (i / spikeCount) * 2 * pi + t * rotSpeed;
        final tip = Offset(cx + cos(a) * outerR, cy + sin(a) * outerR);
        canvas.drawCircle(
          tip, 3.0,
          Paint()
            ..color = Colors.white.withOpacity(0.8)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
    }

    // Rage explosion flash on hit
    if (_rage) {
      final p  = 1.0 - (_rageTimer / _rageDuration);
      final bR = radius * (1.0 + p * 2.8);
      canvas.drawCircle(
        Offset(cx, cy),
        bR,
        Paint()
          ..color = Colors.white.withOpacity((1.0 - p) * 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.0 * (1.0 - p)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 14 * (1.0 - p)),
      );
    }
  }
}

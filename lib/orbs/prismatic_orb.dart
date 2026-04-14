import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

/// Damage oscillates on a sine wave between 2 000 and 60 000 every 6 s.
///
/// Hit at the peak (full gold glow) for maximum damage.
/// Three nested prism arc rings show the current damage cycle position.
/// At peak: six light beams shoot outward like a diamond catching sunlight.
class PrismaticOrb extends OrbBehavior {
  @override String get id   => 'prismatic';
  @override String get name => 'PRISM';
  @override String get description => '2K–60K\ntimed hit';

  static const double _cyclePeriod = 6.0;
  static const int    _minDamage   = 2000;
  static const int    _maxDamage   = 60000;

  double _cycleTimer = 0.0;
  bool   _peakFlash  = false;
  double _flashTimer = 0.0;

  /// 0 = trough, 1 = peak.
  double get _cyclePos =>
      (sin(_cycleTimer * 2 * pi / _cyclePeriod) + 1) / 2;

  @override
  Color get color {
    final hue = (_cycleTimer * 80 + 200) % 360;
    return HSLColor.fromAHSL(1.0, hue, 1.0, 0.58).toColor();
  }

  @override void onAttach(PlayerOrb orb) { _cycleTimer = 0; }

  @override
  void onUpdate(double dt, PlayerOrb orb) {
    _cycleTimer += dt;
    if (_peakFlash) {
      _flashTimer -= dt;
      if (_flashTimer <= 0) _peakFlash = false;
    }
  }

  @override
  void onBossHit(PlayerOrb orb) {
    final damage =
        (_minDamage + (_maxDamage - _minDamage) * _cyclePos).round();
    orb.gameRef.onOrbHitBoss(damage);
    if (_cyclePos > 0.85) {
      _peakFlash  = true;
      _flashTimer = 0.4;
    }
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t   = _cycleTimer;
    final pos = _cyclePos;

    // Three spinning prism arc rings
    for (int i = 0; i < 3; i++) {
      final hue   = (t * 130 + i * 120) % 360.0;
      final c     = HSLColor.fromAHSL(0.80, hue, 1.0, 0.60).toColor();
      final arcR  = radius + 9.0 + i * 8.0;
      final speed = 2.5 + i * 0.9;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: arcR),
        t * speed + i * (2 * pi / 3),
        pi * 0.9,
        false,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }

    // Cycle-position gold glow ring
    final glowAlpha = (pos * 230).round().clamp(15, 230);
    canvas.drawCircle(
      Offset(cx, cy),
      radius * 1.12,
      Paint()
        ..color = Color.fromARGB(glowAlpha, 255, 220, 60)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    // At peak: six light beams radiate outward
    if (pos > 0.7 || _peakFlash) {
      final beamAlpha = _peakFlash
          ? (1.0 - _flashTimer / 0.4).let((p) => (1.0 - p) * 0.9)
          : (pos - 0.7) / 0.3 * 0.7;
      const beams = 6;
      for (int i = 0; i < beams; i++) {
        final angle = t * 1.5 + i * (pi / beams) * 2;
        final len   = radius * 1.5 + (pos - 0.7).clamp(0.0, 0.3) / 0.3 * radius * 1.2;
        canvas.drawLine(
          Offset(cx, cy),
          Offset(cx + cos(angle) * len, cy + sin(angle) * len),
          Paint()
            ..color = const Color(0xFFFFEE88).withOpacity(beamAlpha)
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
    }
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) fn) => fn(this);
}

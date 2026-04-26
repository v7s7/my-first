import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

/// Each hit's damage is determined by the next digit of π.
///
/// Digits of π: 3 1 4 1 5 9 2 6 5 3 5 8 9 7 9 3 2 3 8 4 6 2 6 4 3 3 8 3 2 7 …
/// Damage = digit × 2 000  (range: 2 000 – 18 000)
///
/// The digit sequence loops, so the pattern repeats every 100+ digits.
/// Average digit ≈ 4.59 → average damage ≈ 9 200 per hit.
///
/// Visual: π symbol, a rotating arc whose length matches current digit / 9,
/// and a highlight ring that pulses on 9-digit hits.
class PiOrb extends OrbBehavior {
  @override String get id   => 'pi';
  @override String get name => 'PI';
  @override String get description => 'Digits of π\n2K–18K per hit';
  @override Color  get color => const Color(0xFF66AAFF);

  // First 60 digits of π (after the decimal point, including leading 3)
  static const List<int> _piDigits = [
    3,1,4,1,5,9,2,6,5,3,5,8,9,7,9,3,2,3,8,4,
    6,2,6,4,3,3,8,3,2,7,9,5,0,2,8,8,4,1,9,7,
    1,6,9,3,9,9,3,7,5,1,0,5,8,2,0,9,7,4,9,4,
  ];
  static const int _dmgPerDigit = 2000;

  int    _digitIndex = 0;
  double _time       = 0;
  int    _lastDigit  = 3;
  bool   _flash      = false;
  double _flashTimer = 0;
  static const double _flashDur = 0.35;

  @override
  void onAttach(PlayerOrb orb) {
    _digitIndex = 0;
    _time       = 0;
    _lastDigit  = _piDigits[0];
    _flash      = false;
  }

  @override
  void onUpdate(double dt, PlayerOrb orb) {
    _time += dt;
    if (_flash) {
      _flashTimer -= dt;
      if (_flashTimer <= 0) _flash = false;
    }
  }

  @override
  void onBossHit(PlayerOrb orb) {
    _lastDigit  = _piDigits[_digitIndex % _piDigits.length];
    _digitIndex = (_digitIndex + 1) % _piDigits.length;
    orb.gameRef.onOrbHitBoss(_lastDigit * _dmgPerDigit);
    _flash      = true;
    _flashTimer = _flashDur;
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t = _time;

    // Rotating arc whose sweep = (lastDigit / 9) × full circle
    final sweep = 2 * pi * (_lastDigit / 9.0);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius + 9),
      t * 1.8,
      sweep,
      false,
      Paint()
        ..color = const Color(0xFF66AAFF).withOpacity(0.70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Counter-arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius + 14),
      -t * 1.1,
      sweep * 0.6,
      false,
      Paint()
        ..color = const Color(0xFF66AAFF).withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // π glyph and current digit
    final tpPi = TextPainter(
      text: const TextSpan(
        text: 'π',
        style: TextStyle(
          color: Color(0x7766AAFF),
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpPi.paint(canvas, Offset(cx - tpPi.width / 2, cy - tpPi.height / 2));

    // Show last digit used (top-right badge)
    final tpD = TextPainter(
      text: TextSpan(
        text: '$_lastDigit',
        style: TextStyle(
          color: const Color(0xFF66AAFF).withOpacity(_flash ? 1.0 : 0.65),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpD.paint(canvas, Offset(cx + radius + 3, cy - 7));

    // Flash on 9 (max digit)
    if (_flash && _lastDigit >= 8) {
      final p = 1.0 - (_flashTimer / _flashDur);
      canvas.drawCircle(
        Offset(cx, cy),
        radius + p * radius * 3.5,
        Paint()
          ..color = const Color(0xFF66AAFF).withOpacity((1.0 - p) * 0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5 * (1.0 - p)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * (1.0 - p)),
      );
    }
  }
}

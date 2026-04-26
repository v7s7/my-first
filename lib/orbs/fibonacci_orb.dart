import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

/// Damage follows the Fibonacci sequence, cycling through 8 hits then reset.
///
/// Hit sequence (K = 1 000):
///   1K · 1K · 2K · 3K · 5K · 8K · 13K · 21K → reset (total: 54K per cycle)
///
/// The golden-ratio spiral visual grows wider each hit and collapses on reset.
class FibonacciOrb extends OrbBehavior {
  @override String get id   => 'fibonacci';
  @override String get name => 'FIBONACCI';
  @override String get description => '1K→21K sequence\n54K per cycle';
  @override Color  get color => const Color(0xFFFFCC44);

  static const List<int> _seq = [1000, 1000, 2000, 3000, 5000, 8000, 13000, 21000];

  int    _step     = 0;
  double _time     = 0;
  bool   _hit      = false;
  double _hitTimer = 0;
  static const double _hitDur = 0.35;

  @override
  void onAttach(PlayerOrb orb) { _step = 0; _time = 0; _hit = false; }

  @override
  void onUpdate(double dt, PlayerOrb orb) {
    _time += dt;
    if (_hit) {
      _hitTimer -= dt;
      if (_hitTimer <= 0) _hit = false;
    }
  }

  @override
  void onBossHit(PlayerOrb orb) {
    orb.gameRef.onOrbHitBoss(_seq[_step]);
    _step = (_step + 1) % _seq.length;
    _hit      = true;
    _hitTimer = _hitDur;
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t    = _time;
    final norm = _step / (_seq.length - 1); // 0.0 (just reset) → 1.0 (last step)

    // Golden-ratio Fibonacci spiral approximation using arcs
    // We stack 8 quarter-arc segments of increasing radius
    const phi   = 1.618033988;
    double arcR = radius * 0.22;
    double ox   = cx;
    double oy   = cy + arcR;
    for (int i = 0; i < _step + 1 && i < 8; i++) {
      final hue  = (42.0 + i * 18.0) % 360.0;
      final fade = (i < _step ? 0.65 : 0.90);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(ox, oy), radius: arcR),
        pi * (i % 4 * 0.5 - 0.5),
        pi * 0.5,
        false,
        Paint()
          ..color = HSLColor.fromAHSL(fade, hue, 1.0, 0.65).toColor()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      // Shift pivot following Fibonacci tiling pattern
      switch (i % 4) {
        case 0: oy -= arcR;
        case 1: ox += arcR; oy -= arcR;
        case 2: ox += arcR;
        case 3: oy += arcR;
      }
      arcR *= phi;
      if (arcR > radius * 2.8) break;
    }

    // Charge ring shows progress through the 8-step sequence
    if (_step > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius + 10),
        -pi / 2,
        2 * pi * norm,
        false,
        Paint()
          ..color = const Color(0xFFFFCC44).withOpacity(0.80)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // Step label (F_n)
    if (_step < _seq.length) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'F${_step + 1}',
          style: const TextStyle(
            color: Color(0xFFFFCC44),
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx + radius + 3, cy - 6));
    }

    // Hit burst
    if (_hit) {
      final p = 1.0 - (_hitTimer / _hitDur);
      canvas.drawCircle(
        Offset(cx, cy),
        radius + p * radius * 3,
        Paint()
          ..color = const Color(0xFFFFCC44).withOpacity((1.0 - p) * 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5 * (1.0 - p)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * (1.0 - p)),
      );
    }
  }
}

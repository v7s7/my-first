import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

/// Damage = 1 000 × n!   where n = wall bounces since last boss hit (max 5).
///
///   n = 0 :  1K           n = 3 :  6K
///   n = 1 :  1K           n = 4 : 24K
///   n = 2 :  2K           n = 5 : 120K ← maximum
///
/// Strategy: bounce 5 times WITHOUT hitting the boss, then crash in for 120K.
/// The bounce counter resets after every boss hit.
///
/// Visual: factorion-style layered rings, n! equation displayed live.
class FactorialOrb extends OrbBehavior {
  @override String get id   => 'factorial';
  @override String get name => 'FACTORIAL';
  @override String get description => '1K×n! bounce\n120K at 5 bounces';
  @override Color  get color => const Color(0xFFFF44AA);

  static const List<int> _factorials = [1, 1, 2, 6, 24, 120];
  static const int       _maxN = 5;

  int    _n         = 0;
  double _time      = 0;
  bool   _hit       = false;
  double _hitTimer  = 0;
  static const double _hitDur = 0.45;

  // Ball grows 2.5 px per bounce (up to 12.5 px at max charge)
  @override
  double get visualGrowth => _n * 2.5;

  @override
  void onAttach(PlayerOrb orb) { _n = 0; _time = 0; _hit = false; }

  @override
  void onUpdate(double dt, PlayerOrb orb) {
    _time += dt;
    if (_hit) {
      _hitTimer -= dt;
      if (_hitTimer <= 0) _hit = false;
    }
  }

  @override
  void onWallBounce(PlayerOrb orb) {
    if (_n < _maxN) _n++;
  }

  @override
  void onBossHit(PlayerOrb orb) {
    final damage = 1000 * _factorials[_n];
    orb.gameRef.onOrbHitBoss(damage);
    _hit      = true;
    _hitTimer = _hitDur;
    _n        = 0;
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t    = _time;
    final norm = _n / _maxN;

    // Layered concentric rings — n rings glowing, rest dim
    for (int i = 0; i < _maxN; i++) {
      final active = i < _n;
      final arcR   = radius + 6 + i * 4.5;
      final hue    = 320.0 + i * 12.0;
      canvas.drawCircle(
        Offset(cx, cy),
        arcR,
        Paint()
          ..color = HSLColor.fromAHSL(1.0, hue, 1.0, 0.60).toColor()
              .withOpacity(active ? 0.40 + norm * 0.30 : 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = active ? 2.0 : 1.0
          ..maskFilter = active
              ? MaskFilter.blur(BlurStyle.normal, 4 + norm * 4)
              : null,
      );
    }

    // Current damage value on ball center
    final curDmg = 1000 * _factorials[_n];
    final dmgStr = _n == _maxN ? '120K★' : '${_n}!=${_fmtDmg(curDmg)}';
    final dmgTp = TextPainter(
      text: TextSpan(
        text: dmgStr,
        style: TextStyle(
          color: Colors.white.withOpacity(0.95),
          fontSize: 10.5 + _n * 0.6,
          fontWeight: FontWeight.w900,
          height: 1.0,
          shadows: const [
            Shadow(color: Color(0xCC000000), offset: Offset(1, 1), blurRadius: 2),
            Shadow(color: Color(0xFFFF44AA), blurRadius: 8),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    dmgTp.paint(canvas, Offset(cx - dmgTp.width / 2, cy - dmgTp.height / 2));

    // Max-charge inner glow
    if (_n >= _maxN) {
      canvas.drawCircle(
        Offset(cx, cy),
        radius * 0.65 + sin(t * 18) * 5,
        Paint()
          ..color = const Color(0xAAFF44AA)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }

    // Hit burst
    if (_hit) {
      final p = 1.0 - (_hitTimer / _hitDur);
      for (int i = 0; i < 4; i++) {
        final bR = radius + p * (radius * 3.5 + i * 16);
        canvas.drawCircle(
          Offset(cx, cy),
          bR,
          Paint()
            ..color = const Color(0xFFFF44AA).withOpacity((1.0 - p) * 0.60)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.0 * (1.0 - p)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * (1.0 - p)),
        );
      }
    }
  }

  static String _fmtDmg(int dmg) {
    if (dmg >= 1000000) return '${(dmg / 1000000).toStringAsFixed(1)}M';
    if (dmg >= 1000) return '${dmg ~/ 1000}K';
    return '$dmg';
  }
}

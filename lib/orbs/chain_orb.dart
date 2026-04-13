import 'dart:math';
import 'package:flutter/material.dart' hide Gradient;
import 'orb_behavior.dart';
import '../game/player_orb.dart';

/// Fires three chained lightning bolts in quick succession.
///
/// On each boss hit, the first bolt deals damage immediately and two
/// follow-up bolts fire 0.12 s apart.  Total: 3 × 3 000 = 9 000 dmg.
///
/// Visual: two zig-zag lightning lines track toward the boss while the
/// chain is active.  The zig-zag seed changes every ~50 ms for a flicker.
class ChainOrb extends OrbBehavior {
  @override String get id   => 'chain';
  @override String get name => 'CHAIN';
  @override String get description => '3 bolts\n9K total';
  @override Color  get color => const Color(0xFF44CCFF);

  static const int    _bolts        = 3;
  static const int    _boltDamage   = 3000;
  static const double _boltInterval = 0.12; // seconds between extra bolts

  bool   _chainActive  = false;
  int    _boltsLeft    = 0;
  double _nextBoltTimer = 0;
  double _renderTimer  = 0;          // drives flicker seed
  Offset _bossOffset   = Offset.zero; // boss pos relative to orb centre

  @override
  void onAttach(PlayerOrb orb) {
    _chainActive  = false;
    _boltsLeft    = 0;
    _nextBoltTimer = 0;
    _renderTimer  = 0;
    _bossOffset   = Offset.zero;
  }

  @override
  void onUpdate(double dt, PlayerOrb orb) {
    if (!_chainActive) return;

    _renderTimer += dt;

    // Keep the lightning target updated
    final bp = orb.gameRef.boss.position;
    _bossOffset = Offset(bp.x - orb.position.x, bp.y - orb.position.y);

    _nextBoltTimer -= dt;
    if (_nextBoltTimer <= 0 && _boltsLeft > 0) {
      _nextBoltTimer = _boltInterval;
      _boltsLeft--;
      orb.gameRef.onOrbHitBoss(_boltDamage);
      if (_boltsLeft <= 0) _chainActive = false;
    }
  }

  @override
  void onBossHit(PlayerOrb orb) {
    // First bolt fires immediately
    orb.gameRef.onOrbHitBoss(_boltDamage);
    _chainActive   = true;
    _boltsLeft     = _bolts - 1;
    _nextBoltTimer = _boltInterval;
    _renderTimer   = 0;
    final bp = orb.gameRef.boss.position;
    _bossOffset = Offset(bp.x - orb.position.x, bp.y - orb.position.y);
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    if (!_chainActive) return;

    // Pulsing electric ring on the orb
    canvas.drawCircle(
      Offset(cx, cy),
      radius * 1.3 + sin(_renderTimer * 30) * 2,
      Paint()
        ..color = const Color(0x8844CCFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Two zig-zag lightning lines toward the boss
    final flickerSeed = (_renderTimer * 20).round(); // changes every ~50 ms
    final from = Offset(cx, cy);
    final to   = Offset(cx + _bossOffset.dx, cy + _bossOffset.dy);
    _drawLightning(canvas, from, to, flickerSeed);
    _drawLightning(canvas, from, to, flickerSeed + 17);
  }

  void _drawLightning(Canvas canvas, Offset from, Offset to, int seed) {
    final dx  = to.dx - from.dx;
    final dy  = to.dy - from.dy;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 2) return;

    // Perpendicular unit vector for jitter
    final px = -dy / len;
    final py =  dx / len;

    final rng  = Random(seed);
    const segs = 8;

    final path = Path()..moveTo(from.dx, from.dy);
    for (int i = 1; i < segs; i++) {
      final t      = i / segs;
      final bx     = from.dx + dx * t;
      final by     = from.dy + dy * t;
      final jitter = (rng.nextDouble() - 0.5) * (len * 0.28).clamp(0, 26);
      path.lineTo(bx + px * jitter, by + py * jitter);
    }
    path.lineTo(to.dx, to.dy);

    // Glow layer
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x9966DDFF)
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    // Core bright line
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xEEFFFFFF)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );
  }
}

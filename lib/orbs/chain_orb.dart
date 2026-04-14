import 'dart:math';
import 'package:flutter/material.dart' hide Gradient;
import 'orb_behavior.dart';
import '../game/player_orb.dart';

/// Fires three chained attacks in quick succession.
///
/// On each boss hit, the first bolt deals damage immediately and two
/// follow-up bolts fire 0.12 s apart.  Total: 3 × 3 000 = 9 000 dmg.
///
/// Visual: a real chain of glowing oval links stretches from the orb to
/// the boss while the chain is active, with a pulsing electric ring on
/// the orb and a flickering final lightning bolt at the target end.
class ChainOrb extends OrbBehavior {
  @override String get id   => 'chain';
  @override String get name => 'CHAIN';
  @override String get description => '3 bolts\n9K total';
  @override Color  get color => const Color(0xFF44CCFF);

  static const int    _bolts        = 3;
  static const int    _boltDamage   = 3000;
  static const double _boltInterval = 0.12;

  bool   _chainActive   = false;
  int    _boltsLeft     = 0;
  double _nextBoltTimer = 0;
  double _renderTimer   = 0;
  Offset _bossOffset    = Offset.zero;

  @override
  void onAttach(PlayerOrb orb) {
    _chainActive   = false;
    _boltsLeft     = 0;
    _nextBoltTimer = 0;
    _renderTimer   = 0;
    _bossOffset    = Offset.zero;
  }

  @override
  void onUpdate(double dt, PlayerOrb orb) {
    if (!_chainActive) return;
    _renderTimer += dt;

    // Track live boss position
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
      radius * 1.35 + sin(_renderTimer * 30) * 2,
      Paint()
        ..color = const Color(0x8844CCFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    final from = Offset(cx, cy);
    final to   = Offset(cx + _bossOffset.dx, cy + _bossOffset.dy);

    // Draw the chain link line
    _drawChainLinks(canvas, from, to);

    // Flickering lightning at the boss end
    final flickerSeed = (_renderTimer * 20).round();
    _drawLightningFlicker(canvas, to, flickerSeed);
  }

  /// Draws a row of alternating oval chain links from [from] to [to].
  void _drawChainLinks(Canvas canvas, Offset from, Offset to) {
    final dx   = to.dx - from.dx;
    final dy   = to.dy - from.dy;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist < 5) return;

    const linkLen     = 13.0;
    const linkWidth   = 6.5;
    const linkSpacing = 14.0;
    final count = (dist / linkSpacing).floor();
    if (count <= 0) return;

    final chainAngle = atan2(dy, dx);

    for (int i = 0; i < count; i++) {
      final t  = (i + 0.5) / count;
      final lx = from.dx + dx * t;
      final ly = from.dy + dy * t;

      canvas.save();
      canvas.translate(lx, ly);
      // Alternate: even links align with chain, odd links are perpendicular
      canvas.rotate(chainAngle + (i.isEven ? 0 : pi / 2));

      // Outer glow oval
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset.zero, width: linkLen, height: linkWidth),
        Paint()
          ..color = const Color(0xAA44CCFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      // Bright core oval
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset.zero,
            width: linkLen * 0.62,
            height: linkWidth * 0.5),
        Paint()
          ..color = const Color(0x99DDFAFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      canvas.restore();
    }
  }

  /// Small zigzag lightning flicker near the boss end for impact feel.
  void _drawLightningFlicker(Canvas canvas, Offset target, int seed) {
    final rng    = Random(seed);
    final spread = 18.0;
    final path   = Path()..moveTo(target.dx, target.dy);
    for (int i = 0; i < 4; i++) {
      path.lineTo(
        target.dx + (rng.nextDouble() - 0.5) * spread,
        target.dy + (rng.nextDouble() - 0.5) * spread,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xBBAAEEFF)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }
}

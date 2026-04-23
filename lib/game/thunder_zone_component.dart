import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'boss_ball_game.dart';

/// A crackling thunderstorm zone placed by ZapperOrb on boss hit.
///
/// While active, random lightning bolts flash inside the zone and the
/// boss takes 800 damage per 0.35 s while standing in it.
/// Zone lasts [totalLife] seconds.
class ThunderZoneComponent extends PositionComponent {
  final BossBallGame gameRef;
  final VoidCallback? onExpired;

  double _lifetime;
  double _tick   = 0;
  double _visual = 0;
  final _rng     = Random();

  // Lightning bolt anchor points refreshed each frame
  final List<List<Offset>> _bolts = [];
  double _boltRefresh = 0;

  static const double zoneR        = 55.0;
  static const int    tickDamage   = 800;
  static const double tickInterval = 0.35;
  static const double totalLife    = 4.0;

  ThunderZoneComponent({
    required Vector2 position,
    required this.gameRef,
    this.onExpired,
  })  : _lifetime = totalLife,
        super(
          position: position,
          size: Vector2.all(zoneR * 2),
          anchor: Anchor.center,
          priority: 3,
        );

  @override
  void update(double dt) {
    _visual   += dt;
    _lifetime -= dt;
    _tick     -= dt;
    _boltRefresh -= dt;

    if (_lifetime <= 0) {
      onExpired?.call();
      removeFromParent();
      return;
    }

    // Refresh lightning bolt paths every ~60 ms
    if (_boltRefresh <= 0) {
      _boltRefresh = 0.06;
      _generateBolts();
    }

    // DoT while boss in zone
    final tzBoss = gameRef.boss;
    if (tzBoss != null &&
        position.distanceTo(tzBoss.position) < tzBoss.radius + zoneR &&
        _tick <= 0) {
      _tick = tickInterval;
      gameRef.onOrbHitBoss(tickDamage, isLaserTick: true);
    }
  }

  void _generateBolts() {
    _bolts.clear();
    const boltCount = 5;
    for (int b = 0; b < boltCount; b++) {
      final startAngle = _rng.nextDouble() * 2 * pi;
      final startR     = _rng.nextDouble() * zoneR * 0.9;
      final start      = Offset(
        zoneR + cos(startAngle) * startR,
        zoneR + sin(startAngle) * startR,
      );
      final pts = <Offset>[start];
      double x = start.dx;
      double y = start.dy;
      for (int s = 0; s < 6; s++) {
        x += (_rng.nextDouble() - 0.5) * 24;
        y += (_rng.nextDouble() - 0.5) * 24;
        // Clamp to zone circle roughly
        final dx = x - zoneR;
        final dy = y - zoneR;
        final d  = sqrt(dx * dx + dy * dy);
        if (d > zoneR * 0.95) {
          x = zoneR + dx / d * zoneR * 0.9;
          y = zoneR + dy / d * zoneR * 0.9;
        }
        pts.add(Offset(x, y));
      }
      _bolts.add(pts);
    }
  }

  @override
  void render(Canvas canvas) {
    final t    = _visual;
    final cx   = zoneR;
    final cy   = zoneR;
    final fade = (_lifetime / totalLife).clamp(0.0, 1.0);

    // Electric field base glow
    canvas.drawCircle(
      Offset(cx, cy),
      zoneR,
      Paint()
        ..color = const Color(0xFF001133).withOpacity(fade * 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Spinning electric ring
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: zoneR - 4),
      t * 4.0,
      pi * 1.7,
      false,
      Paint()
        ..color = const Color(0xAA00CCFF).withOpacity(fade * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Lightning bolts inside zone
    for (final bolt in _bolts) {
      if (bolt.length < 2) continue;
      final path = Path()..moveTo(bolt[0].dx, bolt[0].dy);
      for (int i = 1; i < bolt.length; i++) {
        path.lineTo(bolt[i].dx, bolt[i].dy);
      }
      // Glow
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0x8844CCFF).withOpacity(fade * 0.5)
          ..strokeWidth = 3.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      // Core
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withOpacity(fade * 0.8)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    // Centre core spark
    canvas.drawCircle(
      Offset(cx, cy),
      8 + sin(t * 20) * 4,
      Paint()
        ..color = Colors.white.withOpacity(fade * 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }
}

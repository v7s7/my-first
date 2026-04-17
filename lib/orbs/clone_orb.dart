import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

/// On boss hit: spawns 3 ghost echo clones that orbit the orb and
/// independently fire at the boss, each dealing 3 000 every 0.5 s.
/// Duration: 3.5 s.  Total echo damage: up to 63 000 + initial 2 000.
///
/// Visual: translucent ghost copies of the main orb orbiting at varying
/// distances, connected by shimmering echo lines.
class CloneOrb extends OrbBehavior {
  @override String get id   => 'clone';
  @override String get name => 'ECHO';
  @override String get description => '2K + 3 echoes\n63K+ total';
  @override Color  get color => const Color(0xFFDD00FF);

  static const int    _initialDmg   = 2000;
  static const int    _cloneCount   = 3;
  static const int    _cloneDmg     = 3000;
  static const double _cloneDuration = 3.5;
  static const double _hitInterval   = 0.45;

  bool   _active      = false;
  double _activeTimer = 0;
  double _hitCooldown = 0;
  double _time        = 0;

  @override void onAttach(PlayerOrb orb) { _active = false; _time = 0; }

  @override
  void onUpdate(double dt, PlayerOrb orb) {
    _time += dt;
    if (!_active) return;
    _activeTimer -= dt;
    _hitCooldown -= dt;
    if (_hitCooldown <= 0) {
      _hitCooldown = _hitInterval;
      for (int i = 0; i < _cloneCount; i++) {
        orb.gameRef.onOrbHitBoss(_cloneDmg, isLaserTick: true);
      }
    }
    if (_activeTimer <= 0) _active = false;
  }

  @override
  void onBossHit(PlayerOrb orb) {
    orb.gameRef.onOrbHitBoss(_initialDmg);
    _active      = true;
    _activeTimer = _cloneDuration;
    _hitCooldown = 0;
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t = _time;
    if (!_active) return;

    final p        = 1.0 - (_activeTimer / _cloneDuration);
    final echoFade = (1.0 - p).clamp(0.0, 1.0);

    for (int i = 0; i < _cloneCount; i++) {
      final phase  = i / _cloneCount;
      final angle  = p * pi * 8 + phase * 2 * pi;
      final dist   = radius + 28 + i * 14 + sin(t * 5 + i) * 8;
      final ex     = cx + cos(angle) * dist;
      final ey     = cy + sin(angle) * dist;
      final cloneAlpha = echoFade * (0.7 - i * 0.12);

      // Connection line (shimmering echo beam)
      canvas.drawLine(
        Offset(cx, cy),
        Offset(ex, ey),
        Paint()
          ..color = color.withOpacity(cloneAlpha * 0.5 + sin(t * 12 + i) * 0.1)
          ..strokeWidth = 1.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );

      // Ghost clone body
      canvas.drawCircle(
        Offset(ex, ey),
        radius * (0.55 - i * 0.05),
        Paint()
          ..color = color.withOpacity(cloneAlpha * 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      // Ghost highlight
      canvas.drawCircle(
        Offset(ex - radius * 0.18, ey - radius * 0.18),
        radius * 0.22,
        Paint()
          ..color = Colors.white.withOpacity(cloneAlpha * 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      // Ghost rim
      canvas.drawCircle(
        Offset(ex, ey),
        radius * (0.55 - i * 0.05),
        Paint()
          ..color = color.withOpacity(cloneAlpha * 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }
}

import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';
import '../game/mine_component.dart';

/// Places landmines on every wall bounce, then DETONATES ALL OF THEM
/// simultaneously when the boss is hit — maximum chain-reaction damage.
///
/// Each mine:   10 000 damage
/// Max mines:   5  (placed on wall bounces)
/// Contact hit: 2 000
///
/// Max burst (5 mines + contact): 52 000
///
/// The strategy: bounce around to fill the arena with mines, THEN hit
/// the boss and watch everything explode at once.
///
/// Visual: dark yellow with pulsing detonator ring + mine counter.
/// On boss hit: a shockwave ring signals mass detonation.
class ChainBombOrb extends OrbBehavior {
  @override String get id   => 'chainbomb';
  @override String get name => 'CHAIN BOMB';
  @override String get description => '2K + 10K/mine\nall detonate on hit';
  @override Color  get color => const Color(0xFFFFCC00);

  static const int _maxMines      = 5;
  static const int _mineDamage    = 10000;
  static const int _contactDamage = 2000;

  final List<MineComponent> _mines = [];
  double _time   = 0;
  bool   _boom   = false;
  double _boomTimer = 0;
  static const double _boomDuration = 0.5;

  @override
  void onAttach(PlayerOrb orb) {
    _mines.clear();
    _time = 0;
    _boom = false;
    _boomTimer = 0;
  }

  @override
  void onUpdate(double dt, PlayerOrb orb) {
    _time += dt;
    if (_boom) {
      _boomTimer -= dt;
      if (_boomTimer <= 0) _boom = false;
    }
  }

  @override
  void onWallBounce(PlayerOrb orb) {
    if (_mines.length >= _maxMines) return;
    final mine = MineComponent(
      position:    orb.position.clone(),
      gameRef:     orb.gameRef,
      damage:      _mineDamage,
      onDetonated: () => _mines.removeWhere((m) => m.isMounted == false),
    );
    _mines.add(mine);
    orb.gameRef.add(mine);
  }

  @override
  void onBossHit(PlayerOrb orb) {
    orb.gameRef.onOrbHitBoss(_contactDamage);
    // Detonate every active mine at once
    final snapshot = List<MineComponent>.from(_mines);
    _mines.clear();
    for (final m in snapshot) {
      m.detonate();
    }
    if (snapshot.isNotEmpty) {
      _boom      = true;
      _boomTimer = _boomDuration;
    }
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t      = _time;
    final mCount = _mines.length;

    // Danger arcs (2 rotating)
    for (int i = 0; i < 2; i++) {
      final arcR  = radius + 8.0 + i * 6.0;
      final speed = 2.2 + i * 0.6;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: arcR),
        t * speed + i * pi,
        pi * 0.7,
        false,
        Paint()
          ..color = const Color(0xFFFFCC00).withOpacity(0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // Mine count fill indicator (arc from 0 to mCount/maxMines)
    if (mCount > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius + 14),
        -pi / 2,
        2 * pi * (mCount / _maxMines),
        false,
        Paint()
          ..color = const Color(0xFFFFCC00).withOpacity(0.80)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // 5 orbiting bolt dots
    for (int i = 0; i < 5; i++) {
      final a  = i * (2 * pi / 5) + t * 0.55;
      final dR = radius + 6;
      final px = cx + cos(a) * dR;
      final py = cy + sin(a) * dR;
      final active = i < mCount;
      canvas.drawCircle(
        Offset(px, py),
        3.5,
        Paint()
          ..color = (active
                  ? const Color(0xFFFFCC00)
                  : const Color(0xFF664400))
              .withOpacity(active ? 0.9 : 0.4)
          ..maskFilter = active
              ? const MaskFilter.blur(BlurStyle.normal, 3)
              : null,
      );
    }

    // Mine count badge
    if (mCount > 0) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'x$mCount',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx + radius + 4, cy - 7));
    }

    // Mass-detonation shockwave
    if (_boom) {
      final p = 1.0 - (_boomTimer / _boomDuration);
      for (int i = 0; i < 3; i++) {
        final bR = radius + p * (radius * 4 + i * 20);
        canvas.drawCircle(
          Offset(cx, cy),
          bR,
          Paint()
            ..color = const Color(0xFFFFCC00).withOpacity((1.0 - p) * 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = (5.0 * (1.0 - p)).clamp(0.5, 5.0)
            ..maskFilter =
                MaskFilter.blur(BlurStyle.normal, 12 * (1.0 - p)),
        );
      }
    }
  }
}

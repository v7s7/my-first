import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'boss_ball_game.dart';

class BossComponent extends PositionComponent with HasGameRef<BossBallGame> {
  double radius = 60.0;
  double _time  = 0.0;

  late Vector2 velocity;
  final _rng = Random();

  // ── Freeze mechanic (IceOrb) ──────────────────────────────────────────────
  double _frozenTimer = 0.0;
  bool get isFrozen => _frozenTimer > 0;

  void freezeBoss(double duration) {
    if (duration > _frozenTimer) _frozenTimer = duration;
  }

  // ── Physics constants ─────────────────────────────────────────────────────
  static const double mass       = 3.0;
  static const double startSpeed = 145.0; // px/s initial velocity
  static const double minSpeed   = 90.0;  // never stall below this
  static const double maxSpeed   = 420.0; // cap after repeated hits

  BossComponent({required Vector2 position})
      : super(position: position, anchor: Anchor.center);

  @override
  void onLoad() {
    // Launch in a random diagonal direction so it never travels straight
    // along a wall (avoids boring back-and-forth movement).
    final angle = _rng.nextDouble() * 2 * pi;
    velocity    = Vector2(cos(angle), sin(angle)) * startSpeed;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;

    final arena = gameRef.arenaConfig;

    // ── Freeze ──────────────────────────────────────────────────────────────
    if (_frozenTimer > 0) {
      _frozenTimer -= dt;
      // Rapid exponential deceleration while frozen
      velocity.scale(max(0.0, 1.0 - dt * 6.0));
      // When freeze expires and ball has stalled, restart it
      if (_frozenTimer <= 0 && velocity.length < 30) {
        final a = _rng.nextDouble() * 2 * pi;
        velocity = Vector2(cos(a), sin(a)) * startSpeed;
      }
    }

    // ── Move ────────────────────────────────────────────────────────────────
    position += velocity * dt;

    // ── Elastic wall bounces ─────────────────────────────────────────────────
    if (position.x <= arena.minX(radius)) {
      position.x = arena.minX(radius);
      if (velocity.x < 0) velocity.x = -velocity.x;
    } else if (position.x >= arena.maxX(radius)) {
      position.x = arena.maxX(radius);
      if (velocity.x > 0) velocity.x = -velocity.x;
    }

    if (position.y <= arena.minY(radius)) {
      position.y = arena.minY(radius);
      if (velocity.y < 0) velocity.y = -velocity.y;
    } else if (position.y >= arena.maxY(radius)) {
      position.y = arena.maxY(radius);
      if (velocity.y > 0) velocity.y = -velocity.y;
    }

    // ── Speed bounds (only when not frozen) ─────────────────────────────────
    if (_frozenTimer <= 0) {
      final spd = velocity.length;
      if (spd > maxSpeed) {
        velocity = velocity.normalized() * maxSpeed;
      } else if (spd < minSpeed) {
        velocity = spd < 0.01
            ? Vector2(cos(_rng.nextDouble() * 2 * pi),
                      sin(_rng.nextDouble() * 2 * pi)) * minSpeed
            : velocity.normalized() * minSpeed;
      }
    }
  }

  // ── Rendering ─────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    final hpRatio = gameRef.bossHp / gameRef.bossMaxHp;

    final breathe    = sin(_time) * 0.08;
    final glowRadius = radius + 10 + breathe * 8;

    // HP colour: purple → pink → red
    Color bossColor;
    if (hpRatio > 0.6) {
      bossColor = Color.lerp(const Color(0xFF6A5AFF), const Color(0xFF7155FF),
          1.0 - (hpRatio - 0.6) / 0.4)!;
    } else if (hpRatio > 0.3) {
      bossColor = Color.lerp(const Color(0xFFFF4488), const Color(0xFF6A5AFF),
          (hpRatio - 0.3) / 0.3)!;
    } else {
      bossColor = Color.lerp(
          const Color(0xFFFF0033), const Color(0xFFFF4488), hpRatio / 0.3)!;
    }

    // Outer glow
    canvas.drawCircle(Offset.zero, glowRadius,
        Paint()
          ..color = bossColor.withOpacity(0.30)
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 20));

    // Inner glow
    canvas.drawCircle(Offset.zero, radius + 3,
        Paint()
          ..color = bossColor.withOpacity(0.50)
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 8));

    // Main body — solid color OR custom face image
    final faceImg = gameRef.bossUiImage;
    if (faceImg != null) {
      final dst = Rect.fromCircle(center: Offset.zero, radius: radius);
      canvas.save();
      canvas.clipPath(Path()..addOval(dst));
      canvas.drawImageRect(
        faceImg,
        Rect.fromLTWH(0, 0, faceImg.width.toDouble(), faceImg.height.toDouble()),
        dst,
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
    } else {
      canvas.drawCircle(Offset.zero, radius, Paint()..color = bossColor);
    }

    // Metallic highlight
    canvas.drawCircle(
        Offset(-radius * 0.3, -radius * 0.3),
        radius * 0.45,
        Paint()
          ..color = Colors.white.withOpacity(0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    // Rage aura at low HP
    if (hpRatio < 0.2) {
      canvas.drawCircle(Offset.zero, radius + 25,
          Paint()
            ..color = Colors.red.withOpacity(0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 15));
    }

    // ── Ice overlay when frozen ─────────────────────────────────────────────
    if (isFrozen) {
      canvas.drawCircle(Offset.zero, radius + 6,
          Paint()
            ..color = const Color(0x5588CCFF)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
      const crystals = 8;
      for (int i = 0; i < crystals; i++) {
        final angle = i * (2 * pi / crystals) + _time * 0.4;
        final inner = radius * 0.75;
        final outer = radius + 14 + sin(_time * 5 + i) * 5;
        canvas.drawLine(
          Offset(cos(angle) * inner, sin(angle) * inner),
          Offset(cos(angle) * outer, sin(angle) * outer),
          Paint()
            ..color = const Color(0xBBAAE8FF)
            ..strokeWidth = 3.0
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
        canvas.drawCircle(
          Offset(cos(angle) * outer, sin(angle) * outer),
          3.5,
          Paint()
            ..color = const Color(0xDDDDFFFF)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      }
    }

    // HP text
    final hpText = '${gameRef.bossHp} / ${gameRef.bossMaxHp}';
    final tp = TextPainter(
      text: TextSpan(
        text: hpText,
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
                color: Colors.black.withOpacity(0.8),
                blurRadius: 4,
                offset: const Offset(1, 1)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
  }
}

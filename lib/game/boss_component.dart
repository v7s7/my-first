import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'arena_config.dart';

/// The boss ball.
///
/// Physics:
///   - Moves autonomously at [baseSpeed] in a random direction.
///   - Bounces off arena border walls and internal obstacle rects.
///   - Receives velocity impulses from the player orb via [applyImpulse].
///   - Excess speed decays back toward [baseSpeed] via drag.
///
/// Visual:
///   - Idle sine-pulse (gentle size breathe).
///   - Speed-reactive glow aura (brighter when faster).
///   - HP arc ring + centred HP text drawn over the sphere.
class BossComponent extends PositionComponent {
  static const double radius = 55.0;

  // ── Physics constants ──────────────────────────────────────────────────────
  static const double mass      = 8.0;
  static const double baseSpeed = 95.0;  // px/s autonomous cruise speed
  static const double maxSpeed  = 700.0;
  static const double drag      = 1.2;   // excess-speed decay rate

  final ArenaConfig arena;
  Vector2 velocity = Vector2.zero();

  // ── HP state (set by BossBallGame immediately after construction) ──────────
  int maxHp     = 0;
  int currentHp = 0;

  // ── Visual ─────────────────────────────────────────────────────────────────
  double _pulseTimer = 0.0;

  final Random _rng = Random();

  BossComponent({required Vector2 position, required this.arena})
      : super(
          position: position,
          size: Vector2.all(radius * 2),
          anchor: Anchor.center,
        ) {
    final angle = _rng.nextDouble() * 2 * pi;
    velocity = Vector2(cos(angle), sin(angle)) * baseSpeed;
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  void applyImpulse(Vector2 impulse) {
    velocity += impulse;
    if (velocity.length > maxSpeed) velocity = velocity.normalized() * maxSpeed;
  }

  // ── Flame lifecycle ────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    _pulseTimer += dt;

    position += velocity * dt;
    _bounceOffWalls();
    arena.bounceOffObstacles(position, velocity, radius);

    // Drag: bleed excess speed back toward cruise
    final spd = velocity.length;
    if (spd > baseSpeed) {
      velocity = velocity.normalized() * max(baseSpeed, spd - spd * drag * dt);
    }
  }

  void _bounceOffWalls() {
    if (position.x <= arena.minX(radius)) {
      position.x = arena.minX(radius); velocity.x =  velocity.x.abs();
    } else if (position.x >= arena.maxX(radius)) {
      position.x = arena.maxX(radius); velocity.x = -velocity.x.abs();
    }
    if (position.y <= arena.minY(radius)) {
      position.y = arena.minY(radius); velocity.y =  velocity.y.abs();
    } else if (position.y >= arena.maxY(radius)) {
      position.y = arena.maxY(radius); velocity.y = -velocity.y.abs();
    }
  }

  // ── Rendering ──────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    final cx = radius;
    final cy = radius;
    final pulse = 1.0 + sin(_pulseTimer * 1.8) * 0.035;
    final sr = radius * pulse;

    // Speed-reactive glow (0 at cruise, 1 at max)
    final speedRatio =
        ((velocity.length - baseSpeed) / (maxSpeed - baseSpeed)).clamp(0.0, 1.0);
    final glowExtra = speedRatio * 18;

    // Outer aura
    canvas.drawCircle(
      Offset(cx, cy),
      sr + 24 + glowExtra,
      Paint()
        ..color = Color.fromARGB(
            (0x33 + (speedRatio * 0x44).round()).clamp(0, 255), 255, 34, 0)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
    );

    // Mid glow
    canvas.drawCircle(
      Offset(cx, cy),
      sr + 10 + glowExtra * 0.5,
      Paint()
        ..color = const Color(0x55FF4400)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // Core body
    canvas.drawCircle(
      Offset(cx, cy),
      sr,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0xFFFF6633), Color(0xFFCC1100)],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: sr)),
    );

    // Rim
    canvas.drawCircle(
      Offset(cx, cy),
      sr,
      Paint()
        ..color = const Color(0xAAFF7755)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Shine
    canvas.drawCircle(
      Offset(cx - sr * 0.3, cy - sr * 0.3),
      sr * 0.28,
      Paint()..color = const Color(0x55FFFFFF),
    );

    // Velocity trail
    if (velocity.length > baseSpeed * 1.5) {
      final dir = velocity.normalized();
      final trailLen = (velocity.length / maxSpeed * 30).clamp(6.0, 30.0);
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx - dir.x * trailLen, cy - dir.y * trailLen),
        Paint()
          ..color = const Color(0x44FF4400)
          ..strokeWidth = 6
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // HP ring + text
    if (maxHp > 0) {
      _drawHpRing(canvas, cx, cy);
      _drawHpText(canvas, cx, cy);
    }
  }

  void _drawHpRing(Canvas canvas, double cx, double cy) {
    final ratio = (currentHp / maxHp).clamp(0.0, 1.0);
    const ringR  = radius + 9.0;
    const strokeW = 4.5;

    // Background ring
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: ringR),
      -pi / 2, 2 * pi, false,
      Paint()
        ..color = const Color(0x33FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW,
    );

    // HP arc
    if (ratio > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: ringR),
        -pi / 2, 2 * pi * ratio, false,
        Paint()
          ..color = _hpColor(ratio)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawHpText(Canvas canvas, double cx, double cy) {
    final ratio = (currentHp / maxHp.toDouble()).clamp(0.0, 1.0);
    final tp = TextPainter(
      text: TextSpan(
        text: _fmtHp(currentHp),
        style: TextStyle(
          color: _hpColor(ratio),
          fontSize: 13,
          fontWeight: FontWeight.w900,
          height: 1.0,
          shadows: const [
            Shadow(color: Color(0xCC000000), offset: Offset(1, 1), blurRadius: 3),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  static Color _hpColor(double ratio) {
    if (ratio > 0.6) return const Color(0xFF44FF88);
    if (ratio > 0.3) return const Color(0xFFFFBB00);
    return const Color(0xFFFF3311);
  }

  static String _fmtHp(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(0)}K';
    return '$n';
  }
}

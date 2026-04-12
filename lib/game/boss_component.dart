import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'arena_config.dart';

/// The boss ball.
///
/// Physics behaviour:
///   - Moves autonomously at [baseSpeed] in a random direction.
///   - Bounces elastically off all four arena walls.
///   - Receives velocity impulses from the player orb via [applyImpulse].
///   - Excess speed decays back toward [baseSpeed] at rate [drag].
///
/// Visual behaviour:
///   - Idle sine-pulse (gentle size breathe).
///   - Squash-and-stretch spring animation on each hit.
///   - Speed-reactive glow: the faster the boss moves, the brighter its aura.
class BossComponent extends PositionComponent {
  static const double radius = 55.0;

  // ── Physics constants ──────────────────────────────────────────────────────
  static const double mass = 8.0;
  static const double baseSpeed = 95.0;   // px/s autonomous cruise speed
  static const double maxSpeed = 700.0;
  static const double drag = 1.2;         // excess-speed decay (units/s per unit)

  final ArenaConfig arena;
  Vector2 velocity = Vector2.zero();

  // ── HP state (set by BossBallGame after creation) ──────────────────────────
  int maxHp = 0;
  int currentHp = 0;

  // ── Visual animation state ─────────────────────────────────────────────────
  double _scaleX = 1.0;
  double _scaleY = 1.0;
  double _hitTimer = 0.0;
  static const double _hitDuration = 0.22;
  double _pulseTimer = 0.0;

  final Random _rng = Random();

  BossComponent({required Vector2 position, required this.arena})
      : super(
          position: position,
          size: Vector2.all(radius * 2),
          anchor: Anchor.center,
        ) {
    // Launch in a random direction at cruise speed
    final angle = _rng.nextDouble() * 2 * pi;
    velocity = Vector2(cos(angle), sin(angle)) * baseSpeed;
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Called by PlayerOrb's elastic collision resolver.
  /// [impulse] is already scaled by mass ratio — just add it to velocity.
  void applyImpulse(Vector2 impulse) {
    velocity += impulse;
    final len = velocity.length;
    if (len > maxSpeed) velocity = velocity.normalized() * maxSpeed;
  }

  void triggerHitAnimation() {
    _hitTimer = _hitDuration;
    _scaleX = 1.38;
    _scaleY = 0.72;
  }

  // ── Flame lifecycle ────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    _pulseTimer += dt;

    // Move
    position += velocity * dt;

    // Bounce off arena walls
    _bounceOffWalls();

    // Speed drag: bleed excess speed back toward cruise speed
    final spd = velocity.length;
    if (spd > baseSpeed) {
      final newSpd = max(baseSpeed, spd - spd * drag * dt);
      velocity = velocity.normalized() * newSpd;
    }

    // Squash-and-stretch spring recovery
    if (_hitTimer > 0) {
      _hitTimer -= dt;
      final p = 1.0 - (_hitTimer / _hitDuration); // 0 → 1
      final spring = 1.0 + cos(p * pi * 2.6) * (1.0 - p);
      _scaleX = 1.0 + 0.38 * spring * (1.0 - p);
      _scaleY = 1.0 - 0.28 * spring * (1.0 - p);
      if (_hitTimer <= 0) {
        _scaleX = 1.0;
        _scaleY = 1.0;
      }
    }
  }

  void _bounceOffWalls() {
    final mnX = arena.minX(radius);
    final mxX = arena.maxX(radius);
    final mnY = arena.minY(radius);
    final mxY = arena.maxY(radius);

    if (position.x <= mnX) {
      position.x = mnX;
      velocity.x = velocity.x.abs();
    } else if (position.x >= mxX) {
      position.x = mxX;
      velocity.x = -velocity.x.abs();
    }

    if (position.y <= mnY) {
      position.y = mnY;
      velocity.y = velocity.y.abs();
    } else if (position.y >= mxY) {
      position.y = mxY;
      velocity.y = -velocity.y.abs();
    }
  }

  // ── Rendering ──────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    final cx = radius;
    final cy = radius;
    final pulse = 1.0 + sin(_pulseTimer * 1.8) * 0.035;
    final sr = radius * pulse;

    // Speed-reactive glow intensity (0.0 at cruise, 1.0 at maxSpeed)
    final speedRatio = ((velocity.length - baseSpeed) / (maxSpeed - baseSpeed))
        .clamp(0.0, 1.0);
    final glowExtra = speedRatio * 18;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(_scaleX, _scaleY);
    canvas.translate(-cx, -cy);

    // Outer aura — brightens with speed
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

    // Core body with radial gradient
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

    // Shine spot
    canvas.drawCircle(
      Offset(cx - sr * 0.3, cy - sr * 0.3),
      sr * 0.28,
      Paint()..color = const Color(0x55FFFFFF),
    );

    canvas.restore();

    // Velocity arrow (debug feel — a faint directional streak)
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

    // HP ring + text (only when HP is initialised)
    if (maxHp > 0) {
      _drawHpRing(canvas, cx, cy);
      _drawHpText(canvas, cx, cy);
    }
  }

  void _drawHpRing(Canvas canvas, double cx, double cy) {
    final ratio = (currentHp / maxHp).clamp(0.0, 1.0);
    const ringR = radius + 9.0;
    const strokeW = 4.5;

    // Background ring (translucent white)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: ringR),
      -pi / 2,
      2 * pi,
      false,
      Paint()
        ..color = const Color(0x33FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW,
    );

    // Filled HP arc — colour shifts green → yellow → red
    final hpColor = _hpColor(ratio);
    if (ratio > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: ringR),
        -pi / 2,
        2 * pi * ratio,
        false,
        Paint()
          ..color = hpColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawHpText(Canvas canvas, double cx, double cy) {
    final tp = TextPainter(
      text: TextSpan(
        text: _fmtHp(currentHp),
        style: TextStyle(
          color: _hpColor((currentHp / maxHp.toDouble()).clamp(0.0, 1.0)),
          fontSize: 13,
          fontWeight: FontWeight.w900,
          height: 1.0,
          shadows: const [
            Shadow(
              color: Color(0xCC000000),
              offset: Offset(1, 1),
              blurRadius: 3,
            ),
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
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return '$n';
  }
}

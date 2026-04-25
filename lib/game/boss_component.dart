import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'boss_ball_game.dart';

class BossComponent extends PositionComponent with HasGameRef<BossBallGame> {
  double radius = 60.0;
  double _time  = 0.0;

  /// Current phase: 1 = normal, 2 = enraged (60%), 3 = rage (30%)
  int phase = 1;

  late Vector2 velocity;
  final _rng = Random();

  // ── Freeze mechanic ───────────────────────────────────────────────────────
  double _frozenTimer = 0.0;
  bool get isFrozen => _frozenTimer > 0;

  void freezeBoss(double duration) {
    if (duration > _frozenTimer) _frozenTimer = duration;
  }

  // ── Physics constants ─────────────────────────────────────────────────────
  static const double mass       = 3.0;
  static const double startSpeed = 145.0;
  static const double minSpeed   = 90.0;
  static const double maxSpeed   = 420.0;

  /// Extra speed multiplier applied by the Endless wave system (1.0 = no boost).
  double waveSpeedBoost = 1.0;

  // ── Phase system ──────────────────────────────────────────────────────────
  bool _phase2Triggered = false;
  bool _phase3Triggered = false;
  double _attackTimer   = 0.0;
  double _phaseFlashTimer = 0.0;

  double get _attackInterval => phase == 3 ? 2.2 : 3.8;

  double get _speedMultiplier => switch (phase) {
        3 => 1.65,
        2 => 1.30,
        _ => 1.00,
      };

  BossComponent({required Vector2 position})
      : super(position: position, anchor: Anchor.center);

  @override
  void onLoad() {
    final angle = _rng.nextDouble() * 2 * pi;
    velocity = Vector2(cos(angle), sin(angle)) * startSpeed;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;

    _checkPhaseTransitions();

    // Attack timer — phases 2 and 3 only
    if (phase > 1) {
      _attackTimer -= dt;
      if (_attackTimer <= 0) {
        _attackTimer = _attackInterval;
        gameRef.spawnBossAttack(position.clone(), phase);
      }
    }

    if (_phaseFlashTimer > 0) _phaseFlashTimer -= dt;

    // Freeze deceleration
    if (_frozenTimer > 0) {
      _frozenTimer -= dt;
      velocity.scale(max(0.0, 1.0 - dt * 6.0));
      if (_frozenTimer <= 0 && velocity.length < 30) {
        final a = _rng.nextDouble() * 2 * pi;
        velocity = Vector2(cos(a), sin(a)) * startSpeed;
      }
    }

    // Movement (phase-speed-scaled, plus any Endless wave boost)
    if (_frozenTimer <= 0) {
      position += velocity * _speedMultiplier * waveSpeedBoost * dt;
    } else {
      position += velocity * dt;
    }

    // Wall bounces
    final arena = gameRef.arenaConfig;
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

    // Speed clamp
    if (_frozenTimer <= 0) {
      final spd = velocity.length;
      if (spd > maxSpeed) {
        velocity = velocity.normalized() * maxSpeed;
      } else if (spd < minSpeed) {
        velocity = spd < 0.01
            ? Vector2(cos(_rng.nextDouble() * 2 * pi),
                      sin(_rng.nextDouble() * 2 * pi)) *
                minSpeed
            : velocity.normalized() * minSpeed;
      }
    }
  }

  void _checkPhaseTransitions() {
    if (gameRef.bossMaxHp <= 0) return;
    final hpRatio = gameRef.bossHp / gameRef.bossMaxHp;

    if (!_phase2Triggered && hpRatio < 0.6) {
      _phase2Triggered = true;
      phase = 2;
      _attackTimer = 0.8;
      _phaseFlashTimer = 0.7;
      gameRef.onBossPhaseChange(2);
    } else if (!_phase3Triggered && hpRatio < 0.3) {
      _phase3Triggered = true;
      phase = 3;
      _attackTimer = 0.4;
      _phaseFlashTimer = 1.0;
      gameRef.onBossPhaseChange(3);
    }
  }

  // ── Rendering ─────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    final hpRatio = gameRef.bossMaxHp > 0
        ? (gameRef.bossHp / gameRef.bossMaxHp).clamp(0.0, 1.0)
        : 0.0;

    // Phase-based color
    final Color bossColor;
    switch (phase) {
      case 3:
        bossColor = Color.lerp(const Color(0xFFFF0022), const Color(0xFFFF4400),
            sin(_time * 8) * 0.5 + 0.5)!;
      case 2:
        bossColor = Color.lerp(const Color(0xFFFF4488), const Color(0xFFFF6644),
            sin(_time * 3) * 0.5 + 0.5)!;
      default:
        if (hpRatio > 0.6) {
          bossColor = const Color(0xFF6A5AFF);
        } else {
          bossColor = Color.lerp(const Color(0xFFFF4488), const Color(0xFF6A5AFF),
              (hpRatio - 0.3) / 0.3)!;
        }
    }

    final breatheFreq = phase == 3 ? 5.0 : (phase == 2 ? 3.5 : 2.0);
    final breathe = sin(_time * breatheFreq) * 0.08;
    final glowRadius = radius + 10 + breathe * 8;

    // Phase flash burst
    if (_phaseFlashTimer > 0) {
      final flashAlpha = (_phaseFlashTimer / 0.7).clamp(0.0, 1.0) * 0.65;
      canvas.drawCircle(Offset.zero, radius + 50,
          Paint()
            ..color = Colors.white.withOpacity(flashAlpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30));
    }

    // Phase 3: outer rage pulse ring
    if (phase == 3) {
      final rageR = radius + 22 + sin(_time * 6) * 9;
      canvas.drawCircle(Offset.zero, rageR,
          Paint()
            ..color = Colors.red.withOpacity(0.18 + sin(_time * 14) * 0.09)
            ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 15));
    }

    // Orbiting energy orbs (phase 2: 4 orbs, phase 3: 6 orbs)
    if (phase >= 2) {
      final count = phase == 3 ? 6 : 4;
      final orbitR = radius + 24;
      final speed  = phase == 3 ? 3.8 : 2.4;
      final orbColor = phase == 3 ? const Color(0xFFFF2200) : const Color(0xFFFF2288);
      for (int i = 0; i < count; i++) {
        final a = _time * speed + i * (2 * pi / count);
        final ox = cos(a) * orbitR;
        final oy = sin(a) * orbitR;
        canvas.drawCircle(Offset(ox, oy), 6.0,
            Paint()
              ..color = orbColor
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
        canvas.drawCircle(Offset(ox, oy), 2.8, Paint()..color = Colors.white);
      }
    }

    // Outer glow
    canvas.drawCircle(Offset.zero, glowRadius,
        Paint()
          ..color = bossColor.withOpacity(0.30 + (phase > 1 ? 0.12 : 0.0))
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 22));

    // Inner glow
    canvas.drawCircle(Offset.zero, radius + 3,
        Paint()
          ..color = bossColor.withOpacity(0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 8));

    // Main body — image or solid color
    final faceImg = gameRef.bossUiImage;
    if (faceImg != null) {
      final dst = Rect.fromCircle(center: Offset.zero, radius: radius);
      canvas.save();
      canvas.clipPath(Path()..addOval(dst));
      canvas.drawImageRect(
        faceImg,
        Rect.fromLTWH(
            0, 0, faceImg.width.toDouble(), faceImg.height.toDouble()),
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

    // Rim glow
    canvas.drawCircle(Offset.zero, radius,
        Paint()
          ..color = bossColor.withOpacity(0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    // Ice overlay
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
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
        canvas.drawCircle(
          Offset(cos(angle) * outer, sin(angle) * outer),
          3.5,
          Paint()
            ..color = const Color(0xDDDDFFFF)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
      }
    }

    // Phase badge on boss body
    if (phase > 1) {
      final phaseColor =
          phase == 3 ? const Color(0xFFFF2244) : const Color(0xFFFF88CC);
      final tp = TextPainter(
        text: TextSpan(
          text: 'PHASE $phase',
          style: TextStyle(
            color: phaseColor,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, radius * 0.48));
    }
  }
}

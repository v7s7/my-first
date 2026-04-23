import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'arena_config.dart';

/// Animated arena background: pulsing dot grid + ambient drift particles.
/// Call pulse() when the boss is hit for a ripple effect.
class ArenaBackground extends PositionComponent {
  final ArenaConfig arena;

  double _time = 0.0;
  double _pulseIntensity = 0.0;

  final Random _rng = Random();
  final List<_AmbientParticle> _particles = [];
  static const int _particleCount = 28;

  ArenaBackground({required this.arena}) : super(priority: -2);

  @override
  Future<void> onLoad() async {
    for (int i = 0; i < _particleCount; i++) {
      _particles.add(_AmbientParticle.random(_rng, arena));
    }
  }

  void pulse(double intensity) {
    if (intensity > _pulseIntensity) _pulseIntensity = intensity;
  }

  @override
  void update(double dt) {
    _time += dt;
    _pulseIntensity = (_pulseIntensity - dt * 2.5).clamp(0.0, 1.0);
    for (final p in _particles) p.update(dt, arena);
  }

  @override
  void render(Canvas canvas) {
    // Base arena fill
    canvas.drawRect(
      Rect.fromLTWH(arena.left, arena.top, arena.width, arena.height),
      Paint()..color = const Color(0xFF060610),
    );

    // Dot grid
    const spacing = 46.0;
    final cx = arena.left + arena.width / 2;
    final cy = arena.top + arena.height / 2;
    final maxDist =
        sqrt(arena.width * arena.width + arena.height * arena.height) / 2;

    for (double gx = arena.innerLeft + spacing / 2;
        gx < arena.innerRight;
        gx += spacing) {
      for (double gy = arena.innerTop + spacing / 2;
          gy < arena.innerBottom;
          gy += spacing) {
        final dist = sqrt((gx - cx) * (gx - cx) + (gy - cy) * (gy - cy));
        final radialFade = 1.0 - (dist / maxDist).clamp(0.0, 1.0);
        final wave = sin(_time * 1.1 + gx * 0.038 + gy * 0.031) * 0.5 + 0.5;
        final pulseBrightness = _pulseIntensity * 0.22 * radialFade *
            (1.0 - (dist / maxDist).clamp(0.0, 1.0));
        final brightness = 0.05 + wave * 0.05 * radialFade + pulseBrightness;
        canvas.drawCircle(
          Offset(gx, gy),
          1.3,
          Paint()..color = Color.fromRGBO(90, 130, 255, brightness),
        );
      }
    }

    // Ambient drift particles
    for (final p in _particles) {
      canvas.drawCircle(
        Offset(p.x, p.y),
        p.r,
        Paint()
          ..color = p.color.withOpacity(p.alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    // Subtle center vignette glow
    if (_pulseIntensity > 0.01) {
      final r = Rect.fromLTWH(arena.left, arena.top, arena.width, arena.height);
      canvas.drawRect(
        r,
        Paint()
          ..color = const Color(0xFF6644FF).withOpacity(_pulseIntensity * 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
      );
    }
  }
}

class _AmbientParticle {
  double x, y, r, alpha, vx, vy;
  Color color;

  _AmbientParticle(
      {required this.x,
      required this.y,
      required this.r,
      required this.alpha,
      required this.vx,
      required this.vy,
      required this.color});

  factory _AmbientParticle.random(Random rng, ArenaConfig arena) {
    const colors = [
      Color(0xFF3344FF),
      Color(0xFF44AAFF),
      Color(0xFF8844FF),
      Color(0xFF4488FF),
      Color(0xFF44FFEE),
    ];
    return _AmbientParticle(
      x: arena.innerLeft +
          rng.nextDouble() * (arena.innerRight - arena.innerLeft),
      y: arena.innerTop +
          rng.nextDouble() * (arena.innerBottom - arena.innerTop),
      r: 1.2 + rng.nextDouble() * 2.5,
      alpha: 0.04 + rng.nextDouble() * 0.12,
      vx: (rng.nextDouble() - 0.5) * 14,
      vy: (rng.nextDouble() - 0.5) * 14,
      color: colors[rng.nextInt(colors.length)],
    );
  }

  void update(double dt, ArenaConfig arena) {
    x += vx * dt;
    y += vy * dt;
    if (x < arena.innerLeft) x = arena.innerRight;
    if (x > arena.innerRight) x = arena.innerLeft;
    if (y < arena.innerTop) y = arena.innerBottom;
    if (y > arena.innerBottom) y = arena.innerTop;
  }
}

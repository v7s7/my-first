import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A short-lived floating number that appears on hit and fades upward.
class DamageNumber extends PositionComponent {
  final int damage;
  final bool isSmall; // true for laser ticks — smaller, faster fade

  static const double _lifeNormal = 1.4;
  static const double _lifeSmall = 0.75;

  late final double _totalLife;
  double _life = 0;
  final double _floatSpeed;
  final double _driftX;

  DamageNumber({
    required this.damage,
    required Vector2 position,
    this.isSmall = false,
    double driftX = 0,
  })  : _floatSpeed = isSmall ? -48 : -85,
        _driftX = driftX,
        super(position: position, priority: 95) {
    _totalLife = isSmall ? _lifeSmall : _lifeNormal;
    _life = _totalLife;
  }

  @override
  void update(double dt) {
    _life -= dt;
    if (_life <= 0) {
      removeFromParent();
      return;
    }
    position.y += _floatSpeed * dt;
    position.x += _driftX * dt;
  }

  @override
  void render(Canvas canvas) {
    final progress = 1.0 - (_life / _totalLife);

    // Alpha: solid until 70%, then smooth fade to zero
    final alpha = (progress < 0.70
            ? 1.0
            : 1.0 - (progress - 0.70) / 0.30)
        .clamp(0.0, 1.0);

    // Pop scale: rises to peak at ~15% then settles; small numbers just scale flat
    final scale = isSmall ? 0.72 : (1.0 + sin(progress * pi * 0.85) * 0.55);

    final color = _colorFor(damage);
    final fontSize = (isSmall ? 13.0 : 26.0) * scale;
    final text = '-${_fmt(damage)}';

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color.withOpacity(alpha),
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          height: 1.0,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(alpha * 0.9),
              offset: const Offset(2, 2),
              blurRadius: 4,
            ),
            Shadow(
              color: color.withOpacity(alpha * 0.6),
              blurRadius: 14,
            ),
            Shadow(
              color: color.withOpacity(alpha * 0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Scale effect: larger popup
    canvas.save();
    canvas.translate(-tp.width / 2, -tp.height / 2);
    canvas.scale(1.0 + (1.0 - alpha) * 0.15, 1.0 + (1.0 - alpha) * 0.15);
    tp.paint(canvas, Offset.zero);
    canvas.restore();
  }

  static Color _colorFor(int d) {
    if (d >= 100000) return const Color(0xFFFF44AA);
    if (d >= 50000) return const Color(0xFFFF2266);
    if (d >= 10000) return const Color(0xFFFF8800);
    if (d >= 5000) return const Color(0xFFFFBB00);
    if (d >= 1000) return const Color(0xFFFFEE00);
    return const Color(0xFFFFFFFF);
  }

  static String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return '$n';
  }
}

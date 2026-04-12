import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A short-lived laser beam drawn from [startPos] to [endPos].
/// [durationLeft] is a reference to the controlling orb's laser timer.
class LaserBeam extends PositionComponent {
  Vector2 startPos;
  Vector2 endPos;
  double totalDuration;
  double timeLeft;

  LaserBeam({
    required this.startPos,
    required this.endPos,
    required this.totalDuration,
    required this.timeLeft,
  }) : super(position: Vector2.zero(), priority: 50);

  void update(double dt) {
    super.update(dt);
    timeLeft -= dt;
    if (timeLeft <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final opacity = (timeLeft / totalDuration).clamp(0.0, 1.0);
    final s = startPos.toOffset();
    final e = endPos.toOffset();

    // Wide glow
    canvas.drawLine(
      s,
      e,
      Paint()
        ..color = Color.fromARGB((opacity * 80).round(), 255, 34, 0)
        ..strokeWidth = 18
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Outer beam
    canvas.drawLine(
      s,
      e,
      Paint()
        ..color = Color.fromARGB((opacity * 200).round(), 255, 68, 0)
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke,
    );

    // Core white beam
    canvas.drawLine(
      s,
      e,
      Paint()
        ..color = Color.fromARGB((opacity * 255).round(), 255, 255, 255)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );

    // Impact flare at boss end
    canvas.drawCircle(
      e,
      12 * opacity,
      Paint()
        ..color = Color.fromARGB((opacity * 180).round(), 255, 200, 100)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }
}

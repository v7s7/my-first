import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class ArenaWall extends PositionComponent {
  ArenaWall({required Vector2 position, required Vector2 size})
      : super(position: position, size: size);

  @override
  void render(Canvas canvas) {
    // Glow layer
    final glowPaint = Paint()
      ..color = const Color(0x4D00FFFF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawRect(size.toRect(), glowPaint);

    // Solid wall
    final wallPaint = Paint()..color = const Color(0xFF00CCDD);
    canvas.drawRect(size.toRect(), wallPaint);

    // Inner highlight
    final highlightPaint = Paint()
      ..color = const Color(0x8080FFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(size.toRect(), highlightPaint);
  }
}

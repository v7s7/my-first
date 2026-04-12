import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';
import 'boss_ball_game.dart';

class HudComponent extends PositionComponent {
  final BossBallGame gameRef;

  late TextComponent _timerText;
  late TextComponent _hpText;
  late TextComponent _orbLabel;

  static final TextPaint _timerStyle = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 26,
      fontWeight: FontWeight.w900,
      letterSpacing: 2,
    ),
  );

  static final TextPaint _timerWarnStyle = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFFDD00),
      fontSize: 26,
      fontWeight: FontWeight.w900,
    ),
  );

  static final TextPaint _timerDangerStyle = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFF3333),
      fontSize: 26,
      fontWeight: FontWeight.w900,
    ),
  );

  HudComponent({required this.gameRef})
      : super(priority: 100, position: Vector2.zero());

  @override
  Future<void> onLoad() async {
    final w = gameRef.size.x;

    _timerText = TextComponent(
      text: '60',
      textRenderer: _timerStyle,
      position: Vector2(w / 2, 18),
      anchor: Anchor.topCenter,
    );

    _hpText = TextComponent(
      text: '1.00M',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFF5544),
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
      position: Vector2(w / 2, 52),
      anchor: Anchor.topCenter,
    );

    _orbLabel = TextComponent(
      text: '',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0x88FFFFFF),
          fontSize: 11,
          letterSpacing: 2,
        ),
      ),
      position: Vector2(w / 2, 80),
      anchor: Anchor.topCenter,
    );

    addAll([_timerText, _hpText, _orbLabel]);
  }

  @override
  void update(double dt) {
    super.update(dt);

    final t = gameRef.timeLeft;
    _timerText.text = t.ceil().toString();

    if (t <= 10) {
      _timerText.textRenderer = _timerDangerStyle;
    } else if (t <= 20) {
      _timerText.textRenderer = _timerWarnStyle;
    } else {
      _timerText.textRenderer = _timerStyle;
    }

    _hpText.text = _formatHp(gameRef.bossHp);
    _orbLabel.text = gameRef.orbType.name.toUpperCase() + ' ORB';
  }

  @override
  void render(Canvas canvas) {
    // Dim background strip behind HP/timer
    canvas.drawRect(
      Rect.fromLTWH(0, 0, gameRef.size.x, 96),
      Paint()..color = const Color(0xCC050510),
    );
    super.render(canvas);
  }

  static String _formatHp(int hp) {
    if (hp >= 1000000) {
      return '${(hp / 1000000).toStringAsFixed(2)}M';
    } else if (hp >= 1000) {
      return '${(hp / 1000).toStringAsFixed(1)}K';
    }
    return '$hp';
  }
}

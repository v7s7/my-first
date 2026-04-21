import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';
import 'boss_ball_game.dart';
import '../modes/game_mode.dart';

class HudComponent extends PositionComponent {
  final BossBallGame gameRef;

  // Timer text — only created when the mode has a time limit.
  TextComponent? _timerText;
  late TextComponent _hpText;
  late TextComponent _orbLabel;
  // DPS text — only created for damagePerSecond score modes.
  TextComponent? _dpsText;

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
    final mode = gameRef.mode;

    // Timer — only when the mode has a countdown
    if (mode.timeLimitSeconds > 0) {
      _timerText = TextComponent(
        text: mode.timeLimitSeconds.ceil().toString(),
        textRenderer: _timerStyle,
        position: Vector2(w / 2, 18),
        anchor: Anchor.topCenter,
      );
      add(_timerText!);
    }

    _hpText = TextComponent(
      text: _formatHp(gameRef.bossMaxHp),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFF5544),
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
      position: Vector2(w / 2, mode.timeLimitSeconds > 0 ? 52 : 18),
      anchor: Anchor.topCenter,
    );
    add(_hpText);

    _orbLabel = TextComponent(
      text: '',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0x88FFFFFF),
          fontSize: 11,
          letterSpacing: 2,
        ),
      ),
      position: Vector2(w / 2, mode.timeLimitSeconds > 0 ? 80 : 46),
      anchor: Anchor.topCenter,
    );
    add(_orbLabel);

    // DPS display for endless-style modes
    if (mode.scoreMode == ScoreMode.damagePerSecond) {
      _dpsText = TextComponent(
        text: '0 DPS',
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xAAFF44CC),
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        position: Vector2(w / 2, mode.timeLimitSeconds > 0 ? 96 : 62),
        anchor: Anchor.topCenter,
      );
      add(_dpsText!);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Timer (only present in timed modes)
    if (_timerText != null) {
      final t = gameRef.timeLeft;
      _timerText!.text = t.ceil().toString();
      if (t <= 10) {
        _timerText!.textRenderer = _timerDangerStyle;
      } else if (t <= 20) {
        _timerText!.textRenderer = _timerWarnStyle;
      } else {
        _timerText!.textRenderer = _timerStyle;
      }
    }

    _hpText.text = _formatHp(gameRef.bossHp);
    _orbLabel.text = '${gameRef.orbBehavior.name} ORB  ·  ${gameRef.mode.name}';

    // Live DPS
    if (_dpsText != null) {
      final elapsed = max(1.0, gameRef.totalTime);
      final dps = (gameRef.totalDamage / elapsed).round();
      _dpsText!.text = '${_formatHp(dps)} DPS';
    }
  }

  @override
  void render(Canvas canvas) {
    final hudHeight = _dpsText != null ? 112.0 : 96.0;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, gameRef.size.x, hudHeight),
      Paint()..color = const Color(0xCC050510),
    );
    super.render(canvas);
    _renderPickupEffects(canvas);
  }

  void _renderPickupEffects(Canvas canvas) {
    final indicators = <_EffectIndicator>[];

    if (gameRef.shieldTimer > 0) {
      indicators.add(_EffectIndicator(
        emoji: '🛡️',
        label: 'SHIELD',
        color: const Color(0xFF44AAFF),
        progress: gameRef.shieldTimer / 8.0,
      ));
    }
    if (gameRef.speedTimer > 0) {
      indicators.add(_EffectIndicator(
        emoji: '💨',
        label: 'SPEED',
        color: const Color(0xFF00FFEE),
        progress: gameRef.speedTimer / 6.0,
      ));
    }
    if (gameRef.starHitsRemaining > 0) {
      indicators.add(_EffectIndicator(
        emoji: '⭐',
        label: '×3  (${gameRef.starHitsRemaining} left)',
        color: const Color(0xFFFFCC00),
        progress: gameRef.starHitsRemaining / 3.0,
      ));
    }

    if (indicators.isEmpty) return;

    const pillW  = 110.0;
    const pillH  = 32.0;
    const gap    = 8.0;
    const bottomPad = 14.0;

    final totalW = indicators.length * pillW + (indicators.length - 1) * gap;
    double x = (gameRef.size.x - totalW) / 2;
    final y = gameRef.size.y - pillH - bottomPad;

    for (final ind in indicators) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, pillW, pillH),
        const Radius.circular(16),
      );

      // Background pill
      canvas.drawRRect(rect, Paint()..color = const Color(0xCC0A0A20));
      canvas.drawRRect(
        rect,
        Paint()
          ..color = ind.color.withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // Progress bar fill
      final barRect = Rect.fromLTWH(x, y + pillH - 4, pillW * ind.progress.clamp(0.0, 1.0), 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, const Radius.circular(2)),
        Paint()..color = ind.color.withOpacity(0.8),
      );

      // Emoji + label text
      final tp = TextPainter(
        text: TextSpan(
          text: '${ind.emoji} ${ind.label}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white.withOpacity(0.92),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: pillW - 8);

      tp.paint(canvas, Offset(x + (pillW - tp.width) / 2, y + (pillH - 4 - tp.height) / 2));

      x += pillW + gap;
    }
  }

  static String _formatHp(int hp) {
    if (hp >= 1000000) return '${(hp / 1000000).toStringAsFixed(2)}M';
    if (hp >= 1000) return '${(hp / 1000).toStringAsFixed(1)}K';
    return '$hp';
  }
}

class _EffectIndicator {
  final String emoji;
  final String label;
  final Color  color;
  final double progress; // 0.0 – 1.0 for progress bar

  const _EffectIndicator({
    required this.emoji,
    required this.label,
    required this.color,
    required this.progress,
  });
}

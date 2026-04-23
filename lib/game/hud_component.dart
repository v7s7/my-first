import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';
import 'boss_ball_game.dart';
import '../modes/game_mode.dart';

class HudComponent extends PositionComponent {
  final BossBallGame gameRef;

  TextComponent? _timerText;
  TextComponent? _hpText;
  TextComponent? _orbLabel;
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

    if (mode.isPvp) {
      // PVP: show mode label only, HP bars drawn in render()
      _orbLabel = TextComponent(
        text: 'PVP DUEL  ·  ${gameRef.orbBehavior.name} ORB',
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0x88FFFFFF),
            fontSize: 11,
            letterSpacing: 2,
          ),
        ),
        position: Vector2(w / 2, 18),
        anchor: Anchor.topCenter,
      );
      add(_orbLabel!);
      return;
    }

    // Non-PVP layout
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
    add(_hpText!);

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
    add(_orbLabel!);

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
    final mode = gameRef.mode;

    if (mode.isPvp) return; // PVP uses render() only

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

    _hpText?.text = _formatHp(gameRef.bossHp);
    final regenSuffix = mode.bossRegenPerSecond > 0
        ? '  +${_formatHp(mode.bossRegenPerSecond)}/s'
        : '';
    _orbLabel?.text =
        '${gameRef.orbBehavior.name} ORB  ·  ${mode.name}$regenSuffix';

    if (_dpsText != null) {
      final elapsed = max(1.0, gameRef.totalTime);
      final dps = (gameRef.totalDamage / elapsed).round();
      _dpsText!.text = '${_formatHp(dps)} DPS';
    }
  }

  @override
  void render(Canvas canvas) {
    final mode = gameRef.mode;

    if (mode.isPvp) {
      _renderPvpHud(canvas);
    } else {
      final hudHeight = _dpsText != null ? 112.0 : 96.0;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, gameRef.size.x, hudHeight),
        Paint()..color = const Color(0xCC050510),
      );
      super.render(canvas);
      _renderPickupEffects(canvas);
    }
  }

  void _renderPvpHud(Canvas canvas) {
    final w = gameRef.size.x;
    const hudH = 80.0;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, hudH),
      Paint()..color = const Color(0xCC050510),
    );

    super.render(canvas);

    const barH = 18.0;
    const barY = 40.0;
    const sidePad = 16.0;
    const barW = 0.42; // fraction of screen width each bar takes
    final barPx = w * barW;

    final orb1Color = const Color(0xFF00FFEE);
    final orb2Color = const Color(0xFFFF4488);

    // Orb 1 bar (left side)
    final hp1 = gameRef.pvpOrbHp(0);
    final max1 = gameRef.pvpOrbMaxHp;
    final ratio1 = max1 > 0 ? (hp1 / max1).clamp(0.0, 1.0) : 0.0;
    _drawHpBar(canvas,
      x: sidePad,
      y: barY,
      w: barPx,
      h: barH,
      ratio: ratio1,
      color: orb1Color,
      label: 'BALL 1',
      hp: hp1,
      alignRight: false,
    );

    // Orb 2 bar (right side, mirrored)
    final hp2 = gameRef.pvpOrbHp(1);
    final max2 = gameRef.pvpOrbMaxHp;
    final ratio2 = max2 > 0 ? (hp2 / max2).clamp(0.0, 1.0) : 0.0;
    _drawHpBar(canvas,
      x: w - sidePad - barPx,
      y: barY,
      w: barPx,
      h: barH,
      ratio: ratio2,
      color: orb2Color,
      label: 'BALL 2',
      hp: hp2,
      alignRight: true,
    );

    // VS text in center
    final tp = TextPainter(
      text: const TextSpan(
        text: 'VS',
        style: TextStyle(
          color: Color(0xFFFF3355),
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, barY + (barH - tp.height) / 2));

    _renderPickupEffects(canvas);
  }

  void _drawHpBar(Canvas canvas, {
    required double x,
    required double y,
    required double w,
    required double h,
    required double ratio,
    required Color color,
    required String label,
    required int hp,
    required bool alignRight,
  }) {
    // Background
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(4)),
      Paint()..color = const Color(0x33FFFFFF),
    );

    // Fill — mirrored for right side
    final fillW = w * ratio;
    final fillX = alignRight ? x + w - fillW : x;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(fillX, y, fillW, h),
        const Radius.circular(4),
      ),
      Paint()..color = color.withOpacity(0.85),
    );

    // Border
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(4)),
      Paint()
        ..color = color.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Label
    final labelTp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final labelX = alignRight ? x + w - labelTp.width : x;
    labelTp.paint(canvas, Offset(labelX, y - labelTp.height - 2));

    // HP value
    final hpStr = _formatHp(hp);
    final hpTp = TextPainter(
      text: TextSpan(
        text: hpStr,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final hpX = alignRight ? x : x + w - hpTp.width;
    hpTp.paint(canvas, Offset(hpX, y - hpTp.height - 2));
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
    if (gameRef.rapidTimer > 0) {
      indicators.add(_EffectIndicator(
        emoji: '🔥',
        label: 'RAPID',
        color: const Color(0xFFFF6600),
        progress: gameRef.rapidTimer / 6.0,
      ));
    }
    if (gameRef.magnetTimer > 0) {
      indicators.add(_EffectIndicator(
        emoji: '🧲',
        label: 'MAGNET',
        color: const Color(0xFFFF44CC),
        progress: gameRef.magnetTimer / 8.0,
      ));
    }
    if (gameRef.starHitsRemaining > 0) {
      indicators.add(_EffectIndicator(
        emoji: '⭐',
        label: '×2.5 (${gameRef.starHitsRemaining})',
        color: const Color(0xFFFFCC00),
        progress: gameRef.starHitsRemaining / 3.0,
      ));
    }
    if (gameRef.barrierHitsRemaining > 0) {
      indicators.add(_EffectIndicator(
        emoji: '💎',
        label: '×3  (${gameRef.barrierHitsRemaining})',
        color: const Color(0xFF44FFEE),
        progress: gameRef.barrierHitsRemaining / 4.0,
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

      canvas.drawRRect(rect, Paint()..color = const Color(0xCC0A0A20));
      canvas.drawRRect(
        rect,
        Paint()
          ..color = ind.color.withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      final barRect = Rect.fromLTWH(x, y + pillH - 4, pillW * ind.progress.clamp(0.0, 1.0), 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, const Radius.circular(2)),
        Paint()..color = ind.color.withOpacity(0.8),
      );

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
  final double progress;

  const _EffectIndicator({
    required this.emoji,
    required this.label,
    required this.color,
    required this.progress,
  });
}

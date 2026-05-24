import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';
import 'boss_ball_game.dart';
import '../modes/game_mode.dart';

class HudComponent extends PositionComponent {
  final BossBallGame gameRef;

  TextComponent? _timerText;
  TextComponent? _orbLabel;
  TextComponent? _dpsText;

  static final TextPaint _timerStyle = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 24,
      fontWeight: FontWeight.w900,
      letterSpacing: 2,
    ),
  );
  static final TextPaint _timerWarnStyle = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFFDD00),
      fontSize: 24,
      fontWeight: FontWeight.w900,
    ),
  );
  static final TextPaint _timerDangerStyle = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFF3333),
      fontSize: 24,
      fontWeight: FontWeight.w900,
    ),
  );

  HudComponent({required this.gameRef})
      : super(priority: 100, position: Vector2.zero());

  bool get _hasTimer => gameRef.mode.timeLimitSeconds > 0;
  bool get _hasDps   => gameRef.mode.scoreMode == ScoreMode.damagePerSecond;

  // Y positions for the boss HP bar
  double get _barY => _hasTimer ? 38.0 : 14.0;

  @override
  Future<void> onLoad() async {
    final w = gameRef.size.x;
    final mode = gameRef.mode;

    if (mode.isPvp) {
      add(TextComponent(
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
      ));
      return;
    }

    // Timer
    if (_hasTimer) {
      _timerText = TextComponent(
        text: mode.timeLimitSeconds.ceil().toString(),
        textRenderer: _timerStyle,
        position: Vector2(w / 2, 12),
        anchor: Anchor.topCenter,
      );
      add(_timerText!);
    }

    // Orb + mode label (below HP bar)
    final labelY = _barY + 18.0;
    _orbLabel = TextComponent(
      text: '',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0x88FFFFFF),
          fontSize: 11,
          letterSpacing: 2,
        ),
      ),
      position: Vector2(w / 2, labelY),
      anchor: Anchor.topCenter,
    );
    add(_orbLabel!);

    // DPS (endless mode)
    if (_hasDps) {
      _dpsText = TextComponent(
        text: '0 DPS',
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xAAFF44CC),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        position: Vector2(w / 2, labelY + 16),
        anchor: Anchor.topCenter,
      );
      add(_dpsText!);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final mode = gameRef.mode;
    if (mode.isPvp) return;

    if (_timerText != null) {
      final t = gameRef.timeLeft;
      _timerText!.text = t.ceil().toString();
      _timerText!.textRenderer =
          t <= 10 ? _timerDangerStyle : (t <= 20 ? _timerWarnStyle : _timerStyle);
    }

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
      _renderBossHud(canvas);
    }
  }

  // ── Boss fight HUD ─────────────────────────────────────────────────────────

  void _renderBossHud(Canvas canvas) {
    final hudH = _barY + 16 + 18 + (_hasDps ? 18 : 0) + 8.0;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, gameRef.size.x, hudH),
      Paint()..color = const Color(0xCC050510),
    );

    super.render(canvas); // TextComponents

    _renderBossHpBar(canvas);
    _renderCombo(canvas);
    _renderPickupEffects(canvas);
    _renderRageMeter(canvas);
  }

  void _renderBossHpBar(Canvas canvas) {
    if (gameRef.boss == null) return;
    final w = gameRef.size.x;
    final hpRatio =
        (gameRef.bossHp / gameRef.bossMaxHp).clamp(0.0, 1.0);
    final phase = gameRef.bossPhase;

    const barH = 14.0;
    const sidePad = 12.0;
    final barY = _barY;
    final barW = w - sidePad * 2;

    // Background track
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(sidePad, barY, barW, barH),
          const Radius.circular(7)),
      Paint()..color = const Color(0x33FFFFFF),
    );

    // Filled portion — color by phase
    if (hpRatio > 0) {
      final fillColor = phase >= 3
          ? const Color(0xFFFF2244)
          : phase == 2
              ? const Color(0xFFFF4488)
              : const Color(0xFF6A5AFF);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(sidePad, barY, barW * hpRatio, barH),
            const Radius.circular(7)),
        Paint()..color = fillColor.withOpacity(0.88),
      );
      // Shine strip
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(sidePad, barY, barW * hpRatio, barH * 0.4),
            const Radius.circular(4)),
        Paint()..color = Colors.white.withOpacity(0.14),
      );
    }

    // Phase threshold markers at 60% and 30%
    for (final t in [0.6, 0.3]) {
      final mx = sidePad + barW * t;
      canvas.drawLine(
        Offset(mx, barY - 1),
        Offset(mx, barY + barH + 1),
        Paint()
          ..color = Colors.white.withOpacity(0.55)
          ..strokeWidth = 1.5,
      );
    }

    // Border
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(sidePad, barY, barW, barH),
          const Radius.circular(7)),
      Paint()
        ..color = Colors.white.withOpacity(0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // HP text on bar (left side)
    final hpStr =
        '${_formatHp(gameRef.bossHp)} / ${_formatHp(gameRef.bossMaxHp)}';
    final hpTp = TextPainter(
      text: TextSpan(
        text: hpStr,
        style: TextStyle(
          color: Colors.white.withOpacity(0.88),
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    hpTp.paint(
        canvas, Offset(sidePad + 5, barY + (barH - hpTp.height) / 2));

    // Phase badge (right side of bar)
    if (phase > 1) {
      final phaseColor =
          phase == 3 ? const Color(0xFFFF2244) : const Color(0xFFFF88CC);
      final phaseTp = TextPainter(
        text: TextSpan(
          text: 'PHASE $phase',
          style: TextStyle(
            color: phaseColor,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      phaseTp.paint(canvas,
          Offset(sidePad + barW - phaseTp.width - 4,
              barY + (barH - phaseTp.height) / 2));
    }
  }

  void _renderCombo(Canvas canvas) {
    final combo = gameRef.comboCount;
    if (combo < 3) return;

    final comboColor = combo >= 20
        ? const Color(0xFFFF0066)
        : combo >= 10
            ? const Color(0xFFFF8800)
            : combo >= 5
                ? const Color(0xFFFFCC00)
                : const Color(0xFFFFFFFF);

    final fontSize = (16.0 + min((combo - 3) * 0.5, 10.0));
    final tp = TextPainter(
      text: TextSpan(
        text: 'x$combo COMBO!',
        style: TextStyle(
          color: comboColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
          shadows: [
            Shadow(color: comboColor.withOpacity(0.7), blurRadius: 18),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, Offset(gameRef.size.x - tp.width - 12, 12));
  }

  // ── PVP HUD ───────────────────────────────────────────────────────────────

  void _renderPvpHud(Canvas canvas) {
    final w = gameRef.size.x;
    const hudH = 82.0;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, hudH),
      Paint()..color = const Color(0xCC050510),
    );

    super.render(canvas);

    const barH   = 18.0;
    const barY   = 40.0;
    const sidePad = 14.0;
    const barW   = 0.42;
    final barPx  = w * barW;

    final colors = gameRef.pvpOrbColors;
    final orb1Color = colors.isNotEmpty ? colors[0] : const Color(0xFF00FFEE);
    final orb2Color = colors.length > 1  ? colors[1] : const Color(0xFFFF4488);

    final hp1    = gameRef.pvpOrbHp(0);
    final max1   = gameRef.pvpOrbMaxHp;
    final ratio1 = max1 > 0 ? (hp1 / max1).clamp(0.0, 1.0) : 0.0;
    _drawHpBar(canvas,
      x: sidePad, y: barY, w: barPx, h: barH,
      ratio: ratio1, color: orb1Color,
      label: 'BALL 1', hp: hp1, alignRight: false,
      shielded: gameRef.isOrbShielded(0),
      ghosted:  gameRef.isOrbGhosted(0));

    final hp2    = gameRef.pvpOrbHp(1);
    final max2   = gameRef.pvpOrbMaxHp;
    final ratio2 = max2 > 0 ? (hp2 / max2).clamp(0.0, 1.0) : 0.0;
    _drawHpBar(canvas,
      x: w - sidePad - barPx, y: barY, w: barPx, h: barH,
      ratio: ratio2, color: orb2Color,
      label: 'BALL 2', hp: hp2, alignRight: true,
      shielded: gameRef.isOrbShielded(1),
      ghosted:  gameRef.isOrbGhosted(1));

    // VS label
    final vsTp = TextPainter(
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
    vsTp.paint(canvas,
        Offset((w - vsTp.width) / 2, barY + (barH - vsTp.height) / 2));

    _renderPickupEffects(canvas);
  }

  void _drawHpBar(Canvas canvas, {
    required double x, required double y,
    required double w, required double h,
    required double ratio, required Color color,
    required String label, required int hp, required bool alignRight,
    bool shielded = false,
    bool ghosted  = false,
  }) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h), const Radius.circular(4)),
      Paint()..color = const Color(0x33FFFFFF),
    );

    final fillW = w * ratio;
    final fillX = alignRight ? x + w - fillW : x;
    if (fillW > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(fillX, y, fillW, h), const Radius.circular(4)),
        Paint()..color = color.withOpacity(0.85),
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h), const Radius.circular(4)),
      Paint()
        ..color = color.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

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

    final hpTp = TextPainter(
      text: TextSpan(
        text: _formatHp(hp),
        style: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final hpX = alignRight ? x : x + w - hpTp.width;
    hpTp.paint(canvas, Offset(hpX, y - hpTp.height - 2));

    // Status badges (shield / ghost)
    if (shielded || ghosted) {
      final badge = shielded ? '🛡️' : '👻';
      final badgePaint = Paint()
        ..color = (shielded ? const Color(0xFF44AAFF) : const Color(0xFF88FFFF))
            .withOpacity(0.9);
      final badgeR = h * 0.62;
      final badgeCx = alignRight ? x + w + badgeR + 4 : x - badgeR - 4;
      final badgeCy = y + h / 2;
      canvas.drawCircle(Offset(badgeCx, badgeCy), badgeR, badgePaint);
      final bTp = TextPainter(
        text: TextSpan(
          text: badge,
          style: TextStyle(fontSize: badgeR * 1.4),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      bTp.paint(canvas,
          Offset(badgeCx - bTp.width / 2, badgeCy - bTp.height / 2));
    }
  }

  // ── Active pickup pills ───────────────────────────────────────────────────

  void _renderPickupEffects(Canvas canvas) {
    final indicators = <_EffectIndicator>[];

    if (gameRef.shieldTimer > 0) {
      indicators.add(_EffectIndicator(
          emoji: '🛡️', label: 'SHIELD',
          color: const Color(0xFF44AAFF), progress: gameRef.shieldTimer / 8.0));
    }
    if (gameRef.speedTimer > 0) {
      indicators.add(_EffectIndicator(
          emoji: '💨', label: 'SPEED',
          color: const Color(0xFF00FFEE), progress: gameRef.speedTimer / 6.0));
    }
    if (gameRef.rapidTimer > 0) {
      indicators.add(_EffectIndicator(
          emoji: '🔥', label: 'RAPID',
          color: const Color(0xFFFF6600), progress: gameRef.rapidTimer / 6.0));
    }
    if (gameRef.magnetTimer > 0) {
      indicators.add(_EffectIndicator(
          emoji: '🧲', label: 'MAGNET',
          color: const Color(0xFFFF44CC), progress: gameRef.magnetTimer / 8.0));
    }
    if (gameRef.starHitsRemaining > 0) {
      indicators.add(_EffectIndicator(
          emoji: '⭐', label: '×2.5 (${gameRef.starHitsRemaining})',
          color: const Color(0xFFFFCC00),
          progress: gameRef.starHitsRemaining / 3.0));
    }
    if (gameRef.barrierHitsRemaining > 0) {
      indicators.add(_EffectIndicator(
          emoji: '💎', label: '×3  (${gameRef.barrierHitsRemaining})',
          color: const Color(0xFF44FFEE),
          progress: gameRef.barrierHitsRemaining / 4.0));
    }
    if (gameRef.tripleHitsRemaining > 0) {
      indicators.add(_EffectIndicator(
          emoji: '🎯', label: '×3  (${gameRef.tripleHitsRemaining})',
          color: const Color(0xFFFF44FF),
          progress: gameRef.tripleHitsRemaining / 5.0));
    }
    if (gameRef.overdriveHitsRemaining > 0) {
      indicators.add(_EffectIndicator(
          emoji: '🚀', label: '×5  (${gameRef.overdriveHitsRemaining})',
          color: const Color(0xFFFF8800),
          progress: gameRef.overdriveHitsRemaining / 3.0));
    }
    if (gameRef.timeWarpTimer > 0) {
      indicators.add(_EffectIndicator(
          emoji: '🕰️', label: 'TIME WARP',
          color: const Color(0xFF4488FF),
          progress: gameRef.timeWarpTimer / 3.0));
    }

    if (indicators.isEmpty) return;

    const pillW     = 96.0;
    const pillH     = 30.0;
    const gap       = 6.0;
    const bottomPad = 14.0;
    const maxPerRow = 4;

    final rowCount  = indicators.length > maxPerRow ? 2 : 1;
    final show      = indicators.length.clamp(0, maxPerRow * 2);

    for (int idx = 0; idx < show; idx++) {
      final row  = idx ~/ maxPerRow;
      final col  = idx % maxPerRow;

      final countInRow = (idx < maxPerRow
          ? show.clamp(0, maxPerRow)
          : show - maxPerRow).clamp(1, maxPerRow);
      final rowW  = countInRow * pillW + (countInRow - 1) * gap;
      final startX = (gameRef.size.x - rowW) / 2;

      final x = startX + col * (pillW + gap);
      final y = gameRef.size.y - bottomPad
          - (rowCount - row) * pillH
          - (rowCount - row - 1) * gap;

      final ind  = indicators[idx];
      final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, pillW, pillH), const Radius.circular(14));

      canvas.drawRRect(rect, Paint()..color = const Color(0xCC0A0A20));
      canvas.drawRRect(rect,
          Paint()
            ..color = ind.color.withOpacity(0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);

      final barFill = ind.progress.clamp(0.0, 1.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y + pillH - 4, pillW * barFill, 4),
            const Radius.circular(2)),
        Paint()..color = ind.color.withOpacity(0.8),
      );

      final tp = TextPainter(
        text: TextSpan(
          text: '${ind.emoji} ${ind.label}',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.92)),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: pillW - 8);
      tp.paint(canvas,
          Offset(x + (pillW - tp.width) / 2, y + (pillH - 4 - tp.height) / 2));
    }
  }

  void _renderRageMeter(Canvas canvas) {
    if (gameRef.mode.isPvp) return;
    final rage     = gameRef.rageEnergy;
    final isActive = gameRef.isRageActive;
    if (rage < 0.02 && !isActive) return;

    const meterW   = 88.0;
    const meterH   = 6.0;
    const rightPad = 14.0;
    const bottomPad = 56.0;
    final x = gameRef.size.x - meterW - rightPad;
    final y = gameRef.size.y - bottomPad;

    final rageColor = isActive
        ? const Color(0xFFFF2200)
        : (rage >= 1.0 ? const Color(0xFFFFD700) : const Color(0xFFFF6600));

    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, meterW, meterH), const Radius.circular(3)),
      Paint()..color = const Color(0x44FFFFFF),
    );

    final fillFrac = isActive
        ? (gameRef.rageTimer / 4.0).clamp(0.0, 1.0)
        : rage.clamp(0.0, 1.0);
    if (fillFrac > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, meterW * fillFrac, meterH),
            const Radius.circular(3)),
        Paint()..color = rageColor.withOpacity(isActive ? 0.9 : 0.8),
      );
    }

    final rageLabel = isActive
        ? '🔥 FURY  ${gameRef.rageTimer.ceil()}s'
        : (rage >= 1.0 ? '🔥 TAP! FURY READY' : '🔥 ${(rage * 100).round()}%');
    final tp = TextPainter(
      text: TextSpan(
        text: rageLabel,
        style: TextStyle(
          color: rageColor,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x + meterW - tp.width, y + meterH + 3));
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  static String _formatHp(num hp) {
    if (hp >= 1000000) return '${(hp / 1000000).toStringAsFixed(2)}M';
    if (hp >= 1000) return '${(hp / 1000).toStringAsFixed(1)}K';
    return '${hp.round()}';
  }
}

class _EffectIndicator {
  final String emoji;
  final String label;
  final Color  color;
  final double progress;
  const _EffectIndicator(
      {required this.emoji,
      required this.label,
      required this.color,
      required this.progress});
}

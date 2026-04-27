import 'dart:math';
import 'package:flutter/material.dart';
import 'orb_behavior.dart';
import '../game/player_orb.dart';

/// Hits on PRIME-numbered strikes deal 4× damage.
///
/// The global hit counter increments each boss hit.
/// Prime hits (2, 3, 5, 7, 11, 13, 17, 19, 23 …) deal 20 000 instead of 5 000.
///
/// The strategy: keep hitting until you reach a prime-number hit for a burst.
/// Primes become sparser at higher counts (less frequent big hits),
/// rewarding sustained play.
///
/// Visual: rings of geometric dots rotate and flash on prime hits.
class PrimeOrb extends OrbBehavior {
  @override String get id   => 'prime';
  @override String get name => 'PRIME';
  @override String get description => '5K · 20K on\nprime-# hits';
  @override Color  get color => const Color(0xFF44FFCC);

  static const int _baseDamage  = 5000;
  static const int _primeDamage = 20000;

  int    _hitCount   = 0;
  double _time       = 0;
  bool   _isPrime    = false;
  bool   _flash      = false;
  double _flashTimer = 0;
  static const double _flashDur = 0.4;

  // Ball slowly grows per hit, max 10 px; pulses larger on prime hits
  @override
  double get visualGrowth =>
      (_hitCount * 0.5).clamp(0.0, 10.0) + (_flash && _isPrime ? 3.0 : 0.0);

  static bool _checkPrime(int n) {
    if (n < 2) return false;
    if (n == 2) return true;
    if (n % 2 == 0) return false;
    for (int i = 3; i * i <= n; i += 2) {
      if (n % i == 0) return false;
    }
    return true;
  }

  @override
  void onAttach(PlayerOrb orb) {
    _hitCount = 0;
    _time     = 0;
    _isPrime  = false;
    _flash    = false;
  }

  @override
  void onUpdate(double dt, PlayerOrb orb) {
    _time += dt;
    if (_flash) {
      _flashTimer -= dt;
      if (_flashTimer <= 0) _flash = false;
    }
  }

  @override
  void onBossHit(PlayerOrb orb) {
    _hitCount++;
    _isPrime = _checkPrime(_hitCount);
    if (_isPrime) {
      orb.gameRef.onOrbHitBoss(_primeDamage);
      _flash      = true;
      _flashTimer = _flashDur;
    } else {
      orb.gameRef.onOrbHitBoss(_baseDamage);
    }
  }

  // ── Rendering ───────────────────────────────────────────────────────────────

  @override
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {
    final t = _time;

    // Rotating dot ring — 7 dots; on prime hit all glow fully
    const dotCount = 7;
    for (int i = 0; i < dotCount; i++) {
      final a    = i * (2 * pi / dotCount) + t * 1.2;
      final dR   = radius + 11;
      final px   = cx + cos(a) * dR;
      final py   = cy + sin(a) * dR;
      final glow = _isPrime || _flash;
      canvas.drawCircle(
        Offset(px, py),
        glow ? 4.5 : 3.0,
        Paint()
          ..color = const Color(0xFF44FFCC)
              .withOpacity(glow ? 0.95 : 0.35)
          ..maskFilter = glow
              ? const MaskFilter.blur(BlurStyle.normal, 6)
              : null,
      );
    }

    // Counter-rotating inner ring (6 dots)
    for (int i = 0; i < 6; i++) {
      final a  = i * (pi / 3) - t * 0.8;
      final dR = radius + 5;
      canvas.drawCircle(
        Offset(cx + cos(a) * dR, cy + sin(a) * dR),
        2.0,
        Paint()..color = const Color(0xFF44FFCC).withOpacity(0.25),
      );
    }

    // Damage value on ball center (show next hit's damage)
    final nextIsPrime = _checkPrime(_hitCount + 1);
    final nextDmg = nextIsPrime ? _primeDamage : _baseDamage;
    final dmgStr = nextIsPrime ? '20K★' : '5K';
    final dmgTp = TextPainter(
      text: TextSpan(
        text: dmgStr,
        style: TextStyle(
          color: Colors.white.withOpacity(0.95),
          fontSize: nextIsPrime ? 13.0 : 11.0,
          fontWeight: FontWeight.w900,
          height: 1.0,
          shadows: [
            const Shadow(color: Color(0xCC000000), offset: Offset(1, 1), blurRadius: 2),
            Shadow(
              color: nextIsPrime
                  ? const Color(0xFF44FFCC)
                  : const Color(0xFF44FFCC).withOpacity(0.5),
              blurRadius: 8,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    dmgTp.paint(canvas, Offset(cx - dmgTp.width / 2, cy - dmgTp.height / 2));
    // Hit counter badge (small, above damage label)
    final cntTp = TextPainter(
      text: TextSpan(
        text: '#$_hitCount',
        style: TextStyle(
          color: const Color(0xFF44FFCC).withOpacity(0.6),
          fontSize: 7,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    cntTp.paint(canvas, Offset(cx - cntTp.width / 2, cy - dmgTp.height / 2 - cntTp.height - 1));

    // Prime burst
    if (_flash) {
      final p = 1.0 - (_flashTimer / _flashDur);
      // Starburst rays
      for (int i = 0; i < 6; i++) {
        final a   = i * (pi / 3) + p * 0.5;
        final rLen = radius + p * radius * 4;
        canvas.drawLine(
          Offset(cx, cy),
          Offset(cx + cos(a) * rLen, cy + sin(a) * rLen),
          Paint()
            ..color = const Color(0xFF44FFCC).withOpacity((1.0 - p) * 0.8)
            ..strokeWidth = (3.0 * (1.0 - p)).clamp(0.3, 3.0)
            ..strokeCap = StrokeCap.round
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * (1.0 - p)),
        );
      }
      canvas.drawCircle(
        Offset(cx, cy),
        radius + p * radius * 3.5,
        Paint()
          ..color = const Color(0xFF44FFCC).withOpacity((1.0 - p) * 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0 * (1.0 - p)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * (1.0 - p)),
      );
    }
  }
}

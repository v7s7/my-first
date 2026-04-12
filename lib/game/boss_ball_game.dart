import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../orbs/orb_behavior.dart';
import '../modes/game_mode.dart';
import 'arena_wall.dart';
import 'boss_component.dart';
import 'player_orb.dart';
import 'hud_component.dart';

class BossBallGame extends FlameGame {
  final OrbBehavior orbBehavior;
  final GameMode mode;

  static const double wallThickness = 14.0;

  late int bossMaxHp;
  late int bossHp;
  late double timeLeft;

  bool playing = false;
  bool bossDestroyed = false;

  /// Cumulative damage this round — used for score-based modes.
  int totalDamage = 0;

  /// Elapsed game time — used for DPS calculation.
  double totalTime = 0.0;

  late BossComponent boss;
  late PlayerOrb orb;

  double _shakeIntensity = 0.0;
  double _shakeTimer = 0.0;
  final Random _rng = Random();

  BossBallGame({required this.orbBehavior, required this.mode});

  @override
  Color backgroundColor() => const Color(0xFF080812);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    bossMaxHp = mode.bossMaxHp;
    bossHp = bossMaxHp;
    timeLeft = mode.timeLimitSeconds;
    totalDamage = 0;
    totalTime = 0.0;

    _buildArena();
    _buildBoss();
    _buildOrb();
    add(HudComponent(gameRef: this));
    playing = true;
  }

  void _buildArena() {
    final w = size.x;
    final h = size.y;
    const t = wallThickness;
    addAll([
      ArenaWall(position: Vector2(0, 0), size: Vector2(w, t)),
      ArenaWall(position: Vector2(0, h - t), size: Vector2(w, t)),
      ArenaWall(position: Vector2(0, t), size: Vector2(t, h - t * 2)),
      ArenaWall(position: Vector2(w - t, t), size: Vector2(t, h - t * 2)),
    ]);
  }

  void _buildBoss() {
    boss = BossComponent(position: size / 2);
    add(boss);
  }

  void _buildOrb() {
    orb = PlayerOrb(behavior: orbBehavior, gameRef: this);
    add(orb);
  }

  /// Called by OrbBehavior subclasses when they deal damage.
  /// [isLaserTick] dampens screen shake for rapid tick-based damage.
  void onOrbHitBoss(int damage, {bool isLaserTick = false}) {
    bossHp = (bossHp - damage).clamp(0, bossMaxHp);
    totalDamage += damage;

    if (!isLaserTick) {
      final normalizedPower = damage / bossMaxHp;
      triggerShake(
        intensity: (normalizedPower * 300).clamp(4.0, 28.0),
        duration: 0.18,
      );
    } else {
      triggerShake(intensity: 1.8, duration: 0.04);
    }

    if (mode.winOnBossKill && bossHp <= 0 && !bossDestroyed) {
      bossDestroyed = true;
      playing = false;
      Future.delayed(Duration.zero, () => overlays.add('GameOver'));
    }
  }

  void triggerShake({required double intensity, double duration = 0.18}) {
    if (intensity > _shakeIntensity) {
      _shakeIntensity = intensity;
      _shakeTimer = duration;
    }
  }

  @override
  void update(double dt) {
    if (_shakeTimer > 0) _shakeTimer -= dt;
    if (!playing) {
      super.update(dt);
      return;
    }

    totalTime += dt;

    if (mode.timeLimitSeconds > 0) {
      timeLeft -= dt;
      if (timeLeft <= 0) {
        timeLeft = 0;
        playing = false;
        Future.delayed(Duration.zero, () => overlays.add('GameOver'));
      }
    }

    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    if (_shakeTimer > 0) {
      final dx = (_rng.nextDouble() - 0.5) * 2.0 * _shakeIntensity;
      final dy = (_rng.nextDouble() - 0.5) * 2.0 * _shakeIntensity;
      canvas.save();
      canvas.translate(dx, dy);
      super.render(canvas);
      canvas.restore();
    } else {
      super.render(canvas);
    }
  }
}

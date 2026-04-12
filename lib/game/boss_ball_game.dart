import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'game_state.dart';
import 'arena_wall.dart';
import 'boss_component.dart';
import 'player_orb.dart';
import 'hud_component.dart';

class BossBallGame extends FlameGame {
  final OrbType orbType;

  static const int bossMaxHp = 1000000;
  static const double wallThickness = 14.0;

  int bossHp = bossMaxHp;
  double timeLeft = 60.0;
  bool playing = false;
  bool bossDestroyed = false;

  late BossComponent boss;
  late PlayerOrb orb;

  // Screen shake state
  double _shakeIntensity = 0.0;
  double _shakeTimer = 0.0;
  final Random _rng = Random();

  BossBallGame({required this.orbType});

  @override
  Color backgroundColor() => const Color(0xFF080812);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
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
    orb = PlayerOrb(orbType: orbType, gameRef: this);
    add(orb);
  }

  // Called by PlayerOrb when it deals damage.
  // [isLaserTick] suppresses heavy screen shake for rapid laser ticks.
  void onOrbHitBoss(int damage, {bool isLaserTick = false}) {
    bossHp = (bossHp - damage).clamp(0, bossMaxHp);

    if (!isLaserTick) {
      final normalizedPower = damage / bossMaxHp;
      triggerShake(
        intensity: (normalizedPower * 300).clamp(4.0, 28.0),
        duration: 0.18,
      );
    } else {
      triggerShake(intensity: 1.8, duration: 0.04);
    }

    if (bossHp <= 0 && !bossDestroyed) {
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
    timeLeft -= dt;
    if (timeLeft <= 0) {
      timeLeft = 0;
      playing = false;
      Future.delayed(Duration.zero, () => overlays.add('GameOver'));
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

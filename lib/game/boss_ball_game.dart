import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../orbs/orb_behavior.dart';
import '../modes/game_mode.dart';
import 'arena_config.dart';
import 'arena_wall.dart';
import 'boss_component.dart';
import 'player_orb.dart';
import 'hud_component.dart';

class BossBallGame extends FlameGame {
  final OrbBehavior orbBehavior;
  final GameMode mode;
  final ArenaPreset arenaPreset;

  late ArenaConfig arenaConfig;

  late int bossMaxHp;
  late int bossHp;
  late double timeLeft;

  bool playing = false;
  bool bossDestroyed = false;

  int totalDamage = 0;
  double totalTime = 0.0;

  late BossComponent boss;
  late PlayerOrb orb;

  double _shakeIntensity = 0.0;
  double _shakeTimer = 0.0;
  final Random _rng = Random();

  BossBallGame({
    required this.orbBehavior,
    required this.mode,
    this.arenaPreset = ArenaPreset.normal,
  });

  @override
  Color backgroundColor() => const Color(0xFF040408);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    arenaConfig = ArenaConfig.fromScreen(size, arenaPreset);

    bossMaxHp = mode.bossMaxHp;
    bossHp = bossMaxHp;
    timeLeft = mode.timeLimitSeconds;
    totalDamage = 0;
    totalTime = 0.0;

    _buildArenaBackground();
    _buildWalls();
    _buildBoss();
    _buildOrb();
    add(HudComponent(gameRef: this));
    playing = true;
  }

  /// Slightly lighter background panel that marks the playable zone.
  void _buildArenaBackground() {
    final cfg = arenaConfig;
    add(RectangleComponent(
      position: Vector2(cfg.left, cfg.top),
      size: Vector2(cfg.width, cfg.height),
      paint: Paint()..color = const Color(0xFF0C0C18),
      priority: -1,
    ));
  }

  void _buildWalls() {
    final cfg = arenaConfig;
    const t = ArenaConfig.wallThickness;
    addAll([
      ArenaWall(position: Vector2(cfg.left, cfg.top),
                size: Vector2(cfg.width, t)),
      ArenaWall(position: Vector2(cfg.left, cfg.top + cfg.height - t),
                size: Vector2(cfg.width, t)),
      ArenaWall(position: Vector2(cfg.left, cfg.top + t),
                size: Vector2(t, cfg.height - t * 2)),
      ArenaWall(position: Vector2(cfg.left + cfg.width - t, cfg.top + t),
                size: Vector2(t, cfg.height - t * 2)),
    ]);
  }

  void _buildBoss() {
    boss = BossComponent(position: arenaConfig.center, arena: arenaConfig);
    add(boss);
  }

  void _buildOrb() {
    orb = PlayerOrb(behavior: orbBehavior, gameRef: this, arena: arenaConfig);
    add(orb);
  }

  // ── Damage callback ────────────────────────────────────────────────────────

  void onOrbHitBoss(int damage, {bool isLaserTick = false}) {
    bossHp = (bossHp - damage).clamp(0, bossMaxHp);
    totalDamage += damage;

    if (!isLaserTick) {
      final ratio = damage / bossMaxHp;
      triggerShake(intensity: (ratio * 300).clamp(4.0, 28.0), duration: 0.18);
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

  // ── Game loop ──────────────────────────────────────────────────────────────

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

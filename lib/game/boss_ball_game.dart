import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

import '../orbs/orb_behavior.dart';
import '../modes/game_mode.dart';
import 'arena_config.dart';
import 'arena_wall.dart';
import 'boss_component.dart';
import 'damage_number.dart';
import 'pickup_item_component.dart';
import 'pickup_type.dart';
import 'player_orb.dart';
import 'hud_component.dart';
import 'vortex_pickup_zone.dart';

class BossBallGame extends FlameGame {
  final OrbBehavior orbBehavior;
  final GameMode mode;
  final ArenaPreset arenaPreset;
  final int? customBossHp; // overrides mode.bossMaxHp when set

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

  // ── Pickup system ────────────────────────────────────────────────────────────
  double _pickupSpawnTimer = 10.0;
  int    _activePickups    = 0;
  static const int _maxPickups = 2;

  // Active effect state
  double _damageMultiplier   = 1.0;
  double _shieldTimer        = 0.0;
  double _speedTimer         = 0.0;
  int    _starHitsRemaining  = 0;
  int    _revolverBurstsLeft = 0;
  double _revolverBurstTimer = 0.0;

  // Public getters for HUD
  double get shieldTimer       => _shieldTimer;
  double get speedTimer        => _speedTimer;
  int    get starHitsRemaining => _starHitsRemaining;

  BossBallGame({
    required this.orbBehavior,
    required this.mode,
    this.arenaPreset = ArenaPreset.normal,
    this.customBossHp,
  });

  @override
  Color backgroundColor() => const Color(0xFF040408);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    arenaConfig = ArenaConfig.fromScreen(size, arenaPreset);

    bossMaxHp = customBossHp ?? mode.bossMaxHp;
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
    // Border walls
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
    // Internal obstacle walls / pillars
    for (final rect in cfg.obstacles) {
      add(ArenaWall(
        position: Vector2(rect.left, rect.top),
        size: Vector2(rect.width, rect.height),
      ));
    }
  }

  void _buildBoss() {
    boss = BossComponent(position: arenaConfig.center);
    add(boss);
  }

  void _buildOrb() {
    orb = PlayerOrb(behavior: orbBehavior, gameRef: this, arena: arenaConfig);
    add(orb);
  }

  // 🔴 تمت إعادة إضافة دالة تأثير النار المفقودة
  void spawnFireExplosion(Vector2 position) {
    add(
      ParticleSystemComponent(
        position: position,
        particle: Particle.generate(
          count: 40,
          lifespan: 0.5,
          generator: (i) {
            final speed = Vector2((_rng.nextDouble() - 0.5) * 600, (_rng.nextDouble() - 0.5) * 600);
            return AcceleratedParticle(
              acceleration: Vector2(0, 200),
              speed: speed,
              child: ComputedParticle(
                renderer: (canvas, particle) {
                  final color = Color.lerp(
                    Colors.yellow,
                    Colors.red,
                    particle.progress,
                  )!.withOpacity(1.0 - particle.progress);
                  
                  final paint = Paint()
                    ..color = color
                    ..blendMode = BlendMode.screen
                    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
                    
                  final radius = 6.0 * (1.0 - particle.progress);
                  canvas.drawCircle(Offset.zero, radius, paint);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Damage callback ────────────────────────────────────────────────────────

  void onOrbHitBoss(int baseDamage, {bool isLaserTick = false}) {
    // Apply active pickup damage multiplier
    final boostedBase = isLaserTick ? baseDamage : (baseDamage * _damageMultiplier).round();

    // Consume a star hit
    if (!isLaserTick && _starHitsRemaining > 0) {
      _starHitsRemaining--;
      if (_starHitsRemaining <= 0) _damageMultiplier = 1.0;
    }

    // 20% chance for critical hit
    bool isCrit = false;
    int finalDamage = boostedBase;

    if (!isLaserTick && _rng.nextDouble() < 0.20) {
      isCrit = true;
      finalDamage = boostedBase * 2;
    }

    bossHp = (bossHp - finalDamage).clamp(0, bossMaxHp);
    totalDamage += finalDamage;

    if (!isLaserTick) {
      final shakePower = isCrit ? 50.0 : ((finalDamage / bossMaxHp) * 300).clamp(4.0, 28.0);
      triggerShake(
        intensity: shakePower,
        duration: isCrit ? 0.3 : 0.18,
      );
      
      spawnFireExplosion(orb.position.clone());
      
      // Spawn floating damage number
      add(DamageNumber(
        position: boss.position.clone() + Vector2((_rng.nextDouble() - 0.5) * 40, -30),
        damage: finalDamage,
        isSmall: false,
        driftX: (_rng.nextDouble() - 0.5) * 60,
      ));
      
    } else {
      triggerShake(intensity: 1.8, duration: 0.04);
      if (_rng.nextDouble() > 0.5) {
        spawnFireExplosion(boss.position.clone() + Vector2((_rng.nextDouble() - 0.5) * 40, (_rng.nextDouble() - 0.5) * 40));
        // Small damage numbers for laser ticks
        add(DamageNumber(
          position: boss.position.clone() + Vector2((_rng.nextDouble() - 0.5) * 50, (_rng.nextDouble() - 0.5) * 50),
          damage: finalDamage,
          isSmall: true,
          driftX: (_rng.nextDouble() - 0.5) * 40,
        ));
      }
    }

    if (mode.winOnBossKill && bossHp <= 0 && !bossDestroyed) {
      bossDestroyed = true;
      playing = false;
      Future.delayed(Duration.zero, () => overlays.add('GameOver'));
    }
  }

  // ── Pickup system ────────────────────────────────────────────────────────────

  void onPickupExpired() {
    if (_activePickups > 0) _activePickups--;
  }

  void _tickPickupTimers(double dt) {
    // Shield timer
    if (_shieldTimer > 0) {
      _shieldTimer -= dt;
      if (_shieldTimer <= 0) {
        _shieldTimer = 0;
        if (_starHitsRemaining <= 0) _damageMultiplier = 1.0;
      }
    }

    // Speed timer
    if (_speedTimer > 0) {
      _speedTimer -= dt;
      if (_speedTimer <= 0) {
        _speedTimer = 0;
        orb.speedMultiplier = 1.0;
      }
    }

    // Revolver burst sequence
    if (_revolverBurstsLeft > 0) {
      _revolverBurstTimer -= dt;
      if (_revolverBurstTimer <= 0) {
        _revolverBurstTimer = 0.2;
        _revolverBurstsLeft--;
        onOrbHitBoss(40000);
      }
    }
  }

  void _maybeSpawnPickup(double dt) {
    _pickupSpawnTimer -= dt;
    if (_pickupSpawnTimer > 0) return;
    if (_activePickups >= _maxPickups) return;

    final pos = _randomPickupPosition();
    final type = PickupTypeInfo.weighted(_rng);
    add(PickupItemComponent(position: pos, type: type, gameRef: this));
    _activePickups++;
    _pickupSpawnTimer = 8.0 + _rng.nextDouble() * 7.0;
  }

  Vector2 _randomPickupPosition({int retries = 8}) {
    const r = PickupItemComponent.pickupRadius;
    final x = arenaConfig.minX(r) + _rng.nextDouble() * (arenaConfig.maxX(r) - arenaConfig.minX(r));
    final y = arenaConfig.minY(r) + _rng.nextDouble() * (arenaConfig.maxY(r) - arenaConfig.minY(r));
    final pos = Vector2(x, y);
    if (retries > 0 &&
        (pos.distanceTo(boss.position) < 80 || pos.distanceTo(orb.position) < 80)) {
      return _randomPickupPosition(retries: retries - 1);
    }
    return pos;
  }

  void onPickupCollected(PickupType type) {
    switch (type) {
      case PickupType.apple:
        onOrbHitBoss(80000);

      case PickupType.revolver:
        _revolverBurstsLeft = 6;
        _revolverBurstTimer = 0.2;

      case PickupType.lightning:
        onOrbHitBoss(200000);
        boss.freezeBoss(1.0);
        triggerShake(intensity: 35, duration: 0.3);

      case PickupType.shield:
        _damageMultiplier = 2.0;
        _shieldTimer = 8.0;

      case PickupType.speed:
        orb.speedMultiplier = 2.0;
        _speedTimer = 6.0;

      case PickupType.ice:
        boss.freezeBoss(3.0);

      case PickupType.bomb:
        onOrbHitBoss(500000);
        triggerShake(intensity: 60, duration: 0.45);

      case PickupType.vortex:
        add(VortexPickupZone(
          position: _randomPickupPosition(),
          gameRef: this,
        ));

      case PickupType.star:
        _starHitsRemaining = 3;
        _damageMultiplier  = 3.0;

      case PickupType.mystery:
        onPickupCollected(PickupTypeInfo.randomNonMystery(_rng));
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
    _tickPickupTimers(dt);
    _maybeSpawnPickup(dt);

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
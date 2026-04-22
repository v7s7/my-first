import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
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
  final int? customBossHp;

  /// Raw image bytes kept so the retry button can reconstruct the game.
  final List<Uint8List?> orbImageBytes;
  final Uint8List? bossImageBytes;

  late ArenaConfig arenaConfig;

  late int bossMaxHp;
  late int bossHp;
  late double timeLeft;

  bool playing = false;
  bool bossDestroyed = false;

  int totalDamage = 0;
  double totalTime = 0.0;

  late BossComponent boss;

  // Multi-orb support
  final List<PlayerOrb> _orbs = [];
  List<PlayerOrb> get orbs => _orbs;
  PlayerOrb get orb => _orbs.first;

  // Decoded face images — set during onLoad, read by orb/boss render
  final List<ui.Image?> _orbImages = [];
  ui.Image? _bossUiImage;

  ui.Image? orbImage(int index) =>
      index < _orbImages.length ? _orbImages[index] : null;
  ui.Image? get bossUiImage => _bossUiImage;

  double _shakeIntensity = 0.0;
  double _shakeTimer = 0.0;
  final Random _rng = Random();

  // ── Pickup system ─────────────────────────────────────────────────────────
  double _pickupSpawnTimer = 10.0;
  int    _activePickups    = 0;
  static const int _maxPickups = 2;

  // Active effect timers
  double _shieldTimer          = 0.0;
  double _speedTimer           = 0.0;
  double _rapidTimer           = 0.0;
  double _magnetTimer          = 0.0;
  int    _starHitsRemaining    = 0;
  int    _barrierHitsRemaining = 0;
  int    _revolverBurstsLeft   = 0;
  double _revolverBurstTimer   = 0.0;

  // Public getters for HUD
  double get shieldTimer          => _shieldTimer;
  double get speedTimer           => _speedTimer;
  double get rapidTimer           => _rapidTimer;
  double get magnetTimer          => _magnetTimer;
  int    get starHitsRemaining    => _starHitsRemaining;
  int    get barrierHitsRemaining => _barrierHitsRemaining;

  // Stacked damage multiplier from all active buffs (capped at 8×)
  double get _effectiveMultiplier {
    double m = 1.0;
    if (_shieldTimer > 0) m *= 2.0;
    if (_starHitsRemaining > 0) m *= 2.5;
    if (_barrierHitsRemaining > 0) m *= 3.0;
    return m.clamp(1.0, 8.0);
  }

  BossBallGame({
    required this.orbBehavior,
    required this.mode,
    this.arenaPreset = ArenaPreset.normal,
    this.customBossHp,
    this.orbImageBytes = const [],
    this.bossImageBytes,
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

    // Decode face images before building components so they're ready to render
    for (final bytes in orbImageBytes) {
      _orbImages.add(await _decodeUiImage(bytes));
    }
    _bossUiImage = await _decodeUiImage(bossImageBytes);

    _buildArenaBackground();
    _buildWalls();
    _buildBoss();
    _buildOrbs();
    add(HudComponent(gameRef: this));
    playing = true;
  }

  static Future<ui.Image?> _decodeUiImage(Uint8List? bytes) async {
    if (bytes == null) return null;
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 300,
      targetHeight: 300,
    );
    final frame = await codec.getNextFrame();
    return frame.image;
  }

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

  void _buildOrbs() {
    for (int i = 0; i < mode.orbCount; i++) {
      final o = PlayerOrb(
        behavior: orbBehavior,
        gameRef: this,
        arena: arenaConfig,
        orbIndex: i,
      );
      _orbs.add(o);
      add(o);
    }
  }

  void spawnFireExplosion(Vector2 position) {
    add(
      ParticleSystemComponent(
        position: position,
        particle: Particle.generate(
          count: 40,
          lifespan: 0.5,
          generator: (i) {
            final spd = Vector2(
              (_rng.nextDouble() - 0.5) * 600,
              (_rng.nextDouble() - 0.5) * 600,
            );
            return AcceleratedParticle(
              acceleration: Vector2(0, 200),
              speed: spd,
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
                  final r = 6.0 * (1.0 - particle.progress);
                  canvas.drawCircle(Offset.zero, r, paint);
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
    final mult = isLaserTick ? 1.0 : _effectiveMultiplier;
    final boostedBase = (baseDamage * mult).round();

    if (!isLaserTick) {
      if (_barrierHitsRemaining > 0) _barrierHitsRemaining--;
      if (_starHitsRemaining > 0) _starHitsRemaining--;
    }

    bool isCrit = false;
    int finalDamage = boostedBase;

    if (!isLaserTick && _rng.nextDouble() < 0.20) {
      isCrit = true;
      finalDamage = boostedBase * 2;
    }

    bossHp = (bossHp - finalDamage).clamp(0, bossMaxHp);
    totalDamage += finalDamage;

    if (!isLaserTick) {
      final shakePower = isCrit
          ? 50.0
          : ((finalDamage / bossMaxHp) * 300).clamp(4.0, 28.0);
      triggerShake(intensity: shakePower, duration: isCrit ? 0.3 : 0.18);
      spawnFireExplosion(orb.position.clone());
      add(DamageNumber(
        position: boss.position.clone() +
            Vector2((_rng.nextDouble() - 0.5) * 40, -30),
        damage: finalDamage,
        isSmall: false,
        driftX: (_rng.nextDouble() - 0.5) * 60,
      ));
    } else {
      triggerShake(intensity: 1.8, duration: 0.04);
      if (_rng.nextDouble() > 0.5) {
        spawnFireExplosion(
          boss.position.clone() + Vector2(
            (_rng.nextDouble() - 0.5) * 40,
            (_rng.nextDouble() - 0.5) * 40,
          ),
        );
        add(DamageNumber(
          position: boss.position.clone() + Vector2(
            (_rng.nextDouble() - 0.5) * 50,
            (_rng.nextDouble() - 0.5) * 50,
          ),
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

  // ── Pickup system ──────────────────────────────────────────────────────────

  void onPickupExpired() {
    if (_activePickups > 0) _activePickups--;
  }

  void _tickPickupTimers(double dt) {
    if (_shieldTimer > 0) {
      _shieldTimer -= dt;
      if (_shieldTimer < 0) _shieldTimer = 0;
    }
    if (_speedTimer > 0) {
      _speedTimer -= dt;
      if (_speedTimer <= 0) {
        _speedTimer = 0;
        for (final o in _orbs) o.speedMultiplier = 1.0;
      }
    }
    if (_rapidTimer > 0) {
      _rapidTimer -= dt;
      if (_rapidTimer < 0) _rapidTimer = 0;
    }
    if (_magnetTimer > 0) {
      _magnetTimer -= dt;
      if (_magnetTimer < 0) _magnetTimer = 0;
    }

    // Revolver burst — 28K × 6 = 168K total
    if (_revolverBurstsLeft > 0) {
      _revolverBurstTimer -= dt;
      if (_revolverBurstTimer <= 0) {
        _revolverBurstTimer = 0.2;
        _revolverBurstsLeft--;
        onOrbHitBoss(28000);
      }
    }
  }

  void _maybeSpawnPickup(double dt) {
    if (!mode.hasPickups) return; // CLASSIC mode: no item spawning
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
    final x = arenaConfig.minX(r) +
        _rng.nextDouble() * (arenaConfig.maxX(r) - arenaConfig.minX(r));
    final y = arenaConfig.minY(r) +
        _rng.nextDouble() * (arenaConfig.maxY(r) - arenaConfig.minY(r));
    final pos = Vector2(x, y);
    final tooClose = _orbs.any((o) => pos.distanceTo(o.position) < 80);
    if (retries > 0 && (pos.distanceTo(boss.position) < 80 || tooClose)) {
      return _randomPickupPosition(retries: retries - 1);
    }
    return pos;
  }

  void onPickupCollected(PickupType type) {
    switch (type) {
      case PickupType.apple:
        onOrbHitBoss(60000);
      case PickupType.revolver:
        _revolverBurstsLeft = 6;
        _revolverBurstTimer = 0.2;
      case PickupType.lightning:
        onOrbHitBoss(120000);
        boss.freezeBoss(1.0);
        triggerShake(intensity: 35, duration: 0.3);
      case PickupType.shield:
        _shieldTimer = 8.0;
      case PickupType.speed:
        for (final o in _orbs) o.speedMultiplier = 2.0;
        _speedTimer = 6.0;
      case PickupType.ice:
        boss.freezeBoss(3.0);
      case PickupType.bomb:
        onOrbHitBoss(280000);
        triggerShake(intensity: 60, duration: 0.45);
      case PickupType.vortex:
        add(VortexPickupZone(position: _randomPickupPosition(), gameRef: this));
      case PickupType.star:
        _starHitsRemaining = 3;
      case PickupType.rapid:
        _rapidTimer = 6.0;
      case PickupType.magnet:
        _magnetTimer = 8.0;
      case PickupType.barrier:
        _barrierHitsRemaining = 4;
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
    if (_shakeTimer > 0) {
      _shakeTimer -= dt;
      if (_shakeTimer <= 0) _shakeIntensity = 0.0;
    }
    if (!playing) {
      super.update(dt);
      return;
    }

    totalTime += dt;
    _tickPickupTimers(dt);
    _maybeSpawnPickup(dt);

    // Survival mode: boss regenerates HP each tick
    if (mode.bossRegenPerSecond > 0 && !bossDestroyed && bossHp > 0) {
      bossHp = (bossHp + (mode.bossRegenPerSecond * dt).round())
          .clamp(0, bossMaxHp);
    }

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

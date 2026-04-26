import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // rootBundle + HapticFeedback
import 'sound_manager.dart';

import '../orbs/orb_behavior.dart';
import '../modes/game_mode.dart';
import 'arena_background.dart';
import 'arena_config.dart';
import 'arena_wall.dart';
import 'boss_component.dart';
import 'boss_projectile.dart';
import 'bullet_component.dart';
import 'damage_number.dart';
import 'pickup_item_component.dart';
import 'pickup_type.dart';
import 'player_orb.dart';
import 'hud_component.dart';
import 'shockwave_ring_component.dart';
import 'vortex_pickup_zone.dart';

enum PvpGunType { pistol, shotgun, sniper, machineGun, rocket, grenade, burst, minigun, railgun }

class BossBallGame extends FlameGame with TapCallbacks {
  final OrbBehavior orbBehavior;
  final GameMode mode;
  final ArenaPreset arenaPreset;
  final int? customBossHp;

  /// Raw image bytes kept so the retry button can reconstruct the game.
  final List<Uint8List?> orbImageBytes;
  final Uint8List? bossImageBytes;

  /// Custom colours for each PVP orb (index-matched). Empty = use behavior colour.
  final List<Color> pvpOrbColors;

  /// Which pickup types are allowed to spawn. Null = all allowed.
  final Set<PickupType>? pvpAllowedItems;

  late ArenaConfig arenaConfig;

  late int bossMaxHp;
  late int bossHp;
  late double timeLeft;

  bool playing = false;
  bool bossDestroyed = false;

  int totalDamage = 0;
  double totalTime = 0.0;

  // Boss is nullable — null in PVP mode
  BossComponent? boss;

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

  // Gun icon images — loaded from assets/guns/ if present, null = canvas fallback
  final Map<PvpGunType, ui.Image?> _gunImages = {};
  ui.Image? gunImage(PvpGunType type) => _gunImages[type];

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
  int    _starHitsRemaining     = 0;
  int    _barrierHitsRemaining  = 0;
  int    _tripleHitsRemaining   = 0;
  int    _overdriveHitsRemaining = 0;
  List<double> _ghostTimers      = [0.0, 0.0];
  List<double> _pvpShieldTimers  = [0.0, 0.0];
  int    _revolverBurstsLeft    = 0;
  double _revolverBurstTimer    = 0.0;
  double _revolverBurstInterval = 0.38;
  double _revolverHoldTimer     = 0.0; // countdown before first shot fires
  double _revolverHoldDuration  = 0.0; // total hold duration (for fraction calc)
  int    _revolverVictimIndex   = 0;
  int    _revolverCollectorIndex = 0;
  int    _speedCollectorIndex   = -1;
  PvpGunType _pvpGunType       = PvpGunType.pistol;

  // Public getters for HUD
  double get shieldTimer          => _shieldTimer;
  double get speedTimer           => _speedTimer;
  double get rapidTimer           => _rapidTimer;
  double get magnetTimer          => _magnetTimer;
  int    get starHitsRemaining    => _starHitsRemaining;
  int    get barrierHitsRemaining   => _barrierHitsRemaining;
  int    get tripleHitsRemaining    => _tripleHitsRemaining;
  int    get overdriveHitsRemaining => _overdriveHitsRemaining;
  bool isOrbGhosted(int index) =>
      index < _ghostTimers.length && _ghostTimers[index] > 0;
  bool isOrbShielded(int index) =>
      index < _pvpShieldTimers.length && _pvpShieldTimers[index] > 0;
  double pvpShieldTimer(int index) =>
      index < _pvpShieldTimers.length ? _pvpShieldTimers[index] : 0.0;

  // Gun state — read by PlayerOrb to draw the held weapon
  PvpGunType? get activeGunType =>
      (_revolverHoldTimer > 0 || _revolverBurstsLeft > 0) ? _pvpGunType : null;
  bool   get revolverIsHolding    => _revolverHoldTimer > 0;
  /// 0.0 → just picked up, 1.0 → about to fire
  double get revolverHoldFraction =>
      _revolverHoldDuration > 0
          ? (1.0 - _revolverHoldTimer / _revolverHoldDuration).clamp(0.0, 1.0)
          : 1.0;
  int get revolverShooterIndex => _revolverCollectorIndex;
  int get revolverBurstsLeft   => _revolverBurstsLeft;

  // ── PVP state ─────────────────────────────────────────────────────────────
  List<int> _pvpOrbHp     = [];
  int       pvpOrbMaxHp   = 1000000;
  int?      pvpWinner;       // 0 or 1 = winning orb index; null = in progress
  double    _pvpHitCooldown = 0.0;

  int pvpOrbHp(int index) =>
      index < _pvpOrbHp.length ? _pvpOrbHp[index] : 0;

  // ── Combo system ──────────────────────────────────────────────────────────
  int    _comboCount       = 0;
  double _comboDecayTimer  = 0.0;
  static const double _comboDecayTime = 1.6;

  int    get comboCount => _comboCount;
  int    get bossPhase  => boss?.phase ?? 0;

  double get comboMultiplier {
    if (_comboCount >= 20) return 2.00;
    if (_comboCount >= 10) return 1.50;
    if (_comboCount >= 5)  return 1.25;
    return 1.00;
  }

  // ── Endless wave system ───────────────────────────────────────────────────
  int    _waveNumber = 1;
  double _waveTimer  = 30.0;
  int    get waveNumber => _waveNumber;

  // ── Screen flash ──────────────────────────────────────────────────────────
  double _hitFlashTimer   = 0.0;
  double _phaseFlashTimer = 0.0;
  Color  _phaseFlashColor = Colors.white;

  // ── Arena background reference (for hit pulse) ────────────────────────────
  ArenaBackground? _arenaBackground;

  // Stacked damage multiplier from all active buffs (capped at 8×)
  double get _effectiveMultiplier {
    double m = 1.0;
    if (_shieldTimer > 0) m *= 2.0;
    if (_starHitsRemaining > 0) m *= 2.5;
    if (_barrierHitsRemaining > 0) m *= 3.0;
    if (_tripleHitsRemaining > 0) m *= 3.0;
    if (_overdriveHitsRemaining > 0) m *= 5.0;
    return m.clamp(1.0, 12.0);
  }

  BossBallGame({
    required this.orbBehavior,
    required this.mode,
    this.arenaPreset = ArenaPreset.normal,
    this.customBossHp,
    this.orbImageBytes = const [],
    this.bossImageBytes,
    this.pvpOrbColors = const [],
    this.pvpAllowedItems,
  });

  @override
  Color backgroundColor() => const Color(0xFF040408);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    arenaConfig = ArenaConfig.fromScreen(size, arenaPreset, square: mode.isPvp);

    bossMaxHp = customBossHp ?? mode.bossMaxHp;
    bossHp = bossMaxHp;
    timeLeft = mode.timeLimitSeconds;
    totalDamage = 0;
    totalTime = 0.0;

    // Decode face images before building components
    for (final bytes in orbImageBytes) {
      _orbImages.add(await _decodeUiImage(bytes));
    }
    _bossUiImage = await _decodeUiImage(bossImageBytes);

    // Load gun icon images from assets/guns/ (silently skip if file absent)
    const _gunAssets = {
      PvpGunType.pistol:     'assets/guns/gun_pistol.png',
      PvpGunType.shotgun:    'assets/guns/gun_shotgun.png',
      PvpGunType.sniper:     'assets/guns/gun_sniper.png',
      PvpGunType.machineGun: 'assets/guns/gun_machinegun.png',
      PvpGunType.rocket:     'assets/guns/gun_rocket.png',
      PvpGunType.grenade:    'assets/guns/gun_grenade.png',
      PvpGunType.burst:      'assets/guns/gun_burst.png',
      PvpGunType.minigun:    'assets/guns/gun_minigun.png',
      PvpGunType.railgun:    'assets/guns/gun_railgun.png',
    };
    for (final entry in _gunAssets.entries) {
      try {
        final data = await rootBundle.load(entry.value);
        _gunImages[entry.key] =
            await _decodeUiImage(data.buffer.asUint8List());
      } catch (_) {
        _gunImages[entry.key] = null; // file not yet added — use canvas fallback
      }
    }

    _buildArenaBackground();
    _buildWalls();
    if (!mode.isPvp) _buildBoss();
    _buildOrbs();
    add(HudComponent(gameRef: this));

    // PVP: set up per-orb HP and per-orb timer lists
    if (mode.isPvp) {
      pvpOrbMaxHp = customBossHp ?? mode.bossMaxHp;
      _pvpOrbHp        = List.filled(mode.orbCount, pvpOrbMaxHp);
      _ghostTimers     = List.filled(mode.orbCount, 0.0);
      _pvpShieldTimers = List.filled(mode.orbCount, 0.0);
    }

    SoundManager.instance.init(); // fire-and-forget; silent if files missing
    Future.delayed(Duration.zero, () => overlays.add('Countdown'));
  }

  void startPlaying() {
    overlays.remove('Countdown');
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
    _arenaBackground = ArenaBackground(arena: arenaConfig);
    add(_arenaBackground!);
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
    add(boss!);
  }

  void _buildOrbs() {
    final pvpRadius = mode.isPvp ? 32.0 : PlayerOrb.defaultRadius;
    for (int i = 0; i < mode.orbCount; i++) {
      final customColor = i < pvpOrbColors.length ? pvpOrbColors[i] : null;
      final o = PlayerOrb(
        behavior: orbBehavior,
        gameRef: this,
        arena: arenaConfig,
        orbIndex: i,
        orbRadius: pvpRadius,
        customColor: customColor,
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

  // ── Boss damage callback ───────────────────────────────────────────────────

  void onOrbHitBoss(int baseDamage, {bool isLaserTick = false}) {
    if (boss == null) return; // no boss in PVP
    final mult =
        isLaserTick ? 1.0 : _effectiveMultiplier * comboMultiplier;
    final boostedBase = (baseDamage * mult).round();

    if (!isLaserTick) _incrementCombo();

    if (!isLaserTick) {
      if (_barrierHitsRemaining > 0) _barrierHitsRemaining--;
      if (_starHitsRemaining > 0) _starHitsRemaining--;
      if (_tripleHitsRemaining > 0) _tripleHitsRemaining--;
      if (_overdriveHitsRemaining > 0) _overdriveHitsRemaining--;
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
      if (isCrit) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
      SoundManager.instance.playHit(isCrit: isCrit);
    }

    if (!isLaserTick) {
      final shakePower = isCrit
          ? 50.0
          : ((finalDamage / bossMaxHp) * 300).clamp(4.0, 28.0);
      triggerShake(intensity: shakePower, duration: isCrit ? 0.3 : 0.18);
      _hitFlashTimer = isCrit ? 0.14 : 0.07;
      _arenaBackground?.pulse((finalDamage / bossMaxHp).clamp(0.0, 1.0) * 4);
      spawnFireExplosion(orb.position.clone());
      add(DamageNumber(
        position: boss!.position.clone() +
            Vector2((_rng.nextDouble() - 0.5) * 40, -30),
        damage: finalDamage,
        isSmall: false,
        driftX: (_rng.nextDouble() - 0.5) * 60,
      ));
    } else {
      triggerShake(intensity: 1.8, duration: 0.04);
      if (_rng.nextDouble() > 0.5) {
        spawnFireExplosion(
          boss!.position.clone() + Vector2(
            (_rng.nextDouble() - 0.5) * 40,
            (_rng.nextDouble() - 0.5) * 40,
          ),
        );
        add(DamageNumber(
          position: boss!.position.clone() + Vector2(
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
      HapticFeedback.heavyImpact();
      SoundManager.instance.playWin();
      Future.delayed(Duration.zero, () => overlays.add('GameOver'));
    }
  }

  // ── PVP damage callback ────────────────────────────────────────────────────

  Color? _orbEffectiveColor(int index) {
    if (index >= _orbs.length) return null;
    final o = _orbs[index];
    return o.customColor ?? o.behavior.color;
  }

  void onPvpOrbHit({required int victimIndex, required int damage}) {
    if (victimIndex >= _pvpOrbHp.length || pvpWinner != null) return;
    if (isOrbGhosted(victimIndex)) return;
    if (isOrbShielded(victimIndex)) return;

    _pvpOrbHp[victimIndex] =
        (_pvpOrbHp[victimIndex] - damage).clamp(0, pvpOrbMaxHp);
    totalDamage += damage;

    triggerShake(
      intensity: (damage / pvpOrbMaxHp * 200).clamp(4.0, 40.0),
      duration: 0.15,
    );

    final orbPos = victimIndex < _orbs.length
        ? _orbs[victimIndex].position.clone()
        : orb.position.clone();
    spawnFireExplosion(orbPos);
    add(DamageNumber(
      position: orbPos + Vector2((_rng.nextDouble() - 0.5) * 40, -30),
      damage: damage,
      isSmall: false,
      labelColor: _orbEffectiveColor(victimIndex),
      driftX: (_rng.nextDouble() - 0.5) * 60,
    ));

    if (_pvpOrbHp[victimIndex] <= 0) {
      pvpWinner = 1 - victimIndex;
      playing = false;
      Future.delayed(Duration.zero, () => overlays.add('GameOver'));
    }
  }

  // ── Pickup system ──────────────────────────────────────────────────────────

  void onPickupExpired() {
    if (_activePickups > 0) _activePickups--;
  }

  void _spawnRevolverBullet() {
    if (mode.isPvp) {
      _spawnPvpGunBullets();
    } else {
      _spawnBossBullet();
    }
  }

  void _spawnBossBullet() {
    final shooter = _revolverCollectorIndex < _orbs.length
        ? _orbs[_revolverCollectorIndex]
        : (_orbs.isNotEmpty ? _orbs.first : null);
    if (shooter == null) return;
    final targetPos = boss?.position.clone() ?? shooter.position.clone();
    add(BulletComponent.boss(
      position: shooter.position.clone(),
      target: targetPos,
    ));
  }

  void _spawnPvpGunBullets() {
    final shooter = _revolverCollectorIndex < _orbs.length
        ? _orbs[_revolverCollectorIndex]
        : (_orbs.isNotEmpty ? _orbs.first : null);
    if (shooter == null) return;

    final targetPos = _revolverVictimIndex < _orbs.length
        ? _orbs[_revolverVictimIndex].position.clone()
        : shooter.position.clone();

    switch (_pvpGunType) {
      case PvpGunType.pistol:
        add(BulletComponent.pistol(
          position: shooter.position.clone(),
          target: targetPos,
          pvpVictimIndex: _revolverVictimIndex,
        ));
      case PvpGunType.shotgun:
        for (int i = 0; i < 5; i++) {
          final spread = (i - 2) * 0.14;
          add(BulletComponent.shotgunPellet(
            position: shooter.position.clone(),
            target: targetPos,
            pvpVictimIndex: _revolverVictimIndex,
            spreadAngleRad: spread,
          ));
        }
      case PvpGunType.sniper:
        add(BulletComponent.sniper(
          position: shooter.position.clone(),
          target: targetPos,
          pvpVictimIndex: _revolverVictimIndex,
        ));
      case PvpGunType.machineGun:
        final spread = (_rng.nextDouble() - 0.5) * 0.3;
        add(BulletComponent.machineGun(
          position: shooter.position.clone(),
          target: targetPos,
          pvpVictimIndex: _revolverVictimIndex,
          spreadAngleRad: spread,
        ));
      case PvpGunType.rocket:
        add(BulletComponent.rocket(
          position: shooter.position.clone(),
          target: targetPos,
          pvpVictimIndex: _revolverVictimIndex,
        ));
      case PvpGunType.grenade:
        add(BulletComponent.grenade(
          position: shooter.position.clone(),
          target: targetPos,
          pvpVictimIndex: _revolverVictimIndex,
        ));
      case PvpGunType.burst:
        for (int i = 0; i < 3; i++) {
          final spread = (i - 1) * 0.09;
          add(BulletComponent.burst(
            position: shooter.position.clone(),
            target: targetPos,
            pvpVictimIndex: _revolverVictimIndex,
            spreadAngleRad: spread,
          ));
        }
      case PvpGunType.minigun:
        final spread = (_rng.nextDouble() - 0.5) * 0.45;
        add(BulletComponent.minigun(
          position: shooter.position.clone(),
          target: targetPos,
          pvpVictimIndex: _revolverVictimIndex,
          spreadAngleRad: spread,
        ));
      case PvpGunType.railgun:
        add(BulletComponent.railgun(
          position: shooter.position.clone(),
          target: targetPos,
          pvpVictimIndex: _revolverVictimIndex,
        ));
    }
  }

  void _selectPvpGun(int collectorIndex) {
    _pvpGunType = PvpGunType.values[_rng.nextInt(PvpGunType.values.length)];
    _revolverVictimIndex = 1 - collectorIndex;
    _revolverCollectorIndex = collectorIndex;
    _revolverBurstTimer = 0.0;

    switch (_pvpGunType) {
      case PvpGunType.pistol:
        _revolverBurstsLeft = 6;
        _revolverBurstInterval = 0.38;
        _revolverHoldDuration = 1.2;
      case PvpGunType.shotgun:
        _revolverBurstsLeft = 2;
        _revolverBurstInterval = 0.40;
        _revolverHoldDuration = 2.0;
      case PvpGunType.sniper:
        _revolverBurstsLeft = 1;
        _revolverBurstInterval = 0.0;
        _revolverHoldDuration = 5.0;
      case PvpGunType.machineGun:
        _revolverBurstsLeft = 15;
        _revolverBurstInterval = 0.08;
        _revolverHoldDuration = 1.5;
      case PvpGunType.rocket:
        _revolverBurstsLeft = 1;
        _revolverBurstInterval = 0.0;
        _revolverHoldDuration = 3.5;
      case PvpGunType.grenade:
        _revolverBurstsLeft = 3;
        _revolverBurstInterval = 0.35;
        _revolverHoldDuration = 2.5;
      case PvpGunType.burst:
        _revolverBurstsLeft = 3;
        _revolverBurstInterval = 0.18;
        _revolverHoldDuration = 2.0;
      case PvpGunType.minigun:
        _revolverBurstsLeft = 25;
        _revolverBurstInterval = 0.05;
        _revolverHoldDuration = 2.0;
      case PvpGunType.railgun:
        _revolverBurstsLeft = 1;
        _revolverBurstInterval = 0.0;
        _revolverHoldDuration = 5.0;
    }
    _revolverHoldTimer = _revolverHoldDuration;

    final gunLabel = switch (_pvpGunType) {
      PvpGunType.pistol     => 'PISTOL  x6',
      PvpGunType.shotgun    => 'SHOTGUN x2',
      PvpGunType.sniper     => 'SNIPER!!!',
      PvpGunType.machineGun => 'MACHINE GUN',
      PvpGunType.rocket     => 'ROCKET!!!',
      PvpGunType.grenade    => 'GRENADE x3',
      PvpGunType.burst      => 'BURST RIFLE x3',
      PvpGunType.minigun    => 'MINIGUN x25',
      PvpGunType.railgun    => 'RAILGUN!!!',
    };
    final gunColor = switch (_pvpGunType) {
      PvpGunType.pistol     => const Color(0xFFFFCC00),
      PvpGunType.shotgun    => const Color(0xFFFF6600),
      PvpGunType.sniper     => const Color(0xFF00EEFF),
      PvpGunType.machineGun => const Color(0xFFFF3300),
      PvpGunType.rocket     => const Color(0xFFFF2200),
      PvpGunType.grenade    => const Color(0xFF88FF00),
      PvpGunType.burst      => const Color(0xFFFFAA00),
      PvpGunType.minigun    => const Color(0xFFFF5500),
      PvpGunType.railgun    => const Color(0xFF00FFCC),
    };

    final shooterPos = collectorIndex < _orbs.length
        ? _orbs[collectorIndex].position.clone()
        : Vector2.zero();
    add(DamageNumber(
      position: shooterPos + Vector2(0, -60),
      damage: 0,
      label: gunLabel,
      labelColor: gunColor,
      isSmall: false,
      driftX: 0,
    ));
  }

  void spawnRocketExplosion(Vector2 position) {
    add(
      ParticleSystemComponent(
        position: position,
        particle: Particle.generate(
          count: 80,
          lifespan: 0.9,
          generator: (i) {
            final spd = Vector2(
              (_rng.nextDouble() - 0.5) * 1200,
              (_rng.nextDouble() - 0.5) * 1200,
            );
            return AcceleratedParticle(
              acceleration: Vector2(0, 200),
              speed: spd,
              child: ComputedParticle(
                renderer: (canvas, particle) {
                  final t = particle.progress;
                  final color = Color.lerp(Colors.white,
                      i % 3 == 0 ? Colors.orange : Colors.red, t)!
                      .withOpacity(1.0 - t);
                  final r = (14.0 - t * 10.0).clamp(1.0, 14.0);
                  canvas.drawCircle(
                    Offset.zero,
                    r,
                    Paint()
                      ..color = color
                      ..blendMode = BlendMode.screen
                      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
    triggerShake(intensity: 90, duration: 0.55);
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
        if (mode.isPvp && _speedCollectorIndex >= 0 &&
            _speedCollectorIndex < _orbs.length) {
          _orbs[_speedCollectorIndex].speedMultiplier = 1.0;
        } else {
          for (final o in _orbs) o.speedMultiplier = 1.0;
        }
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
    for (int i = 0; i < _ghostTimers.length; i++) {
      if (_ghostTimers[i] > 0) {
        _ghostTimers[i] -= dt;
        if (_ghostTimers[i] < 0) _ghostTimers[i] = 0;
      }
    }
    for (int i = 0; i < _pvpShieldTimers.length; i++) {
      if (_pvpShieldTimers[i] > 0) {
        _pvpShieldTimers[i] -= dt;
        if (_pvpShieldTimers[i] < 0) _pvpShieldTimers[i] = 0;
      }
    }

    // Revolver: hold phase then burst fire
    if (_revolverHoldTimer > 0) {
      _revolverHoldTimer -= dt;
      if (_revolverHoldTimer < 0) _revolverHoldTimer = 0;
    } else if (_revolverBurstsLeft > 0) {
      _revolverBurstTimer -= dt;
      if (_revolverBurstTimer <= 0) {
        _revolverBurstTimer = _revolverBurstInterval;
        _revolverBurstsLeft--;
        _spawnRevolverBullet();
      }
    }
  }

  void _maybeSpawnPickup(double dt) {
    if (!mode.hasPickups) return;
    _pickupSpawnTimer -= dt;
    if (_pickupSpawnTimer > 0) return;
    if (_activePickups >= _maxPickups) return;

    final pos = _randomPickupPosition();
    final type = _pickRandomAllowedItem();
    add(PickupItemComponent(position: pos, type: type, gameRef: this));
    _activePickups++;
    _pickupSpawnTimer = 8.0 + _rng.nextDouble() * 7.0;
  }

  PickupType _pickRandomAllowedItem() {
    final allowed = pvpAllowedItems;
    if (allowed == null || allowed.isEmpty) return PickupTypeInfo.weighted(_rng);
    final pool = <PickupType>[];
    for (final t in allowed) {
      for (int i = 0; i < t.spawnWeight; i++) pool.add(t);
    }
    return pool[_rng.nextInt(pool.length)];
  }

  Vector2 _randomPickupPosition({int retries = 8}) {
    const r = PickupItemComponent.pickupRadius;
    final x = arenaConfig.minX(r) +
        _rng.nextDouble() * (arenaConfig.maxX(r) - arenaConfig.minX(r));
    final y = arenaConfig.minY(r) +
        _rng.nextDouble() * (arenaConfig.maxY(r) - arenaConfig.minY(r));
    final pos = Vector2(x, y);
    final tooCloseToOrb = _orbs.any((o) => pos.distanceTo(o.position) < 80);
    final tooCloseToBoss =
        boss != null && pos.distanceTo(boss!.position) < 80;
    if (retries > 0 && (tooCloseToBoss || tooCloseToOrb)) {
      return _randomPickupPosition(retries: retries - 1);
    }
    return pos;
  }

  void onPickupCollected(PickupType type, {int collectorIndex = 0}) {
    if (mode.isPvp) {
      _onPickupCollectedPvp(type, collectorIndex);
      return;
    }
    switch (type) {
      case PickupType.apple:
        onOrbHitBoss(60000);
      case PickupType.revolver:
        _revolverBurstsLeft = 6;
        _revolverBurstTimer = 0.0;
        _revolverBurstInterval = 0.38;
        _revolverHoldDuration = 1.2;
        _revolverHoldTimer = _revolverHoldDuration;
        _revolverCollectorIndex = collectorIndex;
      case PickupType.lightning:
        onOrbHitBoss(120000);
        boss?.freezeBoss(1.0);
        triggerShake(intensity: 35, duration: 0.3);
      case PickupType.shield:
        _shieldTimer = 8.0;
      case PickupType.speed:
        for (final o in _orbs) o.speedMultiplier = 2.0;
        _speedTimer = 6.0;
      case PickupType.ice:
        boss?.freezeBoss(3.0);
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
      case PickupType.nuke:
        onOrbHitBoss(400000);
        triggerShake(intensity: 80, duration: 0.55);
      case PickupType.triple:
        _tripleHitsRemaining = 5;
      case PickupType.ghost:
        for (final o in _orbs) o.speedMultiplier = 1.8;
        _speedTimer = 4.0;
        _shieldTimer = 4.0;
      case PickupType.snare:
        boss?.freezeBoss(5.0);
      case PickupType.megaHeal:
        onOrbHitBoss(200000);
      case PickupType.overdrive:
        _overdriveHitsRemaining = 3;
      case PickupType.meteor:
        onOrbHitBoss(600000);
        triggerShake(intensity: 120, duration: 0.7);
      case PickupType.freezeBomb:
        onOrbHitBoss(300000);
        boss?.freezeBoss(6.0);
        triggerShake(intensity: 70, duration: 0.5);
      case PickupType.mystery:
        onPickupCollected(PickupTypeInfo.randomNonMystery(_rng));
    }
  }

  void _onPickupCollectedPvp(PickupType type, int collectorIndex) {
    final opponentIndex = 1 - collectorIndex;
    switch (type) {
      case PickupType.apple:
        onPvpOrbHit(victimIndex: opponentIndex, damage: 40000);
      case PickupType.revolver:
        _selectPvpGun(collectorIndex);
      case PickupType.lightning:
        onPvpOrbHit(victimIndex: opponentIndex, damage: 80000);
        if (opponentIndex < _orbs.length) {
          _orbs[opponentIndex].freeze(1.5);
        }
        triggerShake(intensity: 35, duration: 0.3);
      case PickupType.shield:
        while (_pvpShieldTimers.length <= collectorIndex) _pvpShieldTimers.add(0.0);
        _pvpShieldTimers[collectorIndex] = 8.0;
      case PickupType.speed:
        if (collectorIndex < _orbs.length) {
          _orbs[collectorIndex].speedMultiplier = 2.0;
        }
        _speedTimer = 6.0;
        _speedCollectorIndex = collectorIndex;
      case PickupType.ice:
        if (opponentIndex < _orbs.length) {
          _orbs[opponentIndex].freeze(3.0);
        }
      case PickupType.bomb:
        onPvpOrbHit(victimIndex: opponentIndex, damage: 200000);
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
      case PickupType.nuke:
        onPvpOrbHit(victimIndex: opponentIndex, damage: 280000);
        triggerShake(intensity: 80, duration: 0.55);
      case PickupType.triple:
        _tripleHitsRemaining = 5;
      case PickupType.ghost:
        while (_ghostTimers.length <= collectorIndex) _ghostTimers.add(0.0);
        _ghostTimers[collectorIndex] = 3.0;
      case PickupType.snare:
        if (opponentIndex < _orbs.length) {
          _orbs[opponentIndex].freeze(5.0);
        }
      case PickupType.megaHeal:
        const healAmt = 150000;
        _pvpOrbHp[collectorIndex] =
            (_pvpOrbHp[collectorIndex] + healAmt).clamp(0, pvpOrbMaxHp);
        final healPos = collectorIndex < _orbs.length
            ? _orbs[collectorIndex].position.clone()
            : arenaConfig.center.clone();
        add(DamageNumber(
          position: healPos + Vector2((_rng.nextDouble() - 0.5) * 30, -30),
          damage: healAmt,
          label: '+${DamageNumber.fmt(healAmt)}',
          labelColor: const Color(0xFF44FF88),
          isSmall: false,
          driftX: (_rng.nextDouble() - 0.5) * 40,
        ));
      case PickupType.overdrive:
        _overdriveHitsRemaining = 3;
      case PickupType.meteor:
        onPvpOrbHit(victimIndex: opponentIndex, damage: 450000);
        triggerShake(intensity: 120, duration: 0.7);
      case PickupType.freezeBomb:
        onPvpOrbHit(victimIndex: opponentIndex, damage: 200000);
        if (opponentIndex < _orbs.length) {
          _orbs[opponentIndex].freeze(6.0);
        }
        triggerShake(intensity: 70, duration: 0.5);
      case PickupType.mystery:
        _onPickupCollectedPvp(
            PickupTypeInfo.randomNonMystery(_rng), collectorIndex);
    }
  }

  // ── PVP orb-vs-orb collision ───────────────────────────────────────────────

  void _resolvePvpOrbCollisions(double dt) {
    if (_orbs.length < 2) return;
    final a = _orbs[0];
    final b = _orbs[1];

    // ── 1. Physical bounce — keeps orbs from overlapping ──────────────────────
    final dist    = a.position.distanceTo(b.position);
    final minDist = a.orbRadius + b.orbRadius;

    if (dist < minDist) {
      final n       = dist < 0.001 ? Vector2(1, 0) : (a.position - b.position).normalized();
      final overlap = minDist - dist;
      a.position += n * (overlap * 0.5);
      b.position -= n * (overlap * 0.5);
      a.position = arenaConfig.clamp(a.position, a.orbRadius);
      b.position = arenaConfig.clamp(b.position, b.orbRadius);

      final relVel        = a.velocity - b.velocity;
      final velAlongNormal = relVel.dot(n);
      if (velAlongNormal < 0) {
        const restitution = 0.85;
        final j       = -(1.0 + restitution) * velAlongNormal / 2.0;
        final impulse = n * j;
        a.velocity += impulse;
        b.velocity -= impulse;
        for (final o in [a, b]) {
          if (o.velocity.length < o.speed * 0.3) {
            o.velocity = o.velocity.length < 0.01
                ? n * (o.speed * 0.5)
                : o.velocity.normalized() * (o.speed * 0.4);
          }
        }
      }
    }

    // ── 2. Weapon-tip damage ───────────────────────────────────────────────────
    // An orb only deals damage when its sword tip touches the opponent's body.
    if (_pvpHitCooldown > 0) {
      _pvpHitCooldown -= dt;
      return;
    }

    const tipRadius = 22.0; // extra leniency around the opponent orb body
    final aTip = a.weaponTip;
    final bTip = b.weaponTip;

    final aHitsB = aTip.distanceTo(b.position) < b.orbRadius + tipRadius;
    final bHitsA = bTip.distanceTo(a.position) < a.orbRadius + tipRadius;

    if (aHitsB || bHitsA) {
      _pvpHitCooldown = 0.28;
      if (aHitsB) {
        final dmg = (a.velocity.length * 35).clamp(8000.0, 50000.0).round();
        onPvpOrbHit(victimIndex: 1, damage: dmg);
      }
      if (bHitsA) {
        final dmg = (b.velocity.length * 35).clamp(8000.0, 50000.0).round();
        onPvpOrbHit(victimIndex: 0, damage: dmg);
      }
    }
  }

  // ── Combo system ──────────────────────────────────────────────────────────

  void _incrementCombo() {
    _comboCount++;
    _comboDecayTimer = _comboDecayTime;
  }

  void _tickCombo(double dt) {
    if (_comboCount > 0) {
      _comboDecayTimer -= dt;
      if (_comboDecayTimer <= 0) {
        _comboCount = 0;
        _comboDecayTimer = 0;
      }
    }
  }

  // ── Endless wave escalation ────────────────────────────────────────────────

  void _tickWave(double dt) {
    if (mode.id != 'endless') return;
    _waveTimer -= dt;
    if (_waveTimer > 0) return;
    _waveTimer = 30.0;
    _waveNumber++;
    boss?.waveSpeedBoost = 1.0 + (_waveNumber - 1) * 0.12;
    triggerShake(intensity: 40, duration: 0.45);
    _phaseFlashTimer = 0.5;
    _phaseFlashColor = const Color(0xFFFF44CC);
    HapticFeedback.heavyImpact();
    SoundManager.instance.playWave();
    if (boss != null) {
      add(DamageNumber(
        position: arenaConfig.center.clone() + Vector2(0, -80),
        damage: 0,
        label: '★  WAVE $_waveNumber',
        labelColor: const Color(0xFFFF44CC),
        isSmall: false,
        driftX: 0,
      ));
      add(ShockwaveRingComponent(
        position: boss!.position.clone(),
        gameRef: this,
        bonusDamage: 0,
        ringColor: const Color(0xFFFF44CC),
      ));
    }
  }

  // ── Boss attack system ────────────────────────────────────────────────────

  /// Called by BossComponent when its attack timer fires.
  void spawnBossAttack(Vector2 bossPos, int phase) {
    if (_orbs.isEmpty) return;
    // Aim at the closest orb
    PlayerOrb target = _orbs.first;
    double bestDist = double.infinity;
    for (final o in _orbs) {
      final d = bossPos.distanceTo(o.position);
      if (d < bestDist) { bestDist = d; target = o; }
    }

    if (phase == 3) {
      // Phase 3: two projectiles in a slight spread
      for (int i = 0; i < 2; i++) {
        final spread = (i == 0 ? -0.22 : 0.22);
        final dir = (target.position - bossPos).normalized();
        final angle = atan2(dir.y, dir.x) + spread;
        final spreadTarget = bossPos + Vector2(cos(angle), sin(angle)) * 300;
        add(BossProjectile(
          position: bossPos.clone(),
          target: spreadTarget,
          speedMultiplier: 1.15,
        ));
      }
    } else {
      add(BossProjectile(
        position: bossPos.clone(),
        target: target.position.clone(),
      ));
    }
  }

  /// Called by BossComponent when a phase threshold is crossed.
  void onBossPhaseChange(int phase) {
    final shakeIntensity = phase == 3 ? 70.0 : 45.0;
    triggerShake(intensity: shakeIntensity, duration: 0.5);
    HapticFeedback.heavyImpact();
    SoundManager.instance.playPhaseChange();
    _phaseFlashTimer = 0.6;
    _phaseFlashColor =
        phase == 3 ? const Color(0xFFFF2200) : const Color(0xFFFF4488);

    if (boss != null) {
      add(ShockwaveRingComponent(
        position: boss!.position.clone(),
        gameRef: this,
        bonusDamage: 0,
        ringColor: phase == 3
            ? const Color(0xFFFF2200)
            : const Color(0xFFFF4488),
      ));
      add(DamageNumber(
        position: boss!.position.clone() + Vector2(0, -70),
        damage: 0,
        label: phase == 3 ? '⚠ PHASE 3 — RAGE!' : '⚠ PHASE 2',
        labelColor: phase == 3 ? const Color(0xFFFF2200) : const Color(0xFFFF88CC),
        isSmall: false,
        driftX: 0,
      ));
    }
  }

  // ── Freeze explosion visual ───────────────────────────────────────────────

  void spawnFreezeExplosion(Vector2 position) {
    add(
      ParticleSystemComponent(
        position: position,
        particle: Particle.generate(
          count: 35,
          lifespan: 0.7,
          generator: (i) {
            final angle = _rng.nextDouble() * 2 * pi;
            final spd = Vector2(
              cos(angle) * (80 + _rng.nextDouble() * 280),
              sin(angle) * (80 + _rng.nextDouble() * 280),
            );
            return AcceleratedParticle(
              acceleration: Vector2.zero(),
              speed: spd,
              child: ComputedParticle(
                renderer: (canvas, particle) {
                  final t = particle.progress;
                  final color = Color.lerp(Colors.white, const Color(0xFF88CCFF), t)!
                      .withOpacity(1.0 - t);
                  canvas.drawCircle(
                    Offset.zero,
                    (5.0 * (1.0 - t)).clamp(0.5, 5.0),
                    Paint()
                      ..color = color
                      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
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
    _tickCombo(dt);
    if (_hitFlashTimer > 0) _hitFlashTimer -= dt;
    if (_phaseFlashTimer > 0) _phaseFlashTimer -= dt;

    if (mode.isPvp) {
      _resolvePvpOrbCollisions(dt);
    } else {
      _tickWave(dt);
      // Survival mode: boss regenerates HP each tick
      if (mode.bossRegenPerSecond > 0 && boss != null &&
          !bossDestroyed && bossHp > 0) {
        bossHp = (bossHp + (mode.bossRegenPerSecond * dt).round())
            .clamp(0, bossMaxHp);
      }

      if (mode.timeLimitSeconds > 0) {
        timeLeft -= dt;
        if (timeLeft <= 0) {
          timeLeft = 0;
          playing = false;
          HapticFeedback.heavyImpact();
          SoundManager.instance.playLose();
          Future.delayed(Duration.zero, () => overlays.add('GameOver'));
        }
      }
    }

    super.update(dt);
  }

  // ── Tap-to-nudge ──────────────────────────────────────────────────────────

  @override
  void onTapDown(TapDownEvent event) {
    if (!playing || mode.isPvp) return;
    final tapPos = event.localPosition;
    PlayerOrb? nearest;
    double bestDist = double.infinity;
    for (final o in _orbs) {
      final d = o.position.distanceTo(tapPos);
      if (d < bestDist) {
        bestDist = d;
        nearest = o;
      }
    }
    if (nearest == null) return;
    final dir = tapPos - nearest.position;
    if (dir.length < 0.01) return;
    nearest.velocity += dir.normalized() * 130.0;
    if (nearest.velocity.length > nearest.speed * 1.6) {
      nearest.velocity = nearest.velocity.normalized() * nearest.speed * 1.6;
    }
    HapticFeedback.selectionClick();
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

    // White flash on hit
    if (_hitFlashTimer > 0) {
      final alpha = (_hitFlashTimer / 0.14).clamp(0.0, 1.0) * 0.22;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = Colors.white.withOpacity(alpha),
      );
    }

    // Colored flash on phase change
    if (_phaseFlashTimer > 0) {
      final alpha = (_phaseFlashTimer / 0.6).clamp(0.0, 1.0) * 0.38;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = _phaseFlashColor.withOpacity(alpha),
      );
    }
  }
}

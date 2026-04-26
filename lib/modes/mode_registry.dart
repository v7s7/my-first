import 'package:flutter/material.dart';
import 'game_mode.dart';

class ModeRegistry {
  ModeRegistry._();

  static const List<GameMode> all = [
    // ── No-items mode — pure physics, no pickups ──────────────────────────
    GameMode(
      id: 'classic',
      name: 'CLASSIC',
      subtitle: 'No items · pure skill · 60s',
      accentColor: Color(0xFFCCCCFF),
      bossMaxHp: 1000000,
      timeLimitSeconds: 60.0,
      winOnBossKill: true,
      loseOnTimeExpiry: true,
      scoreMode: ScoreMode.timeRemaining,
      hasPickups: false,
    ),

    // ── Items mode — pickups spawn ─────────────────────────────────────────
    GameMode(
      id: 'battle',
      name: 'BATTLE',
      subtitle: 'Items spawn · use them well',
      accentColor: Color(0xFF00FFEE),
      bossMaxHp: 1000000,
      timeLimitSeconds: 60.0,
      winOnBossKill: true,
      loseOnTimeExpiry: true,
      scoreMode: ScoreMode.timeRemaining,
    ),

    // ── Two balls + items ──────────────────────────────────────────────────
    GameMode(
      id: 'dual_ball',
      name: 'DUAL BALL',
      subtitle: '2 orbs · items · 2M HP · 90s',
      accentColor: Color(0xFF44FF88),
      bossMaxHp: 2000000,
      timeLimitSeconds: 90.0,
      winOnBossKill: true,
      loseOnTimeExpiry: true,
      scoreMode: ScoreMode.timeRemaining,
      orbCount: 2,
    ),

    // ── Survival — boss heals ──────────────────────────────────────────────
    GameMode(
      id: 'survival',
      name: 'SURVIVAL',
      subtitle: 'Boss heals · kill it in time',
      accentColor: Color(0xFFFF44AA),
      bossMaxHp: 1500000,
      timeLimitSeconds: 0.0,
      winOnBossKill: true,
      loseOnTimeExpiry: false,
      scoreMode: ScoreMode.damageDealt,
      bossRegenPerSecond: 4000,
    ),

    // ── Blitz — fast pressure ──────────────────────────────────────────────
    GameMode(
      id: 'blitz',
      name: 'BLITZ',
      subtitle: '2M HP · 30 seconds · items',
      accentColor: Color(0xFFFFDD00),
      bossMaxHp: 2000000,
      timeLimitSeconds: 30.0,
      winOnBossKill: true,
      loseOnTimeExpiry: true,
      scoreMode: ScoreMode.timeRemaining,
    ),

    // ── Endless — max DPS ──────────────────────────────────────────────────
    GameMode(
      id: 'endless',
      name: 'ENDLESS',
      subtitle: 'Max DPS · no time limit',
      accentColor: Color(0xFFFF44CC),
      bossMaxHp: 999000000,
      timeLimitSeconds: 0.0,
      winOnBossKill: false,
      loseOnTimeExpiry: false,
      scoreMode: ScoreMode.damagePerSecond,
    ),

    // ── PVP Duel — no boss, orbs fight each other ─────────────────────
    GameMode(
      id: 'pvp_duel',
      name: 'PVP DUEL',
      subtitle: 'Two orbs · no boss · fight each other',
      accentColor: Color(0xFFFF8800),
      bossMaxHp: 1000000,
      timeLimitSeconds: 0.0,
      winOnBossKill: false,
      loseOnTimeExpiry: false,
      scoreMode: ScoreMode.damageDealt,
      orbCount: 2,
      hasPickups: true,
      isPvp: true,
    ),

    // ── Rush — speed-run, kill the boss ASAP ──────────────────────────
    GameMode(
      id: 'rush',
      name: 'RUSH',
      subtitle: 'Speed-run · 250K HP · pure skill · no items',
      accentColor: Color(0xFF00FFAA),
      bossMaxHp: 250000,
      timeLimitSeconds: 0.0,
      winOnBossKill: true,
      loseOnTimeExpiry: false,
      scoreMode: ScoreMode.damagePerSecond,
      hasPickups: false,
    ),

    // ── Trio — triple orbs vs massive boss ────────────────────────────
    GameMode(
      id: 'trio',
      name: 'TRIO',
      subtitle: '3 orbs · 3M HP boss · 90s · items',
      accentColor: Color(0xFFAA44FF),
      bossMaxHp: 3000000,
      timeLimitSeconds: 90.0,
      winOnBossKill: true,
      loseOnTimeExpiry: true,
      scoreMode: ScoreMode.timeRemaining,
      orbCount: 3,
    ),

    // ── Overtime — boss regenerates fast, out-DPS the regen ──────────
    GameMode(
      id: 'overtime',
      name: 'OVERTIME',
      subtitle: 'Boss heals 12K/s · must out-DPS the regen',
      accentColor: Color(0xFFFF3333),
      bossMaxHp: 2000000,
      timeLimitSeconds: 0.0,
      winOnBossKill: true,
      loseOnTimeExpiry: false,
      scoreMode: ScoreMode.damagePerSecond,
      bossRegenPerSecond: 12000,
    ),

    // ── Gauntlet — 3 orbs, massive HP, items, light regen ─────────────
    GameMode(
      id: 'gauntlet',
      name: 'GAUNTLET',
      subtitle: '3 orbs · 5M HP · 180s · items · boss heals 3K/s',
      accentColor: Color(0xFFFF6600),
      bossMaxHp: 5000000,
      timeLimitSeconds: 180.0,
      winOnBossKill: true,
      loseOnTimeExpiry: true,
      scoreMode: ScoreMode.timeRemaining,
      orbCount: 3,
      bossRegenPerSecond: 3000,
    ),

    // ── Dual Blitz — 2 orbs, 2M HP, 25 seconds ────────────────────────
    GameMode(
      id: 'dual_blitz',
      name: 'DUAL BLITZ',
      subtitle: '2 orbs · 2M HP · 25 seconds · items',
      accentColor: Color(0xFFFFFF00),
      bossMaxHp: 2000000,
      timeLimitSeconds: 25.0,
      winOnBossKill: true,
      loseOnTimeExpiry: true,
      scoreMode: ScoreMode.timeRemaining,
      orbCount: 2,
    ),

    // ── Titan — impossible solo mode, 15M HP, brutal regen ────────────
    GameMode(
      id: 'titan',
      name: 'TITAN',
      subtitle: '15M HP · heals 20K/s · items · can you win?',
      accentColor: Color(0xFF880000),
      bossMaxHp: 15000000,
      timeLimitSeconds: 0.0,
      winOnBossKill: true,
      loseOnTimeExpiry: false,
      scoreMode: ScoreMode.damagePerSecond,
      bossRegenPerSecond: 20000,
    ),
  ];

  static GameMode findById(String id) {
    // Support legacy id 'time_attack' → maps to 'battle'
    final lookupId = id == 'time_attack' || id == 'speed_run' ? 'battle' : id;
    return all.firstWhere((m) => m.id == lookupId, orElse: () => all.first);
  }
}

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
  ];

  static GameMode findById(String id) {
    // Support legacy id 'time_attack' → maps to 'battle'
    final lookupId = id == 'time_attack' || id == 'speed_run' ? 'battle' : id;
    return all.firstWhere((m) => m.id == lookupId, orElse: () => all.first);
  }
}

import 'package:flutter/material.dart';
import 'game_mode.dart';

/// The single place where game modes are declared.
///
/// To add a new mode:
///   Add one [GameMode] entry to [all].
///   No other file needs changing.
class ModeRegistry {
  ModeRegistry._();

  static const List<GameMode> all = [
    GameMode(
      id: 'time_attack',
      name: 'TIME ATTACK',
      subtitle: 'Destroy in 60s',
      accentColor: Color(0xFF00FFEE),
      bossMaxHp: 1000000,
      timeLimitSeconds: 60.0,
      winOnBossKill: true,
      loseOnTimeExpiry: true,
      scoreMode: ScoreMode.timeRemaining,
    ),
    GameMode(
      id: 'blitz',
      name: 'BLITZ',
      subtitle: '2M HP · 30 seconds',
      accentColor: Color(0xFFFFDD00),
      bossMaxHp: 2000000,
      timeLimitSeconds: 30.0,
      winOnBossKill: true,
      loseOnTimeExpiry: true,
      scoreMode: ScoreMode.timeRemaining,
    ),
    GameMode(
      id: 'dual_ball',
      name: 'DUAL BALL',
      subtitle: '2 orbs · 2M HP · 90s',
      accentColor: Color(0xFF44FF88),
      bossMaxHp: 2000000,
      timeLimitSeconds: 90.0,
      winOnBossKill: true,
      loseOnTimeExpiry: true,
      scoreMode: ScoreMode.timeRemaining,
      orbCount: 2,
    ),
    GameMode(
      id: 'survival',
      name: 'SURVIVAL',
      subtitle: 'Boss heals · outlast it',
      accentColor: Color(0xFFFF44AA),
      bossMaxHp: 1500000,
      timeLimitSeconds: 0.0,
      winOnBossKill: true,
      loseOnTimeExpiry: false,
      scoreMode: ScoreMode.damageDealt,
      bossRegenPerSecond: 4000,
    ),
    GameMode(
      id: 'endless',
      name: 'ENDLESS',
      subtitle: 'Max DPS · no limit',
      accentColor: Color(0xFFFF44CC),
      bossMaxHp: 999000000,
      timeLimitSeconds: 0.0,
      winOnBossKill: false,
      loseOnTimeExpiry: false,
      scoreMode: ScoreMode.damagePerSecond,
    ),
    GameMode(
      id: 'speed_run',
      name: 'SPEED RUN',
      subtitle: 'Most dmg in 15s',
      accentColor: Color(0xFFFF6600),
      bossMaxHp: 999000000,
      timeLimitSeconds: 15.0,
      winOnBossKill: false,
      loseOnTimeExpiry: false,
      scoreMode: ScoreMode.damageDealt,
    ),
  ];

  static GameMode findById(String id) =>
      all.firstWhere((m) => m.id == id);
}

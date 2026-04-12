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
    // GameMode(id: 'survival', name: 'SURVIVAL', ...)  ← add here
  ];

  static GameMode findById(String id) =>
      all.firstWhere((m) => m.id == id);
}

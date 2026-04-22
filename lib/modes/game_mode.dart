import 'package:flutter/material.dart';

/// How the result is scored / displayed on the game-over screen.
enum ScoreMode {
  /// Show damage dealt as a percentage of boss max HP.
  damageDealt,

  /// Show time remaining (meaningful when the player kills the boss early).
  timeRemaining,

  /// Show total damage ÷ elapsed seconds.
  damagePerSecond,
}

/// Describes a complete rule-set for one game mode.
///
/// All fields are const — no subclassing needed. BossBallGame reads these
/// fields directly to drive the win/lose/timer logic.
///
/// To add a new mode:
///   Add one [GameMode] entry to [ModeRegistry.all].
///   No other file needs changing.
class GameMode {
  final String id;
  final String name;

  /// One-line description shown on the start-screen mode card.
  final String subtitle;

  final Color accentColor;

  /// Starting and maximum HP of the boss for this mode.
  final int bossMaxHp;

  /// Countdown seconds. Set to 0.0 for an untimed mode (no timer in HUD).
  final double timeLimitSeconds;

  /// If true, depleting the boss to 0 HP triggers a win overlay.
  final bool winOnBossKill;

  /// If true, the timer reaching 0 triggers the game-over overlay.
  /// Set false for score-based modes where time expiry just ends the round
  /// without calling it a "loss".
  final bool loseOnTimeExpiry;

  /// Controls what the game-over screen reports as the primary score.
  final ScoreMode scoreMode;

  /// How many player orbs to spawn (1 = normal, 2 = Dual Ball mode).
  final int orbCount;

  /// HP the boss regenerates per second (0 = no regen). Used for Survival mode.
  final int bossRegenPerSecond;

  const GameMode({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.accentColor,
    required this.bossMaxHp,
    this.timeLimitSeconds = 0.0,
    this.winOnBossKill = true,
    this.loseOnTimeExpiry = true,
    this.scoreMode = ScoreMode.damageDealt,
    this.orbCount = 1,
    this.bossRegenPerSecond = 0,
  });
}

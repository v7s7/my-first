import 'package:flutter/material.dart';
import '../game/player_orb.dart';

/// Contract that every orb type must satisfy.
///
/// [PlayerOrb] owns physics (position, velocity, wall-bounce geometry,
/// boss-collision geometry, base sphere rendering). This class owns
/// everything that makes one orb *distinct*: damage logic, timing,
/// per-orb visual overlays, and metadata shown in the UI.
///
/// To add a new orb:
///   1. Create a file in lib/orbs/ that extends this class.
///   2. Add one entry to OrbRegistry.all.
///   Done — no other file needs changing.
abstract class OrbBehavior {
  // ── Metadata (shown on start-screen cards & HUD) ──────────────────────────

  /// Stable unique key. Survives hot-reload; used by Retry to reconstruct.
  String get id;
  String get name;
  String get description;
  Color get color;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Called once inside [PlayerOrb.onLoad] after the orb is positioned.
  /// Use this to reset any per-round state (counters, timers, etc.).
  void onAttach(PlayerOrb orb) {}

  // ── Event hooks ───────────────────────────────────────────────────────────

  /// Called every game frame while the game is playing.
  /// Override for tick-based effects (laser drain, burn DoT, etc.).
  void onUpdate(double dt, PlayerOrb orb) {}

  /// Called after each elastic wall-bounce (physics already applied).
  void onWallBounce(PlayerOrb orb) {}

  /// Called when the orb collides with the boss (after cooldown guard).
  /// Responsible for calling [orb.gameRef.onOrbHitBoss] with the damage.
  void onBossHit(PlayerOrb orb);

  // ── Rendering ─────────────────────────────────────────────────────────────

  /// Draw orb-specific visuals on top of the shared base sphere.
  ///
  /// The canvas is already translated so (0, 0) is the top-left of the
  /// orb's bounding rect. [radius] is [PlayerOrb.radius]. The circle
  /// centre in local coords is ([cx], [cy]) = (radius, radius).
  void renderOverlay(Canvas canvas, double radius, double cx, double cy) {}
}

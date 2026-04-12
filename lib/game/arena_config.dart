import 'package:flame/components.dart';

/// Arena size presets the player chooses on the start screen.
enum ArenaPreset {
  tiny(0.52, 'TINY', 'Insane pressure'),
  small(0.70, 'SMALL', 'Close quarters'),
  normal(0.87, 'NORMAL', 'Balanced'),
  full(1.0, 'FULL', 'Open arena');

  final double fraction; // fraction of screen covered by the arena
  final String label;
  final String subtitle;
  const ArenaPreset(this.fraction, this.label, this.subtitle);
}

/// Geometry of the playable arena, computed once from screen size + preset.
///
/// All physics components (BossComponent, PlayerOrb) receive this object
/// so every bounce/clamp uses the same coordinate space.
class ArenaConfig {
  static const double wallThickness = 14.0;

  final ArenaPreset preset;

  /// Top-left corner of the outer wall rect in screen coordinates.
  final double left;
  final double top;
  final double width;
  final double height;

  const ArenaConfig({
    required this.preset,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  factory ArenaConfig.fromScreen(Vector2 screenSize, ArenaPreset preset) {
    final w = screenSize.x * preset.fraction;
    final h = screenSize.y * preset.fraction;
    return ArenaConfig(
      preset: preset,
      left: (screenSize.x - w) / 2,
      top: (screenSize.y - h) / 2,
      width: w,
      height: h,
    );
  }

  // ── Inner playable bounds (inside the walls) ───────────────────────────────
  double get innerLeft => left + wallThickness;
  double get innerTop => top + wallThickness;
  double get innerRight => left + width - wallThickness;
  double get innerBottom => top + height - wallThickness;

  /// Center of the arena in screen coordinates.
  Vector2 get center => Vector2(left + width / 2, top + height / 2);

  // ── Per-radius bounce limits for circles ──────────────────────────────────
  double minX(double r) => innerLeft + r;
  double maxX(double r) => innerRight - r;
  double minY(double r) => innerTop + r;
  double maxY(double r) => innerBottom - r;

  /// Clamp a circle centre to stay fully inside the arena.
  Vector2 clamp(Vector2 pos, double r) => Vector2(
        pos.x.clamp(minX(r), maxX(r)),
        pos.y.clamp(minY(r), maxY(r)),
      );
}

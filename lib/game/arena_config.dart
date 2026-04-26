import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';

/// Arena shape presets the player selects on the start screen.
enum ArenaPreset {
  tiny(0.52,  'TINY',      'Insane pressure'),
  small(0.70, 'SMALL',     'Close quarters'),
  normal(0.87,'NORMAL',    'Balanced'),
  full(1.0,   'FULL',      'Open arena'),
  pillarsSmall(0.87, 'SQ·SM', 'Small squares'),
  pillarsBig(1.0,   'SQ·LG', 'Big squares'),
  corridors(0.87,   'LANES',  'S-curve maze'),
  maze(1.0,         'MAZE',   'L-wall maze'),
  bumpers(0.87,     'BUMPERS','Corner bumpers'),
  cross(1.0,        'CROSS',  '+ shaped walls'),
  ring(1.0,         'RING',   'Inner square ring');

  final double fraction; // fraction of screen covered by outer wall rect
  final String label;
  final String subtitle;
  const ArenaPreset(this.fraction, this.label, this.subtitle);
}

/// Geometry of the playable arena computed once from screen size + preset.
///
/// Every physics component (BossComponent, PlayerOrb) receives this object
/// so all bounce/clamp logic uses the same coordinate space.
///
/// Obstacle rects (internal walls / pillars) are stored here and used for
/// both visual ArenaWall placement and circle-vs-AABB physics.
class ArenaConfig {
  static const double wallThickness = 14.0;

  final ArenaPreset preset;
  final double left;
  final double top;
  final double width;
  final double height;

  /// Internal wall / pillar rects in screen coordinates.
  final List<Rect> obstacles;

  ArenaConfig._({
    required this.preset,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.obstacles,
  });

  factory ArenaConfig.fromScreen(Vector2 screenSize, ArenaPreset preset,
      {bool square = false}) {
    final w = screenSize.x * preset.fraction;
    final h = square ? w : screenSize.y * preset.fraction;
    final l = (screenSize.x - w) / 2;
    final t = (screenSize.y - h) / 2;
    return ArenaConfig._(
      preset: preset,
      left: l,
      top: t,
      width: w,
      height: h,
      obstacles: _buildObstacles(preset, l, t, w, h),
    );
  }

  // ── Inner playable bounds (inside the border walls) ───────────────────────

  double get innerLeft   => left + wallThickness;
  double get innerTop    => top  + wallThickness;
  double get innerRight  => left + width  - wallThickness;
  double get innerBottom => top  + height - wallThickness;

  Vector2 get center => Vector2(left + width / 2, top + height / 2);

  // ── Per-radius bounce limits for circles ─────────────────────────────────

  double minX(double r) => innerLeft   + r;
  double maxX(double r) => innerRight  - r;
  double minY(double r) => innerTop    + r;
  double maxY(double r) => innerBottom - r;

  /// Clamp a circle centre to stay fully inside the arena border.
  Vector2 clamp(Vector2 pos, double r) => Vector2(
        pos.x.clamp(minX(r), maxX(r)),
        pos.y.clamp(minY(r), maxY(r)),
      );

  // ── Obstacle collision ────────────────────────────────────────────────────

  /// Tests [pos] (circle centre, radius [r], velocity [vel]) against all
  /// obstacle rects.  Mutates [pos] and [vel] in-place on collision.
  /// Returns true if any bounce occurred.
  bool bounceOffObstacles(Vector2 pos, Vector2 vel, double r) {
    if (obstacles.isEmpty) return false;
    bool bounced = false;
    for (final rect in obstacles) {
      // Closest point on the AABB to the circle centre
      final cx = pos.x.clamp(rect.left, rect.right);
      final cy = pos.y.clamp(rect.top,  rect.bottom);
      final dx = pos.x - cx;
      final dy = pos.y - cy;
      final distSq = dx * dx + dy * dy;

      if (distSq >= r * r) continue; // no contact

      if (distSq > 1e-6) {
        // Normal surface collision
        final dist = sqrt(distSq);
        final nx = dx / dist;
        final ny = dy / dist;
        // Push circle out of the obstacle
        pos.x += nx * (r - dist);
        pos.y += ny * (r - dist);
        // Reflect velocity along normal (only when approaching)
        final dot = vel.x * nx + vel.y * ny;
        if (dot < 0) {
          vel.x -= 2 * dot * nx;
          vel.y -= 2 * dot * ny;
        }
      } else {
        // Degenerate: centre is exactly on or inside rect — eject nearest face
        final dL = pos.x - rect.left  + r;
        final dR = rect.right  - pos.x + r;
        final dT = pos.y - rect.top   + r;
        final dB = rect.bottom - pos.y + r;
        if (dL <= dR && dL <= dT && dL <= dB) {
          pos.x = rect.left  - r; vel.x = -vel.x.abs();
        } else if (dR <= dT && dR <= dB) {
          pos.x = rect.right + r; vel.x =  vel.x.abs();
        } else if (dT <= dB) {
          pos.y = rect.top   - r; vel.y = -vel.y.abs();
        } else {
          pos.y = rect.bottom + r; vel.y =  vel.y.abs();
        }
      }
      bounced = true;
    }
    return bounced;
  }

  // ── Obstacle layout builder ───────────────────────────────────────────────

  static List<Rect> _buildObstacles(
      ArenaPreset preset, double al, double at, double aw, double ah) {
    const t  = wallThickness;
    final iL = al + t;        // inner left  (screen x)
    final iT = at + t;        // inner top   (screen y)
    final iW = aw - t * 2;    // inner width
    final iH = ah - t * 2;    // inner height

    switch (preset) {
      // ── Four small pillars at the quadrant centres ──────────────────────
      case ArenaPreset.pillarsSmall:
        const half = 18.0; // half-size of each pillar
        return [
          Rect.fromCenter(center: Offset(iL + iW * 0.25, iT + iH * 0.25), width: half * 2, height: half * 2),
          Rect.fromCenter(center: Offset(iL + iW * 0.75, iT + iH * 0.25), width: half * 2, height: half * 2),
          Rect.fromCenter(center: Offset(iL + iW * 0.25, iT + iH * 0.75), width: half * 2, height: half * 2),
          Rect.fromCenter(center: Offset(iL + iW * 0.75, iT + iH * 0.75), width: half * 2, height: half * 2),
        ];

      // ── Two large pillars left/right of centre ──────────────────────────
      case ArenaPreset.pillarsBig:
        const half = 40.0;
        return [
          Rect.fromCenter(center: Offset(iL + iW * 0.25, iT + iH * 0.5), width: half * 2, height: half * 2),
          Rect.fromCenter(center: Offset(iL + iW * 0.75, iT + iH * 0.5), width: half * 2, height: half * 2),
        ];

      // ── Two horizontal lane dividers (S-curve — gaps alternate sides) ───
      case ArenaPreset.corridors:
        const wh = 16.0; // wall thickness
        return [
          // Top divider: left edge → 58% width, at 37% height
          Rect.fromLTWH(iL,               iT + iH * 0.37 - wh / 2, iW * 0.58, wh),
          // Bottom divider: 42% → right edge, at 63% height
          Rect.fromLTWH(iL + iW * 0.42,  iT + iH * 0.63 - wh / 2, iW * 0.58, wh),
        ];

      // ── Two mirrored L-shaped walls ─────────────────────────────────────
      case ArenaPreset.maze:
        const wh = 16.0;
        return [
          // Top-left L — horizontal arm
          Rect.fromLTWH(iL,               iT + iH * 0.30,           iW * 0.44, wh),
          // Top-left L — vertical drop
          Rect.fromLTWH(iL + iW * 0.44 - wh, iT + iH * 0.30,       wh, iH * 0.26),
          // Bottom-right L — vertical rise
          Rect.fromLTWH(iL + iW * 0.56,   iT + iH * 0.44,           wh, iH * 0.26),
          // Bottom-right L — horizontal arm
          Rect.fromLTWH(iL + iW * 0.56,   iT + iH * 0.70 - wh,      iW * 0.44, wh),
        ];

      // ── Corner bumpers — 5 square bumpers (4 corners + centre) ────────
      case ArenaPreset.bumpers:
        const bh = 22.0; // half-size
        return [
          Rect.fromCenter(center: Offset(iL + iW * 0.20, iT + iH * 0.20), width: bh * 2, height: bh * 2),
          Rect.fromCenter(center: Offset(iL + iW * 0.80, iT + iH * 0.20), width: bh * 2, height: bh * 2),
          Rect.fromCenter(center: Offset(iL + iW * 0.20, iT + iH * 0.80), width: bh * 2, height: bh * 2),
          Rect.fromCenter(center: Offset(iL + iW * 0.80, iT + iH * 0.80), width: bh * 2, height: bh * 2),
          Rect.fromCenter(center: Offset(iL + iW * 0.50, iT + iH * 0.50), width: bh * 2, height: bh * 2),
        ];

      // ── + shaped walls — 4 arms radiating from centre with gaps ────────
      case ArenaPreset.cross:
        const wh = 18.0; // arm thickness (half)
        const gap = 0.18; // fraction of inner dimension left as opening
        return [
          // Left arm
          Rect.fromLTWH(iL,                     iT + iH * 0.5 - wh, iW * (0.5 - gap), wh * 2),
          // Right arm
          Rect.fromLTWH(iL + iW * (0.5 + gap),  iT + iH * 0.5 - wh, iW * (0.5 - gap), wh * 2),
          // Top arm
          Rect.fromLTWH(iL + iW * 0.5 - wh,     iT,                  wh * 2, iH * (0.5 - gap)),
          // Bottom arm
          Rect.fromLTWH(iL + iW * 0.5 - wh,     iT + iH * (0.5 + gap), wh * 2, iH * (0.5 - gap)),
        ];

      // ── Inner square ring — frame in the centre of the arena ───────────
      case ArenaPreset.ring:
        const wh = 14.0; // ring wall thickness
        const ri = 0.28; // ring inner fraction (28% from edges)
        final rL = iL + iW * ri;
        final rT = iT + iH * ri;
        final rR = iL + iW * (1 - ri);
        final rB = iT + iH * (1 - ri);
        return [
          Rect.fromLTWH(rL,          rT,          rR - rL,      wh),     // top
          Rect.fromLTWH(rL,          rB - wh,     rR - rL,      wh),     // bottom
          Rect.fromLTWH(rL,          rT + wh,     wh, rB - rT - wh * 2), // left
          Rect.fromLTWH(rR - wh,     rT + wh,     wh, rB - rT - wh * 2), // right
        ];

      default:
        return [];
    }
  }
}

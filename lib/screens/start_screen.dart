import 'package:flutter/material.dart';
import '../orbs/orb_behavior.dart';
import '../orbs/orb_registry.dart';
import '../modes/game_mode.dart';
import '../modes/mode_registry.dart';
import '../game/arena_config.dart';
import 'game_screen.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  OrbBehavior  _selectedOrb   = OrbRegistry.all.first;
  GameMode     _selectedMode  = ModeRegistry.all.first;
  ArenaPreset  _selectedArena = ArenaPreset.normal;
  int          _selectedHp    = 1000000;

  static const List<int> _hpPresets = [100000, 500000, 1000000, 5000000, 10000000];

  void _startGame() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          orbBehavior: _selectedOrb,
          mode: _selectedMode,
          arenaPreset: _selectedArena,
          customBossHp: _selectedHp,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080812),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Title ───────────────────────────────────────────────
                  Center(
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF00FFEE), Color(0xFF0088FF)],
                      ).createShader(bounds),
                      child: const Text(
                        'BOSS BALL BLITZ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      _selectedMode.subtitle.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0x66FFFFFF),
                        fontSize: 11,
                        letterSpacing: 3,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ── 01 · ORB ────────────────────────────────────────────
                  _StepHeader(step: '01', label: 'ORB'),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: OrbRegistry.all.map((b) => _OrbCard(
                        behavior: b,
                        selected: _selectedOrb.id == b.id,
                        onTap: () => setState(() => _selectedOrb = b),
                      )).toList(),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── 02 · MODE ───────────────────────────────────────────
                  _StepHeader(step: '02', label: 'MODE'),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ModeRegistry.all.map((m) => _ModeCard(
                        mode: m,
                        selected: _selectedMode.id == m.id,
                        onTap: () => setState(() => _selectedMode = m),
                      )).toList(),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── 03 · ARENA ──────────────────────────────────────────
                  _StepHeader(step: '03', label: 'ARENA'),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ArenaPreset.values.map((p) => _ArenaCard(
                        preset: p,
                        selected: _selectedArena == p,
                        onTap: () => setState(() => _selectedArena = p),
                      )).toList(),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── 04 · BOSS HP ─────────────────────────────────────────
                  _StepHeader(step: '04', label: 'BOSS HP'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _hpPresets.map((hp) => _HpChip(
                      hp: hp,
                      selected: _selectedHp == hp,
                      onTap: () => setState(() => _selectedHp = hp),
                    )).toList(),
                  ),

                  const SizedBox(height: 44),

                  // ── START button ─────────────────────────────────────────
                  Center(
                    child: GestureDetector(
                      onTap: _startGame,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00DDCC),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'START',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF080812),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 8,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Step header ──────────────────────────────────────────────────────────────

class _StepHeader extends StatelessWidget {
  final String step;
  final String label;

  const _StepHeader({required this.step, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          step,
          style: const TextStyle(
            color: Color(0x55FFFFFF),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xCCFFFFFF),
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Divider(color: Color(0x22FFFFFF), thickness: 1),
        ),
      ],
    );
  }
}

// ── Orb card ─────────────────────────────────────────────────────────────────

class _OrbCard extends StatelessWidget {
  final OrbBehavior behavior;
  final bool        selected;
  final VoidCallback onTap;

  const _OrbCard({
    required this.behavior,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = behavior.color;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        width: 88,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: selected
              ? Color.fromARGB(30, color.red, color.green, color.blue)
              : const Color(0x0CFFFFFF),
          border: Border.all(
            color: selected ? color : const Color(0x33FFFFFF),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GlowCircle(color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              behavior.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? color : const Color(0xAAFFFFFF),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mode card ─────────────────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  final GameMode   mode;
  final bool       selected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = mode.accentColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        width: 110,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: selected
              ? Color.fromARGB(30, color.red, color.green, color.blue)
              : const Color(0x0CFFFFFF),
          border: Border.all(
            color: selected ? color : const Color(0x33FFFFFF),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mode.name,
              style: TextStyle(
                color: selected ? color : const Color(0xAAFFFFFF),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              mode.subtitle,
              style: const TextStyle(
                color: Color(0x77FFFFFF),
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Arena card ────────────────────────────────────────────────────────────────

class _ArenaCard extends StatelessWidget {
  final ArenaPreset preset;
  final bool        selected;
  final VoidCallback onTap;

  const _ArenaCard({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  Color get _color {
    switch (preset) {
      case ArenaPreset.tiny:         return const Color(0xFFFF4444);
      case ArenaPreset.small:        return const Color(0xFFFFAA00);
      case ArenaPreset.normal:       return const Color(0xFF00FFEE);
      case ArenaPreset.full:         return const Color(0xFF8844FF);
      case ArenaPreset.pillarsSmall: return const Color(0xFF44BBFF);
      case ArenaPreset.pillarsBig:   return const Color(0xFF0088FF);
      case ArenaPreset.corridors:    return const Color(0xFFFF44AA);
      case ArenaPreset.maze:         return const Color(0xFF44FF88);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        width: 78,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: selected
              ? Color.fromARGB(30, color.red, color.green, color.blue)
              : const Color(0x0CFFFFFF),
          border: Border.all(
            color: selected ? color : const Color(0x33FFFFFF),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 34,
              height: 42,
              child: CustomPaint(
                painter: _ArenaPreviewPainter(
                  preset: preset,
                  color: selected ? color : const Color(0x66FFFFFF),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              preset.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? color : const Color(0x88FFFFFF),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              preset.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0x66FFFFFF),
                fontSize: 8,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Boss HP chip ──────────────────────────────────────────────────────────────

class _HpChip extends StatelessWidget {
  final int  hp;
  final bool selected;
  final VoidCallback onTap;

  const _HpChip({required this.hp, required this.selected, required this.onTap});

  static const Color _accent = Color(0xFFFF6633);

  static String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(0)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(0)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected ? const Color(0x22FF6633) : const Color(0x0CFFFFFF),
          border: Border.all(
            color: selected ? _accent : const Color(0x33FFFFFF),
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          _fmt(hp),
          style: TextStyle(
            color: selected ? _accent : const Color(0x77FFFFFF),
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

// ── Orb color dot ─────────────────────────────────────────────────────────────

class _GlowCircle extends StatelessWidget {
  final Color  color;
  final double size;

  const _GlowCircle({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GlowCirclePainter(color: color),
    );
  }
}

class _GlowCirclePainter extends CustomPainter {
  final Color color;
  const _GlowCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 2;
    canvas.drawCircle(c, r, Paint()..color = color);
    canvas.drawCircle(
      Offset(c.dx - r * 0.28, c.dy - r * 0.28),
      r * 0.28,
      Paint()..color = const Color(0x55FFFFFF),
    );
  }

  @override
  bool shouldRepaint(_GlowCirclePainter old) => old.color != color;
}

// ── Arena preview painter ─────────────────────────────────────────────────────

class _ArenaPreviewPainter extends CustomPainter {
  final ArenaPreset preset;
  final Color       color;

  const _ArenaPreviewPainter({required this.preset, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final f  = preset.fraction;
    final bW = size.width  * f;
    final bH = size.height * f;
    final l  = (size.width  - bW) / 2;
    final t  = (size.height - bH) / 2;
    final rect = Rect.fromLTWH(l, t, bW, bH);

    canvas.drawRect(rect,
      Paint()
        ..color = color.withOpacity(0.08),
    );
    canvas.drawRect(rect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final wallPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.square;
    final pillPaint = Paint()..color = color;

    switch (preset) {
      case ArenaPreset.pillarsSmall:
        for (final cx in [l + bW * 0.25, l + bW * 0.75]) {
          for (final cy in [t + bH * 0.25, t + bH * 0.75]) {
            canvas.drawRect(
              Rect.fromCenter(center: Offset(cx, cy), width: 7, height: 7),
              pillPaint,
            );
          }
        }
      case ArenaPreset.pillarsBig:
        for (final cx in [l + bW * 0.25, l + bW * 0.75]) {
          canvas.drawRect(
            Rect.fromCenter(center: Offset(cx, t + bH * 0.5), width: 14, height: 14),
            pillPaint,
          );
        }
      case ArenaPreset.corridors:
        canvas.drawLine(Offset(l + 1, t + bH * 0.37), Offset(l + bW * 0.58, t + bH * 0.37), wallPaint);
        canvas.drawLine(Offset(l + bW * 0.42, t + bH * 0.63), Offset(l + bW - 1, t + bH * 0.63), wallPaint);
      case ArenaPreset.maze:
        canvas.drawLine(Offset(l + 1, t + bH * 0.30), Offset(l + bW * 0.44, t + bH * 0.30), wallPaint);
        canvas.drawLine(Offset(l + bW * 0.44, t + bH * 0.30), Offset(l + bW * 0.44, t + bH * 0.56), wallPaint);
        canvas.drawLine(Offset(l + bW * 0.56, t + bH * 0.44), Offset(l + bW * 0.56, t + bH * 0.70), wallPaint);
        canvas.drawLine(Offset(l + bW * 0.56, t + bH * 0.70), Offset(l + bW - 1, t + bH * 0.70), wallPaint);
      default:
        break;
    }
  }

  @override
  bool shouldRepaint(_ArenaPreviewPainter old) =>
      old.preset != preset || old.color != color;
}

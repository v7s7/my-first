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

class _StartScreenState extends State<StartScreen>
    with SingleTickerProviderStateMixin {
  OrbBehavior _selectedOrb = OrbRegistry.all.first;
  GameMode _selectedMode = ModeRegistry.all.first;
  ArenaPreset _selectedArena = ArenaPreset.normal;
  int _selectedHp = 1000000;

  static const List<int> _hpPresets = [
    100000,
    500000,
    1000000,
    5000000,
    10000000,
  ];

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080812),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Title
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF00FFEE), Color(0xFF0088FF)],
                    ).createShader(bounds),
                    child: const Text(
                      'BOSS BALL\nBLITZ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 5,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Live subtitle from selected mode
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _selectedMode.subtitle.toUpperCase(),
                      key: ValueKey(_selectedMode.id),
                      style: const TextStyle(
                        color: Color(0x88FFFFFF),
                        fontSize: 11,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // ── Orb selector ──────────────────────────────────────────
                  const Text(
                    'SELECT ORB',
                    style: TextStyle(
                      color: Color(0xAAFFFFFF),
                      fontSize: 13,
                      letterSpacing: 4,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Auto-populated from OrbRegistry — add an orb class and
                  // register it; a card appears here automatically.
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: OrbRegistry.all
                          .map((b) => _OrbCard(
                                behavior: b,
                                selected: _selectedOrb.id == b.id,
                                onTap: () => setState(() => _selectedOrb = b),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Mode selector ─────────────────────────────────────────
                  const Text(
                    'SELECT MODE',
                    style: TextStyle(
                      color: Color(0xAAFFFFFF),
                      fontSize: 13,
                      letterSpacing: 4,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Auto-populated from ModeRegistry.
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: ModeRegistry.all
                          .map((m) => _ModeCard(
                                mode: m,
                                selected: _selectedMode.id == m.id,
                                onTap: () =>
                                    setState(() => _selectedMode = m),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Arena size selector ───────────────────────────────────
                  const Text(
                    'ARENA SIZE',
                    style: TextStyle(
                      color: Color(0xAAFFFFFF),
                      fontSize: 13,
                      letterSpacing: 4,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: ArenaPreset.values
                          .map((p) => _ArenaCard(
                                preset: p,
                                selected: _selectedArena == p,
                                onTap: () =>
                                    setState(() => _selectedArena = p),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Boss HP selector ──────────────────────────────────────
                  const Text(
                    'BOSS HP',
                    style: TextStyle(
                      color: Color(0xAAFFFFFF),
                      fontSize: 13,
                      letterSpacing: 4,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: _hpPresets
                        .map((hp) => _HpChip(
                              hp: hp,
                              selected: _selectedHp == hp,
                              onTap: () => setState(() => _selectedHp = hp),
                            ))
                        .toList(),
                  ),

                  const SizedBox(height: 40),

                  // ── Start button ──────────────────────────────────────────
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, child) =>
                        Transform.scale(scale: _pulseAnim.value, child: child),
                    child: GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GameScreen(
                            orbBehavior: _selectedOrb,
                            mode: _selectedMode,
                            arenaPreset: _selectedArena,
                            customBossHp: _selectedHp,
                          ),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 52, vertical: 18),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: const Color(0xFF00FFEE), width: 2),
                          borderRadius: BorderRadius.circular(4),
                          color: const Color(0x1400FFEE),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x4400FFEE),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Text(
                          'START',
                          style: TextStyle(
                            color: Color(0xFF00FFEE),
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Orb card ────────────────────────────────────────────────────────────────

class _OrbCard extends StatelessWidget {
  final OrbBehavior behavior;
  final bool selected;
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(14),
        width: 96,
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? color : const Color(0x44FFFFFF),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: selected
              ? Color.fromARGB(28, color.red, color.green, color.blue)
              : Colors.transparent,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Color.fromARGB(80, color.red, color.green, color.blue),
                    blurRadius: 16,
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: const Size(38, 38),
              painter: _GlowCirclePainter(color: color),
            ),
            const SizedBox(height: 8),
            Text(
              behavior.name,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              behavior.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0x88FFFFFF),
                fontSize: 9,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mode card ────────────────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  final GameMode mode;
  final bool selected;
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        width: 96,
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? color : const Color(0x44FFFFFF),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: selected
              ? Color.fromARGB(28, color.red, color.green, color.blue)
              : Colors.transparent,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Color.fromARGB(80, color.red, color.green, color.blue),
                    blurRadius: 16,
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              mode.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              mode.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0x88FFFFFF),
                fontSize: 9,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared orb-icon painter ──────────────────────────────────────────────────

class _GlowCirclePainter extends CustomPainter {
  final Color color;
  const _GlowCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 3;
    canvas.drawCircle(
      c,
      r + 6,
      Paint()
        ..color = Color.fromARGB(80, color.red, color.green, color.blue)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(c, r, Paint()..color = color);
    canvas.drawCircle(
      Offset(c.dx - r * 0.3, c.dy - r * 0.3),
      r * 0.3,
      Paint()..color = const Color(0x66FFFFFF),
    );
  }

  @override
  bool shouldRepaint(covariant _GlowCirclePainter old) =>
      old.color != color;
}

// ── Arena size card ──────────────────────────────────────────────────────────

class _ArenaCard extends StatelessWidget {
  final ArenaPreset preset;
  final bool selected;
  final VoidCallback onTap;

  const _ArenaCard({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  // Accent color per preset
  Color get _color {
    switch (preset) {
      case ArenaPreset.tiny:   return const Color(0xFFFF4444);
      case ArenaPreset.small:  return const Color(0xFFFFAA00);
      case ArenaPreset.normal: return const Color(0xFF00FFEE);
      case ArenaPreset.full:   return const Color(0xFF8844FF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    // Visual box preview: a small rectangle scaled to the preset fraction
    final boxW = 32.0 * preset.fraction;
    final boxH = 44.0 * preset.fraction;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        width: 88,
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? color : const Color(0x44FFFFFF),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: selected
              ? Color.fromARGB(28, color.red, color.green, color.blue)
              : Colors.transparent,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Color.fromARGB(
                        80, color.red, color.green, color.blue),
                    blurRadius: 16,
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Miniature arena preview box
            SizedBox(
              width: 36,
              height: 48,
              child: Center(
                child: Container(
                  width: boxW,
                  height: boxH,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selected ? color : const Color(0x66FFFFFF),
                      width: 1.5,
                    ),
                    color: selected
                        ? Color.fromARGB(
                            20, color.red, color.green, color.blue)
                        : Colors.transparent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              preset.label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              preset.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0x88FFFFFF),
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

// ── Boss HP chip ─────────────────────────────────────────────────────────────

class _HpChip extends StatelessWidget {
  final int hp;
  final bool selected;
  final VoidCallback onTap;

  const _HpChip({
    required this.hp,
    required this.selected,
    required this.onTap,
  });

  static const Color _accent = Color(0xFFFF6633);

  static String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(0)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? _accent : const Color(0x44FFFFFF),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
          color: selected
              ? const Color(0x22FF6633)
              : Colors.transparent,
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x44FF6633),
                    blurRadius: 12,
                  )
                ]
              : [],
        ),
        child: Text(
          _fmt(hp),
          style: TextStyle(
            color: selected ? _accent : const Color(0x88FFFFFF),
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

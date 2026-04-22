import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../orbs/orb_behavior.dart';
import '../orbs/orb_registry.dart';
import '../modes/game_mode.dart';
import '../modes/mode_registry.dart';
import '../game/arena_config.dart';
import '../widgets/orb_image_picker.dart';
import 'game_screen.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  OrbBehavior  _selectedOrb   = OrbRegistry.all.first;
  GameMode     _selectedMode  = ModeRegistry.all[1]; // default: BATTLE
  ArenaPreset  _selectedArena = ArenaPreset.normal;
  int          _selectedHp    = 1000000;

  // Fighter skins
  Uint8List? _ball1Image;
  Uint8List? _ball2Image;
  Uint8List? _bossImage;

  static const List<int> _hpPresets = [100000, 500000, 1000000, 5000000, 10000000];

  bool get _isDualBall => _selectedMode.orbCount >= 2;

  void _startGame() {
    final orbImages = _isDualBall
        ? [_ball1Image, _ball2Image]
        : [_ball1Image];

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          orbBehavior: _selectedOrb,
          mode: _selectedMode,
          arenaPreset: _selectedArena,
          customBossHp: _selectedHp,
          orbImageBytes: orbImages,
          bossImageBytes: _bossImage,
        ),
      ),
    );
  }

  Future<void> _pickImage(int slot) async {
    final bytes = await pickAndCropOrbImage(context);
    if (bytes == null || !mounted) return;
    setState(() {
      if (slot == 0) _ball1Image = bytes;
      else if (slot == 1) _ball2Image = bytes;
      else _bossImage = bytes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060610),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTitle(),
                  const SizedBox(height: 36),

                  // ── VS Fighter Select ──────────────────────────────────────
                  _buildFighterSelect(),
                  const SizedBox(height: 40),

                  // ── Game Mode ─────────────────────────────────────────────
                  _SectionLabel(label: 'GAME MODE', hint: 'choose your rules'),
                  const SizedBox(height: 12),
                  _buildModeGrid(),
                  const SizedBox(height: 36),

                  // ── Orb Type ──────────────────────────────────────────────
                  _SectionLabel(label: 'ORB TYPE', hint: 'your weapon'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 96,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: OrbRegistry.all.map((b) => _OrbCard(
                        behavior: b,
                        selected: _selectedOrb.id == b.id,
                        onTap: () => setState(() => _selectedOrb = b),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Arena ─────────────────────────────────────────────────
                  _SectionLabel(label: 'ARENA', hint: 'battlefield'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 90,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: ArenaPreset.values.map((p) => _ArenaCard(
                        preset: p,
                        selected: _selectedArena == p,
                        onTap: () => setState(() => _selectedArena = p),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Boss HP ───────────────────────────────────────────────
                  _SectionLabel(label: 'BOSS HP', hint: 'difficulty'),
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
                  const SizedBox(height: 48),

                  // ── START ─────────────────────────────────────────────────
                  _buildStartButton(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Title ────────────────────────────────────────────────────────────────

  Widget _buildTitle() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [Color(0xFF00FFEE), Color(0xFF0055FF)],
          ).createShader(b),
          child: const Text(
            'BOSS BALL BLITZ',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 5,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'FACE BATTLE ARENA',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0x44FFFFFF),
            fontSize: 11,
            letterSpacing: 6,
          ),
        ),
      ],
    );
  }

  // ── Fighter Select (VS layout) ───────────────────────────────────────────

  Widget _buildFighterSelect() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0x08FFFFFF),
        border: Border.all(color: const Color(0x18FFFFFF)),
      ),
      child: Column(
        children: [
          const Text(
            'TAP CIRCLES TO ADD FACES  —  MESSI VS CR7 STYLE',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0x55FFFFFF),
              fontSize: 9,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 18),
          _isDualBall
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _FighterSlot(
                      image: _ball1Image,
                      label: 'BALL 1',
                      color: const Color(0xFF00FFEE),
                      onTap: () => _pickImage(0),
                    ),
                    const SizedBox(width: 8),
                    _FighterSlot(
                      image: _ball2Image,
                      label: 'BALL 2',
                      color: const Color(0xFF44FF88),
                      onTap: () => _pickImage(1),
                      size: 64,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: _VsText(),
                    ),
                    _FighterSlot(
                      image: _bossImage,
                      label: 'BOSS',
                      color: const Color(0xFFFF4488),
                      onTap: () => _pickImage(2),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _FighterSlot(
                      image: _ball1Image,
                      label: 'YOU',
                      color: const Color(0xFF00FFEE),
                      onTap: () => _pickImage(0),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 28),
                      child: _VsText(),
                    ),
                    _FighterSlot(
                      image: _bossImage,
                      label: 'BOSS',
                      color: const Color(0xFFFF4488),
                      onTap: () => _pickImage(2),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  // ── Mode grid (2 columns) ─────────────────────────────────────────────────

  Widget _buildModeGrid() {
    final modes = ModeRegistry.all;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.6,
      ),
      itemCount: modes.length,
      itemBuilder: (_, i) => _ModeCard(
        mode: modes[i],
        selected: _selectedMode.id == modes[i].id,
        onTap: () => setState(() => _selectedMode = modes[i]),
      ),
    );
  }

  // ── START button ──────────────────────────────────────────────────────────

  Widget _buildStartButton() {
    final c = _selectedMode.accentColor;
    return GestureDetector(
      onTap: _startGame,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: c,
          boxShadow: [
            BoxShadow(
              color: Color.fromARGB(70, c.red, c.green, c.blue),
              blurRadius: 28,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Text(
          'START  GAME',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF06060F),
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 8,
          ),
        ),
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final String hint;
  const _SectionLabel({required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xCCFFFFFF),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          hint,
          style: const TextStyle(
            color: Color(0x44FFFFFF),
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: Color(0x1AFFFFFF))),
      ],
    );
  }
}

// ── VS text ────────────────────────────────────────────────────────────────

class _VsText extends StatelessWidget {
  const _VsText();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'VS',
      style: TextStyle(
        color: Color(0xFFFF3355),
        fontSize: 26,
        fontWeight: FontWeight.w900,
        letterSpacing: 3,
        shadows: [Shadow(color: Color(0x88FF3355), blurRadius: 16)],
      ),
    );
  }
}

// ── Fighter slot (photo circle) ────────────────────────────────────────────

class _FighterSlot extends StatelessWidget {
  final Uint8List? image;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final double size;

  const _FighterSlot({
    required this.image,
    required this.label,
    required this.color,
    required this.onTap,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = image != null;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: hasImage ? color : const Color(0x33FFFFFF),
                width: hasImage ? 2.5 : 1.5,
              ),
              color: const Color(0x0AFFFFFF),
              boxShadow: hasImage
                  ? [
                      BoxShadow(
                        color: Color.fromARGB(55, color.red, color.green, color.blue),
                        blurRadius: 18,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: hasImage
                ? ClipOval(child: Image.memory(image!, fit: BoxFit.cover))
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        color: color.withOpacity(0.5),
                        size: size * 0.35,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ADD',
                        style: TextStyle(
                          color: color.withOpacity(0.4),
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: hasImage ? color : const Color(0x55FFFFFF),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mode card (2-column grid) ──────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  final GameMode mode;
  final bool selected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  String get _emoji {
    switch (mode.id) {
      case 'classic':   return '🎯';
      case 'battle':    return '⚔️';
      case 'dual_ball': return '⚡';
      case 'survival':  return '💀';
      case 'blitz':     return '🔥';
      case 'endless':   return '∞';
      default:          return '🎮';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = mode.accentColor;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: selected
              ? Color.fromARGB(38, c.red, c.green, c.blue)
              : const Color(0x07FFFFFF),
          border: Border.all(
            color: selected ? c : const Color(0x1EFFFFFF),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(
                  color: Color.fromARGB(40, c.red, c.green, c.blue),
                  blurRadius: 14,
                )]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_emoji, style: const TextStyle(fontSize: 22)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mode.name,
                  style: TextStyle(
                    color: selected ? c : const Color(0xBBFFFFFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  mode.subtitle,
                  style: const TextStyle(
                    color: Color(0x66FFFFFF),
                    fontSize: 9,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Orb card ───────────────────────────────────────────────────────────────

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
            color: selected ? color : const Color(0x22FFFFFF),
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
                color: selected ? color : const Color(0x99FFFFFF),
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

// ── Arena card ─────────────────────────────────────────────────────────────

class _ArenaCard extends StatelessWidget {
  final ArenaPreset preset;
  final bool selected;
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
            color: selected ? color : const Color(0x22FFFFFF),
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
                  color: selected ? color : const Color(0x55FFFFFF),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              preset.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? color : const Color(0x77FFFFFF),
                fontSize: 9,
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

// ── Boss HP chip ───────────────────────────────────────────────────────────

class _HpChip extends StatelessWidget {
  final int hp;
  final bool selected;
  final VoidCallback onTap;

  const _HpChip({required this.hp, required this.selected, required this.onTap});

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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected ? const Color(0x22FF6633) : const Color(0x0CFFFFFF),
          border: Border.all(
            color: selected ? _accent : const Color(0x22FFFFFF),
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          _fmt(hp),
          style: TextStyle(
            color: selected ? _accent : const Color(0x66FFFFFF),
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

// ── Glow circle (orb preview) ──────────────────────────────────────────────

class _GlowCircle extends StatelessWidget {
  final Color color;
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

// ── Arena preview painter ──────────────────────────────────────────────────

class _ArenaPreviewPainter extends CustomPainter {
  final ArenaPreset preset;
  final Color color;
  const _ArenaPreviewPainter({required this.preset, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final f  = preset.fraction;
    final bW = size.width  * f;
    final bH = size.height * f;
    final l  = (size.width  - bW) / 2;
    final t  = (size.height - bH) / 2;
    final rect = Rect.fromLTWH(l, t, bW, bH);

    canvas.drawRect(rect, Paint()..color = color.withOpacity(0.10));
    canvas.drawRect(rect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);

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

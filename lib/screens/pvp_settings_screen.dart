import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../game/arena_config.dart';
import '../game/pickup_type.dart';
import '../modes/game_mode.dart';
import '../orbs/orb_behavior.dart';
import '../widgets/orb_image_picker.dart';
import 'game_screen.dart';

class PvpSettingsScreen extends StatefulWidget {
  final OrbBehavior orbBehavior;
  final GameMode mode;

  const PvpSettingsScreen({
    super.key,
    required this.orbBehavior,
    required this.mode,
  });

  @override
  State<PvpSettingsScreen> createState() => _PvpSettingsScreenState();
}

class _PvpSettingsScreenState extends State<PvpSettingsScreen> {
  // ── Colour palette ─────────────────────────────────────────────────────────
  static const List<Color> _palette = [
    Color(0xFF00FFEE), // cyan
    Color(0xFFFF4488), // pink
    Color(0xFFFF8800), // orange
    Color(0xFF44FF88), // green
    Color(0xFF8844FF), // purple
    Color(0xFFFFCC00), // yellow
    Color(0xFFFF3333), // red
    Color(0xFF4488FF), // blue
    Color(0xFFFF44FF), // magenta
    Color(0xFFFFFFFF), // white
  ];

  static const List<int> _hpPresets = [
    100000, 500000, 1000000, 5000000, 10000000,
  ];

  // ── State ──────────────────────────────────────────────────────────────────
  Color _color1 = const Color(0xFF00FFEE);
  Color _color2 = const Color(0xFFFF4488);
  Uint8List? _image1;
  Uint8List? _image2;
  int _hp = 1000000;
  ArenaPreset _arena = ArenaPreset.normal;
  late Set<PickupType> _allowedItems;

  @override
  void initState() {
    super.initState();
    _allowedItems = Set.from(PickupType.values);
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _pickImage(int slot) async {
    final bytes = await pickAndCropOrbImage(context);
    if (bytes == null || !mounted) return;
    setState(() {
      if (slot == 0) _image1 = bytes;
      else _image2 = bytes;
    });
  }

  void _startBattle() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          orbBehavior: widget.orbBehavior,
          mode: widget.mode,
          arenaPreset: _arena,
          customBossHp: _hp,
          orbImageBytes: [_image1, _image2],
          pvpOrbColors: [_color1, _color2],
          pvpAllowedItems: _allowedItems,
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060610),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      _buildFighterRow(),
                      const SizedBox(height: 16),
                      _buildSettingsCard(),
                      const SizedBox(height: 16),
                      _buildItemsPanel(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
            _buildStartButton(),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.arrow_back_ios_new,
                color: Color(0x66FFFFFF), size: 18),
          ),
        ),
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [Color(0xFFFF8800), Color(0xFFFF3355)],
          ).createShader(b),
          child: const Text(
            'PVP DUEL SETUP',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
        ),
      ],
    );
  }

  // ── Fighter row ────────────────────────────────────────────────────────────

  Widget _buildFighterRow() {
    return Row(
      children: [
        Expanded(child: _buildFighterCard(slot: 0, color: _color1, image: _image1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            children: const [
              Text(
                'VS',
                style: TextStyle(
                  color: Color(0xFFFF3355),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  shadows: [Shadow(color: Color(0x88FF3355), blurRadius: 14)],
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildFighterCard(slot: 1, color: _color2, image: _image2)),
      ],
    );
  }

  Widget _buildFighterCard({
    required int slot,
    required Color color,
    required Uint8List? image,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Color.fromARGB(18, color.red, color.green, color.blue),
        border: Border.all(
          color: color.withOpacity(0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Text(
            'BALL ${slot + 1}',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          // Avatar circle
          GestureDetector(
            onTap: () => _pickImage(slot),
            child: Stack(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.15),
                    border: Border.all(color: color, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: image != null
                      ? ClipOval(child: Image.memory(image, fit: BoxFit.cover))
                      : Icon(Icons.add_photo_alternate_outlined,
                          color: color.withOpacity(0.5), size: 30),
                ),
                if (image != null)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        if (slot == 0) _image1 = null;
                        else _image2 = null;
                      }),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF2244),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF060610), width: 1.5),
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 11),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Colour palette
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: _palette.map((c) {
              final selected = slot == 0 ? _color1 == c : _color2 == c;
              return GestureDetector(
                onTap: () => setState(() {
                  if (slot == 0) _color1 = c;
                  else _color2 = c;
                }),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c,
                    border: Border.all(
                      color: selected ? Colors.white : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: selected
                        ? [BoxShadow(color: c.withOpacity(0.7), blurRadius: 8)]
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Settings card (HP + Arena) ─────────────────────────────────────────────

  Widget _buildSettingsCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0x08FFFFFF),
        border: Border.all(color: const Color(0x18FFFFFF)),
      ),
      child: Column(
        children: [
          _SettingRow(
            icon: Icons.favorite_border,
            label: 'ORB HP',
            value: _fmtHp(_hp),
            valueColor: const Color(0xFFFF6633),
            onTap: _openHpSheet,
            isFirst: true,
          ),
          _Divider(),
          _SettingRow(
            icon: Icons.grid_view_outlined,
            label: 'ARENA',
            value: _arena.label,
            valueColor: const Color(0xFF00FFEE),
            onTap: _openArenaSheet,
            isLast: true,
          ),
        ],
      ),
    );
  }

  void _openHpSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _BottomSheetWrap(
        title: 'ORB HP',
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _hpPresets.map((hp) => _HpChip(
              hp: hp,
              selected: _hp == hp,
              onTap: () {
                setState(() => _hp = hp);
                Navigator.pop(context);
              },
            )).toList(),
          ),
        ),
      ),
    );
  }

  void _openArenaSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _BottomSheetWrap(
        title: 'ARENA',
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: ArenaPreset.values.map((p) => _ArenaChip(
              preset: p,
              selected: _arena == p,
              onTap: () {
                setState(() => _arena = p);
                Navigator.pop(context);
              },
            )).toList(),
          ),
        ),
      ),
    );
  }

  // ── Items panel ────────────────────────────────────────────────────────────

  Widget _buildItemsPanel() {
    final allOn = _allowedItems.length == PickupType.values.length;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0x08FFFFFF),
        border: Border.all(color: const Color(0x18FFFFFF)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ITEMS IN PLAY',
                  style: TextStyle(
                    color: Color(0xAAFFFFFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  if (allOn) {
                    _allowedItems.clear();
                  } else {
                    _allowedItems = Set.from(PickupType.values);
                  }
                }),
                child: Text(
                  allOn ? 'DISABLE ALL' : 'ENABLE ALL',
                  style: const TextStyle(
                    color: Color(0x66FFFFFF),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PickupType.values.map((t) {
              final on = _allowedItems.contains(t);
              final c = t.ringColor;
              return GestureDetector(
                onTap: () => setState(() {
                  if (on) _allowedItems.remove(t);
                  else _allowedItems.add(t);
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: on
                        ? Color.fromARGB(40, c.red, c.green, c.blue)
                        : const Color(0x08FFFFFF),
                    border: Border.all(
                      color: on ? c.withOpacity(0.8) : const Color(0x22FFFFFF),
                      width: on ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(t.emoji,
                          style: TextStyle(
                              fontSize: 14,
                              color: on ? null : const Color(0x44FFFFFF))),
                      const SizedBox(width: 5),
                      Text(
                        t.displayName,
                        style: TextStyle(
                          color: on ? c : const Color(0x44FFFFFF),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Start button ───────────────────────────────────────────────────────────

  Widget _buildStartButton() {
    const c = Color(0xFFFF8800);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: GestureDetector(
        onTap: _allowedItems.isEmpty ? null : _startBattle,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: _allowedItems.isEmpty
                ? const Color(0xFF333344)
                : c,
            boxShadow: _allowedItems.isEmpty
                ? null
                : [
                    BoxShadow(
                      color: c.withOpacity(0.45),
                      blurRadius: 28,
                      spreadRadius: 2,
                    ),
                  ],
          ),
          child: Text(
            _allowedItems.isEmpty ? 'ENABLE AT LEAST 1 ITEM' : '⚔  START BATTLE',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _allowedItems.isEmpty
                  ? const Color(0x44FFFFFF)
                  : const Color(0xFF06060F),
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 5,
            ),
          ),
        ),
      ),
    );
  }

  static String _fmtHp(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(0)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return '$n';
  }
}

// ── Reusable widgets ───────────────────────────────────────────────────────

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  const _SettingRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: const Color(0x66FFFFFF), size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xAAFFFFFF),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right,
                color: Color(0x44FFFFFF), size: 18),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: Color(0x12FFFFFF)),
    );
  }
}

class _BottomSheetWrap extends StatelessWidget {
  final String title;
  final Widget child;
  const _BottomSheetWrap({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.90,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: const Color(0x44FFFFFF),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xCCFFFFFF),
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(controller: ctrl, child: child),
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }
}

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
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
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
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _ArenaChip extends StatelessWidget {
  final ArenaPreset preset;
  final bool selected;
  final VoidCallback onTap;

  const _ArenaChip({required this.preset, required this.selected, required this.onTap});

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
        child: Text(
          preset.label,
          style: TextStyle(
            color: selected ? color : const Color(0x77FFFFFF),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

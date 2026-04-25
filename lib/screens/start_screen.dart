import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../orbs/orb_behavior.dart';
import '../orbs/orb_registry.dart';
import '../modes/game_mode.dart';
import '../modes/mode_registry.dart';
import '../game/arena_config.dart';
import '../widgets/orb_image_picker.dart';
import 'game_screen.dart';
import 'pvp_settings_screen.dart';

// ── Persistence keys ──────────────────────────────────────────────────────────
const _kModeId    = 'mode_id';
const _kOrbId     = 'orb_id';
const _kArena     = 'arena_preset';
const _kBossHp    = 'boss_hp';

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

  Uint8List? _ball1Image;
  Uint8List? _ball2Image;
  Uint8List? _bossImage;

  static const List<int> _hpPresets = [
    100000, 500000, 1000000, 5000000, 10000000,
  ];

  bool get _isPvp      => _selectedMode.isPvp;
  bool get _isDualBall => _selectedMode.orbCount >= 2;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _selectedMode  = ModeRegistry.findById(prefs.getString(_kModeId) ?? 'battle');
      _selectedOrb   = OrbRegistry.findById(prefs.getString(_kOrbId)   ?? OrbRegistry.all.first.id);
      final arenaName = prefs.getString(_kArena) ?? 'normal';
      _selectedArena = ArenaPreset.values.firstWhere(
        (p) => p.name == arenaName,
        orElse: () => ArenaPreset.normal,
      );
      _selectedHp = prefs.getInt(_kBossHp) ?? 1000000;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kModeId, _selectedMode.id);
    await prefs.setString(_kOrbId,  _selectedOrb.id);
    await prefs.setString(_kArena,  _selectedArena.name);
    await prefs.setInt(_kBossHp,    _selectedHp);
  }

  void _startGame() {
    // PVP mode → go to dedicated settings screen first
    if (_isPvp) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PvpSettingsScreen(
            orbBehavior: _selectedOrb,
            mode: _selectedMode,
          ),
        ),
      );
      return;
    }

    final orbImages = _isDualBall ? [_ball1Image, _ball2Image] : [_ball1Image];
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

  // ── Settings bottom sheets ─────────────────────────────────────────────────

  void _openModeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => _BottomSheetWrap(
        title: 'GAME MODE',
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.6,
          ),
          itemCount: ModeRegistry.all.length,
          itemBuilder: (_, i) {
            final m = ModeRegistry.all[i];
            return _ModeCard(
              mode: m,
              selected: _selectedMode.id == m.id,
              onTap: () {
                setState(() => _selectedMode = m);
                _savePrefs();
                Navigator.pop(context);
              },
            );
          },
        ),
      ),
    );
  }

  void _openOrbSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => _BottomSheetWrap(
        title: 'ORB TYPE',
        child: ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: OrbRegistry.all.length,
          itemBuilder: (_, i) {
            final b = OrbRegistry.all[i];
            final selected = _selectedOrb.id == b.id;
            final color = b.color;
            return GestureDetector(
              onTap: () {
                setState(() => _selectedOrb = b);
                _savePrefs();
                Navigator.pop(context);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: selected
                      ? Color.fromARGB(35, color.red, color.green, color.blue)
                      : const Color(0x08FFFFFF),
                  border: Border.all(
                    color: selected ? color : const Color(0x18FFFFFF),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    _GlowCircle(color: color, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.name,
                            style: TextStyle(
                              color: selected ? color : const Color(0xCCFFFFFF),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            b.description,
                            style: const TextStyle(
                              color: Color(0x55FFFFFF),
                              fontSize: 10,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check_circle, color: color, size: 18),
                  ],
                ),
              ),
            );
          },
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
            children: ArenaPreset.values.map((p) => _ArenaCard(
              preset: p,
              selected: _selectedArena == p,
              onTap: () {
                setState(() => _selectedArena = p);
                _savePrefs();
                Navigator.pop(context);
              },
            )).toList(),
          ),
        ),
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
        title: _isPvp ? 'ORB HP' : 'BOSS HP',
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _hpPresets.map((hp) => _HpChip(
              hp: hp,
              selected: _selectedHp == hp,
              onTap: () {
                setState(() => _selectedHp = hp);
                _savePrefs();
                Navigator.pop(context);
              },
            )).toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060610),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTitle(),
                        const SizedBox(height: 28),
                        _buildFighterSelect(),
                        const SizedBox(height: 28),
                        _buildSettingsList(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Sticky PLAY button
            _buildPlayButton(),
          ],
        ),
      ),
    );
  }

  // ── Title ──────────────────────────────────────────────────────────────────

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

  // ── Fighter circles ────────────────────────────────────────────────────────

  Widget _buildFighterSelect() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0x08FFFFFF),
        border: Border.all(color: const Color(0x18FFFFFF)),
      ),
      child: Column(
        children: [
          Text(
            _isPvp
                ? 'TAP CIRCLES TO ADD FIGHTER FACES'
                : 'TAP CIRCLES TO ADD FACES  —  MESSI VS CR7 STYLE',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0x55FFFFFF),
              fontSize: 9,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 18),
          _isPvp
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _FighterSlot(
                      image: _ball1Image,
                      label: 'BALL 1',
                      color: const Color(0xFF00FFEE),
                      onTap: () => _pickImage(0),
                      onRemove: _ball1Image != null
                          ? () => setState(() => _ball1Image = null)
                          : null,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 28),
                      child: _VsText(),
                    ),
                    _FighterSlot(
                      image: _ball2Image,
                      label: 'BALL 2',
                      color: const Color(0xFFFF8800),
                      onTap: () => _pickImage(1),
                      onRemove: _ball2Image != null
                          ? () => setState(() => _ball2Image = null)
                          : null,
                    ),
                  ],
                )
              : _isDualBall
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _FighterSlot(
                          image: _ball1Image,
                          label: 'BALL 1',
                          color: const Color(0xFF00FFEE),
                          onTap: () => _pickImage(0),
                          onRemove: _ball1Image != null
                              ? () => setState(() => _ball1Image = null)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        _FighterSlot(
                          image: _ball2Image,
                          label: 'BALL 2',
                          color: const Color(0xFF44FF88),
                          onTap: () => _pickImage(1),
                          onRemove: _ball2Image != null
                              ? () => setState(() => _ball2Image = null)
                              : null,
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
                          onRemove: _bossImage != null
                              ? () => setState(() => _bossImage = null)
                              : null,
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
                          onRemove: _ball1Image != null
                              ? () => setState(() => _ball1Image = null)
                              : null,
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
                          onRemove: _bossImage != null
                              ? () => setState(() => _bossImage = null)
                              : null,
                        ),
                      ],
                    ),
        ],
      ),
    );
  }

  // ── Settings list (tappable rows) ─────────────────────────────────────────

  Widget _buildSettingsList() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0x08FFFFFF),
        border: Border.all(color: const Color(0x18FFFFFF)),
      ),
      child: Column(
        children: [
          _SettingRow(
            icon: Icons.sports_esports_outlined,
            label: 'GAME MODE',
            value: _selectedMode.name,
            valueColor: _selectedMode.accentColor,
            onTap: _openModeSheet,
            isFirst: true,
          ),
          _Divider(),
          _SettingRow(
            icon: Icons.circle_outlined,
            label: 'ORB TYPE',
            value: _selectedOrb.name,
            valueColor: _selectedOrb.color,
            onTap: _openOrbSheet,
          ),
          _Divider(),
          _SettingRow(
            icon: Icons.grid_view_outlined,
            label: 'ARENA',
            value: _selectedArena.label,
            valueColor: const Color(0xFF00FFEE),
            onTap: _openArenaSheet,
          ),
          _Divider(),
          _SettingRow(
            icon: Icons.favorite_border,
            label: _isPvp ? 'ORB HP' : 'BOSS HP',
            value: _fmtHp(_selectedHp),
            valueColor: const Color(0xFFFF6633),
            onTap: _openHpSheet,
            isLast: true,
          ),
        ],
      ),
    );
  }

  // ── PLAY button (sticky bottom) ────────────────────────────────────────────

  Widget _buildPlayButton() {
    final c = _selectedMode.accentColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: GestureDetector(
        onTap: _startGame,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: c,
            boxShadow: [
              BoxShadow(
                color: Color.fromARGB(80, c.red, c.green, c.blue),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Text(
            '▶  PLAY GAME',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF06060F),
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 6,
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

// ── Bottom sheet wrapper ───────────────────────────────────────────────────

class _BottomSheetWrap extends StatelessWidget {
  final String title;
  final Widget child;
  const _BottomSheetWrap({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
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

// ── Setting row ────────────────────────────────────────────────────────────

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
            const Icon(Icons.chevron_right, color: Color(0x44FFFFFF), size: 18),
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

// ── Fighter slot (photo circle with optional X remove button) ──────────────

class _FighterSlot extends StatelessWidget {
  final Uint8List? image;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final double size;

  const _FighterSlot({
    required this.image,
    required this.label,
    required this.color,
    required this.onTap,
    this.onRemove,
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
          Stack(
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
                            color: Color.fromARGB(
                                55, color.red, color.green, color.blue),
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
              // X remove button — only when image is set
              if (hasImage && onRemove != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF2244),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF060610),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
                ),
            ],
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

// ── Mode card (used in bottom sheet grid) ─────────────────────────────────

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
      case 'pvp_duel':  return '🥊';
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

// ── Arena card ──────────────────────────────────────────────────────────────

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
        width: 80,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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

// ── Boss HP chip ────────────────────────────────────────────────────────────

class _HpChip extends StatelessWidget {
  final int hp;
  final bool selected;
  final VoidCallback onTap;

  const _HpChip({required this.hp, required this.selected, required this.onTap});

  static const Color _accent = Color(0xFFFF6633);

  static const Map<int, String> _difficulty = {
    100000:   'EASY',
    500000:   'MEDIUM',
    1000000:  'NORMAL',
    5000000:  'HARD',
    10000000: 'INSANE',
  };

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _fmt(hp),
              style: TextStyle(
                color: selected ? _accent : const Color(0x66FFFFFF),
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            if (_difficulty.containsKey(hp))
              Text(
                _difficulty[hp]!,
                style: TextStyle(
                  color: selected
                      ? _accent.withOpacity(0.65)
                      : const Color(0x33FFFFFF),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Glow circle (orb preview) ───────────────────────────────────────────────

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

// ── Arena preview painter ───────────────────────────────────────────────────

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

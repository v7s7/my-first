import 'package:flutter/material.dart';
import '../game/game_state.dart';
import 'game_screen.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen>
    with SingleTickerProviderStateMixin {
  OrbType _selected = OrbType.basic;
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
        child: Center(
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
              const Text(
                'DESTROY THE BOSS IN 60 SECONDS',
                style: TextStyle(
                  color: Color(0x88FFFFFF),
                  fontSize: 11,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 48),

              // Orb selector label
              const Text(
                'SELECT ORB',
                style: TextStyle(
                  color: Color(0xAAFFFFFF),
                  fontSize: 13,
                  letterSpacing: 4,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 18),

              // Orb cards
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: OrbType.values
                    .map((t) => _OrbCard(
                          type: t,
                          selected: _selected == t,
                          onTap: () => setState(() => _selected = t),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 52),

              // Start button
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, child) => Transform.scale(
                  scale: _pulseAnim.value,
                  child: child,
                ),
                child: GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GameScreen(orbType: _selected),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 52, vertical: 18),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF00FFEE), width: 2),
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
    );
  }
}

class _OrbCard extends StatelessWidget {
  final OrbType type;
  final bool selected;
  final VoidCallback onTap;

  const _OrbCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  Color get _color => Color(OrbConfig.configs[type]!.color);
  String get _name => OrbConfig.configs[type]!.name;
  String get _desc => OrbConfig.configs[type]!.description;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(14),
        width: 96,
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? _color : const Color(0x44FFFFFF),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: selected
              ? Color.fromARGB(28, _color.red, _color.green, _color.blue)
              : Colors.transparent,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Color.fromARGB(80, _color.red, _color.green, _color.blue),
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
              painter: _OrbIconPainter(color: _color),
            ),
            const SizedBox(height: 8),
            Text(
              _name,
              style: TextStyle(
                color: _color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _desc,
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

class _OrbIconPainter extends CustomPainter {
  final Color color;
  const _OrbIconPainter({required this.color});

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
  bool shouldRepaint(covariant _OrbIconPainter old) => old.color != color;
}

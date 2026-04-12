enum OrbType { basic, laser, combo }

class OrbConfig {
  final String name;
  final String description;
  final int color;

  const OrbConfig({
    required this.name,
    required this.description,
    required this.color,
  });

  static const Map<OrbType, OrbConfig> configs = {
    OrbType.basic: OrbConfig(
      name: 'BASIC',
      description: '1K dmg\nper hit',
      color: 0xFF00FFEE,
    ),
    OrbType.laser: OrbConfig(
      name: 'LASER',
      description: '10K dmg\nbeam burst',
      color: 0xFFFF4400,
    ),
    OrbType.combo: OrbConfig(
      name: 'COMBO',
      description: 'x2/x4/x8\nbounce mult',
      color: 0xFFCC44FF,
    ),
  };
}

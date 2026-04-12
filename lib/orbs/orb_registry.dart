import 'orb_behavior.dart';
import 'basic_orb.dart';
import 'laser_orb.dart';
import 'combo_orb.dart';

/// The single place where orb types are declared.
///
/// To add a new orb:
///   1. import it here
///   2. add one entry to [all]
///
/// Everything else (start-screen cards, PlayerOrb factory) reads from here.
class OrbRegistry {
  OrbRegistry._();

  static final List<OrbBehavior> all = [
    BasicOrb(),
    LaserOrb(),
    ComboOrb(),
    // ThunderOrb(),   ← add line here to register a new orb
  ];

  static OrbBehavior findById(String id) =>
      all.firstWhere((b) => b.id == id);
}

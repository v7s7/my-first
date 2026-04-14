import 'orb_behavior.dart';
import 'basic_orb.dart';
import 'laser_orb.dart';
import 'combo_orb.dart';
import 'chain_orb.dart';
import 'fire_orb.dart';
import 'prismatic_orb.dart';
import 'nova_star_orb.dart';
import 'void_orb.dart';
import 'hook_orb.dart';
import 'splitter_orb.dart';
import 'zapper_orb.dart';
import 'clone_orb.dart';
import 'black_hole_orb.dart';
import 'rainbow_orb.dart';
import 'plasma_orb.dart';
import 'comet_orb.dart';
/// The single place where orb types are declared.
///
/// To add a new orb:
///   1. Create a file in lib/orbs/ that extends OrbBehavior.
///   2. Import it here and add one entry to [all].
///
/// Everything else (start-screen cards, PlayerOrb) reads from this list.
class OrbRegistry {
  OrbRegistry._();

  static final List<OrbBehavior> all = [
    BasicOrb(),
    LaserOrb(),
    ComboOrb(),
    ChainOrb(),
    FireOrb(),
    PrismaticOrb(),
    NovaStarOrb(),
    VoidOrb(),
    HookOrb(),
    SplitterOrb(),
    ZapperOrb(),
    CloneOrb(),
    BlackHoleOrb(),
    RainbowOrb(),
    PlasmaOrb(),
    CometOrb(),
  ];

  static OrbBehavior findById(String id) =>
      all.firstWhere((b) => b.id == id);
}

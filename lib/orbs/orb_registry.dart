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
import 'mine_orb.dart';
import 'ice_orb.dart';
import 'fire_trap_orb.dart';
import 'comet_orb.dart';
import 'plasma_orb.dart';
import 'rainbow_orb.dart';
import 'turbo_orb.dart';
import 'berserker_orb.dart';
import 'bouncer_orb.dart';
import 'reflect_orb.dart';
import 'phantom_orb.dart';
import 'crystal_orb.dart';
import 'chain_bomb_orb.dart';
import 'fibonacci_orb.dart';
import 'prime_orb.dart';
import 'pi_orb.dart';
import 'golden_orb.dart';
import 'factorial_orb.dart';

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
    MineOrb(),
    IceOrb(),
    FireTrapOrb(),
    CometOrb(),
    PlasmaOrb(),
    RainbowOrb(),
    TurboOrb(),
    BerserkerOrb(),
    BouncerOrb(),
    ReflectOrb(),
    PhantomOrb(),
    CrystalOrb(),
    ChainBombOrb(),
    FibonacciOrb(),
    PrimeOrb(),
    PiOrb(),
    GoldenOrb(),
    FactorialOrb(),
  ];

  static OrbBehavior findById(String id) =>
      all.firstWhere((b) => b.id == id, orElse: () => all.first);
}

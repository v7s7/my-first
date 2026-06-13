import 'package:flame_audio/flame_audio.dart';

/// Manages all in-game sound effects.
///
/// Sound effect files live in assets/audio/:
///   hit.wav       — boss hit (normal)
///   crit.wav      — critical hit
///   wall.wav      — wall bounce
///   phase.wav     — boss phase transition
///   win.wav       — victory
///   lose.wav      — game over / time up
///   wave.wav      — endless wave start
///
/// All methods are silent no-ops if audio files are missing.
class SoundManager {
  SoundManager._();
  static final SoundManager instance = SoundManager._();

  bool _ready = false;

  static const _hit   = 'hit.wav';
  static const _crit  = 'crit.wav';
  static const _wall  = 'wall.wav';
  static const _phase = 'phase.wav';
  static const _win   = 'win.wav';
  static const _lose  = 'lose.wav';
  static const _wave  = 'wave.wav';

  Future<void> init() async {
    try {
      await FlameAudio.audioCache.loadAll(
        [_hit, _crit, _wall, _phase, _win, _lose, _wave],
      );
      _ready = true;
    } catch (_) {
      // Audio files not present — silently skip all sounds.
    }
  }

  void playHit({bool isCrit = false}) =>
      _play(isCrit ? _crit : _hit, isCrit ? 0.95 : 0.70);

  void playWall()         => _play(_wall,  0.30);
  void playPhaseChange()  => _play(_phase, 1.00);
  void playWin()          => _play(_win,   1.00);
  void playLose()         => _play(_lose,  1.00);
  void playWave()         => _play(_wave,  0.90);

  void _play(String name, double volume) {
    if (!_ready) return;
    try {
      FlameAudio.play(name, volume: volume);
    } catch (_) {}
  }
}

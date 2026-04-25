import 'package:flame_audio/flame_audio.dart';

/// Manages all in-game sound effects.
///
/// Add the following .ogg files to assets/audio/ to enable sounds:
///   hit.ogg       — boss hit (normal)
///   crit.ogg      — critical hit
///   wall.ogg      — wall bounce
///   phase.ogg     — boss phase transition
///   win.ogg       — victory
///   lose.ogg      — game over / time up
///   wave.ogg      — endless wave start
///
/// All methods are silent no-ops if audio files are missing.
class SoundManager {
  SoundManager._();
  static final SoundManager instance = SoundManager._();

  bool _ready = false;

  static const _hit   = 'hit.ogg';
  static const _crit  = 'crit.ogg';
  static const _wall  = 'wall.ogg';
  static const _phase = 'phase.ogg';
  static const _win   = 'win.ogg';
  static const _lose  = 'lose.ogg';
  static const _wave  = 'wave.ogg';

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

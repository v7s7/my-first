import 'dart:math';
import 'package:flutter/material.dart';

enum PickupType {
  apple,
  revolver,
  lightning,
  shield,
  speed,
  ice,
  bomb,
  vortex,
  star,
  mystery,
  rapid,    // halves hit cooldown for 6s
  magnet,   // homes orb toward boss for 8s
  barrier,  // 3× damage for 4 hits
  nuke,     // 💥 massive instant damage
  triple,   // 🎯 3× damage for next 5 hits
  ghost,    // 👻 PVP: invincible 3s / boss: speed+shield 4s
  snare,    // 🕸️ long freeze on boss/opponent
  megaHeal, // 💊 large direct hit / heal boost
  overdrive, // 🚀 next 3 hits deal 5× damage
  meteor,    // ☄️ 600K instant nuke — rarest drop
  freezeBomb, // ❄️💣 freeze 6s + 300K instant damage
  timeWarp,   // 🕰️ bullet time — boss & projectiles slow to 20% for 3s
}

extension PickupTypeInfo on PickupType {
  String get emoji {
    switch (this) {
      case PickupType.apple:    return '🍎';
      case PickupType.revolver: return '🔫';
      case PickupType.lightning:return '⚡';
      case PickupType.shield:   return '🛡️';
      case PickupType.speed:    return '💨';
      case PickupType.ice:      return '🧊';
      case PickupType.bomb:     return '💣';
      case PickupType.vortex:   return '🌀';
      case PickupType.star:     return '⭐';
      case PickupType.mystery:  return '❓';
      case PickupType.rapid:    return '🔥';
      case PickupType.magnet:   return '🧲';
      case PickupType.barrier:  return '💎';
      case PickupType.nuke:     return '💥';
      case PickupType.triple:   return '🎯';
      case PickupType.ghost:    return '👻';
      case PickupType.snare:    return '🕸️';
      case PickupType.megaHeal:  return '💊';
      case PickupType.overdrive: return '🚀';
      case PickupType.meteor:    return '☄️';
      case PickupType.freezeBomb:return '🧊💣';
      case PickupType.timeWarp: return '🕰️';
    }
  }

  String get displayName {
    switch (this) {
      case PickupType.apple:    return 'HEAL';
      case PickupType.revolver: return 'REVOLVER';
      case PickupType.lightning:return 'LIGHTNING';
      case PickupType.shield:   return 'SHIELD';
      case PickupType.speed:    return 'SPEED';
      case PickupType.ice:      return 'FREEZE';
      case PickupType.bomb:     return 'BOMB';
      case PickupType.vortex:   return 'VORTEX';
      case PickupType.star:     return 'STAR x3';
      case PickupType.mystery:  return '???';
      case PickupType.rapid:    return 'RAPID';
      case PickupType.magnet:   return 'MAGNET';
      case PickupType.barrier:  return 'BARRIER';
      case PickupType.nuke:     return 'NUKE';
      case PickupType.triple:   return 'TRIPLE x5';
      case PickupType.ghost:    return 'GHOST';
      case PickupType.snare:    return 'SNARE';
      case PickupType.megaHeal:  return 'MEGA HEAL';
      case PickupType.overdrive: return 'OVERDRIVE';
      case PickupType.meteor:    return 'METEOR';
      case PickupType.freezeBomb:return 'FREEZE BOMB';
      case PickupType.timeWarp: return 'TIME WARP';
    }
  }

  Color get ringColor {
    switch (this) {
      case PickupType.apple:    return const Color(0xFF66FF44);
      case PickupType.revolver: return const Color(0xFFCCCCCC);
      case PickupType.lightning:return const Color(0xFFFFEE00);
      case PickupType.shield:   return const Color(0xFF44AAFF);
      case PickupType.speed:    return const Color(0xFF00FFEE);
      case PickupType.ice:      return const Color(0xFF88DDFF);
      case PickupType.bomb:     return const Color(0xFFFF4422);
      case PickupType.vortex:   return const Color(0xFFAA44FF);
      case PickupType.star:     return const Color(0xFFFFCC00);
      case PickupType.mystery:  return const Color(0xFFFF88FF);
      case PickupType.rapid:    return const Color(0xFFFF6600);
      case PickupType.magnet:   return const Color(0xFFFF44CC);
      case PickupType.barrier:  return const Color(0xFF44FFEE);
      case PickupType.nuke:     return const Color(0xFFFF3300);
      case PickupType.triple:   return const Color(0xFFFF44FF);
      case PickupType.ghost:    return const Color(0xFF88FFFF);
      case PickupType.snare:    return const Color(0xFF99BB44);
      case PickupType.megaHeal:  return const Color(0xFFFF6699);
      case PickupType.overdrive: return const Color(0xFFFF8800);
      case PickupType.meteor:    return const Color(0xFFFF4400);
      case PickupType.freezeBomb:return const Color(0xFF44CCFF);
      case PickupType.timeWarp: return const Color(0xFF4488FF);
    }
  }

  // Spawn weight — common=3, uncommon=2, rare=1
  int get spawnWeight {
    switch (this) {
      case PickupType.apple:    return 3;
      case PickupType.revolver: return 3;
      case PickupType.lightning:return 3;
      case PickupType.ice:      return 3;
      case PickupType.shield:   return 2;
      case PickupType.speed:    return 2;
      case PickupType.bomb:     return 2;
      case PickupType.rapid:    return 2;
      case PickupType.magnet:   return 2;
      case PickupType.vortex:   return 1;
      case PickupType.star:     return 1;
      case PickupType.barrier:  return 1;
      case PickupType.mystery:  return 1;
      case PickupType.nuke:     return 1;
      case PickupType.triple:   return 1;
      case PickupType.ghost:    return 1;
      case PickupType.snare:    return 2;
      case PickupType.megaHeal:  return 2;
      case PickupType.overdrive: return 1;
      case PickupType.meteor:    return 1;
      case PickupType.freezeBomb:return 1;
      case PickupType.timeWarp: return 1;
    }
  }

  static PickupType weighted(Random rng) {
    final pool = <PickupType>[];
    for (final t in PickupType.values) {
      for (int i = 0; i < t.spawnWeight; i++) {
        pool.add(t);
      }
    }
    return pool[rng.nextInt(pool.length)];
  }

  /// A random non-mystery type (used when mystery is collected).
  static PickupType randomNonMystery(Random rng) {
    final options = PickupType.values
        .where((t) => t != PickupType.mystery)
        .toList();
    return options[rng.nextInt(options.length)];
  }
}

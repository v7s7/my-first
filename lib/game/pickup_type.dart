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
  rapid,   // halves hit cooldown for 6s
  magnet,  // homes orb toward boss for 8s
  barrier, // 3× damage for 4 hits
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

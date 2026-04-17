import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/start_screen.dart';
import 'screens/game_screen.dart';
import 'orbs/orb_registry.dart';
import 'modes/mode_registry.dart';
import 'game/arena_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  Map<String, String>? autoplayParams;
  if (kIsWeb) {
    final query = Uri.base.queryParameters;
    if (query['autoplay'] == 'true') {
      autoplayParams = query;
    }
  }

  runApp(BossBallApp(autoplayParams: autoplayParams));
}

class BossBallApp extends StatelessWidget {
  final Map<String, String>? autoplayParams;
  const BossBallApp({super.key, this.autoplayParams});

  @override
  Widget build(BuildContext context) {
    Widget home;

    if (autoplayParams != null) {
      try {
        final orbId    = autoplayParams!['orb']   ?? 'basic';
        final arenaId  = autoplayParams!['arena']  ?? 'normal';
        final modeId   = autoplayParams!['mode']   ?? 'time_attack';
        final customHp = int.tryParse(autoplayParams!['hp'] ?? '');

        final orb   = OrbRegistry.findById(orbId);
        final mode  = ModeRegistry.findById(modeId);
        final arena = ArenaPreset.values.firstWhere(
          (a) => a.name == arenaId,
          orElse: () => ArenaPreset.normal,
        );

        home = GameScreen(
          orbBehavior: orb,
          mode: mode,
          arenaPreset: arena,
          customBossHp: customHp,
        );
      } catch (_) {
        home = const StartScreen();
      }
    } else {
      home = const StartScreen();
    }

    return MaterialApp(
      title: 'Boss Ball Blitz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF080812),
      ),
      home: home,
    );
  }
}

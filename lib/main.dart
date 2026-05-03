import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:kultivate_new_ver/screens/splash_screen.dart';
import 'package:kultivate_new_ver/theme/kultivate_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Web has no google-services.json; Firebase requires explicit options via
  // `flutterfire configure` (lib/firebase_options.dart). Android/iOS use the
  // config files you already added.
  //
  // Never block app launch on Firebase: missing/outdated Play services, wrong
  // signing SHA in the Firebase project, or Huawei-style devices can throw
  // here and would otherwise crash before the first frame.
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
    } catch (e, st) {
      debugPrint('Firebase.initializeApp failed; continuing without Firebase: $e\n$st');
    }
  }
  runApp(const KultivateApp());
}

class KultivateApp extends StatelessWidget {
  const KultivateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: KultivateTheme.dark(),
      home: const SplashScreen(),
    );
  }
}
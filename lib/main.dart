import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:kultivate_new_ver/screens/splash_screen.dart';
import 'package:kultivate_new_ver/theme/kultivate_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Web has no google-services.json; Firebase requires explicit options via
  // `flutterfire configure` (lib/firebase_options.dart). Android/iOS use the
  // config files you already added.
  if (!kIsWeb) {
    await Firebase.initializeApp();
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
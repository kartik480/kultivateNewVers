import 'package:flutter/material.dart';
import 'package:kultivate_new_ver/screens/login_screen.dart';
import 'package:kultivate_new_ver/theme/kultivate_theme.dart';

void main() {
  runApp(const KultivateApp());
}

class KultivateApp extends StatelessWidget {
  const KultivateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: KultivateTheme.dark(),
      home: const LoginScreen(),
    );
  }
}
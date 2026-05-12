import 'package:flutter/material.dart';
import 'theme/mech_theme.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const ShiftDownloadsApp());
}

class ShiftDownloadsApp extends StatelessWidget {
  const ShiftDownloadsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShiftDownloads',
      theme: MechTheme.theme,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

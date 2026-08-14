import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/splash_screen.dart';
import 'theme/terminal_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(MakcoApp(token: prefs.getString('token')));
}

class MakcoApp extends StatelessWidget {
  final String? token;
  const MakcoApp({super.key, this.token});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MAKCO',
      debugShowCheckedModeBanner: false,
      theme: Terminal.theme(),
      home: SplashScreen(startToken: token),
    );
  }
}
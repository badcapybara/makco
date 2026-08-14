import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../theme/terminal_theme.dart';
import 'auth_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  final String? startToken;
  const SplashScreen({super.key, this.startToken});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final ApiService api = ApiService();
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(milliseconds: 140), (t) {
      if (mounted) setState(() => _frame = (_frame + 1) % 4);
    });
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final token = widget.startToken ?? prefs.getString('token');
    if (token != null && token.isNotEmpty) {
      api.setToken(token);
    }
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => token != null && token.isNotEmpty ? HomeScreen(api: api) : AuthScreen(api: api),
    ));
  }

  @override
  Widget build(BuildContext context) {
    const letters = ['M', 'A', 'K', 'C', 'O'];
    final visible = List.generate(5, (i) => i < _frame + 1);
    return Scaffold(
      backgroundColor: Terminal.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 5; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: SplitFlap(
                      visible[i] ? letters[i] : ' ',
                      width: 44,
                      height: 44,
                      fontSize: 22,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'CHENNAI TRANSIT TERMINAL',
              style: Terminal.mono(13, color: Terminal.dim, spacing: 3),
            ),
            const SizedBox(height: 12),
            Text(
              'SYSTEM INITIALIZING...',
              style: Terminal.mono(12, color: Terminal.green, spacing: 2),
            ),
          ],
        ),
      ),
    );
  }
}